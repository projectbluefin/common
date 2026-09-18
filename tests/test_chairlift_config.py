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
import re
import shlex

import pytest
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
CHAIRLIFT_VALIDATOR = ROOT / "tests/check-chairlift-config"
CHAIRLIFT_WORKFLOW = ROOT / ".github/workflows/validate-chairlift-config.yaml"
JUSTFILE = ROOT / "Justfile"
DESKTOP_FILE = (
    ROOT / "system_files/shared/usr/share/applications/org.frostyard.ChairLift.desktop"
)
ICON_ROOT = ROOT / "system_files/shared/usr/share/icons/hicolor"
ICONS = (
    ICON_ROOT / "scalable/apps/org.frostyard.ChairLift.svg",
    ICON_ROOT / "scalable/apps/org.frostyard.ChairLift-flower.svg",
    ICON_ROOT / "symbolic/apps/org.frostyard.ChairLift-symbolic.svg",
)
#: Homebrew's shared prefix on Bluefin. The cask links chairlift-wrapper here.
CHAIRLIFT_WRAPPER = "/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper"

#: bootc flags the privileged helper must never carry. --apply and
#: --soft-reboot reboot the machine; --download-only locks finalization so
#: the update does NOT apply on the next reboot (and re-locks one uupd had
#: already staged); --from-downloaded only unlocks, never checks upstream.
FORBIDDEN_BOOTC_FLAGS = (
    "--apply",
    "--from-downloaded",
    "--download-only",
    "--soft-reboot",
    "--reboot",
)

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


def _stage_script_exec_argv() -> list[str]:
    exec_lines = [
        line.strip()
        for line in BOOTC_STAGE_SCRIPT.read_text(encoding="utf-8").splitlines()
        if line.strip().startswith("exec ")
    ]
    assert len(exec_lines) == 1, f"expected exactly one exec invocation: {exec_lines}"
    return shlex.split(exec_lines[0])


def test_bootc_stage_script_is_executable_and_stages_only():
    """The privileged helper must run plain `bootc upgrade` and nothing else.

    Plain `bootc upgrade` fetches the update and queues it as a staged
    deployment that ostree-finalize-staged applies at the user's next
    ordinary shutdown -- which is exactly what ChairLift's UI promises when
    it reads back `status.staged` and says "restart to apply", and what
    uupd already does in the background.

    `--download-only` is the trap: bootc-upgrade(8) says the image "will not
    be applied on reboot", so the user would authenticate, pay a full image
    pull, and get nothing on reboot. Worse, it calls change_finalization()
    on an already-staged deployment, so pressing ChairLift's button would
    *cancel* an update uupd had staged for the next shutdown.

    Assert the exact argv rather than substrings. `pkexec` runs this script
    as root, so "contains 'bootc upgrade'" is far too weak a claim: it
    would also accept `exec /some/other/tool "bootc upgrade"`.
    """
    assert BOOTC_STAGE_SCRIPT.stat().st_mode & 0o111, (
        "bootc-update-stage must be executable"
    )
    argv = _stage_script_exec_argv()
    assert argv == ["exec", "/usr/bin/bootc", "upgrade"], (
        f"unexpected privileged command: {argv!r}"
    )


@pytest.mark.parametrize("flag", FORBIDDEN_BOOTC_FLAGS)
def test_bootc_stage_script_rejects_dangerous_flags(flag):
    """The exact-argv test above already pins the command, but name the
    forbidden flags individually so a future edit that adds one fails with
    the reason rather than a diff of two lists.

    Match whole tokens, including the `--soft-reboot=auto` spelling, and
    never a bare substring: `--apply` must not be found inside a word.
    """
    argv = _stage_script_exec_argv()
    offenders = [
        token for token in argv if token == flag or token.startswith(f"{flag}=")
    ]
    assert not offenders, (
        f"bootc-update-stage passes {flag}: {offenders}; the helper stages "
        "only and must never reboot, lock finalization, or skip the "
        "registry check"
    )


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


def test_schema_validator_pins_the_shipped_chairlift_release():
    """The drift gate must read the tag the cask pins, never upstream main.

    Against `main` the gate false-greens on a key the pinned binary rejects
    -- which is the whole disabledConfig() failure it exists to catch -- and
    false-reds on renames that never reach our users. One constant, used to
    build every upstream URL, so a cask bump has exactly one place to touch.
    """
    validator = CHAIRLIFT_VALIDATOR.read_text(encoding="utf-8")

    refs = re.findall(r'^CHAIRLIFT_SCHEMA_REF = "([^"]+)"$', validator, re.MULTILINE)
    assert refs == ["v0.10.1"], (
        f"expected exactly one CHAIRLIFT_SCHEMA_REF pinned to v0.10.1, got {refs}"
    )

    urls = re.findall(r"https://raw\.githubusercontent\.com/frostyard/chairlift/\S*", validator)
    unpinned = [url for url in urls if "{CHAIRLIFT_SCHEMA_REF}" not in url]
    assert not unpinned, (
        f"upstream URLs bypass the pin: {unpinned}; build every URL from "
        "CHAIRLIFT_SCHEMA_REF so the cask bump moves them together"
    )


def test_schema_validator_sends_no_credentials():
    """raw.githubusercontent.com serves public content anonymously and does
    not draw on the api.github.com rate limit, so the fetch must not send an
    Authorization header or read a token out of the environment."""
    code = "\n".join(
        line
        for line in CHAIRLIFT_VALIDATOR.read_text(encoding="utf-8").splitlines()
        if not line.lstrip().startswith("#")
    )
    for forbidden in ("Authorization", "add_header", "GITHUB_TOKEN", "GH_TOKEN"):
        assert forbidden not in code, (
            f"tests/check-chairlift-config references {forbidden}; the "
            "upstream fetch is anonymous and needs no credential"
        )


#: Matches a just recipe header at column 0: `name params: dep (dep "arg")`.
#: Recipe bodies are indented, so anchoring at column 0 skips them, and the
#: `(?!=)` guard keeps assignments like `just := just_executable()` from
#: being read as a recipe named `just`.
_JUST_RECIPE_HEADER = re.compile(
    r"^(?P<name>@?[A-Za-z_][A-Za-z0-9_-]*)(?P<params>[^\n:]*):(?!=)(?P<deps>[^\n]*)$"
)


def _just_recipe_block(justfile: str, name: str) -> str:
    """Return a just recipe's header plus its whole indented body.

    Matching only the header line is what let the first version of the
    hermetic gate below pass while `python3 tests/check-chairlift-config`
    sat in the recipe body one line down.
    """
    lines = justfile.splitlines()
    for index, line in enumerate(lines):
        match = _JUST_RECIPE_HEADER.match(line)
        if match is None or match.group("name") != name:
            continue
        body = []
        for candidate in lines[index + 1 :]:
            if candidate.strip() and not candidate[:1].isspace():
                break
            body.append(candidate)
        return "\n".join([line, *body])
    raise AssertionError(f"Justfile has no `{name}` recipe")


def _just_recipe_dependencies(header: str) -> list[str]:
    """Recipe names `header` depends on, bare or parenthesized with args.

    String arguments are stripped first so `(_fmt "--check" "Checking")`
    yields `_fmt` and not the words inside its arguments.
    """
    match = _JUST_RECIPE_HEADER.match(header)
    assert match is not None, f"not a just recipe header: {header!r}"
    deps = re.sub(r'"[^"]*"|\'[^\']*\'', " ", match.group("deps"))
    return re.findall(r"@?[A-Za-z_][A-Za-z0-9_-]*", deps)


def _just_recipe_closure(justfile: str, name: str) -> str:
    """Everything `just <name>` would execute: the recipe and, transitively,
    every recipe it depends on."""
    blocks = []
    seen: set[str] = set()
    pending = [name]
    while pending:
        current = pending.pop(0).lstrip("@")
        if current in seen:
            continue
        seen.add(current)
        block = _just_recipe_block(justfile, current)
        blocks.append(block)
        pending.extend(_just_recipe_dependencies(block.splitlines()[0]))
    return "\n".join(blocks)


def _assert_just_check_is_hermetic(justfile: str) -> None:
    """`just check` must not reach the network, directly or through a
    dependency."""
    closure = _just_recipe_closure(justfile, "check")
    assert "check-chairlift-config" not in closure, (
        "`just check` must stay hermetic; the networked ChairLift drift gate "
        "belongs to .github/workflows/validate-chairlift-config.yaml. Found "
        f"it in the recipe closure:\n{closure}"
    )


def test_just_check_stays_hermetic():
    """`just check` is the repo-wide pre-commit gate documented across the
    skill docs and the PR template. Chaining a third-party network fetch
    into it makes every unrelated PR, the merge queue, and every offline
    contributor depend on frostyard/chairlift being reachable.

    Inspect the whole recipe closure -- header, body, and every recipe
    `check` depends on -- because `just check` runs all of it. A header-only
    check passes while the fetch sits in the body.
    """
    justfile = JUSTFILE.read_text(encoding="utf-8")
    _assert_just_check_is_hermetic(justfile)
    assert "check-chairlift-config:" in justfile, (
        "keep check-chairlift-config as a standalone recipe so it can still "
        "be run on demand"
    )


#: Mutations that each make `just check` fetch from the network. Every one
#: must trip the guard; a mutation that survives means the guard is
#: decorative.
_HERMETIC_MUTATIONS = {
    "in the check body": (
        'check: (_fmt "--check" "Checking")',
        'check: (_fmt "--check" "Checking")\n    python3 tests/check-chairlift-config',
    ),
    "as a check dependency": (
        'check: (_fmt "--check" "Checking")',
        'check: check-chairlift-config (_fmt "--check" "Checking")',
    ),
    "in a transitive dependency body": (
        "_fmt mode verb:\n",
        "_fmt mode verb:\n    python3 tests/check-chairlift-config\n",
    ),
}


@pytest.mark.parametrize("placement", sorted(_HERMETIC_MUTATIONS))
def test_hermetic_guard_catches_check_recipe_mutations(placement):
    """Mutation test for the guard above.

    The original guard only regex-matched the `check:` header line, so
    moving the validator one line down into the recipe body defeated it
    silently. Re-add the fetch in three places and assert each one fails.
    """
    justfile = JUSTFILE.read_text(encoding="utf-8")
    original, mutated = _HERMETIC_MUTATIONS[placement]
    assert original in justfile, (
        f"Justfile no longer contains {original!r}; update _HERMETIC_MUTATIONS "
        "so this mutation still exercises the hermetic guard"
    )

    with pytest.raises(AssertionError, match="must stay hermetic"):
        _assert_just_check_is_hermetic(justfile.replace(original, mutated, 1))


def test_just_recipe_closure_reaches_dependency_bodies():
    """The guard is only as good as the parser. Pin that the closure of
    `check` actually contains `_fmt`'s body rather than just its name."""
    justfile = JUSTFILE.read_text(encoding="utf-8")
    closure = _just_recipe_closure(justfile, "check")
    assert "--unstable --fmt" in closure, (
        "the `check` closure does not include _fmt's body; the dependency "
        f"walk is broken:\n{closure}"
    )
    assert "just := just_executable()" not in closure, (
        "variable assignments must not be parsed as recipes"
    )


def test_chairlift_drift_workflow_documents_the_pin():
    workflow = CHAIRLIFT_WORKFLOW.read_text(encoding="utf-8")
    assert "CHAIRLIFT_SCHEMA_REF" in workflow, (
        "the drift workflow must say where the pin lives so the next editor "
        "does not reintroduce a main-tracking fetch"
    )
    assert "python3 tests/check-chairlift-config" in workflow
    assert "GITHUB_TOKEN" not in workflow, (
        "the validator fetches public raw content anonymously"
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
    assert 'cask "frostyard/tap/chairlift"' in content


# ---------------------------------------------------------------------------
# System-wide desktop integration
#
# The Homebrew cask installs the desktop entry and icons into the *installing*
# user's ~/.local/share. Homebrew has one shared prefix on Bluefin, so every
# user after the first sees the cask as already installed, brew bundle skips
# it, and those users never get a launcher or an icon. Shipping the same
# upstream artifacts from the image is what makes ChairLift appear for all
# users; the per-user copies stay harmless duplicates.
# ---------------------------------------------------------------------------


def _desktop_entry() -> dict[str, str]:
    entries: dict[str, str] = {}
    in_section = False
    for line in DESKTOP_FILE.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("["):
            in_section = stripped == "[Desktop Entry]"
            continue
        if in_section and "=" in stripped:
            key, _, value = stripped.partition("=")
            entries[key.strip()] = value.strip()
    return entries


def test_chairlift_desktop_entry_ships_system_wide():
    assert DESKTOP_FILE.is_file(), (
        f"missing {DESKTOP_FILE.relative_to(ROOT)}; without it only the first "
        "user to run brew bundle gets a ChairLift launcher"
    )
    entry = _desktop_entry()
    assert entry.get("Name") == "ChairLift"
    assert entry.get("Type") == "Application"
    assert entry.get("Icon") == "org.frostyard.ChairLift"
    assert entry.get("NoDisplay") == "false", (
        "the system-wide entry must be visible; it is the launcher for every "
        "user the cask's user-scoped artifact never reaches"
    )


def test_chairlift_desktop_entry_execs_the_homebrew_wrapper():
    """qecore and the shell both launch through Exec=. The wrapper sets up the
    Homebrew environment, so a bare `chairlift` would depend on brew being on
    a session PATH that GDM-launched apps do not have. Absolute path only, no
    arguments, and /var/home spelling: /home is a symlink on bootc systems and
    the image should name the real path."""
    exec_line = _desktop_entry().get("Exec")
    assert exec_line, f"no Exec= in {DESKTOP_FILE.relative_to(ROOT)}"
    argv = shlex.split(exec_line)
    assert argv == [CHAIRLIFT_WRAPPER], (
        f"expected Exec={CHAIRLIFT_WRAPPER} with no arguments, got {exec_line!r}"
    )


def test_chairlift_icons_ship_system_wide():
    """Icon=org.frostyard.ChairLift only resolves if the theme icon exists in
    a system search path; the flower and symbolic variants are referenced by
    the app itself."""
    for icon in ICONS:
        assert icon.is_file(), f"missing icon: {icon.relative_to(ROOT)}"
        assert icon.stat().st_size > 0, f"empty icon: {icon.relative_to(ROOT)}"
        assert icon.read_text(encoding="utf-8").lstrip().startswith(("<?xml", "<svg")), (
            f"{icon.relative_to(ROOT)} is not an SVG document"
        )


def test_chairlift_desktop_entry_records_upstream_provenance():
    """These are verbatim upstream GPL-3.0 artifacts. Keep the attribution and
    the version next to them so a cask bump has an obvious place to look."""
    header = DESKTOP_FILE.read_text(encoding="utf-8")
    assert "frostyard/chairlift" in header
    assert "v0.10.1" in header
    assert "GPL-3.0" in header
