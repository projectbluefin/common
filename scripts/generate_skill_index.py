#!/usr/bin/env python3
"""Validate skill front matter and generate docs/skills/index.json from it.

Usage:
    python3 scripts/generate_skill_index.py --write   # regenerate index.json
    python3 scripts/generate_skill_index.py --check   # verify index.json is up to date (exit 1 if stale)

The catalog is validated against docs/skills/index.schema.json (JSON Schema
2020-12) before being written or compared; each skill must also have
name == id and stay under the line budget. This script is the only supported
way to produce index.json — do not hand-edit it.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "docs" / "skills"
SCHEMA_PATH = SKILLS_DIR / "index.schema.json"
INDEX_PATH = SKILLS_DIR / "index.json"
SCHEMA_VERSION = "1.0"
MAX_LINES_SOFT = 200
MAX_LINES_HARD = 500

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)


def find_skill_files() -> list[Path]:
    """Return every skill's canonical Markdown file, flat and per-directory."""
    files = sorted(p for p in SKILLS_DIR.glob("*.md") if p.name != "index.md")
    files += sorted(SKILLS_DIR.glob("*/SKILL.md"))
    return files


def parse_front_matter(path: Path) -> dict:
    text = path.read_text()
    m = FRONTMATTER_RE.match(text)
    if not m:
        raise ValueError(f"{path}: no YAML front matter found")
    data = yaml.safe_load(m.group(1))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: front matter did not parse to a mapping")
    return data


def build_skill_entry(path: Path) -> dict:
    fm = parse_front_matter(path)
    rel = path.relative_to(REPO_ROOT).as_posix()

    required = [
        "id", "name", "one_line_purpose", "entry_point", "category",
        "status", "tags", "description", "version", "last_updated",
    ]
    missing = [k for k in required if k not in fm]
    if missing:
        raise ValueError(f"{rel}: missing required front-matter key(s): {missing}")
    if fm["name"] != fm["id"]:
        raise ValueError(f"{rel}: name ({fm['name']!r}) does not match id ({fm['id']!r})")

    # Oversized skills are migrated to per-skill directories (write-a-skill.md).
    lines = path.read_text().count("\n")
    if lines > MAX_LINES_HARD:
        raise ValueError(f"{rel} is {lines} lines (hard max {MAX_LINES_HARD})")
    if lines > MAX_LINES_SOFT:
        print(f"warning: {rel} is {lines} lines (soft max {MAX_LINES_SOFT})", file=sys.stderr)

    entry = {
        "id": fm["id"],
        "name": fm["name"],
        "one_line_purpose": fm["one_line_purpose"],
        "entry_point": fm["entry_point"],
        "category": fm["category"],
        "status": fm["status"],
        "tags": fm["tags"],
        "description": " ".join(fm["description"].split()),
        "version": str(fm["version"]),
        "last_updated": str(fm["last_updated"]),
    }
    doc_type = (fm.get("metadata") or {}).get("type")
    if doc_type:
        entry["doc_type"] = doc_type

    if fm["entry_point"] != rel:
        raise ValueError(
            f"{rel}: entry_point front-matter value ({fm['entry_point']!r}) "
            f"does not match actual path ({rel!r})"
        )
    return entry


def build_catalog() -> dict:
    skills = [build_skill_entry(p) for p in find_skill_files()]
    skills.sort(key=lambda s: s["id"])
    return {
        "generated_at": date.today().isoformat(),
        "schema_version": SCHEMA_VERSION,
        "skills": skills,
    }


def load_existing_catalog() -> dict | None:
    """Return the currently committed catalog, or None if it doesn't exist/parse."""
    if not INDEX_PATH.exists():
        return None
    try:
        return json.loads(INDEX_PATH.read_text())
    except json.JSONDecodeError:
        return None


def pin_unchanged_generated_at(catalog: dict, existing: dict | None) -> None:
    """Reuse the committed `generated_at` when the actual catalog content
    (schema_version + skills) hasn't changed.

    `generated_at` is a "last regenerated" timestamp, not build-time metadata:
    it should only advance when a skill doc actually changes. Without this,
    every run stamps today's date, which makes `--check` fail on pure
    calendar drift (e.g. a PR branch cut before today, or CI running a day
    after the last regeneration) even though no skill content is stale.
    """
    if (
        existing is not None
        and existing.get("schema_version") == catalog["schema_version"]
        and existing.get("skills") == catalog["skills"]
    ):
        catalog["generated_at"] = existing.get("generated_at", catalog["generated_at"])


def validate_catalog(catalog: dict) -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(catalog), key=lambda e: e.path)
    if errors:
        for e in errors:
            loc = "/".join(str(p) for p in e.path) or "<root>"
            print(f"schema error at {loc}: {e.message}", file=sys.stderr)
        raise SystemExit(1)


def render_markdown(catalog: dict) -> str:
    lines = [
        "# Skill catalog (generated)",
        "",
        "This file is a human-readable mirror of `index.json`. Both are generated by",
        "`scripts/generate_skill_index.py` — do not hand-edit either file.",
        "",
        f"Generated: {catalog['generated_at']} · schema {catalog['schema_version']} · "
        f"{len(catalog['skills'])} skills",
        "",
        "| id | category | status | one-line purpose |",
        "|---|---|---|---|",
    ]
    for s in catalog["skills"]:
        rel_link = s["entry_point"].removeprefix("docs/skills/")
        lines.append(
            f"| [{s['id']}]({rel_link}) | {s['category']} | {s['status']} | "
            f"{s['one_line_purpose']} |"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true", help="Regenerate index.json and index.md")
    group.add_argument("--check", action="store_true", help="Verify index.json/index.md are up to date")
    args = parser.parse_args()

    try:
        catalog = build_catalog()
        pin_unchanged_generated_at(catalog, load_existing_catalog())
        validate_catalog(catalog)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    json_text = json.dumps(catalog, indent=2, sort_keys=False) + "\n"
    md_text = render_markdown(catalog)

    if args.write:
        INDEX_PATH.write_text(json_text)
        (SKILLS_DIR / "index.md").write_text(md_text)
        print(f"wrote {INDEX_PATH.relative_to(REPO_ROOT)} and index.md "
              f"({len(catalog['skills'])} skills)")
        return 0

    # --check
    ok = True
    if not INDEX_PATH.exists() or INDEX_PATH.read_text() != json_text:
        print("error: docs/skills/index.json is stale. Run "
              "`python3 scripts/generate_skill_index.py --write`.", file=sys.stderr)
        ok = False
    md_path = SKILLS_DIR / "index.md"
    if not md_path.exists() or md_path.read_text() != md_text:
        print("error: docs/skills/index.md is stale. Run "
              "`python3 scripts/generate_skill_index.py --write`.", file=sys.stderr)
        ok = False
    if not ok:
        return 1
    print(f"docs/skills/index.json and index.md are up to date "
          f"({len(catalog['skills'])} skills)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
