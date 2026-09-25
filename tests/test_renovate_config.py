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


def test_opentabletdriver_updates_do_not_automerge():
    config = _load_config()
    package_rules = config.get("packageRules", [])
    rule = next(
        (
            r
            for r in package_rules
            if r.get("automerge") is False
            and "OpenTabletDriver/OpenTabletDriver" in r.get("matchDepNames", [])
        ),
        None,
    )
    assert rule is not None, "OpenTabletDriver automerge: false rule must exist"
