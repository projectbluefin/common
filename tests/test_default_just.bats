#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/just/default.just
#
# Covers the recipes that had no test coverage:
#   - bios                    (EFI guard + gum-confirmed firmware reboot)
#   - bios-info               (dmidecode fields read under sudo)
#   - enroll-secure-boot-key  (mokutil MOK import under sudo)
#   - toggle-user-motd        (uwelcome compatibility shim)
#   - check-local-overrides   (NO_COLOR handling + /usr/etc vs /etc diff)
#   - check-idle-power-draw   (powerstat availability guard)
#   - benchmark               (stress-ng install prompt + run)
#
# Deliberately NOT covered here:
#   - clean-system  — already covered by tests/test_clean_system_podman_path.bats
#   - device-info   — in flight in PR #1003
#
# Every shebang recipe body is extracted verbatim and executed against stubbed
# binaries, so the real control flow is exercised rather than grepped. Absolute
# host paths (/sys/firmware/efi, /usr/etc, /etc) are redirected into the
# sandbox with sed before execution.

DEFAULT_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/default.just"
WORKDIR=""

# Extract a shebang recipe body from default.just and dedent it by four spaces.
_extract_recipe() {
    awk -v name="$1" '
        $0 == name ":" { in_recipe = 1; next }
        in_recipe && $0 ~ /^[^[:space:]]/ { exit }
        in_recipe && $0 ~ /^    / { sub(/^    /, ""); print }
        in_recipe && $0 == "" { print }
    ' "${DEFAULT_JUST}"
}

_write_stub() {
    local name="$1"
    cat > "${WORKDIR}/bin/${name}" <<EOF
#!/usr/bin/bash
printf '${name} %s\n' "\$*" >> "\${CALLS}"
EOF
    chmod +x "${WORKDIR}/bin/${name}"
}

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    : > "${WORKDIR}/calls.log"
    : > "${WORKDIR}/gum-exits"

    # gum stub: logs the call and pops one exit status per invocation so that
    # `gum confirm` branches can be driven from the test.
    cat > "${WORKDIR}/bin/gum" <<'EOF'
#!/usr/bin/bash
printf 'gum %s\n' "$*" >> "${CALLS}"
code="$(/usr/bin/head -n1 "${GUM_EXITS}")"
/usr/bin/tail -n +2 "${GUM_EXITS}" > "${GUM_EXITS}.tmp"
/bin/mv "${GUM_EXITS}.tmp" "${GUM_EXITS}"
exit "${code:-0}"
EOF
    chmod +x "${WORKDIR}/bin/gum"

    # sudo stub: logs the call and then runs the command it was given, so
    # heredocs piped into `sudo bash` still execute against the other stubs.
    cat > "${WORKDIR}/bin/sudo" <<'EOF'
#!/usr/bin/bash
printf 'sudo %s\n' "$*" >> "${CALLS}"
exec "$@"
EOF
    chmod +x "${WORKDIR}/bin/sudo"

    for stub in systemctl dmidecode mokutil powerstat stress-ng uwelcome; do
        _write_stub "${stub}"
    done

    # brew stub: logs the call and, on `brew install`, drops a stress-ng stub on
    # PATH so the post-install run in `benchmark` resolves like it would after a
    # real install.
    cat > "${WORKDIR}/bin/brew" <<'EOF'
#!/usr/bin/bash
printf 'brew %s\n' "$*" >> "${CALLS}"
if [ "$1" = "install" ]; then
    printf '#!/usr/bin/bash\nprintf '"'"'stress-ng %%s\\n'"'"' "$*" >> "${CALLS}"\n' \
        > "${STUB_BIN}/stress-ng"
    /usr/bin/chmod +x "${STUB_BIN}/stress-ng"
fi
EOF
    chmod +x "${WORKDIR}/bin/brew"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_queue_gum_exits() {
    printf '%s\n' "$@" > "${WORKDIR}/gum-exits"
}

# Run a script from the sandbox with a clean environment and stubs on PATH.
_run_script() {
    run /usr/bin/env -i \
        PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        HOME="${WORKDIR}" \
        CALLS="${WORKDIR}/calls.log" \
        GUM_EXITS="${WORKDIR}/gum-exits" \
        STUB_BIN="${WORKDIR}/bin" \
        NO_COLOR="${NO_COLOR_VALUE:-}" \
        /usr/bin/bash "$1"
}

_calls() {
    cat "${WORKDIR}/calls.log"
}

# ---------------------------------------------------------------- bios

# Extract `bios` with the EFI probe redirected at a sandbox directory so both
# branches are reachable without depending on the host's firmware.
_prepare_bios() {
    _extract_recipe bios \
        | sed "s#/sys/firmware/efi#${WORKDIR}/efi#g" > "${WORKDIR}/bios.sh"
    chmod +x "${WORKDIR}/bios.sh"
}

@test "default.just: bios recipe body is extractable and non-empty" {
    _prepare_bios
    [ -s "${WORKDIR}/bios.sh" ]
    run head -n1 "${WORKDIR}/bios.sh"
    [ "${output}" = "#!/usr/bin/bash" ]
}

@test "bios: refuses on legacy BIOS systems and never reboots" {
    _prepare_bios
    _queue_gum_exits 0

    _run_script "${WORKDIR}/bios.sh"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"not supported"* ]]
    run grep -q "systemctl" <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "bios: reboots to firmware setup when EFI present and user confirms" {
    _prepare_bios
    mkdir -p "${WORKDIR}/efi"
    _queue_gum_exits 0

    _run_script "${WORKDIR}/bios.sh"

    [ "${status}" -eq 0 ]
    run grep -Fq "systemctl reboot --firmware-setup" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "bios: does not reboot when the user declines the confirmation" {
    _prepare_bios
    mkdir -p "${WORKDIR}/efi"
    _queue_gum_exits 1

    _run_script "${WORKDIR}/bios.sh"

    run grep -q "systemctl" <<< "$(_calls)"
    [ "${status}" -ne 0 ]
    run grep -Fq "gum confirm" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

# ----------------------------------------------------------- bios-info

@test "bios-info: reads all four dmidecode fields under sudo" {
    _extract_recipe bios-info > "${WORKDIR}/bios-info.sh"

    _run_script "${WORKDIR}/bios-info.sh"

    [ "${status}" -eq 0 ]
    local calls
    calls="$(_calls)"
    for field in baseboard-manufacturer baseboard-product-name bios-version bios-release-date; do
        run grep -Fq "dmidecode -s ${field}" <<< "${calls}"
        [ "${status}" -eq 0 ]
    done
    run grep -Fq "sudo bash" <<< "${calls}"
    [ "${status}" -eq 0 ]
}

@test "bios-info: labels every field it prints" {
    _extract_recipe bios-info > "${WORKDIR}/bios-info.sh"

    _run_script "${WORKDIR}/bios-info.sh"

    for label in "Manufacturer:" "Product Name:" "Version:" "Release Date:"; do
        [[ "${output}" == *"${label}"* ]]
    done
}

# --------------------------------------------- enroll-secure-boot-key

@test "enroll-secure-boot-key: disables the mokutil timeout before importing" {
    _extract_recipe enroll-secure-boot-key > "${WORKDIR}/enroll.sh"

    _run_script "${WORKDIR}/enroll.sh"

    [ "${status}" -eq 0 ]
    run grep -Fq "mokutil --timeout -1" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "enroll-secure-boot-key: imports the ublue akmods certificate" {
    _extract_recipe enroll-secure-boot-key > "${WORKDIR}/enroll.sh"

    _run_script "${WORKDIR}/enroll.sh"

    run grep -Fq "mokutil --import /etc/pki/akmods/certs/akmods-ublue.der" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "enroll-secure-boot-key: tells the user the enrollment password" {
    _extract_recipe enroll-secure-boot-key > "${WORKDIR}/enroll.sh"

    _run_script "${WORKDIR}/enroll.sh"

    [[ "${output}" == *"universalblue"* ]]
    [[ "${output}" == *"Enroll MOK"* ]]
}

# ------------------------------------------------------ toggle-user-motd

@test "toggle-user-motd: is a thin shim that delegates to uwelcome toggle" {
    local body
    body="$(awk '
        $0 == "toggle-user-motd:" { in_recipe = 1; next }
        in_recipe && $0 ~ /^[^[:space:]]/ { exit }
        in_recipe && $0 ~ /^    / { sub(/^    /, ""); print }
    ' "${DEFAULT_JUST}")"

    [ "${body}" = "uwelcome toggle" ]
}

# ------------------------------------------------- check-local-overrides

# Extract `check-local-overrides` with the /usr/etc and /etc operands pointed at
# sandbox trees. The trailing ` /usr/etc /etc ` operand pair is the only place
# those paths appear, so an anchored substitution is unambiguous.
_prepare_overrides() {
    mkdir -p "${WORKDIR}/usr-etc" "${WORKDIR}/etc"
    _extract_recipe check-local-overrides \
        | sed "s#^  /usr/etc /etc #  ${WORKDIR}/usr-etc ${WORKDIR}/etc #" \
        > "${WORKDIR}/overrides.sh"
    chmod +x "${WORKDIR}/overrides.sh"
}

@test "check-local-overrides: recipe still diffs /usr/etc against /etc" {
    run grep -Fq "/usr/etc /etc" "$(printf '%s' "${DEFAULT_JUST}")"
    [ "${status}" -eq 0 ]
}

@test "check-local-overrides: reports a file that exists only in /etc" {
    _prepare_overrides
    printf 'local\n' > "${WORKDIR}/etc/custom.conf"

    _run_script "${WORKDIR}/overrides.sh"

    [[ "${output}" == *"custom.conf"* ]]
}

@test "check-local-overrides: reports a file whose content diverged" {
    _prepare_overrides
    printf 'shipped\n' > "${WORKDIR}/usr-etc/shared.conf"
    printf 'edited\n' > "${WORKDIR}/etc/shared.conf"

    _run_script "${WORKDIR}/overrides.sh"

    [[ "${output}" == *"shared.conf"* ]]
}

@test "check-local-overrides: stays quiet when the trees match" {
    _prepare_overrides
    printf 'same\n' > "${WORKDIR}/usr-etc/shared.conf"
    printf 'same\n' > "${WORKDIR}/etc/shared.conf"

    _run_script "${WORKDIR}/overrides.sh"

    [ -z "${output}" ]
}

@test "check-local-overrides: drops its own color codes when NO_COLOR=1" {
    _prepare_overrides
    printf 'local\n' > "${WORKDIR}/etc/custom.conf"

    NO_COLOR_VALUE=1 _run_script "${WORKDIR}/overrides.sh"

    [[ "${output}" == *"custom.conf"* ]]
    # GNU sed expands the \x1b in the palette variables, so real ESC bytes
    # would appear in the output if the palette were still active.
    run grep -Fq $'\x1b[38;5;' <<< "${output}"
    [ "${status}" -ne 0 ]
    run grep -Fq $'\x1b[93m' <<< "${output}"
    [ "${status}" -ne 0 ]
}

@test "check-local-overrides: applies its own color codes when NO_COLOR is unset" {
    _prepare_overrides
    printf 'local\n' > "${WORKDIR}/etc/custom.conf"

    _run_script "${WORKDIR}/overrides.sh"

    [[ "${output}" == *"custom.conf"* ]]
    run grep -Fq $'\x1b[38;5;85m' <<< "${output}"
    [ "${status}" -eq 0 ]
}

# Documents current behaviour: NO_COLOR=1 only suppresses the palette the
# recipe applies itself. `diff --color="always"` is hardcoded, so diff's own
# ANSI escapes are still emitted. Pinning this makes any future fix visible.
@test "check-local-overrides: diff --color=always is unconditional (NO_COLOR gap)" {
    local recipe
    recipe="$(_extract_recipe check-local-overrides)"

    run grep -Fq -- '--color="always"' <<< "${recipe}"
    [ "${status}" -eq 0 ]

    _prepare_overrides
    printf 'local\n' > "${WORKDIR}/etc/custom.conf"

    NO_COLOR_VALUE=1 _run_script "${WORKDIR}/overrides.sh"

    run grep -q $'\x1b\\[' <<< "${output}"
    [ "${status}" -eq 0 ]
}

@test "check-local-overrides: excludes host identity and credential files" {
    local recipe
    recipe="$(_extract_recipe check-local-overrides)"

    for excluded in "passwd*" "shadow*" "gshadow*" "group*" "machine-id" \
        "ssh_host*" "system-connections" "subuid*" "subgid*"; do
        run grep -Fq -- "--exclude" <<< "${recipe}"
        [ "${status}" -eq 0 ]
        run grep -Fq -- "${excluded}" <<< "${recipe}"
        [ "${status}" -eq 0 ]
    done
}

# ------------------------------------------------ check-idle-power-draw

@test "check-idle-power-draw: bails out when powerstat is missing" {
    _extract_recipe check-idle-power-draw > "${WORKDIR}/idle.sh"
    rm -f "${WORKDIR}/bin/powerstat"

    _run_script "${WORKDIR}/idle.sh"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Powerstat is not available"* ]]
    run grep -q "powerstat" <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "check-idle-power-draw: runs powerstat with -a -r under sudo" {
    _extract_recipe check-idle-power-draw > "${WORKDIR}/idle.sh"

    _run_script "${WORKDIR}/idle.sh"

    [ "${status}" -eq 0 ]
    run grep -Fq "powerstat -a -r" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

# ------------------------------------------------------------ benchmark

@test "benchmark: runs the one minute matrix load when stress-ng is present" {
    _extract_recipe benchmark > "${WORKDIR}/benchmark.sh"

    _run_script "${WORKDIR}/benchmark.sh"

    [ "${status}" -eq 0 ]
    local calls
    calls="$(_calls)"
    run grep -Fq "stress-ng --matrix 0 -t 1m --times" <<< "${calls}"
    [ "${status}" -eq 0 ]
    run grep -q "^brew " <<< "${calls}"
    [ "${status}" -ne 0 ]
}

@test "benchmark: installs stress-ng via brew when the user accepts" {
    _extract_recipe benchmark > "${WORKDIR}/benchmark.sh"
    rm -f "${WORKDIR}/bin/stress-ng"
    _queue_gum_exits 0

    _run_script "${WORKDIR}/benchmark.sh"

    [ "${status}" -eq 0 ]
    local calls
    calls="$(_calls)"
    run grep -Fq "brew install stress-ng" <<< "${calls}"
    [ "${status}" -eq 0 ]
    run grep -Fq "brew link stress-ng" <<< "${calls}"
    [ "${status}" -eq 0 ]
    run grep -Fq "stress-ng --matrix 0 -t 1m --times" <<< "${calls}"
    [ "${status}" -eq 0 ]
}

@test "benchmark: exits without installing when the user declines" {
    _extract_recipe benchmark > "${WORKDIR}/benchmark.sh"
    rm -f "${WORKDIR}/bin/stress-ng"
    _queue_gum_exits 1

    _run_script "${WORKDIR}/benchmark.sh"

    [ "${status}" -eq 0 ]
    run grep -q "^brew " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}
