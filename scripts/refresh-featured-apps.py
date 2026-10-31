#!/usr/bin/env python3
"""Refresh the "Bluefin Recommends" row in Bazaar's curated.yaml by hotness.

Run monthly by .github/workflows/bazaar-featured-refresh.yml. Editorial input
(pins, deny, allow) lives in .github/bazaar-featured.yaml; scoring constants
live below.

Sources: Flathub's /collection/popular and /eol/message APIs, and FlatPark's
published stats rollup (dl.flatpark.org/stats), search index and registry.
Any missing, stale or partial source aborts the run (exit 1) so a short or
empty row is never written.

Score per source: hot = W_GROWTH*pct(trend) + W_NEW*newness + W_SIZE*pct(installs30).
The row interleaves pins with scored apps: pin, scored, pin, scored, ...

Usage: refresh-featured-apps.py [--report PATH] [--dry-run]
"""
import argparse
import bisect
import http.client
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / ".github/bazaar-featured.yaml"
CURATED = ROOT / "system_files/bluefin/etc/bazaar/curated.yaml"
BLOCKLIST = ROOT / "system_files/bluefin/etc/bazaar/blocklist.yaml"
FLATPARK_FILTER = ROOT / "system_files/shared/usr/share/flatpak/flatpark.filter"
HOMEBREW = ROOT / "system_files/bluefin/usr/share/ublue-os/homebrew"
PREINSTALLED = [HOMEBREW / "system-flatpaks.Brewfile", HOMEBREW / "system-dx-flatpaks.Brewfile"]
FULL_DESKTOP = HOMEBREW / "full-desktop.Brewfile"
PR_TEMPLATE = ROOT / ".github/pull_request_template.md"

FLATHUB = "https://flathub.org/api/v2"
FLATPARK_STATS = "https://dl.flatpark.org/stats"
FLATPARK_INDEX = "https://flatpark.org/search-index.json"
FLATPARK_REPO = "https://github.com/flatpark/flatpark"
FLATPARK_RAW = "https://raw.githubusercontent.com/flatpark/flatpark/main/registry"

ROW_SIZE = 12  # pins + scored slots
FLATPARK_MAX = 2  # scored FlatPark slots; unused slots go to Flathub
INCUMBENT_BONUS = 0.15  # hysteresis: added to `hot` for apps already in the row
MAX_NEW = 4  # additions per month; extra slots keep the best eligible incumbents
W_GROWTH, W_NEW, W_SIZE = 0.60, 0.25, 0.15
NEWNESS_DAYS = 730  # newness decays linearly to 0 at this age
FLATHUB_FLOOR = 200  # installs_last_month
FLATPARK_FLOOR = 50  # installs30
STALE_DAYS = 365  # Flathub apps without an update this long are skipped
EXCLUDE_FULL_DESKTOP = False  # also skip apps the full-desktop Brewfile offers
FLATHUB_MIN_HITS = 1000
FLATPARK_MIN_APPS = 50
FLATPARK_MAX_LAG_DAYS = 3
TREND_DAYS = 21

TITLE_LINE = "      en: Bluefin Recommends"
LIST_LINE = "      list:"
ITEM_RE = re.compile(r"      - \S+\n?")

USER_AGENT = "projectbluefin-common-featured-refresh"
TRANSIENT_HTTP_STATUSES = {429, 500, 502, 503, 504}
RETRY_BACKOFF_SECONDS = (2, 8)
REQUEST_TIMEOUT_SECONDS = 30


class Abort(Exception):
    """A source or safety check failed; nothing is written."""


def http_get(url):
    """GET url as text: 3 attempts with 2s/8s backoff on transient errors."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(len(RETRY_BACKOFF_SECONDS) + 1):
        try:
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
                return resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code not in TRANSIENT_HTTP_STATUSES:
                raise Abort(f"{url}: HTTP {e.code}") from e
            err = e
        except (urllib.error.URLError, TimeoutError, http.client.HTTPException) as e:
            err = e
        if attempt < len(RETRY_BACKOFF_SECONDS):
            time.sleep(RETRY_BACKOFF_SECONDS[attempt])
    raise Abort(f"{url}: {err} (gave up after {attempt + 1} attempts)")


def fetch_json(fetch, url):
    """fetch(url) parsed as JSON; an HTML error page or other non-JSON aborts."""
    text = fetch(url)
    try:
        return json.loads(text)
    except ValueError as e:
        raise Abort(f"{url}: not JSON (HTML error page?): {text[:80]!r}") from e


def load_flathub(fetch):
    """All /collection/popular hits plus EOL ids. Aborts on an incomplete page set."""
    url = f"{FLATHUB}/collection/popular?per_page=250&page="
    first = fetch_json(fetch, url + "1")
    total = first["totalHits"]
    hits = list(first["hits"])
    for page in range(2, first["totalPages"] + 1):
        hits += fetch_json(fetch, url + str(page))["hits"]
    if total < FLATHUB_MIN_HITS or len(hits) != total:
        raise Abort(f"Flathub incomplete: collected {len(hits)} hits, totalHits {total}")
    return hits, set(fetch_json(fetch, f"{FLATHUB}/eol/message"))


def load_flatpark(fetch, today):
    """(totals, {id: 21 daily installs ending at `through`}, listed ids). Aborts if stale or partial."""
    totals = fetch_json(fetch, f"{FLATPARK_STATS}/totals.json")
    through = date.fromisoformat(totals["through"])
    if (today - through).days > FLATPARK_MAX_LAG_DAYS:
        raise Abort(f"FlatPark stats stale: through {through}, today {today}")
    if len(totals["apps"]) < FLATPARK_MIN_APPS:
        raise Abort(f"FlatPark totals has only {len(totals['apps'])} apps")
    series = {}
    for k in range(TREND_DAYS):
        day = (through - timedelta(days=TREND_DAYS - 1 - k)).isoformat()
        daily = fetch_json(fetch, f"{FLATPARK_STATS}/daily/{day}.json")
        if not isinstance(daily, dict) or daily.get("date") != day or not isinstance(daily.get("apps"), dict):
            raise Abort(f"FlatPark daily file {day} has an unexpected shape")
        for app_id, stats in daily["apps"].items():
            series.setdefault(app_id, [0] * TREND_DAYS)[k] = stats.get("installs", 0)
    listed = {entry["id"] for entry in fetch_json(fetch, FLATPARK_INDEX)}
    return totals, series, listed


def flatpark_policy(fetch, ids):
    """{id: proprietary} from each registry/<id>/flatpark.yml; a missing policy counts as proprietary."""
    return {
        i: (yaml.safe_load(fetch(f"{FLATPARK_RAW}/{i}/flatpark.yml")) or {}).get("policy", {}).get("proprietary", True)
        for i in ids
    }


def parse_added_dates(log):
    """{id: earliest date} from `git log --diff-filter=A --format=@%as --name-only` output."""
    added, day = {}, None
    for line in log.splitlines():
        if line.startswith("@"):
            day = date.fromisoformat(line[1:])
        elif m := re.fullmatch(r"registry/([^/]+)/flatpark\.yml", line):
            added[m[1]] = min(added.get(m[1], day), day)
    return added


def flatpark_added_dates():
    """When each FlatPark registry entry was added: one blobless clone, no API rate limit."""
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["git", "clone", "-q", "--filter=blob:none", "--no-checkout", FLATPARK_REPO, d], check=True, timeout=300)
        log = subprocess.run(
            ["git", "-C", d, "log", "--diff-filter=A", "--format=@%as", "--name-only", "--", "registry/*/flatpark.yml"],
            check=True, capture_output=True, text=True, timeout=300,
        ).stdout
    return parse_added_dates(log)


def trend(s):
    """Port of flathub-infra/website backend/app/trending.py with the quality multiplier at 1."""
    base, recent = sum(s[:14]) / 14, sum(s[14:]) / 7
    g = (recent - base) / (abs(base) + 5)
    if recent <= 0:
        g = min(g, 0)
    volume = sum(abs(v) for v in s[14:])
    conf = volume / (volume + 50)
    disp = math.sqrt(sum((v - recent) ** 2 for v in s[14:]) / 7)
    cons = abs(recent) / (abs(recent) + disp) if abs(recent) + disp else 0
    t = 20 * math.tanh(20 * g * conf * (0.5 + 0.5 * cons) / 20)
    return max(min(t, math.nextafter(20, 0)), math.nextafter(-20, 0))  # tanh rounds to ±1 for big inputs


def percentiles(values):
    """Mid-rank percentile of each value within values, in [0, 1]; ties share a rank."""
    ordered = sorted(values)
    n = len(ordered)
    return [(bisect.bisect_left(ordered, v) + bisect.bisect_right(ordered, v)) / (2 * n) for v in values]


def newness(age_days):
    """1 when brand new, 0 at NEWNESS_DAYS or when the age is unknown."""
    if age_days is None:
        return 0.0
    return min(max(1 - age_days / NEWNESS_DAYS, 0.0), 1.0)


def score(pool, w_growth=W_GROWTH, w_new=W_NEW, w_size=W_SIZE):
    """Set growth/size percentiles, newness and hot on each app of one source's pool."""
    for app, g, s in zip(pool, percentiles([a["trend"] for a in pool]), percentiles([a["installs30"] for a in pool])):
        app.update(growth=g, size=s, newness=newness(app["age_days"]))
        app["hot"] = w_growth * g + w_new * app["newness"] + w_size * s


def flathub_app(hit, eol, now):
    added, updated = hit.get("added_at"), hit.get("updated_at")
    return {
        "id": hit["app_id"],
        "source": "flathub",
        "listed": hit.get("type") == "desktop-application",
        "eol": hit["app_id"] in eol,
        "updated_days": (now - updated) / 86400 if updated else None,
        "installs30": hit.get("installs_last_month") or 0,
        "free": bool(hit.get("is_free_license")),
        "trend": hit.get("trending") or 0.0,
        "age_days": (now - added) / 86400 if added else None,
    }


def flatpark_app(app_id, totals, series, listed, proprietary, added, today):
    return {
        "id": app_id,
        "source": "flatpark",
        "listed": app_id in listed,
        "eol": False,  # delisted apps drop out of totals.json
        "updated_days": None,  # wrappers are auto-bumped; no reliable date
        "installs30": totals["apps"][app_id].get("installs30", 0),
        "free": proprietary.get(app_id) is False,
        "trend": trend(series.get(app_id, [0] * TREND_DAYS)),
        "age_days": (today - added[app_id]).days if app_id in added else None,
    }


def eligible(app, ctx):
    """None if app may take a scored slot, else the reason it may not."""
    i = app["id"]
    if i in ctx["pins"]:
        return None
    if i in ctx["deny"]:
        return "denied in .github/bazaar-featured.yaml"
    if i in ctx["blocklist"]:
        return "in blocklist.yaml"
    if app["source"] == "flatpark" and i in ctx["flatpark_filter"]:
        return "denied by flatpark.filter"
    if i in ctx["preinstalled"]:
        return "preinstalled"
    if i in ctx["other_sections"]:
        return f"now in {ctx['other_sections'][i]}"
    if EXCLUDE_FULL_DESKTOP and i in ctx["full_desktop"]:
        return "in full-desktop.Brewfile"
    if not app["listed"]:
        return "not a listed desktop app"
    if app["eol"]:
        return "EOL"
    if app["updated_days"] is not None and app["updated_days"] > STALE_DAYS:
        return f"stale (no update in {app['updated_days']:.0f} days)"
    floor = FLATHUB_FLOOR if app["source"] == "flathub" else FLATPARK_FLOOR
    if app["installs30"] < floor:
        return f"below floor ({app['installs30']} < {floor} installs/30d)"
    if not app["free"] and i not in ctx["allow"]:
        return "non-free license"
    return None


def interleave(pins, scored):
    """pin1, scored1, pin2, scored2, ...; the longer list's remainder goes last."""
    row = []
    for k in range(max(len(pins), len(scored))):
        row += pins[k:k + 1] + scored[k:k + 1]
    return row


def select(pools, incumbents, pins, row_size=ROW_SIZE, flatpark_max=FLATPARK_MAX, bonus=INCUMBENT_BONUS, max_new=MAX_NEW):
    """Ordered row ids from scored pools {"flathub": [...], "flatpark": [...]}. Pure."""
    def key(a):
        return a["hot"] + (bonus if a["id"] in incumbents else 0)

    def ranked(src):
        return sorted((a for a in pools.get(src, []) if a["id"] not in pins), key=key, reverse=True)

    n = row_size - len(pins)
    picks = ranked("flatpark")[:min(flatpark_max, n)]
    picks += ranked("flathub")[:n - len(picks)]
    picked = {a["id"] for a in picks}
    spare = sorted(
        (a for pool in pools.values() for a in pool if a["id"] in incumbents and a["id"] not in picked and a["id"] not in pins),
        key=key, reverse=True,
    )
    new = sorted((a for a in picks if a["id"] not in incumbents), key=key)
    for drop in new[:max(0, len(new) - max_new)]:  # lowest-ranked new picks first
        fp_left = sum(a["source"] == "flatpark" for a in picks if a is not drop)
        sub = next((a for a in spare if a["source"] != "flatpark" or fp_left < flatpark_max), None)
        if sub is None:
            continue
        picks[picks.index(drop)] = sub
        spare.remove(sub)
    if len(picks) < n:
        raise Abort(f"only {len(picks)} eligible apps for {n} scored slots")
    return interleave(list(pins), [a["id"] for a in sorted(picks, key=lambda a: a["hot"], reverse=True)])


def recommends_section(data):
    sections = [r["section"] for r in data["rows"] if "section" in r and r["section"]["title"].get("en") == "Bluefin Recommends"]
    if len(sections) != 1:
        raise Abort(f"expected one Bluefin Recommends section, found {len(sections)}")
    return sections[0]


def rewrite_recommends(text, ids):
    """Replace only the Recommends appids.list lines; raise if anything else would change."""
    lines = text.splitlines(keepends=True)
    titles = [k for k, line in enumerate(lines) if line.rstrip("\n") == TITLE_LINE]
    if len(titles) != 1:
        raise Abort(f"expected one {TITLE_LINE.strip()!r} line in curated.yaml, found {len(titles)}")
    start = next((k for k in range(titles[0], len(lines)) if lines[k].rstrip("\n") == LIST_LINE), None)
    if start is None:
        raise Abort("no appids list after the Bluefin Recommends title")
    start += 1
    end = start
    while end < len(lines) and ITEM_RE.fullmatch(lines[end]):
        end += 1
    new = "".join(lines[:start] + [f"      - {i}\n" for i in ids] + lines[end:])
    expected = yaml.safe_load(text)
    recommends_section(expected)["appids"]["list"] = list(ids)
    if yaml.safe_load(new) != expected:
        raise Abort("rewriting the Recommends list would change curated.yaml outside that list")
    return new


def _fmt(app, incumbents, pins):
    status = "pin" if app["id"] in pins else "kept" if app["id"] in incumbents else "new"
    if "hot" not in app:
        return f"`{app['id']}` | {app['source']} | – | – | – | – | – | – | {status}"
    return (
        f"`{app['id']}` | {app['source']} | {app['installs30']} | {app['trend']:.2f} | {app['growth']:.2f}"
        f" | {app['size']:.2f} | {app['newness']:.2f} | {app['hot']:.3f} | {status}"
    )


def render_report(*, month, fetched_at, flathub_hits, flatpark_totals, pools, row, old_row, pins, incumbents, reasons, run_url=None, merge_section=""):
    """Markdown PR body for the refresh."""
    by_id = {a["id"]: a for pool in pools.values() for a in pool}
    scored = [by_id[i] for i in row if i not in pins]
    cut = min((a["hot"] + (INCUMBENT_BONUS if a["id"] in incumbents else 0) for a in scored), default=0.0)
    header = "app | source | 30d installs | trend | pct(trend) | pct(installs) | newness | hot | status"
    out = [
        "# bluefin-common PR",
        "",
        "## What does this change?",
        "",
        f"Monthly hotness refresh of the Bluefin Recommends row in Bazaar for {month}.",
        "",
        "## Why?",
        "",
        "Recommends is the discovery row. `scripts/refresh-featured-apps.py` keeps it to apps that are rising now:",
        f"pins from `.github/bazaar-featured.yaml`, interleaved with the {len(scored)} hottest eligible FOSS apps",
        f"(hot = {W_GROWTH} pct(trend) + {W_NEW} newness + {W_SIZE} pct(installs), per source;",
        f"incumbent bonus {INCUMBENT_BONUS}, at most {MAX_NEW} new and {FLATPARK_MAX} FlatPark apps a month).",
        "",
        "Data:",
        f"- Flathub `/collection/popular` fetched {fetched_at}: totalHits {flathub_hits}, {len(pools['flathub'])} eligible.",
        (
            f"- FlatPark stats `{flatpark_totals['since']}` through `{flatpark_totals['through']}`"
            f" (generated {flatpark_totals.get('generated')}): {len(pools['flatpark'])} eligible."
        ),
    ]
    if run_url:
        out.append(f"- Run: {run_url}")
    added = [i for i in row if i not in old_row]
    removed = [i for i in old_row if i not in row]
    out += ["", "### Added", ""]
    out += [f"- `{i}`: " + ("pin" if i in pins else f"{by_id[i]['source']}, hot {by_id[i]['hot']:.3f}, {by_id[i]['installs30']} installs/30d, trend {by_id[i]['trend']:.2f}") for i in added] or ["None."]
    out += ["", "### Removed", ""]
    for i in removed:
        if i in by_id:
            reason = f"score {by_id[i]['hot'] + INCUMBENT_BONUS:.3f} < cut {cut:.3f}"
        else:
            reason = reasons.get(i, "not found on Flathub or FlatPark")
        out.append(f"- `{i}`: {reason}")
    if not removed:
        out.append("None.")
    out += ["", "### New row", "", f"\\# | {header}", "--- | " + " | ".join(["---"] * 9)]
    for k, i in enumerate(row, 1):
        app = by_id.get(i, {"id": i, "source": "pin"})
        out.append(f"{k} | {_fmt(app, incumbents, pins)}")
    out += ["", "### Runners-up (next 5 per source)", ""]
    for src in ("flathub", "flatpark"):
        rest = sorted(
            (a for a in pools[src] if a["id"] not in row),
            key=lambda a: a["hot"] + (INCUMBENT_BONUS if a["id"] in incumbents else 0),
            reverse=True,
        )[:5]
        out += [f"**{src}**", "", header, " | ".join(["---"] * 9)]
        out += [_fmt(a, incumbents, pins) for a in rest]
        out.append("")
    out += [
        "### How to veto",
        "",
        "Add the id to `deny` in `.github/bazaar-featured.yaml` on main (with the reason in a comment) and re-run",
        "*Refresh Bazaar featured apps* with workflow dispatch, or push a fix to this branch. To keep an app",
        "permanently, add it to `pins`.",
        "",
        "> [!WARNING]",
        "> Do not auto-merge this PR. It is opened by a bot token that can bypass review rules; it needs",
        "> 2 human approvals plus Prow `/lgtm` and `/approve` like any other PR.",
        "",
        merge_section.rstrip(),
        "",
    ]
    return "\n".join(out)


def brewfile_flatpaks(path):
    return set(re.findall(r'^flatpak "([^"]+)"', path.read_text(encoding="utf-8"), re.M))


def check_pins(pins, flathub_ids, flatpark_listed, blocklist, flatpark_filter):
    for p in pins:
        if p not in flathub_ids and p not in flatpark_listed:
            raise Abort(f"pin {p} is in neither Flathub popular nor FlatPark search-index.json")
        if p in blocklist or p in flatpark_filter:
            raise Abort(f"pin {p} is denied by blocklist.yaml or flatpark.filter")


def main(argv=None, fetch=http_get, added_dates=flatpark_added_dates, now=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--report", type=Path, help="write the PR-body Markdown here")
    ap.add_argument("--dry-run", action="store_true", help="print the row and report; do not write curated.yaml")
    args = ap.parse_args(argv)
    now = now or datetime.now(timezone.utc)
    try:
        config = yaml.safe_load(CONFIG.read_text(encoding="utf-8"))
        pins = list(config["pins"])
        text = CURATED.read_text(encoding="utf-8")
        data = yaml.safe_load(text)
        old_row = list(recommends_section(data)["appids"]["list"])
        incumbents = set(old_row) - set(pins)
        other_sections = {
            i: r["section"]["title"]["en"]
            for r in data["rows"] if "section" in r and r["section"]["title"].get("en") != "Bluefin Recommends"
            for i in r["section"]["appids"]["list"]
        }
        blocklist = {i for b in yaml.safe_load(BLOCKLIST.read_text(encoding="utf-8"))["blocklists"] for i in b.get("block", [])}
        flatpark_filter = set(re.findall(r"^deny app/([^/\s]+)/", FLATPARK_FILTER.read_text(encoding="utf-8"), re.M))
        ctx = {
            "pins": set(pins),
            "deny": set(config.get("deny") or []),
            "allow": set(config.get("allow") or []),
            "blocklist": blocklist,
            "flatpark_filter": flatpark_filter,
            "other_sections": other_sections,
            "preinstalled": set().union(*map(brewfile_flatpaks, PREINSTALLED)),
            "full_desktop": brewfile_flatpaks(FULL_DESKTOP),
        }

        hits, eol = load_flathub(fetch)
        totals, series, listed = load_flatpark(fetch, now.date())
        check_pins(pins, {h["app_id"] for h in hits}, listed, blocklist, flatpark_filter)

        reasons = {}
        fh = []
        for hit in hits:
            app = flathub_app(hit, eol, now.timestamp())
            reason = eligible(app, ctx)
            if reason is None and app["id"] not in ctx["pins"]:
                fh.append(app)
            elif reason:
                reasons[app["id"]] = reason
        fh_ids = {a["id"] for a in fh}
        candidates = [i for i in totals["apps"] if i in listed and totals["apps"][i].get("installs30", 0) >= FLATPARK_FLOOR]
        proprietary = flatpark_policy(fetch, candidates)
        added = added_dates()
        fp = []
        for app_id in totals["apps"]:
            app = flatpark_app(app_id, totals, series, listed, proprietary, added, now.date())
            reason = eligible(app, ctx)
            if reason is None and app_id not in ctx["pins"] and app_id not in fh_ids:
                fp.append(app)
            elif reason and app_id not in fh_ids:
                reasons.setdefault(app_id, reason)
        pools = {"flathub": fh, "flatpark": fp}
        for pool in pools.values():
            score(pool)
        row = select(pools, incumbents, pins)
        new_text = rewrite_recommends(text, row)
    except (Abort, KeyError, OSError, subprocess.SubprocessError, yaml.YAMLError) as e:
        print(f"error: {e}" if isinstance(e, Abort) else f"error: unexpected source or file shape: {e!r}", file=sys.stderr)
        return 1

    run_url = None
    if os.environ.get("GITHUB_RUN_ID"):
        run_url = f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    template = PR_TEMPLATE.read_text(encoding="utf-8")
    merge = re.search(r"^## How this PR merges\n.*?(?=^## )", template, re.M | re.S)
    report = render_report(
        month=now.strftime("%Y-%m"),
        fetched_at=now.strftime("%Y-%m-%d %H:%M UTC"),
        flathub_hits=len(hits),
        flatpark_totals=totals,
        pools=pools,
        row=row,
        old_row=old_row,
        pins=pins,
        incumbents=incumbents,
        reasons=reasons,
        run_url=run_url,
        merge_section=merge[0] if merge else "",
    )
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    if args.dry_run:
        print("\n".join(row))
        print()
        print(report)
    else:
        CURATED.write_text(new_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
