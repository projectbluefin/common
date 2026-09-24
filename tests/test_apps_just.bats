#!/usr/bin/env bats
# Tests for apps.just recipes: install-opentabletdriver and cncf.
#
# install-opentabletdriver carries supply-chain pins (projectbluefin/common#1170):
# the OTD_TARBALL_* / OTD_SERVICE_* constants below mirror the URL and sha256
# pins in the recipe and must be updated together with it on every bump.
#
# Scope note: the `install-jetbrains-toolbox` and `install-asus` recipes in the
# same file are not covered here yet. Their `brew tap` / `brew trust` lines are
# covered by tests/test_brew_tap_trust.bats; recipe-level coverage for them is
# a follow-up.

APPS_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/apps.just"
OTD_TARBALL_URL="https://github.com/OpenTabletDriver/OpenTabletDriver/releases/download/v0.6.7/opentabletdriver-0.6.7_linux-x64_simple.tar.gz"
OTD_TARBALL_SHA256="ab3ecfed8579864d947b2ad04c236822a109bc7c52519af7aaa36e03e99d2265"
OTD_SERVICE_URL="https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/1a2a2083b8ed831df3b8b6ae3ddfe7dc21d02e01/scripts/opentabletdriver.service"
OTD_SERVICE_SHA256="ef2f5c450ed1b30cd143285ee119f3cd89fc7b00e1a62ffe471dc4bdd0a1260a"
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

    # The otd curl mock honours the flags the recipe passes: -f (fail mode) and
# -o (write payload to file instead of stdout). Modes set via CURL_OTD_MODE
# (default 'ok'; 'corrupt' serves a tampered tarball, 'http-error' exits 22).
_write_mock "curl" <<'MOCK'
#!/usr/bin/env bash
echo "curl $*" >> "${COMMAND_LOG}"
url=""
outfile=""
want_outfile=0
for arg in "$@"; do
    if [[ "${want_outfile}" == 1 ]]; then
        outfile="${arg}"
        want_outfile=0
        continue
    fi
    case "${arg}" in
        -o|--output) want_outfile=1 ;;
        -*) ;;
        *) url="${arg}" ;;
    esac
done
mode="${CURL_OTD_MODE:-ok}"
if [[ "${mode}" == "http-error" ]]; then
    echo "curl: (22) The requested URL returned error: 500" >&2
    exit 22
fi
if [[ -n "${outfile}" ]]; then
    emit() { cat > "${outfile}"; }
else
    emit() { cat; }
fi
case "${url}" in
    *opentabletdriver.service)
        printf '%s\n' "MOCK-SYSTEMD-UNIT" | emit
        ;;
    *OpenTabletDriver*releases/latest*)
        emit < "${MOCK_RELEASE_JSON}"
        ;;
    *)
        # tarball download leg; 'corrupt' serves a payload that fails the
        # recipe's sha256 gate
        if [[ "${mode}" == "corrupt" ]]; then
            printf 'tampered-payload' | emit
        elif [[ -n "${MOCK_OTD_TARBALL:-}" && -f "${MOCK_OTD_TARBALL}" ]]; then
            emit < "${MOCK_OTD_TARBALL}"
        fi
        ;;
esac
exit 0
MOCK

    # Log-and-passthrough so checksum-gate ordering is observable while the
    # real verification (and its tamper behaviour) still runs.
    _write_mock "sha256sum" <<'MOCK'
#!/usr/bin/env bash
echo "sha256sum $*" >> "${COMMAND_LOG}"
exec /usr/bin/sha256sum "$@"
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

    # Fixture: tarball shaped like the upstream 'simple' release package (one
    # top-level dir that --strip-components=1 removes, rules file at the
    # archive root), carrying the udev rule the recipe copies.
    local stage="${WORKDIR}/stage/opentabletdriver-Simple"
    mkdir -p "${stage}"
    printf '%s\n' "MOCK-UDEV-RULE" > "${stage}/70-opentabletdriver.rules"
    MOCK_OTD_TARBALL="${WORKDIR}/otd.tar.gz"
    tar -czf "${MOCK_OTD_TARBALL}" -C "${WORKDIR}/stage" opentabletdriver-Simple
    # Matches OTD_TARBALL_SHA256 so the recipe's checksum gate passes.
    MOCK_OTD_TARBALL_SHA256="${OTD_TARBALL_SHA256}"

    # Redirect the recipe's absolute system paths into the sandbox. Anchor on a
    # leading space so the "${OTD_TMPDIR}/..." source path is left alone.
    FAKE_ROOT="${WORKDIR}/root"
    mkdir -p "${FAKE_ROOT}/etc/udev/rules.d" "${FAKE_ROOT}/etc/modprobe.d" \
        "${FAKE_ROOT}/usr/share/ublue-os/homebrew"
    sed -i \
        -e "s| /etc/udev/rules.d| ${FAKE_ROOT}/etc/udev/rules.d|g" \
        -e "s| /etc/modprobe.d| ${FAKE_ROOT}/etc/modprobe.d|g" \
        "${OTD_SCRIPT}"
    # The sha256 gate in the recipe uses the real release pin; substitute the
    # fixture tarball's own sha256 so the sandboxed install run passes its
    # checksum gate (the tampered-payload test asserts the gate still fires).
    local fixture_hash
    fixture_hash="$(sha256sum "${MOCK_OTD_TARBALL}" | awk '{print $1}')"
    sed -i "s|${OTD_TARBALL_SHA256}|${fixture_hash}|" "${OTD_SCRIPT}"
    # Same for the systemd-unit gate: the mock serves a fixture unit, so swap
    # in the hash of the exact bytes the mock writes.
    local fixture_service_hash
    fixture_service_hash="$(printf '%s\n' "MOCK-SYSTEMD-UNIT" | sha256sum | awk '{print $1}')"
    sed -i "s|${OTD_SERVICE_SHA256}|${fixture_service_hash}|" "${OTD_SCRIPT}"
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
        MOCK_OTD_TARBALL_SHA256="${MOCK_OTD_TARBALL_SHA256}" \
        CURL_OTD_MODE="${CURL_OTD_MODE:-ok}" \
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

# --- install-opentabletdriver: install branch ----------------------------

@test "install-opentabletdriver: gum confirm affirmative runs the install branch" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing OpenTabletDriver..."* ]]
    [[ "$output" != *"Uninstalling OpenTabletDriver..."* ]]
}

@test "install-opentabletdriver: install fetches the pinned release tarball URL" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    # $* in the mock collapses the recipe's quoting; the URL appears unquoted
    grep -qF "curl -fsSL ${OTD_TARBALL_URL}" "${COMMAND_LOG}"
}

@test "install-opentabletdriver: install verifies the tarball sha256 before extraction" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    local log_line
    log_line="$(grep -F "sha256sum -c" "${COMMAND_LOG}" | head -1)"
    [ -n "${log_line}" ]
}

@test "install-opentabletdriver: install rejects a tampered tarball (sha256 mismatch)" {
    CURL_OTD_MODE=corrupt MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -ne 0 ]
    [[ "$output" == *"WARNING: 1 computed checksum did NOT match"* ]]
    # Nothing may be installed after the failed verification.
    ! grep -q "sudo cp" "${COMMAND_LOG}"
    ! grep -q "flatpak --system install" "${COMMAND_LOG}"
    [ ! -f "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules" ]
    [ ! -f "${HOMEDIR}/.config/systemd/user/opentabletdriver.service" ]
}

@test "install-opentabletdriver: install fetches the systemd unit from a pinned commit, not a moving branch" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    grep -qF "curl -fsSL ${OTD_SERVICE_URL}" "${COMMAND_LOG}"
    ! grep -qE "refs/heads/|/master/" "${COMMAND_LOG}"
}

@test "install-opentabletdriver: install renames the udev rule 70- -> 71-" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    [ -f "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules" ]
    [ ! -f "${FAKE_ROOT}/etc/udev/rules.d/70-opentabletdriver.rules" ]
    grep -q "MOCK-UDEV-RULE" "${FAKE_ROOT}/etc/udev/rules.d/71-opentabletdriver.rules"
}

@test "install-opentabletdriver: install writes the systemd unit only after its sha256 verifies" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    [ -f "${HOMEDIR}/.config/systemd/user/opentabletdriver.service" ]
    grep -q "MOCK-SYSTEMD-UNIT" "${HOMEDIR}/.config/systemd/user/opentabletdriver.service"
    # The unit sha256 gate runs against the downloaded file before enable.
    grep -q "sha256sum -c" "${COMMAND_LOG}"
    local last_check
    last_check="$(grep -n "sha256sum -c" "${COMMAND_LOG}" | tail -1 | cut -d: -f1)"
    local enable_line
    enable_line="$(grep -n "systemctl enable --user --now" "${COMMAND_LOG}" | head -1 | cut -d: -f1)"
    [ -n "${enable_line}" ]
    [ "${last_check}" -lt "${enable_line}" ]
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

@test "install-opentabletdriver: install enables the user service unit" {
    MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -eq 0 ]
    grep -q "systemctl --user daemon-reload" "${COMMAND_LOG}"
    grep -q "systemctl enable --user --now opentabletdriver.service" "${COMMAND_LOG}"
}

@test "install-opentabletdriver: install fails closed when curl errors (no -f would hide it)" {
    CURL_OTD_MODE=http-error MOCK_GUM_CONFIRM_EXIT=0 _run_otd
    [ "$status" -ne 0 ]
    ! grep -q "sudo cp" "${COMMAND_LOG}"
    ! grep -q "flatpak --system install" "${COMMAND_LOG}"
    [ ! -f "${HOMEDIR}/.config/systemd/user/opentabletdriver.service" ]
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

@test "install-opentabletdriver: uninstall removes the modprobe blacklist it installed" {
    # Install writes blacklist-opentabletdriver.conf; uninstall must remove the
    # same file, or hid_uclogic and wacom stay blacklisted after removal
    # (projectbluefin/common#1065: uninstall used to target a .rules name).
    printf '%s\n' "blacklist wacom" > "${FAKE_ROOT}/etc/modprobe.d/blacklist-opentabletdriver.conf"
    MOCK_GUM_CONFIRM_EXIT=1 _run_otd
    [ "$status" -eq 0 ]
    [ ! -f "${FAKE_ROOT}/etc/modprobe.d/blacklist-opentabletdriver.conf" ]
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
