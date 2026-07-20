#!/usr/bin/env python3
"""Verify all relative .md links inside docs/ point to existing files."""
import os
import re
import sys
from pathlib import Path

DOCS_DIR = Path("docs")
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+\.md)\)")
EXTERNAL = re.compile(r"^[a-z][a-z0-9+.-]*://", re.IGNORECASE)

broken = 0

for src in sorted(DOCS_DIR.rglob("*.md")):
    text = src.read_text(encoding="utf-8")
    for _label, target in LINK_RE.findall(text):
        if EXTERNAL.match(target):
            continue
        # Drop URL anchors
        target = target.split("#", 1)[0]
        target = target.replace("%20", " ")
        if target.startswith("/"):
            resolved = Path(target.lstrip("/"))
        else:
            resolved = (src.parent / target).resolve()
        if not resolved.exists():
            print(f"error: broken link in {src.as_posix()} -> {target}")
            broken += 1

sys.exit(1 if broken else 0)
