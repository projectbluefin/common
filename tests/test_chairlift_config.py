"""Regression checks for the ChairLift config and preinstall Brewfile.

ChairLift (https://github.com/frostyard/chairlift) reads
/usr/share/chairlift/config.yml for maintainer defaults. These tests pin
the Bluefin decisions: frostyard/chairlift#54 resolved via the
system-integration split (frostyard/chairlift#102), so bootc staging is
now backed by an image-side polkit policy and stage script and
bootc_updates_group is enabled. updex (features_group) stays disabled
because no updex helper ships on Bluefin. Bundle paths point at Bluefin's
Brewfiles, and help links point at Bluefin resources.

Note on strictness: ChairLift does not ignore unknown configuration keys.
internal/config/validate.go classifies an unrecognised page, group, or
field as KindSchema, and internal/config/config.go::Load() answers that
with disabledConfig() -- every group on every page forced off, plus a
persistent configuration-error toast. So a typo in this config is not a
cosmetic defect; it ships an empty app to every user.
"""

from pathlib import Path
import shlex

import yaml


ROOT = Path(__file__).parent.parent
CONFIG = ROOT / "system_files/shared/usr/share/chairlift/config.yml"
BREWFILE = (
    ROOT
    / "system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile"
)
BOOTC_POLICY = (
    ROOT
    / "system_files/shared/usr/share/polkit-1/actions"
    / "org.frostyard.ChairLift.bootc.policy"
)
BOOTC_STAGE_SCRIPT = ROOT / "system_files/shared/usr/libexec/bootc-update-stage"

# The canonical page -> group map, mirrored from upstream
# internal/config/config.go::defaultConfig(). ChairLift validates configs
# STRICTLY: internal/config/validate.go classifies any page, group, or
# field name it does not recognise as KindSchema, which makes Load()
# return disabledConfig() -- every group on every page forced off, plus a
# persistent "Configuration error" toast. A typo here is not a silent
# no-op, it bricks the whole app.
#
# This list is an offline pin. The authoritative check against upstream
# lives in .github/workflows/validate-chairlift-config.yaml, which fetches
# upstream's config.yml and fails on drift.
KNOWN_GROUPS = {
    "system_page": {"system_info_group", "bootc_status_group", "health_group"},
    "updates_page": {
        "bootc_updates_group",
        "flatpak_updates_group",
        "brew_updates_group",
        "brew_trust_group",
    },
    "applications_page": {
        "applications_installed_group",
        "flatpak_user_group",
        "flatpak_system_group",
        "brew_group",
        "brew_search_group",
        "brew_bundles_group",
    },
    "maintenance_page": {
        "maintenance_cleanup_group",
        "maintenance_brew_group",
        "maintenance_flatpak_group",
        "maintenance_optimization_group",
    },
    "features_page": {"features_group"},
    "help_page": {"help_resources_group"},
}

# Group field names, mirrored from upstream GroupConfig's yaml struct tags.
# validateGroupFieldEntries() classifies an unknown FIELD as KindSchema too,
# so `bundle_paths` for `bundles_paths` bricks the app exactly like a bad
# group name would. Action fields come from ActionConfig.
KNOWN_FIELDS = {
    "enabled",
    "app_id",
    "actions",
    "website",
    "issues",
    "chat",
    "bundles_paths",
}
KNOWN_ACTION_FIELDS = {"title", "script", "sudo"}


def _load_config():
    return yaml.safe_load(CONFIG.read_text(encoding="utf-8"))


def test_config_parses_and_uses_known_pages_and_groups():
    data = _load_config()
    assert isinstance(data, dict)

    for page, groups in data.items():
        assert page in KNOWN_GROUPS, f"unknown page: {page}"
        assert isinstance(groups, dict)
        for group, settings in groups.items():
            assert group in KNOWN_GROUPS[page], f"unknown group: {page}.{group}"
            assert isinstance(settings, dict)
            assert isinstance(settings.get("enabled"), bool), (
                f"{page}.{group} must set enabled: true/false"
            )


def test_bootc_staging_enabled_now_that_polkit_glue_ships():
    """frostyard/chairlift#54 resolved via the system-integration split
    (frostyard/chairlift#102): Bluefin now ships the fixed
    /usr/libexec/bootc-update-stage helper and the bootc polkit policy, so
    bootc_updates_group can be enabled."""
    data = _load_config()
    assert data["updates_page"]["bootc_updates_group"]["enabled"] is True


def test_updex_features_group_stays_disabled():
    """updex has no Bluefin helper yet, independent of the bootc polkit
    fix. Keep it off until updex actually ships on Bluefin."""
    data = _load_config()
    assert data["features_page"]["features_group"]["enabled"] is False


def test_bootc_stage_polkit_policy_pins_fixed_helper_path():
    """The polkit action must annotate the exact fixed path ChairLift's
    pkexec invocation expects, and require authentication."""
    content = BOOTC_POLICY.read_text(encoding="utf-8")
    assert "org.frostyard.ChairLift.bootc.stage" in content
    assert (
        '<annotate key="org.freedesktop.policykit.exec.path">'
        "/usr/libexec/bootc-update-stage</annotate>" in content
    )
    assert "<allow_any>auth_admin</allow_any>" in content
    assert "<allow_inactive>auth_admin</allow_inactive>" in content
    assert "<allow_active>auth_admin_keep</allow_active>" in content


def test_no_polkit_rule_grants_bootc_staging_without_authentication():
    """auth_admin in the .policy file is only the default; a rules.d file
    returning polkit.Result.YES for this action would silently override it
    into a passwordless root exec for any user.

    The previous version of this test asserted this in its docstring but
    never opened rules.d, so it would not have noticed such a rule. Read
    every shipped rules file and fail on one that mentions our action.
    """
    rules_dirs = [
        ROOT / "system_files/shared/usr/share/polkit-1/rules.d",
        ROOT / "system_files/shared/etc/polkit-1/rules.d",
        ROOT / "system_files/bluefin/usr/share/polkit-1/rules.d",
        ROOT / "system_files/bluefin/etc/polkit-1/rules.d",
    ]
    offenders = []
    for rules_dir in rules_dirs:
        if not rules_dir.is_dir():
            continue
        for rules_file in rules_dir.glob("*.rules"):
            text = rules_file.read_text(encoding="utf-8")
            if "ChairLift" in text or "bootc-update-stage" in text:
                offenders.append(str(rules_file.relative_to(ROOT)))

    assert not offenders, (
        f"polkit rules reference the ChairLift staging action: {offenders}; "
        "staging must stay behind auth_admin, never a passwordless rule"
    )


def test_bootc_stage_script_is_executable_and_stages_only():
    """The privileged helper must only stage (never auto-apply/reboot) so
    uupd remains the sole owner of when an update actually takes effect,
    and must not suppress progress output: ChairLift streams the helper's
    merged stdout+stderr into its progress view, so --quiet would leave
    the user with an empty dialog.

    Assert the exact argv rather than substrings. `pkexec` runs this script
    as root, so "contains 'bootc upgrade'" is far too weak a claim: it
    would also accept `exec /some/other/tool "bootc upgrade"`.
    """
    assert BOOTC_STAGE_SCRIPT.stat().st_mode & 0o111, (
        "bootc-update-stage must be executable"
    )
    exec_lines = [
        line.strip()
        for line in BOOTC_STAGE_SCRIPT.read_text(encoding="utf-8").splitlines()
        if line.strip().startswith("exec ")
    ]
    assert len(exec_lines) == 1, "expected exactly one exec invocation"
    (exec_line,) = exec_lines
    assert shlex.split(exec_line) == [
        "exec",
        "/usr/bin/bootc",
        "upgrade",
        "--download-only",
    ], f"unexpected privileged command: {exec_line!r}"


def test_bootc_stage_script_ignores_arguments():
    """pkexec forwards caller-supplied argv. The helper must never pass it
    through to bootc, or the polkit action becomes a way to run arbitrary
    bootc subcommands as root."""
    content = BOOTC_STAGE_SCRIPT.read_text(encoding="utf-8")
    for positional in ('"$@"', "$@", '"$1"', "$1", '"${@}"'):
        assert positional not in content, (
            f"stage script forwards {positional} into a privileged invocation"
        )


def test_config_uses_only_upstream_schema_keys():
    """Every page and group we set must exist in ChairLift's schema.

    This is the regression test for the bug this file previously shipped:
    config.yml declared an `updates_settings_group` that upstream never
    defined. Unknown keys are not ignored -- validate.go classifies them
    as KindSchema, Load() falls back to disabledConfig(), and the user
    gets an empty app with a configuration-error toast. Assert a strict
    subset rather than equality, since omitting a group is legitimate
    (it just inherits upstream's default).
    """
    data = _load_config()

    unknown_pages = set(data) - set(KNOWN_GROUPS)
    assert not unknown_pages, f"pages absent from ChairLift's schema: {unknown_pages}"

    for page, groups in data.items():
        unknown_groups = set(groups) - KNOWN_GROUPS[page]
        assert not unknown_groups, (
            f"{page}: groups absent from ChairLift's schema: {unknown_groups}; "
            "an unknown group disables every feature group in the app"
        )
        for group, settings in groups.items():
            unknown_fields = set(settings) - KNOWN_FIELDS
            assert not unknown_fields, (
                f"{page}.{group}: fields absent from ChairLift's schema: "
                f"{unknown_fields}; an unknown field disables the whole app "
                "just like an unknown group does"
            )
            for action in settings.get("actions") or []:
                unknown_action_fields = set(action) - KNOWN_ACTION_FIELDS
                assert not unknown_action_fields, (
                    f"{page}.{group}.actions: fields absent from ChairLift's "
                    f"schema: {unknown_action_fields}"
                )


def test_update_scheduling_is_not_expressed_as_a_config_group():
    """Bluefin's update policy belongs to uupd, but that intent must not be
    encoded as a made-up group. upstream's updates_page is exactly the four
    groups in KNOWN_GROUPS; anything settings-shaped here is an invention
    that would fail strict validation."""
    updates = _load_config()["updates_page"]
    invented = {name for name in updates if "setting" in name or "schedul" in name}
    assert not invented, (
        f"invented update-scheduling groups: {invented}; "
        "document the uupd policy in a comment instead"
    )


def test_bundles_paths_point_at_bluefin_brewfiles():
    group = _load_config()["applications_page"]["brew_bundles_group"]
    assert group["bundles_paths"] == ["/usr/share/ublue-os/homebrew"]


def test_help_links_point_at_bluefin():
    resources = _load_config()["help_page"]["help_resources_group"]
    for key in ("website", "issues", "chat"):
        assert resources[key].startswith("https://"), f"{key} must be https"
        assert "projectbluefin.io" in resources[key], (
            f"{key} must point at a Bluefin resource"
        )


def test_brewfile_taps_frostyard_with_trust():
    """Homebrew 6 blocks untrusted taps silently; trusted: true is load-bearing."""
    content = BREWFILE.read_text(encoding="utf-8")
    assert 'tap "frostyard/tap", trusted: true' in content
    assert 'cask "chairlift"' in content
