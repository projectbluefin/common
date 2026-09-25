#!/usr/bin/env python3
"""Validate OCI image references in workflow files and docs against GHCR.

Two checks:
  1. No ghcr.io/ublue-os/ references remain anywhere (org migration is complete).
  2. Every ghcr.io/projectbluefin/IMAGE:TAG reference in docs/ resolves to a
     real tag that exists in GHCR.

For check 2, run with GITHUB_TOKEN set (or GH_TOKEN) to avoid rate limits.
In CI, github.token is available automatically.

Source of truth for valid image names and tags:
  projectbluefin/bluefin  → .github/workflows/execute-release.yml
  projectbluefin/bluefin-lts → .github/workflows/execute-release.yml
  projectbluefin/dakota   → .github/workflows/execute-release.yml

Do not update the allowed list below from memory. Read the workflow files.
"""
from pathlib import Path
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

# HTTP statuses that indicate transient infrastructure failures or rate limits,
# where retrying makes sense. 401 and non-rate-limit 403 are excluded as auth/permission
# failures are non-transient.
TRANSIENT_HTTP_STATUSES = {429, 500, 502, 503, 504}
MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 2

# ── Check 1: no ublue-os refs ────────────────────────────────────────────────
# The org migration from ublue-os to projectbluefin is complete.
# ghcr.io/ublue-os/ must not appear in workflow files or docs.
# Exception: build-time COPY sources in Containerfile (wallpapers) are allowed.
UBLUE_PATTERN = re.compile(r"ghcr\.io/ublue-os/")
UBLUE_EXCEPTIONS = {
    "Containerfile",   # build-time COPY of wallpapers — not a runtime ref
}
# Legitimate read-only upstream ublue-os sources that are not migration targets.
# These are build-time or upstream kernel dependencies, not projectbluefin images.
UBLUE_ALLOWED_UPSTREAMS = {
    "ghcr.io/ublue-os/bluefin-wallpapers-gnome",  # build-time wallpaper artwork source
    "ghcr.io/ublue-os/akmods-nvidia-open",         # upstream NVIDIA kernel modules
    "ghcr.io/ublue-os/akmods-extra",               # upstream extra kernel modules
}

UBLUE_SKIP_DIRS = {"docs/factory"}

# ── Check 2: all projectbluefin image:tag refs in docs exist in GHCR ─────────
TAG_PATTERN = re.compile(
    r"ghcr\.io/projectbluefin/([a-zA-Z0-9_/-]+):([a-zA-Z0-9._-]+)"
)


def check_ublue_refs(root=None):
    """Check 1: scan for ghcr.io/ublue-os/ refs that should have been migrated.

    Returns a list of violation strings (empty = clean).
    """
    root = Path(root) if root is not None else Path(".")
    violations = []
    paths = (
        list((root / ".github/workflows").rglob("*.yml"))
        + list((root / ".github/workflows").rglob("*.yaml"))
        + list((root / "docs").rglob("*.md"))
        + [root / "AGENTS.md"]
    )
    for path in paths:
        rel = path.as_posix()
        if any(rel.startswith(str(root / d)) for d in UBLUE_SKIP_DIRS):
            continue
        if path.name in UBLUE_EXCEPTIONS:
            continue
        try:
            text = path.read_text()
        except FileNotFoundError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if UBLUE_PATTERN.search(line):
                if any(allowed in line for allowed in UBLUE_ALLOWED_UPSTREAMS):
                    continue
                violations.append(f"{path}:{lineno}: {line.strip()}")
    return violations


def collect_tag_refs(root=None):
    """Check 2: collect ghcr.io/projectbluefin/IMAGE:TAG refs from docs.

    Returns dict mapping "image:tag" -> [location strings].
    """
    root = Path(root) if root is not None else Path(".")
    refs: dict[str, list[str]] = {}
    paths = list((root / "docs").rglob("*.md")) + [root / "AGENTS.md"]
    for path in paths:
        try:
            text = path.read_text()
        except FileNotFoundError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in TAG_PATTERN.finditer(line):
                image, tag = m.group(1), m.group(2)
                if tag.startswith("sha256"):
                    continue
                # Skip template/placeholder tags used in docs examples.
                if (
                    tag.endswith("-")
                    or tag.endswith("_")
                    or any(c.isupper() for c in tag)
                    or "placeholder" in tag
                    or "number" in tag
                ):
                    continue
                key = f"{image}:{tag}"
                refs.setdefault(key, []).append(f"{path}:{lineno}")
    return refs


def tag_exists_in_ghcr(image: str, tag: str):
    """Return True/False if image:tag existence in GHCR is known, or None if
    the GHCR packages API could not be reached after retries (transient
    outage/rate limit) -- callers must treat None as "unknown, don't fail"."""
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN", "")
    page = 1
    while True:
        url = (
            f"https://api.github.com/orgs/projectbluefin/packages/container"
            f"/{urllib.request.quote(image, safe='')}/versions"
            f"?per_page=100&page={page}"
        )
        req = urllib.request.Request(url)
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("X-GitHub-Api-Version", "2022-11-28")
        if token:
            req.add_header("Authorization", f"Bearer {token}")

        versions = None
        last_error = None
        for attempt in range(MAX_RETRIES + 1):
            try:
                with urllib.request.urlopen(req) as resp:
                    versions = json.loads(resp.read())
                last_error = None
                break
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    return False  # image doesn't exist at all
                is_rate_limit_403 = False
                if e.code == 403 and e.headers is not None:
                    # Treat 403 as transient only if rate-limit headers confirm it
                    rem = e.headers.get("x-ratelimit-remaining")
                    retry_after = e.headers.get("retry-after")
                    if (rem is not None and rem.strip() == "0") or retry_after is not None:
                        is_rate_limit_403 = True

                if e.code not in TRANSIENT_HTTP_STATUSES and not is_rate_limit_403:
                    raise
                last_error = e
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_BACKOFF_SECONDS * (2 ** attempt))

        if last_error is not None:
            print(
                f"  \u26a0 GHCR packages API returned HTTP {last_error.code} for "
                f"{image} after {MAX_RETRIES + 1} attempts -- skipping existence "
                "check for this ref (transient error, not a ref regression)."
            )
            return None

        if not versions:
            return False
        for version in versions:
            tags = version.get("metadata", {}).get("container", {}).get("tags", [])
            if tag in tags:
                return True
        if len(versions) < 100:
            break
        page += 1
    return False


def main(root=None):
    """Run both OCI ref checks. Returns exit code (0 = clean, 1 = violations)."""
    if root is None:
        root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")

    violations = check_ublue_refs(root)
    if violations:
        print("\nERROR: ghcr.io/ublue-os/ references found. The org migration is complete.")
        print("All runtime image refs must use ghcr.io/projectbluefin/.\n")
        for v in violations:
            print(f"  {v}")
        return 1

    refs = collect_tag_refs(root)
    if not refs:
        print("✓ No projectbluefin image:tag refs found in docs.")
        return 0

    missing = []
    skipped = []
    for key, locations in sorted(refs.items()):
        image, tag = key.rsplit(":", 1)
        exists = tag_exists_in_ghcr(image, tag)
        if exists is None:
            # Transient GHCR API error after retries — don't fail the build
            # over a registry hiccup, but don't silently claim it's fine.
            print(f"  ⚠ ghcr.io/projectbluefin/{key} (skipped, GHCR unreachable)")
            skipped.append(key)
            continue
        status = "✅" if exists else "❌"
        print(f"  {status} ghcr.io/projectbluefin/{key}")
        if not exists:
            for loc in locations:
                print(f"       referenced at: {loc}")
            missing.append(key)

    if skipped:
        print(
            "\nWARNING: GHCR packages API was unreachable (transient error) for "
            f"{len(skipped)} ref(s); their existence could not be verified this run:\n"
            + "\n".join(f"  ghcr.io/projectbluefin/{s}" for s in skipped)
        )

    if missing:
        print(
            "\nERROR: The following image:tag refs in docs do not exist in GHCR:\n"
            + "\n".join(f"  ghcr.io/projectbluefin/{m}" for m in missing)
            + "\n\nRead execute-release.yml and build-image-testing.yml in each repo"
            "\nbefore writing image names or tags. Do not use training data."
            "\nSee docs/skills/image-registry.md#verification for the exact commands."
        )
        return 1

    if skipped:
        print(
            f"\n✓ Validated {len(refs) - len(skipped)} of {len(refs)} image:tag refs against GHCR "
            f"({len(skipped)} skipped due to transient errors)."
        )
    else:
        print(f"\n✓ All {len(refs)} image:tag refs validated against GHCR.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
