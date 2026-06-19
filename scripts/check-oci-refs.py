#!/usr/bin/env python3
"""Guard against ublue-os→projectbluefin OCI image ref regressions.

Only testing-stream tags are allowed under ghcr.io/projectbluefin/bluefin,
and only in the explicitly whitelisted workflow files.
See docs/skills/image-registry.md for details.
"""
from pathlib import Path
import re
import sys

allowed_refs = {
    Path(".github/workflows/promotion-candidate-e2e.yml"): {
        "ghcr.io/projectbluefin/bluefin:testing",
        "ghcr.io/projectbluefin/bluefin:lts-testing",
    },
    Path(".github/workflows/e2e.yml"): {
        "ghcr.io/projectbluefin/bluefin:testing",
        "ghcr.io/projectbluefin/bluefin:lts-testing",
    },
    Path(".github/workflows/pr-e2e.yml"): {
        "ghcr.io/projectbluefin/bluefin:testing",
    },
}
pattern = re.compile(r"ghcr\.io/projectbluefin/(bluefin|aurora|bazzite)(?::[A-Za-z0-9._-]+)?")
candidates = [
    path
    for path in Path(".github/workflows").rglob("*.yml")
    if path.name != "validate.yml"
]
candidates += list(Path(".github/workflows").rglob("*.yaml"))

violations = []
for path in candidates:
    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        for match in pattern.finditer(line):
            ref = match.group(0)
            if ref in allowed_refs.get(path, set()):
                continue
            violations.append(f"{path}:{lineno}:{ref}")

if violations:
    print("")
    print("ERROR: Found disallowed projectbluefin OCI image refs:")
    for violation in violations:
        print(f"  - {violation}")
    print("")
    print("Production images are still published at ghcr.io/ublue-os/.")
    print("Only testing-stream tags are allowed under ghcr.io/projectbluefin/bluefin,")
    print("and only in the explicitly whitelisted workflow files:")
    for allowed_path, allowed in allowed_refs.items():
        print(f"  {allowed_path}: {sorted(allowed)}")
    print("See docs/skills/image-registry.md for details.")
    sys.exit(1)
