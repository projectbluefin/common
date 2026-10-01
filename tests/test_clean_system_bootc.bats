#!/usr/bin/env bats
# Regression tests for issue #1330: clean-system must not call rpm-ostree
# unconditionally. Bootc images (Utah) don't ship rpm-ostree, so the recipe
# errored mid-run. The cleanup now runs only when the binary is on PATH.
#
# The recipe calls podman by absolute path (/usr/bin/podman) and guards
# docker/brew with command -v / -x. We redirect that absolute path into the
# sandbox and stub the rest. The recipe runs with a self-contained PATH so a
# host rpm-ostree can never leak into the "absent" case.

DEFAULT_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/default.just"
WORKDIR=""

# Write a logging stub: records its invocation to $CALLS and succeeds. The
# body is built with printf so ${CALLS} stays a runtime (double-quoted)
# expansion — single quotes would suppress it and the stub would fail to log.
_mklog() {
    local name="$1"
    {
        echo '#!/usr/bin/bash'
        printf "printf 'log-%%s %%s\\n' '%s' \"\$*\" >> \"\${CALLS}\"\n" "${name}"
        echo 'exit 0'
    } > "${WORKDIR}/bin/${name}"
    chmod +x "${WORKDIR}/bin/${name}"
}

_setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    : > "${WORKDIR}/calls.log"
    : > "${WORKDIR}/gum-exits"

    # gum confirm: log the call, then pop one queued exit status (default 0).
    # Pure-bash queue (mapfile/printf/<) so no head/tail/mv are needed and the
    # sandbox PATH can stay minimal.
    cat > "${WORKDIR}/bin/gum" <<'EOF'
#!/usr/bin/bash
printf 'gum %s\n' "$*" >> "${CALLS}"
mapfile -t _lines < "${GUM_EXITS}"
_code="${_lines[0]:-0}"
: > "${GUM_EXITS}"
printf '%s\n' "${_lines[@]:1}" >> "${GUM_EXITS}"
exit "${_code}"
EOF
    chmod +x "${WORKDIR}/bin/gum"

    for stub in podman docker flatpak brew; do
        _mklog "${stub}"
    done

    # The recipe pipes the image/volume listings through head.
    ln -s "$(command -v head)" "${WORKDIR}/bin/head"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_queue_gum_exits() {
    printf '%s\n' "$@" > "${WORKDIR}/gum-exits"
}

# Extract the clean-system recipe and redirect the absolute /usr/bin/podman
# calls into the sandbox stub.
_prepare() {
    awk '
        /^clean-system:/ { in_recipe=1; next }
        in_recipe && $0 !~ /^    / && $0 !~ /^$/ { exit }
        in_recipe && $0 ~ /^    / { print }
    ' "${DEFAULT_JUST}" \
        | sed "s#/usr/bin/podman#${WORKDIR}/bin/podman#g" \
        > "${WORKDIR}/clean.sh"
    chmod +x "${WORKDIR}/clean.sh"
}

_calls() {
    cat "${WORKDIR}/calls.log"
}

# Run with a minimal self-contained PATH so a host rpm-ostree cannot leak in.
# stderr is captured: the recipe has no `set -e`, so an unguarded rpm-ostree
# call still exits 0 and only shows up as a "command not found" diagnostic.
_run() {
    PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" \
        GUM_EXITS="${WORKDIR}/gum-exits" \
        /usr/bin/bash "${WORKDIR}/clean.sh" 2> "${WORKDIR}/stderr.log"
}

_stderr() {
    cat "${WORKDIR}/stderr.log"
}

_clean_system_recipe() {
    awk '
        /^clean-system:/ { in_recipe=1; next }
        in_recipe && $0 !~ /^    / && $0 !~ /^$/ { exit }
        in_recipe && $0 ~ /^    / { print }
    ' "${DEFAULT_JUST}"
}

@test "clean-system: guards the rpm-ostree cleanup with command -v" {
    local recipe
    recipe="$(_clean_system_recipe)"

    run grep -Eq 'command -v rpm-ostree' <<< "${recipe}"
    [ "${status}" -eq 0 ]
    run grep -Eq '^[[:space:]]*rpm-ostree cleanup -bm' <<< "${recipe}"
    [ "${status}" -eq 0 ]
}

@test "clean-system: skips rpm-ostree cleanup when the binary is absent (bootc)" {
    _setup
    _prepare
    _queue_gum_exits 0 0 0 0

    _run
    local exit_code=$?

    [ "${exit_code}" -eq 0 ]
    run grep -Fq "rpm-ostree cleanup" <<< "$(_calls)"
    [ "${status}" -ne 0 ]
    # Without the guard the recipe still exits 0 (no `set -e`), so the only
    # runtime evidence of the bug is bash's diagnostic on stderr.
    run grep -Fq "command not found" <<< "$(_stderr)"
    [ "${status}" -ne 0 ]
}

@test "clean-system: runs rpm-ostree cleanup when the binary is present" {
    _setup
    _prepare
    _mklog_rpm() {
        {
            echo '#!/usr/bin/bash'
            echo 'printf "rpm-ostree %s\n" "$*" >> "${CALLS}"'
            echo 'exit 0'
        } > "${WORKDIR}/bin/rpm-ostree"
        chmod +x "${WORKDIR}/bin/rpm-ostree"
    }
    _mklog_rpm
    _queue_gum_exits 0 0 0 0

    _run
    local exit_code=$?

    [ "${exit_code}" -eq 0 ]
    run grep -Fq "rpm-ostree cleanup -bm" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    run grep -Fq "command not found" <<< "$(_stderr)"
    [ "${status}" -ne 0 ]
}
