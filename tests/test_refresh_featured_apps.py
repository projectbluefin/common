"""Tests for scripts/refresh-featured-apps.py. Offline: every source is a fake fetch."""

import importlib.util
import json
import shutil
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent
SCRIPT_PATH = ROOT / "scripts/refresh-featured-apps.py"
CURATED = ROOT / "system_files/bluefin/etc/bazaar/curated.yaml"


def _load_module():
    spec = importlib.util.spec_from_file_location("refresh_featured_apps", SCRIPT_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


m = _load_module()

TODAY = date(2026, 10, 31)


# --- trend ---------------------------------------------------------------


def test_trend_flat_series_is_about_zero():
    assert abs(m.trend([10] * 21)) < 1e-9


def test_trend_direction():
    assert m.trend([5] * 14 + [20] * 7) > 0
    assert m.trend([20] * 14 + [0] * 7) <= 0
    assert m.trend([0] * 21) <= 0


def test_trend_stays_inside_20():
    for s in ([0] * 14 + [10**9] * 7, [10**9] * 14 + [0] * 7, [3, 0] * 10 + [7]):
        assert abs(m.trend(s)) < 20


def test_trend_matches_flathub_trending_py():
    # calculate_trending_score(s, quality_passed_ratio=0, icon_quality_bonus=0,
    # is_eol=False, icons_passed=True): quality multiplier 1.
    assert m.trend([10] * 14 + [30] * 7) == pytest.approx(15.841105554240402)
    assert m.trend([50] * 14 + [40, 45, 38, 52, 41, 47, 39]) == pytest.approx(-2.027179062179923)


# --- percentiles / newness / score ---------------------------------------


def test_percentiles_mid_rank():
    assert m.percentiles([7]) == [0.5]
    p = m.percentiles([1, 2, 2, 3])
    assert p[1] == p[2]
    assert p == sorted(p)
    assert all(0 <= x <= 1 for x in p)


def test_newness_and_zero_weight():
    assert m.newness(0) == 1
    assert m.newness(730) == 0
    assert m.newness(5000) == 0
    assert m.newness(None) == 0
    pool = [_app(f"a{k}", trend=k, installs30=1000 - k, age_days=k * 100) for k in range(5)]
    m.score(pool, w_growth=0.75, w_new=0, w_size=0.25)
    for a in pool:
        assert a["hot"] == pytest.approx(0.75 * a["growth"] + 0.25 * a["size"])


# --- eligible ------------------------------------------------------------


def _app(app_id, source="flathub", **kw):
    app = {
        "id": app_id, "source": source, "listed": True, "eol": False, "updated_days": 10,
        "installs30": 10_000, "free": True, "trend": 1.0, "age_days": 100,
    }
    app.update(kw)
    return app


def _ctx(**kw):
    ctx = {
        "pins": set(), "deny": set(), "allow": set(), "blocklist": set(), "flatpark_filter": set(),
        "other_sections": {}, "preinstalled": set(), "full_desktop": set(),
    }
    ctx.update(kw)
    return ctx


@pytest.mark.parametrize(
    "app,ctx,reason",
    [
        (_app("x", eol=True), _ctx(), "EOL"),
        (_app("x", updated_days=400), _ctx(), "stale"),
        (_app("x", installs30=199), _ctx(), "below floor"),
        (_app("x", "flatpark", installs30=49, updated_days=None), _ctx(), "below floor"),
        (_app("x", free=False), _ctx(), "non-free license"),
        (_app("x"), _ctx(blocklist={"x"}), "blocklist.yaml"),
        (_app("x", "flatpark"), _ctx(flatpark_filter={"x"}), "flatpark.filter"),
        (_app("x"), _ctx(other_sections={"x": "Utilities"}), "now in Utilities"),
        (_app("x"), _ctx(preinstalled={"x"}), "preinstalled"),
        (_app("x"), _ctx(deny={"x"}), "denied"),
        (_app("x", listed=False), _ctx(), "not a listed desktop app"),
    ],
)
def test_eligible_reasons(app, ctx, reason):
    assert reason in m.eligible(app, ctx)


def test_eligible_passes_and_waivers(monkeypatch):
    assert m.eligible(_app("x"), _ctx()) is None
    assert m.eligible(_app("x", free=False), _ctx(allow={"x"})) is None
    # flatpark.filter only applies to the FlatPark remote
    assert m.eligible(_app("x"), _ctx(flatpark_filter={"x"})) is None
    assert m.eligible(_app("x"), _ctx(full_desktop={"x"})) is None
    monkeypatch.setattr(m, "EXCLUDE_FULL_DESKTOP", True)
    assert "full-desktop" in m.eligible(_app("x"), _ctx(full_desktop={"x"}))


def test_eligible_pins_skip_every_rule():
    bad = _app("p", eol=True, installs30=0, free=False, listed=False, updated_days=9999)
    ctx = _ctx(pins={"p"}, deny={"p"}, blocklist={"p"}, other_sections={"p": "AI"}, preinstalled={"p"})
    assert m.eligible(bad, ctx) is None


# --- select --------------------------------------------------------------


def _pool(prefix, n, source="flathub", top=0.99):
    return [{"id": f"{prefix}{k}", "source": source, "hot": top - k * 0.01} for k in range(n)]


PINS = [f"pin{k}" for k in range(7)]


def test_select_interleaves_seven_pins_and_five_scored():
    pools = {"flathub": _pool("fh", 20), "flatpark": _pool("fp", 5, "flatpark")}
    row = m.select(pools, incumbents=set(), pins=PINS, row_size=12, max_new=12)
    assert len(row) == 12
    kinds = "".join("P" if i in PINS else "S" for i in row)
    assert kinds == "PSPSPSPSPSPP"
    assert [i for i in row if i in PINS] == PINS
    scored = [i for i in row if i not in PINS]
    hot = {a["id"]: a["hot"] for p in pools.values() for a in p}
    assert [hot[i] for i in scored] == sorted((hot[i] for i in scored), reverse=True)


def test_select_flatpark_quota_and_backfill():
    pools = {"flathub": _pool("fh", 20, top=0.5), "flatpark": _pool("fp", 10, "flatpark")}
    row = m.select(pools, set(), [], row_size=5, flatpark_max=2, max_new=5)
    assert sum(i.startswith("fp") for i in row) == 2
    short = {"flathub": _pool("fh", 20), "flatpark": []}
    assert len(m.select(short, set(), [], row_size=5, flatpark_max=2, max_new=5)) == 5


def test_select_incumbent_bonus_hysteresis():
    pools = {"flathub": [
        {"id": "challenger", "source": "flathub", "hot": 0.90},
        {"id": "incumbent", "source": "flathub", "hot": 0.80},
    ]}
    assert m.select(pools, {"incumbent"}, [], row_size=1, bonus=0.15) == ["incumbent"]
    pools["flathub"][0]["hot"] = 0.96
    assert m.select(pools, {"incumbent"}, [], row_size=1, bonus=0.15) == ["challenger"]


def test_select_max_new_cap_keeps_incumbents():
    new = _pool("new", 8, top=0.99)
    old = _pool("old", 8, top=0.50)
    incumbents = {a["id"] for a in old}
    row = m.select({"flathub": new + old}, incumbents, [], row_size=8, bonus=0, max_new=4)
    assert sum(i.startswith("new") for i in row) == 4
    assert set(row) >= {"new0", "new1", "new2", "new3", "old0", "old1", "old2", "old3"}


def test_select_drops_ineligible_incumbents():
    # "gone" failed eligible(), so it is absent from every pool.
    row = m.select({"flathub": _pool("fh", 5)}, {"gone"}, [], row_size=3)
    assert "gone" not in row


def test_select_too_few_candidates_raises():
    with pytest.raises(m.Abort):
        m.select({"flathub": _pool("fh", 3)}, set(), PINS, row_size=12)


# --- rewrite_recommends --------------------------------------------------


def test_rewrite_only_touches_recommends_list(tmp_path):
    copy = tmp_path / "curated.yaml"
    shutil.copy(CURATED, copy)
    old = copy.read_text(encoding="utf-8")
    ids = ["com.example.One", "com.example.Two", "com.example.Three"]
    new = m.rewrite_recommends(old, ids)

    data = yaml.safe_load(new)
    assert m.recommends_section(data)["appids"]["list"] == ids
    old_lines, new_lines = old.splitlines(keepends=True), new.splitlines(keepends=True)
    title = old_lines.index(m.TITLE_LINE + "\n")
    start = old_lines.index(m.LIST_LINE + "\n", title) + 1
    n_old = len(m.recommends_section(yaml.safe_load(old))["appids"]["list"])
    assert old_lines[:start] == new_lines[:start]
    assert new_lines[start:start + 3] == [f"      - {i}\n" for i in ids]
    assert old_lines[start + n_old:] == new_lines[start + 3:]


def test_rewrite_title_must_be_unique():
    text = CURATED.read_text(encoding="utf-8")
    with pytest.raises(m.Abort):
        m.rewrite_recommends(text.replace(m.TITLE_LINE, "      en: Something Else"), ["a"])
    with pytest.raises(m.Abort):
        m.rewrite_recommends(text + "- section:\n    title:\n" + m.TITLE_LINE + "\n", ["a"])


def test_rewrite_guard_catches_wrong_list():
    # The first list after the title belongs to a different section: the guard must refuse.
    text = "rows:\n- section:\n    title:\n" + m.TITLE_LINE + "\n    appids: {list: [a]}\n- section:\n    title:\n      en: Other\n    appids:\n" + m.LIST_LINE + "\n      - b\n"
    with pytest.raises(m.Abort):
        m.rewrite_recommends(text, ["c"])


# --- source sanity -------------------------------------------------------


def _fake(routes):
    def fetch(url):
        if url not in routes:
            return "<!DOCTYPE html><html>404 Not Found</html>"
        body = routes[url]
        return body if isinstance(body, str) else json.dumps(body)
    return fetch


def _flathub_routes(total=1500, served=1500, per=250):
    pages = -(-total // per)
    routes = {}
    hits = [{"app_id": f"org.x.A{k}"} for k in range(served)]
    for p in range(1, pages + 1):
        routes[f"{m.FLATHUB}/collection/popular?per_page=250&page={p}"] = {
            "totalHits": total, "totalPages": pages, "hits": hits[(p - 1) * per:p * per],
        }
    routes[f"{m.FLATHUB}/eol/message"] = {"org.x.A3": "gone"}
    return routes


def test_load_flathub_complete_and_truncated():
    hits, eol = m.load_flathub(_fake(_flathub_routes()))
    assert len(hits) == 1500 and eol == {"org.x.A3"}
    with pytest.raises(m.Abort, match="incomplete"):
        m.load_flathub(_fake(_flathub_routes(served=1400)))


def test_duplicate_filter_uses_complete_catalog_and_sorts():
    assert m.render_flatpark_filter({"org.z.App", "org.a.App", "org.only.Flatpark"}, {"org.a.App", "org.z.App", "org.only.Flathub"}) == (
        "# Generated monthly by scripts/refresh-featured-apps.py; do not edit.\n"
        "deny app/org.a.App/*\n"
        "deny app/org.z.App/*\n"
    )


def test_flathub_catalog_rejects_incomplete_data():
    with pytest.raises(m.Abort, match="incomplete or invalid"):
        m.load_flathub_ids(_fake({f"{m.FLATHUB}/appstream": []}))


def _flatpark_routes(through=TODAY - timedelta(days=2), n_apps=60):
    routes = {
        f"{m.FLATPARK_STATS}/totals.json": {
            "since": "2026-10-04", "through": through.isoformat(),
            "apps": {f"org.fp.A{k}": {"installs30": k} for k in range(n_apps)},
        },
        m.FLATPARK_INDEX: [{"id": f"org.fp.A{k}"} for k in range(n_apps)],
    }
    for k in range(m.TREND_DAYS):
        day = (through - timedelta(days=k)).isoformat()
        routes[f"{m.FLATPARK_STATS}/daily/{day}.json"] = {"date": day, "apps": {"org.fp.A1": {"installs": k}}}
    return routes


def test_load_flatpark_ok():
    _, series, listed = m.load_flatpark(_fake(_flatpark_routes()), TODAY)
    assert listed == {f"org.fp.A{k}" for k in range(60)}
    assert series["org.fp.A1"] == list(range(20, -1, -1))


def test_load_flatpark_stale_raises():
    with pytest.raises(m.Abort, match="stale"):
        m.load_flatpark(_fake(_flatpark_routes(through=TODAY - timedelta(days=4))), TODAY)


def test_load_flatpark_missing_daily_file_raises():
    routes = _flatpark_routes()
    del routes[f"{m.FLATPARK_STATS}/daily/{(TODAY - timedelta(days=10)).isoformat()}.json"]
    with pytest.raises(m.Abort, match="not JSON"):
        m.load_flatpark(_fake(routes), TODAY)


def test_check_pins_raises_for_unknown_or_denied_pin():
    m.check_pins(["a", "b"], {"a"}, {"b"}, set(), set())
    with pytest.raises(m.Abort, match="neither"):
        m.check_pins(["a", "zzz"], {"a"}, set(), set(), set())
    with pytest.raises(m.Abort, match="denied"):
        m.check_pins(["a"], {"a"}, set(), {"a"}, set())


def test_parse_added_dates_keeps_earliest():
    log = "@2026-10-20\n\nregistry/a.B/flatpark.yml\n@2026-09-01\n\nregistry/a.B/flatpark.yml\nregistry/c.D/flatpark.yml\n"
    assert m.parse_added_dates(log) == {"a.B": date(2026, 9, 1), "c.D": date(2026, 9, 1)}


# --- main (end to end, offline) -------------------------------------------

NOW = datetime(2026, 10, 31, 12, 0, tzinfo=timezone.utc)
CONFIG_PINS = yaml.safe_load(m.CONFIG.read_text(encoding="utf-8"))["pins"]


def _world(flatpark_through=TODAY - timedelta(days=1)):
    """Fake Flathub + FlatPark sources big enough to pass every completeness check."""
    ts = NOW.timestamp()
    hits = [
        {
            "app_id": f"org.test.Hot{k:04d}", "type": "desktop-application", "is_free_license": True,
            "installs_last_month": 10_000 - k, "trending": 15 - k * 0.01,
            "added_at": ts - 30 * 86400, "updated_at": ts - 86400,
        }
        for k in range(m.FLATHUB_MIN_HITS)
    ]
    hits += [{"app_id": p, "type": "desktop-application"} for p in CONFIG_PINS]
    per = 250
    pages = -(-len(hits) // per)
    routes = {
        f"{m.FLATHUB}/collection/popular?per_page=250&page={p}": {
            "totalHits": len(hits), "totalPages": pages, "hits": hits[(p - 1) * per:p * per],
        }
        for p in range(1, pages + 1)
    }
    routes[f"{m.FLATHUB}/eol/message"] = {}
    routes[f"{m.FLATHUB}/appstream"] = [h["app_id"] for h in hits] + ["org.fp.App00"]
    fp_ids = [f"org.fp.App{k:02d}" for k in range(m.FLATPARK_MIN_APPS)]
    routes[f"{m.FLATPARK_STATS}/totals.json"] = {
        "since": "2026-10-01", "through": flatpark_through.isoformat(), "generated": "2026-10-31T01:30:00Z",
        "apps": {i: {"installs30": 500 + k} for k, i in enumerate(fp_ids)},
    }
    for k in range(m.TREND_DAYS):
        day = (flatpark_through - timedelta(days=k)).isoformat()
        routes[f"{m.FLATPARK_STATS}/daily/{day}.json"] = {
            "date": day, "apps": {i: {"installs": 40 - k} for i in fp_ids},
        }
    routes[m.FLATPARK_INDEX] = [{"id": i} for i in fp_ids]
    for i in fp_ids:
        routes[f"{m.FLATPARK_RAW}/{i}/flatpark.yml"] = "policy:\n  proprietary: false\n"
    added = {i: TODAY - timedelta(days=10) for i in fp_ids}
    return _fake(routes), (lambda: added)


@pytest.fixture
def curated_copy(tmp_path, monkeypatch):
    copy = tmp_path / "curated.yaml"
    shutil.copy(CURATED, copy)
    monkeypatch.setattr(m, "CURATED", copy)
    filter_copy = tmp_path / "flatpark.filter"
    filter_copy.write_text("deny app/org.old.App/*\n", encoding="utf-8")
    monkeypatch.setattr(m, "FLATPARK_FILTER", filter_copy)
    monkeypatch.delenv("GITHUB_RUN_ID", raising=False)
    return copy


def test_main_writes_recommends_row(curated_copy, tmp_path):
    before = curated_copy.read_text(encoding="utf-8")
    fetch, added = _world()
    report = tmp_path / "report.md"

    assert m.main(["--report", str(report)], fetch=fetch, added_dates=added, now=NOW) == 0

    after = curated_copy.read_text(encoding="utf-8")
    row = m.recommends_section(yaml.safe_load(after))["appids"]["list"]
    assert len(row) == m.ROW_SIZE
    assert [i for i in row if i in CONFIG_PINS] == CONFIG_PINS
    assert row[0] == CONFIG_PINS[0] and row[1] not in CONFIG_PINS
    assert sum(i.startswith("org.fp.") for i in row) == m.FLATPARK_MAX
    expected = yaml.safe_load(before)
    m.recommends_section(expected)["appids"]["list"] = row
    assert yaml.safe_load(after) == expected
    text = report.read_text(encoding="utf-8")
    assert "Monthly hotness refresh of the Bluefin Recommends row in Bazaar for 2026-10." in text
    assert "totalHits {}".format(m.FLATHUB_MIN_HITS + len(CONFIG_PINS)) in text
    assert "## How this PR merges" in text
    assert m.FLATPARK_FILTER.read_text(encoding="utf-8") == (
        "# Generated monthly by scripts/refresh-featured-apps.py; do not edit.\n"
        "deny app/org.fp.App00/*\n"
    )
    assert "Added:\n- `org.fp.App00`" in text
    assert "Removed:\n- `org.old.App`" in text
    assert "- Run:" not in text


def test_main_dry_run_prints_and_leaves_curated_alone(curated_copy, capsys):
    before = curated_copy.read_text(encoding="utf-8")
    before_filter = m.FLATPARK_FILTER.read_text(encoding="utf-8")
    fetch, added = _world()

    assert m.main(["--dry-run"], fetch=fetch, added_dates=added, now=NOW) == 0

    assert curated_copy.read_text(encoding="utf-8") == before
    assert m.FLATPARK_FILTER.read_text(encoding="utf-8") == before_filter
    out = capsys.readouterr().out
    printed_row = out.split("\n\n", 1)[0].splitlines()
    assert len(printed_row) == m.ROW_SIZE and printed_row[0] == CONFIG_PINS[0]
    assert "### Added" in out and "### Removed" in out and "### Runners-up (next 5 per source)" in out
    old_row = m.recommends_section(yaml.safe_load(before))["appids"]["list"]
    gone = next(i for i in old_row if i not in printed_row)
    assert f"- `{gone}`: " in out


def test_main_report_links_the_actions_run(curated_copy, tmp_path, monkeypatch):
    monkeypatch.setenv("GITHUB_RUN_ID", "42")
    monkeypatch.setenv("GITHUB_SERVER_URL", "https://github.com")
    monkeypatch.setenv("GITHUB_REPOSITORY", "projectbluefin/common")
    fetch, added = _world()
    report = tmp_path / "report.md"

    assert m.main(["--dry-run", "--report", str(report)], fetch=fetch, added_dates=added, now=NOW) == 0

    assert "- Run: https://github.com/projectbluefin/common/actions/runs/42" in report.read_text(encoding="utf-8")


def test_main_aborts_without_writing_on_bad_source(curated_copy, tmp_path, capsys):
    before = curated_copy.read_text(encoding="utf-8")
    fetch, added = _world(flatpark_through=TODAY - timedelta(days=m.FLATPARK_MAX_LAG_DAYS + 2))
    report = tmp_path / "report.md"

    assert m.main(["--report", str(report)], fetch=fetch, added_dates=added, now=NOW) == 1

    assert curated_copy.read_text(encoding="utf-8") == before
    assert not report.exists()
    assert "error: FlatPark stats stale" in capsys.readouterr().err


def test_main_aborts_on_unexpected_source_shape(curated_copy, capsys):
    before = curated_copy.read_text(encoding="utf-8")
    fetch, added = _world()

    def broken(url):
        return "{}" if url.endswith("/totals.json") else fetch(url)

    assert m.main([], fetch=broken, added_dates=added, now=NOW) == 1

    assert curated_copy.read_text(encoding="utf-8") == before
    assert "error: unexpected source or file shape: KeyError('through')" in capsys.readouterr().err
