#!/usr/bin/env bats
# Tests for apps.just recipes: install-opentabletdriver and cncf.
#
# Scope note: the `install-jetbrains-toolbox` and `install-asus` recipes in the
# same file are deliberately NOT covered here — their `brew tap --trust` lines
# are being changed by other open PRs. This file only exercises recipes that do
# not use `brew tap`.

APPS_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/apps.just"
WORKDIR=""
MOCKDIR=""
COMMAND_LOG=""
OTD_SCRIPT=""
CNCF_SCRIPT=""

# Extract the bash body of a just recipe into a standalone script.
# Handles both `#!/usr/bin/bash` and `#!/usr/bin/env bash` recipe shebangs.
_extract_script() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { in_recipe=1; next }
        in_recipe && /^    #!\/usr\/bin\/(env )?bash$/ { found=1; print "#!/usr/bin/env bash"; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${APPS_JUST}" > "${out_file}"
    chmod +x "${out_file}"
}

_write_mock() {
    local name="$1"
    cat > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test-apps-just-${BATS_TEST_NUMBER}-$$"
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"

    MOCKDIR="${WORKDIR}/bin"
    COMMAND_LOG="${WORKDIR}/commands.log"
    mkdir -p "${MOCKDIR}"
    : > "${COMMAND_LOG}"

    OTD_SCRIPT="${WORKDIR}/install-opentabletdriver.sh"
    CNCF_SCRIPT="${WORKDIR}/cncf.sh"
    _extract_script "install-opentabletdriver" "${OTD_SCRIPT}"
    _extract_script "cncf" "${CNCF_SCRIPT}"

    _write_mock "gum" <<'MOCK'
#!/usr/bin/env bash
echo "gum $*" >> "${COMMAND_LOG}"
if [[ "$1" == "confirm" ]]; then
    exit "${MOCK_GUM_CONFIRM_EXIT:-0}"
fi
exit 0
MOCK

    _write_mock "sudo" <<'MOCK'
#!/usr/bin/env bash
echo "sudo $*" >> "${COMMAND_LOG}"
exec "$@"
MOCK

    _write_mock "curl" <<'MOCK'
#!/usr/bin/env bash
echo "curl $*" >> "${COMMAND_LOG}"
for arg in "$@"; do
    case "${arg}" in
        *api.github.com/repos/OpenTabletDriver*)
            cat "${MOCK_RELEASE_JSON}"
            exit 0
            ;;
        *opentabletdriver.service)
            printf '%s\n' "MOCK-SYSTEMD-UNIT"
            exit 0
            ;;
    esac
done
# asset download leg: emit the prepared tarball on stdout
if [[ -n "${MOCK_OTD_TARBALL:-}" && -f "${MOCK_OTD_TARBALL}" ]]; then
    cat "${MOCK_OTD_TARBALL}"
fi
exit 0
MOCK

    _write_mock "flatpak" <<'MOCK'
#!/usr/bin/env bash
echo "flatpak $*" >> "${COMMAND_LOG}"
exit 0
MOCK

    _write_mock "systemctl" <<'MOCK'
#!/usr/bin/env bash
echo "systemctl $*" >> "${COMMAND_LOG}"
exit 0
MOCK

    _write_mock "brew" <<'MOCK'
#!/usr/bin/env bash
echo "brew $*" >> "${COMMAND_LOG}"
exit "${MOCK_BREW_EXIT:-0}"
MOCK

    _write_mock "ujust" <<'MOCK'
#!/usr/bin/env bash
echo "ujust $*" >> "${COMMAND_LOG}"
exit 0
MOCK

    # Fixture: GitHub release payload with one matching tar.gz asset plus decoys.
    MOCK_RELEASE_JSON="${WORKDIR}/release.json"
    cat > "${MOCK_RELEASE_JSON}" <<'JSON'
{
  "assets": [
    {"name": "OpenTabletDriver.deb", "browser_download_url": "https://example.invalid/otd.deb"},
    {"name": "opentabletdriver-0.6.4.tar.gz", "browser_download_url": "https://example.invalid/otd.tar.gz"},
    {"name": "OpenTabletDriver.rpm", "browser_download_url": "https://example.invalid/otd.rpm"}
  ]
}
JSON

    # Fixture: tarball shaped like the real release (one top-level dir that
    # --strip-components=1 removes), carrying the udev rule the recipe copies.
    local stage="${WORKDIR}/stage/OpenTabletDriver"
    mkdir -p "${stage}/etc/udev/rules.d"
    printf '%s\n' "MOCK-UDEV-RULE" > "${stage}/etc/udev/rules.d/70-opentabletdriver.rules"
    MOCK_OTD_TARBALL="${WORKDIR}/otd.tar.gz"
    tar -czf "${MOCK_OTD_TARBALL}" -C "${WORKDIR}/stage" OpenTabletDriver

    # Redirect the recipe's absolute system paths into the sandbox. Anchor on a
    # leading space so the "${OTD_TMPDIR}/etc/..." source path is left alone.
    FAKE_ROOT="${WORKDIR}/root"
    mkdir -p "${FAKE_ROOT}/etc/udev/rules.d" "${FAKE_ROOT}/etc/modprobe.d" \
        "${FAKE_ROOT}/usr/share/ublue-os/homebrew"
    sed -i \
        -e "s| /etc/udev/rules.d| ${FAKE_ROOT}/etc/udev/rules.d|g" \
        -e "s| /etc/modprobe.d| ${FAKE_ROOT}/etc/modprobe.d|g" \
        "${OTD_SCRIPT}"
    sed -i \
        -e "s|/usr/share/ublue-os/homebrew|${FAKE_ROOT}/usr/share/ublue-os/homebrew|g" \
        "${CNCF_SCRIPT}"
    printf '%s\n' 'brew "kubectl"' > "${FAKE_ROOT}/usr/share/ublue-os/homebrew/cncf.Brewfile"

    HOMEDIR="${WORKDIR}/home"
    mkdir -p "${HOMEDIR}"

    chmod -R a+rwX "${WORKDIR}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_run_otd() {
    run env \
        PATH="${MOCKDIR}:${PATH}" \
        COMMAND_LOG="${COMMAND_LOG}" \
        HOME="${HOMEDIR}" \
        MOCK_GUM_CONFIRM_EXIT="${MOCK_GUM_CONFIRM_EXIT:-0}" \
        MOCK_RELEASE_JSON="${MOCK_RELEASE_JSON}" \
        MOCK_OTD_TARBALL="${MOCK_OTD_TARBALL}" \
        bash "${OTD_SCRIPT}"
}

_run_cncf() {
    run env \
        PATH="${MOCKDIR}:${PATH}" \
        COMMAND_LOG="${COMMAND_LOG}" \
        HOME="${HOMEDIR}" \
        MOCK_BREW_EXIT="${MOCK_BREW_EXIT:-0}" \
        bash "$@" "${CNCF_SCRIPT}"
}

# --- extraction sanity ---------------------------------------------------

@test "install-opentabletdriver recipe body is extractable and non-empty" {
    [ -s "${OTD_SCRIPT}" ]
    grep -q "OTD_TMPDIR" "${OTD_SCRIPT}"
}

@test "cncf recipe body is extractable and non-empty" {
    [ -s "${CNCF_SCRIPT}" ]
    grep -q "brew bundle" "${CNCF_SCRIPT}"
}

@test "apps.just recipes covered here do not call brew tap" {
    # Guards the scope boundary of this file against future edits.
    ! grep -q "brew tap" "${OTD_SCRIPT}"
    ! grep -q "brew tap" "${CNCF_SCRIPT}"
}

# --- install-opentabletdriver: install branch ----------------------------

@test "install-opentabletdriver: gum confirm affirmative runs the install branch" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing OpenTabletDriver..."* ]]
    [[ "$output" != *"Uninstalling OpenTabletDriver..."* ]]
}

@test "install-opentabletdriver: install selects the tar.gz asset, not the deb or rpm" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    grep -q "otd.tar.gz" "${COMMAND_LOG}"
    ! grep -q "otd.deb" "${COMMAND_LOG}"
    ! grep -q "otd.rpm" "${COMMAND_LOG}"
}

@test "install-opentabletdriver: install renames the udev rule 70- -> 71-" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    [ -f "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules" ]
    [ ! -f "${FAKE_ROOT}/etc/udev/rules.d/70-opentabletdriver.rules" ]
    grep -q "MOCK-UDEV-RULE" "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules"
}

@test "install-opentabletdriver: install blacklists hid_uclogic and wacom" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    local conf="${FAKE_ROOT}/etc/modprobe.d/blacklist-opentabletdriver.conf"
    [ -f "${conf}" ]
    grep -qx "blacklist hid_uclogic" "${conf}"
    grep -qx "blacklist wacom" "${conf}"
}

@test "install-opentabletdriver: install removes the temp extraction directory" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    local tmpdir
    tmpdir="$(grep -m1 -o "${TMPDIR:-/tmp}/tmp\.[A-Za-z0-9]*" "${COMMAND_LOG}" || true)"
    if [ -n "${tmpdir}" ]; then
        [ ! -d "${tmpdir}" ]
    fi
}

@test "install-opentabletdriver: install adds the flathub package system-wide" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    grep -q "flatpak --system install -y flathub net.opentabletdriver.OpenTabletDriver" "${COMMAND_LOG}"
}

@test "install-opentabletdriver: install writes the user service unit and enables it" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    [ -f "${HOMEDIR}/.config/systemd/user/opentabletdriver.service" ]
    grep -q "MOCK-SYSTEMD-UNIT" "${HOMEDIR}/.config/systemd/user/opentabletdriver.service"
    grep -q "systemctl --user daemon-reload" "${COMMAND_LOG}"
    grep -q "systemctl enable --user --now opentabletdriver.service" "${COMMAND_LOG}"
}

# --- install-opentabletdriver: uninstall branch --------------------------

@test "install-opentabletdriver: gum confirm negative runs the uninstall branch" {
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uninstalling OpenTabletDriver..."* ]]
    [[ "$output" != *"Installing OpenTabletDriver..."* ]]
}

@test "install-opentabletdriver: uninstall removes the flathub package" {
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    grep -q "flatpak --system remove -y flathub net.opentabletdriver.OpenTabletDriver" "${COMMAND_LOG}"
}

@test "install-opentabletdriver: uninstall makes no network calls" {
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    ! grep -q "^curl " "${COMMAND_LOG}"
}

@test "install-opentabletdriver: uninstall does not touch the user service unit" {
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    [ ! -f "${HOMEDIR}/.config/systemd/user/opentabletdriver.service" ]
}

@test "install-opentabletdriver: uninstall leaves the udev rule path clean" {
    # Seed the artifacts an earlier install would have left behind.
    printf '%s\n' "MOCK-UDEV-RULE" > "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules"
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    [ ! -f "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules" ]
}

@test "install-opentabletdriver: uninstall targets the wrong modprobe filename (regression guard)" {
    # The recipe writes blacklist-opentabletdriver.conf on install but removes
    # blacklist-opentabletdriver.rules on uninstall, so the blacklist survives.
    # This test pins the current behaviour; flip it when the recipe is fixed.
    printf '%s\n' "blacklist wacom" > "${FAKE_ROOT}/etc/modprobe.d/blacklist-opentabletdriver.conf"
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    [ -f "${FAKE_ROOT}/etc/modprobe.d/blacklist-opentabletdriver.conf" ]
}

@test "install-opentabletdriver: gum confirm exit code 130 (Ctrl-C) does nothing" {
    MOCK_GUM_CONFIRM_EXIT=130 _run_otd
    [ "$status" -eq 0 ]
    [[ "$output" != *"Installing OpenTabletDriver..."* ]]
    [[ "$output" != *"Uninstalling OpenTabletDriver..."* ]]
    ! grep -q "^flatpak " "${COMMAND_LOG}"
}

# --- cncf ----------------------------------------------------------------

@test "cncf: runs brew bundle against the curated cncf Brewfile" {
    _run_cncf
    [ "$status" -eq 0 ]
    grep -q "brew bundle --file=.*cncf.Brewfile" "${COMMAND_LOG}"
}

@test "cncf: does not invoke ujust --choose when stdin is not a tty" {
    _run_cncf < /dev/null
    [ "$status" -eq 0 ]
    ! grep -q "ujust --choose" "${COMMAND_LOG}"
}

@test "cncf: exits 0 even when stdin is not a tty" {
    # The `|| true` tail must keep the recipe from failing on a non-tty run.
    _run_cncf < /dev/null
    [ "$status" -eq 0 ]
}

@test "cncf: a failing brew bundle does not stop the recipe (no set -e)" {
    MOCK_BREW_EXIT=1 _run_cncf < /dev/null
    [ "$status" -eq 0 ]
    grep -q "brew bundle" "${COMMAND_LOG}"
}
