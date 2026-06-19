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
import re
import subprocess
import sys

# ── Check 1: no ublue-os refs ────────────────────────────────────────────────
# The org migration from ublue-os to projectbluefin is complete.
# ghcr.io/ublue-os/ must not appear in workflow files or docs.
# Exception: build-time COPY sources in Containerfile (wallpapers) are allowed.
UBLUE_PATTERN = re.compile(r"ghcr\.io/ublue-os/")
UBLUE_EXCEPTIONS = {
    "Containerfile",   # build-time COPY of wallpapers — not a runtime ref
}

ublue_violations = []
for path in list(Path(".github/workflows").rglob("*.yml")) + \
            list(Path(".github/workflows").rglob("*.yaml")) + \
            list(Path("docs").rglob("*.md")) + \
            [Path("AGENTS.md")]:
    if path.name in UBLUE_EXCEPTIONS:
        continue
    try:
        text = path.read_text()
    except FileNotFoundError:
        continue
    for lineno, line in enumerate(text.splitlines(), start=1):
        if UBLUE_PATTERN.search(line):
            ublue_violations.append(f"{path}:{lineno}: {line.strip()}")

if ublue_violations:
    print("\nERROR: ghcr.io/ublue-os/ references found. The org migration is complete.")
    print("All runtime image refs must use ghcr.io/projectbluefin/.\n")
    for v in ublue_violations:
        print(f"  {v}")
    sys.exit(1)

# ── Check 2: all projectbluefin image:tag refs in docs exist in GHCR ─────────
# Parse docs/ and AGENTS.md for ghcr.io/projectbluefin/IMAGE:TAG.
# Validate each tag exists. Fail if any don't.
# This prevents committing docs that reference non-existent image tags.
TAG_PATTERN = re.compile(
    r"ghcr\.io/projectbluefin/([a-zA-Z0-9_/-]+):([a-zA-Z0-9._-]+)"
)

refs: dict[str, list[str]] = {}  # "image:tag" -> [locations]
for path in list(Path("docs").rglob("*.md")) + [Path("AGENTS.md")]:
    try:
        text = path.read_text()
    except FileNotFoundError:
        continue
    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in TAG_PATTERN.finditer(line):
            image, tag = m.group(1), m.group(2)
            # Skip digest-style tags (sha256-...)
            if tag.startswith("sha256"):
                continue
            key = f"{image}:{tag}"
            refs.setdefault(key, []).append(f"{path}:{lineno}")

if not refs:
    print("✓ No projectbluefin image:tag refs found in docs.")
    sys.exit(0)

import json, os, urllib.request, urllib.error

def tag_exists_in_ghcr(image: str, tag: str) -> bool:
    """Return True if image:tag exists in GHCR under projectbluefin."""
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN", "")
    # Use the GHCR container package versions API and paginate
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
        try:
            with urllib.request.urlopen(req) as resp:
                versions = json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return False  # image doesn't exist at all
            raise
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


missing = []
for key, locations in sorted(refs.items()):
    image, tag = key.rsplit(":", 1)
    exists = tag_exists_in_ghcr(image, tag)
    status = "✅" if exists else "❌"
    print(f"  {status} ghcr.io/projectbluefin/{key}")
    if not exists:
        for loc in locations:
            print(f"       referenced at: {loc}")
        missing.append(key)

if missing:
    print(
        "\nERROR: The following image:tag refs in docs do not exist in GHCR:\n"
        + "\n".join(f"  ghcr.io/projectbluefin/{m}" for m in missing)
        + "\n\nRead execute-release.yml and build-image-testing.yml in each repo"
        "\nbefore writing image names or tags. Do not use training data."
        "\nSee docs/skills/image-registry.md#verification for the exact commands."
    )
    sys.exit(1)

print(f"\n✓ All {len(refs)} image:tag refs validated against GHCR.")
