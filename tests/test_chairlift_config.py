"""Regression checks for the ChairLift config and preinstall Brewfile.

ChairLift (https://github.com/projectbluefin/chairlift) reads
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

import os
from pathlib import Path
import re
import shlex
import subprocess

import pytest
import yaml


ROOT = Path(__file__).parent.parent
CONFIG = ROOT / "system_files/shared/usr/share/chairlift/config.yml"
BREWFILE = (
    ROOT
    / "system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile"
)
#: The directory ChairLift's brew_bundles_group scans. Its image path is the
#: one in config.yml; this is the repo-side path of the same tree.
BUNDLES_DIR = ROOT / "system_files/shared/usr/share/ublue-os/homebrew"
BOOTC_POLICY = (
    ROOT
    / "system_files/shared/usr/share/polkit-1/actions"
    / "io.projectbluefin.chairlift.bootc.policy"
)
BOOTC_STAGE_SCRIPT = ROOT / "system_files/shared/usr/libexec/bootc-update-stage"
CHAIRLIFT_VALIDATOR = ROOT / "tests/check-chairlift-config"
CHAIRLIFT_WORKFLOW = ROOT / ".github/workflows/validate-chairlift-config.yaml"
JUSTFILE = ROOT / "Justfile"
DESKTOP_FILE = (
    ROOT / "system_files/shared/usr/share/applications/io.projectbluefin.chairlift.desktop"
)
ICON_ROOT = ROOT / "system_files/shared/usr/share/icons/hicolor"
ICONS = (
    ICON_ROOT / "scalable/apps/io.projectbluefin.chairlift.svg",
    ICON_ROOT / "symbolic/apps/io.projectbluefin.chairlift-symbolic.svg",
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
    "agents_page": {"agents_group"},
    "updates_page": {
        "automatic_updates_group",
        "bootc_updates_group",
        "flatpak_updates_group",
        "brew_updates_group",
        "brew_trust_group",
        "channel_group",
        "bootc_status_group",
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
        "maintenance_freespace_group",
        "reset_group",
    },
    "features_page": {"features_group", "dx_group", "gaming_group"},
    "livery_page": {
        "account_group",
        "livery_app_grid_group",
        "livery_foundation_group",
        "livery_dock_group",
    },
    "help_page": {"troubleshooting_group", "help_resources_group"},
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
    "ai_images",
    "ai_model",
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
    """Upstream's features_group is the updex-managed feature set (it
    requires the `updex` command), and no updex helper ships on Bluefin —
    independent of the bootc polkit fix. Keep it off until updex actually
    ships on Bluefin."""
    data = _load_config()
    assert data["features_page"]["features_group"]["enabled"] is False


def test_bootc_stage_polkit_policy_pins_fixed_helper_path():
    """The polkit action must annotate the exact fixed path ChairLift's
    pkexec invocation expects, and require authentication."""
    content = BOOTC_POLICY.read_text(encoding="utf-8")
    assert "io.projectbluefin.chairlift.bootc.stage" in content
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
    assert refs == ["v26.10.2"], (
        f"expected exactly one CHAIRLIFT_SCHEMA_REF pinned to v26.10.2, got {refs}"
    )

    urls = re.findall(r"https://raw\.githubusercontent\.com/projectbluefin/chairlift/\S*", validator)
    unpinned = [url for url in urls if "{CHAIRLIFT_SCHEMA_REF}" not in url]
    assert not unpinned, (
        f"upstream URLs bypass the pin: {unpinned}; build every URL from "
        "CHAIRLIFT_SCHEMA_REF so the cask bump moves them together"
    )


#: Where the Containerfile installs each file from the ChairLift release
#: archive, keyed by image path: (install mode, archive member). The cask
#: cannot install root-owned files, so these are the image's contract with
#: the ChairLift GUI; the GUI binary, desktop file, icons and the updex
#: helper are deliberately absent.
CHAIRLIFT_SYSTEM_FILES = {
    "/usr/bin/chairlift-helper": ("0755", "chairlift-helper"),
    "/usr/share/polkit-1/actions/io.projectbluefin.chairlift.ublue.policy": (
        "0644",
        "data/io.projectbluefin.chairlift.ublue.policy",
    ),
    "/usr/share/glib-2.0/schemas/io.projectbluefin.chairlift.livery.gschema.xml": (
        "0644",
        "data/io.projectbluefin.chairlift.livery.gschema.xml",
    ),
    "/usr/share/glib-2.0/schemas/io.projectbluefin.chairlift.updates.gschema.xml": (
        "0644",
        "data/io.projectbluefin.chairlift.updates.gschema.xml",
    ),
    "/usr/share/glib-2.0/schemas/io.projectbluefin.chairlift.firstrun.gschema.xml": (
        "0644",
        "data/io.projectbluefin.chairlift.firstrun.gschema.xml",
    ),
}


def _chairlift_archive_step() -> str:
    """The Containerfile's ChairLift pins plus the RUN that consumes them."""
    lines = (ROOT / "Containerfile").read_text(encoding="utf-8").splitlines()
    start = next(
        i for i, line in enumerate(lines) if line.startswith("ARG CHAIRLIFT_RELEASE=")
    )
    run = next(i for i in range(start, len(lines)) if lines[i].startswith("RUN "))
    end = next(i for i in range(run, len(lines)) if not lines[i].endswith("\\"))
    return "\n".join(lines[start : end + 1])


def _chairlift_installs(step: str) -> dict[str, tuple[str, str]]:
    """Map image path -> (mode, archive member) for every install in the step."""
    installs = {}
    for mode, src, dst in re.findall(r"install -Dm(\d+) (\S+) (\S+?);?(?: \\)?$", step, re.MULTILINE):
        src = src.strip('"')
        if src == "$policy":
            src = re.search(r"^\s*policy=(\S+);", step, re.MULTILINE).group(1)
        assert dst.startswith("/out/shared/"), f"{dst} is not staged into /out/shared"
        installs[dst.removeprefix("/out/shared")] = (mode, src.removeprefix("/tmp/chairlift/"))
    return installs


#: The only identity allowed to sign a ChairLift release's checksums.txt:
#: upstream's release workflow, running for the exact tag being installed.
CHAIRLIFT_SIGNER = (
    "https://github.com/projectbluefin/chairlift/.github/workflows/release.yml"
    "@refs/tags/${CHAIRLIFT_RELEASE}"
)
CHAIRLIFT_SIGNER_ISSUER = "https://token.actions.githubusercontent.com"


def _chairlift_commands(step: str) -> list[str]:
    """The RUN body split into its `;`-terminated shell commands."""
    body = step[step.index("RUN ") :].replace("\\\n", " ")
    return [" ".join(cmd.split()) for cmd in body.split(";") if cmd.strip()]


def _first_command_index(commands: list[str], prefix: str) -> int:
    return next(i for i, cmd in enumerate(commands) if cmd.startswith(prefix))


def test_chairlift_release_pins_one_version_and_no_archive_hash():
    """A bump must be a one-line change: the tag is the only pin and the
    archive hash comes from the signed checksums.txt of that release."""
    containerfile = (ROOT / "Containerfile").read_text(encoding="utf-8")
    releases = re.findall(r"^ARG CHAIRLIFT_RELEASE=(\S+)$", containerfile, re.MULTILINE)
    assert len(releases) == 1, f"expected exactly one ChairLift release pin, got {releases}"
    assert re.fullmatch(r"v\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?", releases[0])

    step = _chairlift_archive_step()
    hashes = re.findall(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])", step)
    cosign_digest = re.search(r"cosign:\S+@sha256:([0-9a-f]{64})", step)
    assert cosign_digest and hashes == [cosign_digest.group(1)], (
        f"only the cosign image digest may be pinned in the ChairLift step, found {hashes}"
    )
    assert "CHAIRLIFT_SHA256" not in containerfile

    assert "\nARG TARGETARCH\n" in step, "TARGETARCH must be declared to be visible to RUN"
    commands = _chairlift_commands(step)
    assert commands[0] == "RUN set -eu"
    assert 'case "${TARGETARCH}" in amd64|arm64)' in commands
    default = next(
        i for i, cmd in enumerate(commands) if re.fullmatch(r'\*\) echo ".*TARGETARCH.*" >&2', cmd)
    )
    assert commands[default + 1] == "exit 1", "an arch without a release archive must fail the build"
    assert 'archive="chairlift_${version}_linux_${TARGETARCH}.tar.gz"' in commands
    assert 'for asset in checksums.txt checksums.txt.sigstore.json "$archive"' in commands
    assert (
        '"https://github.com/projectbluefin/chairlift/releases/download/'
        '${CHAIRLIFT_RELEASE}/${asset}"' in step
    )


def test_chairlift_cosign_comes_from_a_digest_pinned_image():
    """The verifier is part of the trust chain, so it must be immutable."""
    step = _chairlift_archive_step()
    copies = re.findall(r"^COPY --from=(\S+) /ko-app/cosign /usr/local/bin/cosign$", step, re.MULTILINE)
    assert len(copies) == 1, "cosign must be copied from its image exactly once"
    assert re.fullmatch(r"ghcr\.io/sigstore/cosign/cosign:v[\d.]+@sha256:[0-9a-f]{64}", copies[0])
    assert step.index("COPY --from=") < step.index("RUN ")


def test_chairlift_checksums_signature_is_verified_before_any_use():
    """checksums.txt is only trustworthy once cosign proves upstream's release
    workflow signed it for this very tag. A regexp identity, a missing
    issuer, or reading the file first would let any signer or no signer in."""
    commands = _chairlift_commands(_chairlift_archive_step())
    verify = _first_command_index(commands, "cosign verify-blob ")
    assert shlex.split(commands[verify]) == [
        "cosign",
        "verify-blob",
        "--bundle",
        "checksums.txt.sigstore.json",
        "--certificate-identity",
        CHAIRLIFT_SIGNER,
        "--certificate-oidc-issuer",
        CHAIRLIFT_SIGNER_ISSUER,
        "checksums.txt",
    ]
    downloads = _first_command_index(commands, "done")
    for consumer in ("awk ", "sha256sum ", "tar "):
        first_use = _first_command_index(commands, consumer)
        assert downloads < verify < first_use, f"`{consumer.strip()}` runs before verify-blob"


def _checksum_selection(step: str) -> str:
    """The shell that picks the archive's line out of checksums.txt."""
    commands = _chairlift_commands(step)
    start = _first_command_index(commands, "awk ")
    end = commands.index("fi")
    return "; ".join(commands[start : end + 1])


@pytest.mark.parametrize(
    ("arch", "expected"),
    [
        ("amd64", "a" * 64 + "  chairlift_1.2.3-alpha.4_linux_amd64.tar.gz\n"),
        ("arm64", None),
    ],
    ids=["entry-present", "entry-missing"],
)
def test_chairlift_archive_is_checked_against_its_exact_checksums_entry(tmp_path, arch, expected):
    """Run the Containerfile's own selection logic: it must take only the line
    naming this archive exactly (not its .sbom.json sibling, not a filename
    that merely contains it) and fail when checksums.txt has none."""
    step = _chairlift_archive_step()
    commands = _chairlift_commands(step)
    assert 'sha256sum -c "$archive.sha256"' in commands
    assert _first_command_index(commands, "sha256sum ") < _first_command_index(commands, "tar ")

    (tmp_path / "checksums.txt").write_text(
        "a" * 64 + "  chairlift_1.2.3-alpha.4_linux_amd64.tar.gz\n"
        + "b" * 64 + "  chairlift_1.2.3-alpha.4_linux_amd64.tar.gz.sbom.json\n"
        + "c" * 64 + "  chairlift_1.2.3-alpha.4_linux_arm64.tar.gz.sbom.json\n"
        + "d" * 64 + "  xchairlift_1.2.3-alpha.4_linux_arm64.tar.gz\n",
        encoding="utf-8",
    )
    archive = f"chairlift_1.2.3-alpha.4_linux_{arch}.tar.gz"
    result = subprocess.run(
        ["sh", "-euc", _checksum_selection(step)],
        cwd=tmp_path,
        env={"PATH": os.environ["PATH"], "archive": archive},
        capture_output=True,
        text=True,
        check=False,
    )
    if expected is None:
        assert result.returncode != 0, "a missing checksums.txt entry must fail the build"
        assert f"no single entry for {archive}" in result.stderr
    else:
        assert result.returncode == 0, result.stderr
        assert (tmp_path / f"{archive}.sha256").read_text(encoding="utf-8") == expected


def test_chairlift_system_files_install_to_exact_paths_and_modes():
    step = _chairlift_archive_step()
    assert _chairlift_installs(step) == CHAIRLIFT_SYSTEM_FILES

    # Naming each member makes tar fail the build when upstream drops one.
    tar = re.search(r'tar -xzf "\$archive" -C /tmp/chairlift((?: \\\n\s+[^\s;]+)+);', step)
    assert tar, "the archive must be extracted by explicit member list"
    members = re.findall(r"\\\n\s+([^\s;]+)", tar.group(1))
    assert sorted(members) == sorted(member for _, member in CHAIRLIFT_SYSTEM_FILES.values())


def test_chairlift_policy_is_gated_on_the_installed_helper_path():
    """pkexec runs whatever path the policy's exec.path names. If upstream
    moves the helper, the fetched policy would authorize a path nothing
    installs, so the build must refuse a policy that names any other path."""
    step = _chairlift_archive_step()
    helper = next(
        path for path, (mode, _) in CHAIRLIFT_SYSTEM_FILES.items() if mode == "0755"
    )
    assert (
        "grep -qF '<annotate key=\"org.freedesktop.policykit.exec.path\">"
        f"{helper}</annotate>' \"$policy\";" in step
    )
    assert (
        "grep -F 'org.freedesktop.policykit.exec.path' \"$policy\" | "
        f"grep -vqF '>{helper}<'; then" in step
    )
    assert step.index('"$policy";') < step.index("install -Dm")


def test_chairlift_schemas_are_compiled_for_composed_images():
    compose_workflow = (ROOT / ".github/workflows/pr-e2e.yml").read_text(
        encoding="utf-8"
    )
    assert "glib-compile-schemas /usr/share/glib-2.0/schemas" in compose_workflow


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
    contributor depend on projectbluefin/chairlift being reachable.

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
    encoded as a made-up group. Any setting-shaped key absent from the pinned
    upstream schema would fail strict validation."""
    updates = _load_config()["updates_page"]
    invented = {name for name in updates if "setting" in name or "schedul" in name}
    assert not invented, (
        f"invented update-scheduling groups: {invented}; "
        "document the uupd policy in a comment instead"
    )


def test_bundles_paths_point_at_bluefin_brewfiles():
    group = _load_config()["applications_page"]["brew_bundles_group"]
    assert group["bundles_paths"] == ["/usr/share/ublue-os/homebrew"]


#: Bundles ChairLift renders on its Applications page, keyed by Brewfile name.
#: ChairLift derives the bundle's display name from the filename, so these
#: stems are user-visible. They must be immediate children of the directory in
#: brew_bundles_group.bundles_paths -- a nested file is never discovered -- and
#: the filename must carry the exact suffix ChairLift globs for.
EXPECTED_BUNDLES = {
    "wallpaper-slideshow": "app.drey.Damask",
    "video-wallpaper": "io.github.jeffshee.Hidamari",
}


def test_bundle_brewfiles_are_discoverable_by_chairlift():
    """Each bundle must be an immediate *.Brewfile child of bundles_paths.

    ChairLift only scans the top level of each configured path and only for
    the *.Brewfile suffix, so a misplaced file is silently absent from the UI
    rather than an error -- the user just never sees the bundle. Pin both
    halves of that discovery contract against the configured path.
    """
    configured = _load_config()["applications_page"]["brew_bundles_group"][
        "bundles_paths"
    ]
    assert configured == ["/usr/share/ublue-os/homebrew"], (
        "update BUNDLES_DIR if the image path in config.yml changed"
    )
    image_path = configured[0].removeprefix("/usr/share/ublue-os/homebrew")
    assert image_path == "", "BUNDLES_DIR assumes the path is the scan root"

    for stem in EXPECTED_BUNDLES:
        bundle = BUNDLES_DIR / f"{stem}.Brewfile"
        assert bundle.is_file(), f"missing bundle Brewfile: {bundle.name}"
        assert bundle.parent == BUNDLES_DIR, (
            f"{bundle.name} must be an immediate child of {BUNDLES_DIR.name}/; "
            "ChairLift does not recurse"
        )
        assert bundle.stat().st_mode & 0o444 == 0o444, (
            f"{bundle.name} must be world-readable so every user's ChairLift "
            "can read it"
        )


def test_bundle_brewfiles_declare_the_expected_flatpaks():
    """Pin the app ids: a typo here installs the wrong app, or none at all."""
    for stem, app_id in EXPECTED_BUNDLES.items():
        content = (BUNDLES_DIR / f"{stem}.Brewfile").read_text(encoding="utf-8")
        declarations = [
            line.strip()
            for line in content.splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        assert declarations == [f'flatpak "{app_id}"'], (
            f"{stem}.Brewfile must declare exactly flatpak \"{app_id}\", "
            f"found {declarations}"
        )


def test_bundle_names_do_not_collide_with_other_discovered_brewfiles():
    """A duplicate stem would render two identically-named bundles across discoverable paths."""
    all_brewfile_stems = []
    for brewfile in ROOT.glob("system_files/**/usr/share/ublue-os/homebrew/*.Brewfile"):
        all_brewfile_stems.append(brewfile.stem)
    assert len(all_brewfile_stems) == len(set(all_brewfile_stems)), (
        f"duplicate bundle names across homebrew directories: {all_brewfile_stems}"
    )


def test_help_links_point_at_bluefin():
    resources = _load_config()["help_page"]["help_resources_group"]
    for key in ("website", "issues", "chat"):
        assert resources[key].startswith("https://"), f"{key} must be https"
        assert "projectbluefin.io" in resources[key], (
            f"{key} must point at a Bluefin resource"
        )


def test_brewfile_taps_homebrew_tap_with_trust():
    """Homebrew 6 blocks untrusted taps silently; trusted: true is load-bearing.

    The cask must stay the rebranded upstream release: ublue-os/tap
    pins projectbluefin/chairlift, which is the source the schema gate in
    tests/check-chairlift-config validates against."""
    content = BREWFILE.read_text(encoding="utf-8")
    assert 'tap "ublue-os/tap", trusted: true' in content
    assert 'cask "ublue-os/tap/chairlift"' in content


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
    assert entry.get("Name") == "Control Center"
    assert entry.get("Type") == "Application"
    assert entry.get("Icon") == "io.projectbluefin.chairlift"
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
    """Icon=io.projectbluefin.chairlift only resolves if the theme icon exists
    in a system search path; the symbolic variant is referenced by the app
    itself."""
    for icon in ICONS:
        assert icon.is_file(), f"missing icon: {icon.relative_to(ROOT)}"
        assert icon.stat().st_size > 0, f"empty icon: {icon.relative_to(ROOT)}"
        assert icon.read_text(encoding="utf-8").lstrip().startswith(("<?xml", "<svg")), (
            f"{icon.relative_to(ROOT)} is not an SVG document"
        )


# ---------------------------------------------------------------------------
# Ask Bluefin menu entry — the dconf Custom Command Menu entry that launches
# ChairLift's --ask-bluefin dispatcher.
#
# The Custom Command Menu runs each entry through a non-interactive `bash -c`
# with no Homebrew on PATH, so the absolute wrapper path is load-bearing. The
# label "Ask Bluefin" is ChairLift's identity key: its Agents-page switch
# matches the entry by label + a known command, so renames break the switch's
# hide/show behaviour for users who already configured it. The slot number is
# pinned because Developer Mode writes user-layer overrides keyed by slot.
#
# See projectbluefin/common#1396.
# ---------------------------------------------------------------------------

CUSTOM_COMMAND_MENU = (
    ROOT / "system_files/bluefin/etc/dconf/db/distro.d/04-bluefin-custom-command-menu"
)
ASK_BLUEFIN_LABEL = "Ask Bluefin"
ASK_BLUEFIN_SLOT = 11
ASK_BLUEFIN_COMMAND = f"{CHAIRLIFT_WRAPPER} --ask-bluefin"


def _parse_custom_command_menu() -> tuple[dict[int, tuple[str, str, str, bool]], list[int]]:
    """Parse the dconf-style key=value entries into a slot map + the order list.

    The file uses single-quoted GVariant strings and unquoted integers. The
    menu's tuple shape is (label, command, accelerator, enabled).
    """
    entries: dict[int, tuple[str, str, str, bool]] = {}
    order: list[int] = []
    for raw in CUSTOM_COMMAND_MENU.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("menuoptions-setting"):
            continue
        if line.startswith("command-order="):
            inner = line[len("command-order="):]
            order = [int(x.strip()) for x in inner.strip("[]").split(",") if x.strip()]
            continue
        if line.startswith("menu"):
            continue
        if not line.startswith("command"):
            continue
        key, _, value = line.partition("=")
        slot = int(key[len("command"):])
        # GVariant tuple literal: ('label', 'command', 'accelerator', true)
        body = value.strip()
        assert body.startswith("(") and body.endswith(")"), (
            f"unexpected tuple syntax in {CUSTOM_COMMAND_MENU.name}: {raw!r}"
        )
        parts = [p.strip() for p in body[1:-1].split(",")]
        assert len(parts) == 4, (
            f"expected 4-tuple, got {len(parts)} in {CUSTOM_COMMAND_MENU.name}: {raw!r}"
        )
        label = parts[0].strip("'")
        command = parts[1].strip("'")
        accelerator = parts[2].strip("'")
        enabled = parts[3] == "true"
        entries[slot] = (label, command, accelerator, enabled)
    return entries, order


def test_ask_bluefin_menu_entry_dispatches_via_chairlift_wrapper():
    """The Custom Command Menu must launch the ChairLift --ask-bluefin
    dispatcher at the absolute wrapper path. Bare `chairlift --ask-bluefin`
    fails because Homebrew is not on PATH in the menu's bash -c context.
    """
    entries, _ = _parse_custom_command_menu()
    assert ASK_BLUEFIN_SLOT in entries, (
        f"slot {ASK_BLUEFIN_SLOT} is missing from {CUSTOM_COMMAND_MENU.relative_to(ROOT)}"
    )
    label, command, _, enabled = entries[ASK_BLUEFIN_SLOT]
    assert label == ASK_BLUEFIN_LABEL, (
        f"slot {ASK_BLUEFIN_SLOT} label must be {ASK_BLUEFIN_LABEL!r} "
        f"(ChairLift's identity key), got {label!r}"
    )
    assert command == ASK_BLUEFIN_COMMAND, (
        f"slot {ASK_BLUEFIN_SLOT} command must be {ASK_BLUEFIN_COMMAND!r} "
        f"so the menu can find the wrapper on a PATH-less bash -c, got {command!r}"
    )
    assert enabled is True, (
        f"slot {ASK_BLUEFIN_SLOT} must be enabled, got enabled={enabled}"
    )


def test_ask_bluefin_slot_is_listed_in_command_order():
    """The slot number is part of command-order, or the menu hides the entry."""
    _, order = _parse_custom_command_menu()
    assert ASK_BLUEFIN_SLOT in order, (
        f"slot {ASK_BLUEFIN_SLOT} must appear in command-order, got {order}"
    )


def test_no_system_file_references_ask_projectbluefin_io():
    """ask.projectbluefin.io is being shut down; no shipped file should still
    point at it. Caught by ripgrep in CI; this assertion makes the intent
    explicit and lets a single PR prove the cleanup."""
    offenders: list[Path] = []
    for path in ROOT.glob("system_files/**/*"):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if "ask.projectbluefin" in text:
            offenders.append(path)
    assert offenders == [], (
        "these shipped files still reference ask.projectbluefin.io: "
        + ", ".join(str(o.relative_to(ROOT)) for o in offenders)
    )
