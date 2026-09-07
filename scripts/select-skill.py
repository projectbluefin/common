#!/usr/bin/env python3
"""CLI skill discovery tool for Project Bluefin.

Queries docs/skills/index.json and ranks skills by relevance based on:
- Name token match (+10)
- Tag token match (+8)
- Trigger token match (+6)
- Purpose/description token match (+2)

Usage:
    python3 scripts/select-skill.py <query>
    python3 scripts/select-skill.py --json <query>
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INDEX = REPO_ROOT / "docs" / "skills" / "index.json"

STOP_WORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
    "has", "he", "in", "is", "it", "its", "of", "on", "or", "that",
    "the", "to", "was", "were", "will", "with",
}


def tokenize(text: str | None) -> list[str]:
    """Split text into lowercase alphanumeric tokens, filtering stop words."""
    if not text:
        return []
    clean = re.sub(r"[^a-z0-9_-]+", " ", str(text).lower())
    return [t for t in clean.split() if t and t not in STOP_WORDS]


def rank_skill(skill: dict[str, Any], query_tokens: list[str]) -> dict[str, Any]:
    """Score a skill dictionary against query tokens."""
    score = 0
    matched_tags: list[str] = []
    matched_triggers: list[str] = []

    name_tokens = tokenize(skill.get("name", ""))
    tag_tokens = [t for tag in skill.get("tags", []) for t in tokenize(tag)]
    trigger_tokens = [t for tr in skill.get("triggers", []) for t in tokenize(tr)]
    desc_tokens = tokenize(skill.get("description", "")) + tokenize(skill.get("one_line_purpose", ""))

    for token in query_tokens:
        if token in name_tokens:
            score += 10
        if token in tag_tokens:
            score += 8
            matched_tags.append(token)
        if token in trigger_tokens:
            score += 6
            matched_triggers.append(token)
        if token in desc_tokens:
            score += 2

    return {
        "score": score,
        "skill": skill,
        "matched_tags": matched_tags,
        "matched_triggers": matched_triggers,
    }


def select_skills(query: str, catalog_path: Path = DEFAULT_INDEX) -> dict[str, Any]:
    """Search and rank skills from the catalog matching the query."""
    if not catalog_path.is_file():
        raise FileNotFoundError(
            f"Skills index not found at {catalog_path}. Run scripts/generate_skill_index.py first."
        )

    with catalog_path.open("r", encoding="utf-8") as f:
        catalog = json.load(f)

    tokens = tokenize(query)
    scored = [rank_skill(s, tokens) for s in catalog.get("skills", [])]
    matches = [r for r in scored if r["score"] > 0]
    matches.sort(key=lambda r: r["score"], reverse=True)

    return {
        "query": query,
        "count": len(matches),
        "matches": [
            {
                "score": r["score"],
                "id": r["skill"].get("id"),
                "name": r["skill"].get("name"),
                "entry_point": r["skill"].get("entry_point"),
                "one_line_purpose": r["skill"].get("one_line_purpose"),
                "category": r["skill"].get("category"),
            }
            for r in matches
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Find Project Bluefin skills matching a query.")
    parser.add_argument("query", nargs="+", help="Keywords or description to search for")
    parser.add_argument("--json", dest="as_json", action="store_true", help="Output results as JSON")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_INDEX, help="Path to skills index.json")

    args = parser.parse_args(argv)
    query_str = " ".join(args.query).strip()
    if not query_str:
        parser.error("query must not be empty")

    try:
        result = select_skills(query_str, catalog_path=args.catalog)
    except FileNotFoundError as err:
        sys.stderr.write(f"error: {err}\n")
        return 1

    if args.as_json:
        print(json.dumps(result, indent=2))
    else:
        if not result["matches"]:
            print(f"No skills found matching '{query_str}'.")
            return 0

        print(f"Found {result['count']} matching skill(s) for '{query_str}':\n")
        for m in result["matches"]:
            print(f"  [{m['score']:2d}] {m['name']} ({m['entry_point']})")
            print(f"       {m['one_line_purpose']}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
