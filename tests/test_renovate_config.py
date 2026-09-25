"""Regression checks for the repository Renovate policy."""

import json
from pathlib import Path


ROOT = Path(__file__).parent.parent
RENOVATE = ROOT / "renovate.json"


def _load_config():
    return json.loads(RENOVATE.read_text(encoding="utf-8"))


def test_github_actions_minor_patch_updates_require_review():
    config = _load_config()
    rules = config["packageRules"]

    blanket_rule = next(
        rule
        for rule in rules
        if set(rule.get("matchUpdateTypes", []))
        == {"digest", "pin", "patch", "minor"}
        and "matchManagers" not in rule
    )
    review_rule = next(
        rule
        for rule in rules
        if rule.get("matchManagers") == ["github-actions"]
        and set(rule.get("matchUpdateTypes", [])) == {"minor", "patch"}
    )

    assert rules.index(review_rule) > rules.index(blanket_rule)
    assert blanket_rule["automerge"] is True
    assert blanket_rule["platformAutomerge"] is True
    assert review_rule["automerge"] is False
