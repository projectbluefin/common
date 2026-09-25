"""Regression checks for the repository Renovate configuration layout and manager coverage."""

import json
from pathlib import Path
import re


ROOT = Path(__file__).parent.parent
RENOVATE_JSON = ROOT / "renovate.json"


def _load_config():
    return json.loads(RENOVATE_JSON.read_text(encoding="utf-8"))


def _js_regex_to_python(regex_str: str) -> str:
    """Convert JavaScript named capture groups (?<name>...) to Python (?P<name>...)."""
    return re.sub(r"\(\?<([a-zA-Z0-9_]+)>", r"(?P<\1>", regex_str)


def test_single_active_renovate_config_layout():
    """Ensure renovate.json exists at root and no inactive/duplicate configs exist."""
    assert RENOVATE_JSON.is_file(), "Root renovate.json must exist"

    inactive_candidates = [
        ROOT / ".github" / "renovate.json5",
        ROOT / ".github" / "renovate.json",
        ROOT / ".github" / "renovate.jsonc",
        ROOT / "renovate.json5",
        ROOT / "renovate.jsonc",
    ]
    for candidate in inactive_candidates:
        assert not candidate.exists(), (
            f"Inactive or duplicate Renovate configuration found at {candidate.relative_to(ROOT)}. "
            "Only root renovate.json should exist to prevent shadow configurations."
        )


def test_renovate_config_inheritance_and_managers():
    """Verify base configuration inheritance and that manager discovery is unrestricted."""
    config = _load_config()

    assert config.get("$schema") == "https://docs.renovatebot.com/renovate-schema.json"
    assert "local>projectbluefin/renovate-config" in config.get("extends", [])

    # enabledManagers must not be restricted (e.g. to ["github-actions", "custom.regex"])
    # because that would disable the built-in dockerfile manager.
    assert "enabledManagers" not in config, (
        "enabledManagers should not be restricted; omitting it allows dockerfile, "
        "github-actions, and custom.regex managers to run simultaneously."
    )


def test_wallpaper_custom_regex_manager():
    """Verify the custom regex manager for bluefin-wallpapers-gnome in Containerfile."""
    config = _load_config()
    custom_managers = config.get("customManagers", [])

    manager = next(
        (
            m
            for m in custom_managers
            if m.get("customType") == "regex"
            and any("Containerfile" in pattern for pattern in m.get("managerFilePatterns", []))
        ),
        None,
    )
    assert manager is not None, "Custom regex manager for Containerfile not found"

    assert manager.get("datasourceTemplate") == "docker"
    assert manager.get("versioningTemplate") == "docker"

    containerfile_path = ROOT / "Containerfile"
    assert containerfile_path.is_file()
    content = containerfile_path.read_text(encoding="utf-8")

    match_found = False
    for match_str in manager.get("matchStrings", []):
        py_regex = _js_regex_to_python(match_str)
        match = re.search(py_regex, content)
        if match:
            groups = match.groupdict()
            assert groups.get("depName") == "ghcr.io/ublue-os/bluefin-wallpapers-gnome"
            assert groups.get("currentValue") == "latest"
            assert groups.get("currentDigest", "").startswith("sha256:")
            assert len(groups["currentDigest"]) == 71  # "sha256:" (7) + 64 hex chars
            match_found = True
            break

    assert match_found, "Wallpaper regex pattern did not match Containerfile content"


def test_bonedigger_custom_regex_manager():
    """Verify the custom regex manager for BONEDIGGER_VERSION in 60-bonedigger.just."""
    config = _load_config()
    custom_managers = config.get("customManagers", [])

    manager = next(
        (
            m
            for m in custom_managers
            if m.get("customType") == "regex"
            and any("60-bonedigger" in pattern for pattern in m.get("managerFilePatterns", []))
        ),
        None,
    )
    assert manager is not None, "Custom regex manager for 60-bonedigger.just not found"

    assert manager.get("datasourceTemplate") == "github-releases"
    assert manager.get("depNameTemplate") == "projectbluefin/bonedigger"

    just_path = ROOT / "system_files" / "bluefin" / "usr" / "share" / "ublue-os" / "just" / "60-bonedigger.just"
    assert just_path.is_file()
    content = just_path.read_text(encoding="utf-8")

    match_found = False
    for match_str in manager.get("matchStrings", []):
        py_regex = _js_regex_to_python(match_str)
        match = re.search(py_regex, content)
        if match:
            groups = match.groupdict()
            assert "currentValue" in groups
            assert re.match(r"^v?[0-9.]+$", groups["currentValue"])
            match_found = True
            break

    assert match_found, "Bonedigger regex pattern did not match 60-bonedigger.just content"


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


def test_opentabletdriver_custom_regex_manager():
    """Verify the custom regex manager for OTD_RELEASE in apps.just."""
    config = _load_config()
    custom_managers = config.get("customManagers", [])

    manager = next(
        (
            m
            for m in custom_managers
            if m.get("customType") == "regex"
            and any("apps" in pattern for pattern in m.get("managerFilePatterns", []))
        ),
        None,
    )
    assert manager is not None, "Custom regex manager for apps.just not found"

    assert manager.get("datasourceTemplate") == "github-releases"
    assert manager.get("depNameTemplate") == "OpenTabletDriver/OpenTabletDriver"

    just_path = ROOT / "system_files" / "shared" / "usr" / "share" / "ublue-os" / "just" / "apps.just"
    assert just_path.is_file()
    content = just_path.read_text(encoding="utf-8")

    match_found = False
    for match_str in manager.get("matchStrings", []):
        py_regex = _js_regex_to_python(match_str)
        match = re.search(py_regex, content)
        if match:
            groups = match.groupdict()
            assert "currentValue" in groups
            assert re.match(r"^v?[0-9.]+$", groups["currentValue"])
            match_found = True
            break

    assert match_found, "OpenTabletDriver regex pattern did not match apps.just content"


def test_opentabletdriver_updates_do_not_automerge():
    """OTD bumps need manual sha256 updates, so they must be excluded from automerge.

    ``OTD_TARBALL_SHA256``/``OTD_SERVICE_SHA256`` in apps.just are not Renovate-managed; a
    Renovate-only bump of ``OTD_RELEASE`` produces a recipe that fails its ``sha256sum -c``
    gate. The repo-wide patch/minor automerge rule must therefore be overridden for this
    dependency.
    """
    config = _load_config()
    package_rules = config.get("packageRules", [])

    disable_rules = [
        rule
        for rule in package_rules
        if rule.get("automerge") is False
        and "OpenTabletDriver/OpenTabletDriver" in rule.get("matchDepNames", [])
    ]
    assert disable_rules, (
        "renovate.json must contain a packageRule with matchDepNames "
        "['OpenTabletDriver/OpenTabletDriver'] and automerge: false, because the sha256 pins "
        "beside OTD_RELEASE in apps.just have to be updated by hand."
    )

    for rule in disable_rules:
        assert "matchUpdateTypes" not in rule, (
            "The OpenTabletDriver automerge exclusion must cover every update type; the "
            "manual sha256 requirement applies to patch bumps too."
        )

    # The exclusion must be ordered after the repo-wide automerge rule, since later
    # packageRules win in Renovate.
    automerge_index = next(
        i for i, rule in enumerate(package_rules) if rule.get("automerge") is True
    )
    assert package_rules.index(disable_rules[0]) > automerge_index, (
        "The OpenTabletDriver automerge: false rule must come after the repo-wide automerge "
        "rule; Renovate applies later packageRules last."
    )
