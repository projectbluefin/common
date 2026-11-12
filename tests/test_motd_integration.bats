#!/usr/bin/env bats
# Tests for the uwelcome integration:
#   - system_files/shared/etc/profile.d/uwelcome.sh
#   - system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish
#   - toggle-user-motd compatibility recipe in default.just
#   - etc/uwelcome/config.toml
#
# Behavioral contract:
#   - uwelcome owns the opt-out decision. Its state lives at
#     ~/.config/uwelcome/disabled (upstream internal/state/state.go). Neither
#     shell hook gates the uwelcome invocation on any marker file.
#   - Both hooks carry a one-time migration of the legacy
#     ~/.config/no-show-user-motd marker to uwelcome's path. That is the only
#     reason either file mentions the legacy name, and the migration must
#     consume the legacy marker so it does not retry on every login.
#
# Run: bats tests/test_motd_integration.bats

bats_require_minimum_version 1.5.0

UWELCOME_PROFILE="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/uwelcome.sh"
FISH_GREETING="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish"
DEFAULT_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/default.just"
UWELCOME_CONFIG="${BATS_TEST_DIRNAME}/../system_files/shared/etc/uwelcome/config.toml"
UWELCOME_CONFIG_VERSION=1

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home/.config"

    # Mock uwelcome — exits 0, records args to a log
    printf '#!/usr/bin/env bash\necho "uwelcome $*" >> "%s/uwelcome.log"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/uwelcome"
    chmod +x "${WORKDIR}/bin/uwelcome"

    export HOME="${WORKDIR}/home"
    export PATH="${WORKDIR}/bin:${PATH}"
    unset UWELCOME_SHOWN
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# profile.d/uwelcome.sh — bash/zsh login banner
# ---------------------------------------------------------------------------

@test "uwelcome.sh: invokes uwelcome" {
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/uwelcome.log" ]
}

@test "uwelcome.sh: migrates legacy opt-out and still runs uwelcome" {
    touch "${HOME}/.config/no-show-user-motd"
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    # Legacy marker is consumed, not left behind to retry every login
    [ ! -e "${HOME}/.config/no-show-user-motd" ]
    [ -e "${HOME}/.config/uwelcome/disabled" ]
    # uwelcome is invoked unconditionally; it owns the opt-out decision
    [ -f "${WORKDIR}/uwelcome.log" ]
}

@test "uwelcome.sh: migration creates uwelcome config dir when absent" {
    # Regression: the migration used to mv into a directory nothing created,
    # so the opt-out silently failed to migrate on a fresh system.
    [ ! -d "${HOME}/.config/uwelcome" ]
    touch "${HOME}/.config/no-show-user-motd"
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -e "${HOME}/.config/uwelcome/disabled" ]
}

@test "uwelcome.sh: is a no-op migration when no legacy marker exists" {
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.config/uwelcome/disabled" ]
    [ -f "${WORKDIR}/uwelcome.log" ]
}

@test "uwelcome.sh: migration is idempotent across repeated logins" {
    touch "${HOME}/.config/no-show-user-motd"
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -e "${HOME}/.config/uwelcome/disabled" ]
    [ ! -e "${HOME}/.config/no-show-user-motd" ]
}

@test "uwelcome.sh: does not gate the uwelcome call on the legacy marker" {
    # The only mention of the legacy name must be inside the migration block
    run grep -c 'no-show-user-motd' "${UWELCOME_PROFILE}"
    [ "${output}" -le 2 ]
    # uwelcome is called at top level, not nested inside the if
    grep -qE '^\s*uwelcome' "${UWELCOME_PROFILE}"
}

@test "uwelcome.sh: does not call legacy ublue-motd" {
    run grep 'ublue-motd' "${UWELCOME_PROFILE}"
    [ "${status}" -ne 0 ]
}

@test "uwelcome.sh: skips invocation if UWELCOME_SHOWN is set" {
    export UWELCOME_SHOWN=1
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    [ ! -f "${WORKDIR}/uwelcome.log" ]
}

# ---------------------------------------------------------------------------
# fish_greeting.fish — fish login banner (static content checks)
# Fish is not required in CI; these are grep-based structural assertions.
# ---------------------------------------------------------------------------

@test "fish_greeting: function body calls uwelcome" {
    grep -q 'uwelcome' "${FISH_GREETING}"
}

@test "fish_greeting: migrates the legacy opt-out marker to uwelcome state" {
    grep -q 'no-show-user-motd' "${FISH_GREETING}"
    grep -q 'uwelcome/disabled' "${FISH_GREETING}"
}

@test "fish_greeting: migration creates the uwelcome config dir before moving" {
    # Regression: without mkdir the mv fails and fish printed an error on
    # every single shell start, forever, for anyone who had opted out.
    local body
    body="$(cat "${FISH_GREETING}")"
    [[ "${body}" == *"mkdir -p"* ]]
    # mkdir must precede the mv
    local mkdir_line mv_line
    mkdir_line="$(grep -n 'mkdir -p' "${FISH_GREETING}" | head -1 | cut -d: -f1)"
    mv_line="$(grep -n 'mv ' "${FISH_GREETING}" | head -1 | cut -d: -f1)"
    [ "${mkdir_line}" -lt "${mv_line}" ]
}

@test "fish_greeting: invokes uwelcome outside the migration block" {
    # uwelcome must run for every user, not only those being migrated
    local end_line uwelcome_line
    end_line="$(grep -n '^\s*end\s*$' "${FISH_GREETING}" | head -1 | cut -d: -f1)"
    uwelcome_line="$(grep -n '^\s*uwelcome\s*$' "${FISH_GREETING}" | head -1 | cut -d: -f1)"
    [ -n "${uwelcome_line}" ]
    [ "${uwelcome_line}" -gt "${end_line}" ]
}

@test "fish_greeting: does not call legacy ublue-motd" {
    run grep 'ublue-motd' "${FISH_GREETING}"
    [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# toggle-user-motd just recipe — compatibility shim
# ---------------------------------------------------------------------------

@test "toggle-user-motd: recipe delegates to uwelcome toggle" {
    grep -A5 '^toggle-user-motd:' "${DEFAULT_JUST}" | grep -q 'uwelcome toggle'
}

@test "toggle-user-motd: recipe no longer contains legacy gum logic" {
    local recipe
    recipe="$(grep -A20 '^toggle-user-motd:' "${DEFAULT_JUST}")"
    [[ "${recipe}" != *'gum confirm'* ]]
}

@test "toggle-user-motd: recipe no longer manipulates no-show-user-motd file" {
    local recipe
    recipe="$(grep -A20 '^toggle-user-motd:' "${DEFAULT_JUST}")"
    [[ "${recipe}" != *'no-show-user-motd'* ]]
}

# ---------------------------------------------------------------------------
# Shipped configuration — must match the upstream schemas
# ---------------------------------------------------------------------------

@test "uwelcome config: is valid TOML" {
    run python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "${UWELCOME_CONFIG}"
    [ "${status}" -eq 0 ]
}

@test "uwelcome config: command descriptions use known translation keys" {
    run python3 - "${UWELCOME_CONFIG}" <<'PY'
import sys, tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)

known = {
    "cmd_list",
    "cli_pkg",
    "term_bling",
    "banner_toggle",
    "sys_info",
    "man_upd",
    "cmd_report",
}

commands = cfg.get("commands", [])
assert isinstance(commands, list), "commands must be an array"
assert all(isinstance(command, dict) and isinstance(command.get("desc"), str) for command in commands), \
    "every command must have a string description"

descs = {command["desc"] for command in commands}
unknown = sorted(descs - known)
assert not unknown, f"unknown command descriptions: {unknown}"
PY
    [ "${status}" -eq 0 ]
}

@test "uwelcome config: banner toggle points at the uwelcome subcommand" {
    run python3 - "${UWELCOME_CONFIG}" <<'PY'
import sys, tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)

commands = cfg.get("commands", [])
toggle_commands = [
    command.get("cmd")
    for command in commands
    if isinstance(command, dict) and command.get("desc") == "banner_toggle"
]
assert toggle_commands == ["uwelcome toggle"], f"unexpected banner toggle commands: {toggle_commands!r}"
PY
    [ "${status}" -eq 0 ]
}

@test "uwelcome config: has the expected version" {
    run python3 - "${UWELCOME_CONFIG}" "${UWELCOME_CONFIG_VERSION}" <<'PY'
import sys, tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)

expected = int(sys.argv[2])
actual = cfg.get("version")
assert type(actual) is int and actual == expected, f"expected config version {expected}, got {actual!r}"
PY
    [ "${status}" -eq 0 ]
}


@test "uwelcome config: explicitly disables built-in and command tips" {
    run python3 - "${UWELCOME_CONFIG}" <<'PY'
import sys, tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)
assert cfg.get("motd") == {"messages": [], "commands": []}
PY
    [ "${status}" -eq 0 ]
}
