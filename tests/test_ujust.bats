#!/usr/bin/env bats
# Tests for the ujust wrapper's on-demand fzf installation.

UJUST="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ujust"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/prefix/bin"
    : > "${WORKDIR}/calls.log"

    cat > "${WORKDIR}/bin/brew" <<'EOF'
#!/usr/bin/bash
printf 'brew %s\n' "$*" >> "${CALLS}"
case "$1" in
    install)
        /usr/bin/mkdir -p "${MOCK_PREFIX}/bin"
        printf '#!/usr/bin/bash\nexit 0\n' > "${MOCK_PREFIX}/bin/fzf"
        /usr/bin/chmod +x "${MOCK_PREFIX}/bin/fzf"
        ;;
    shellenv)
        printf 'export PATH="%s/bin:$PATH"\n' "${MOCK_PREFIX}"
        ;;
    *)
        exit 1
        ;;
esac
EOF

    cat > "${WORKDIR}/bin/just" <<'EOF'
#!/usr/bin/bash
printf 'just %s\n' "$*" >> "${CALLS}"
if [[ " $* " == *" --choose "* ]] && ! command -v fzf >/dev/null 2>&1; then
    echo "ujust: fzf is unavailable for --choose" >&2
    exit 127
fi
EOF

    chmod +x "${WORKDIR}/bin/brew" "${WORKDIR}/bin/just"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "ujust installs fzf before --choose when fzf is missing" {
    run /usr/bin/env PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" MOCK_PREFIX="${WORKDIR}/prefix" \
        /usr/bin/bash "${UJUST}" --choose

    [ "${status}" -eq 0 ]
    install_line=$(grep -nF "brew install fzf" "${WORKDIR}/calls.log" | head -n1 | cut -d: -f1)
    shellenv_line=$(grep -nF "brew shellenv" "${WORKDIR}/calls.log" | head -n1 | cut -d: -f1)
    just_line=$(grep -nF "just --justfile /usr/share/ublue-os/just/00-entry.just --choose" "${WORKDIR}/calls.log" | head -n1 | cut -d: -f1)
    [ -n "${install_line}" ]
    [ -n "${shellenv_line}" ]
    [ -n "${just_line}" ]
    [ "${install_line}" -lt "${shellenv_line}" ]
    [ "${shellenv_line}" -lt "${just_line}" ]
}

@test "ujust does not install fzf for other commands" {
    run /usr/bin/env PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" MOCK_PREFIX="${WORKDIR}/prefix" \
        /usr/bin/bash "${UJUST}" --list

    [ "${status}" -eq 0 ]
    [ "$(grep -cF "brew install fzf" "${WORKDIR}/calls.log" || true)" -eq 0 ]
    grep -qF "just --justfile /usr/share/ublue-os/just/00-entry.just --list" "${WORKDIR}/calls.log"
}

@test "ujust skips fzf install when fzf is already present" {
    printf '#!/usr/bin/bash\nexit 0\n' > "${WORKDIR}/bin/fzf"
    chmod +x "${WORKDIR}/bin/fzf"

    run /usr/bin/env PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" MOCK_PREFIX="${WORKDIR}/prefix" \
        /usr/bin/bash "${UJUST}" --choose

    [ "${status}" -eq 0 ]
    [ "$(grep -cF "brew install fzf" "${WORKDIR}/calls.log" || true)" -eq 0 ]
    [ "$(grep -cF "brew shellenv" "${WORKDIR}/calls.log" || true)" -eq 0 ]
    grep -qF "just --justfile /usr/share/ublue-os/just/00-entry.just --choose" "${WORKDIR}/calls.log"
}

@test "ujust fails when Homebrew is missing" {
    run /usr/bin/env PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" MOCK_PREFIX="${WORKDIR}/prefix" \
        BREW_BIN="${WORKDIR}/no-such-brew" \
        /usr/bin/bash "${UJUST}" --choose

    [ "${status}" -eq 127 ]
    [ "$(grep -cF "brew install fzf" "${WORKDIR}/calls.log" || true)" -eq 0 ]
    [ "$(grep -cF "just" "${WORKDIR}/calls.log" || true)" -eq 0 ]
}

@test "ujust fails when brew install fzf fails" {
    cat > "${WORKDIR}/bin/brew" <<'EOF'
#!/usr/bin/bash
printf 'brew %s\n' "$*" >> "${CALLS}"
exit 1
EOF
    chmod +x "${WORKDIR}/bin/brew"

    run /usr/bin/env PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" MOCK_PREFIX="${WORKDIR}/prefix" \
        /usr/bin/bash "${UJUST}" --choose

    [ "${status}" -eq 1 ]
    grep -qF "brew install fzf" "${WORKDIR}/calls.log"
    [ "$(grep -cF "just" "${WORKDIR}/calls.log" || true)" -eq 0 ]
}

@test "ujust fails when brew shellenv fails" {
    cat > "${WORKDIR}/bin/brew" <<'EOF'
#!/usr/bin/bash
printf 'brew %s\n' "$*" >> "${CALLS}"
[[ "$1" == shellenv ]] && exit 1
exit 0
EOF
    chmod +x "${WORKDIR}/bin/brew"

    run /usr/bin/env PATH="${WORKDIR}/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" MOCK_PREFIX="${WORKDIR}/prefix" \
        /usr/bin/bash "${UJUST}" --choose

    [ "${status}" -ne 0 ]
    [ "$(grep -cF "just" "${WORKDIR}/calls.log" || true)" -eq 0 ]
}

# ---------------------------------------------------------------------------
# apps.just: install-ai-tools recipe tests
# ---------------------------------------------------------------------------

APPS_JUST="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/just/apps.just"

_extract_apps_recipe() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { in_recipe=1; next }
        in_recipe && /^[[:space:]]+#!\/usr\/bin\/env bash/ { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^[[:space:]]{4}/, ""); print }
    ' "${APPS_JUST}" > "${out_file}"
}

@test "apps.just: install-ai-tools installs brew bundle and creates goose config on fresh setup" {
    local script="${WORKDIR}/install-ai-tools.sh"
    _extract_apps_recipe "install-ai-tools" "${script}"

    local mock_template="${WORKDIR}/mock-goose-config.yaml"
    echo "mock-template-data" > "${mock_template}"

    local test_home="${WORKDIR}/test-user-home"
    mkdir -p "${test_home}"

    run env \
        PATH="${WORKDIR}/bin:${PATH}" \
        CALLS="${WORKDIR}/calls.log" \
        HOME="${test_home}" \
        GOOSE_TEMPLATE="${mock_template}" \
        bash "${script}"

    [ "${status}" -eq 0 ]
    grep -qF "brew bundle --file=/usr/share/ublue-os/homebrew/ai-tools.Brewfile" "${WORKDIR}/calls.log"
    [ -f "${test_home}/.config/goose/config.yaml" ]
    [ "$(< "${test_home}/.config/goose/config.yaml")" = "mock-template-data" ]
    [[ "${output}" == *"Goose configured with read-only Linux diagnostics."* ]]
}

@test "apps.just: install-ai-tools respects XDG_CONFIG_HOME on fresh setup" {
    local script="${WORKDIR}/install-ai-tools.sh"
    _extract_apps_recipe "install-ai-tools" "${script}"

    local mock_template="${WORKDIR}/mock-goose-config.yaml"
    echo "mock-template-data" > "${mock_template}"

    local test_home="${WORKDIR}/test-user-home"
    local custom_xdg="${WORKDIR}/custom-xdg"
    mkdir -p "${test_home}" "${custom_xdg}"

    run env \
        PATH="${WORKDIR}/bin:${PATH}" \
        CALLS="${WORKDIR}/calls.log" \
        HOME="${test_home}" \
        XDG_CONFIG_HOME="${custom_xdg}" \
        GOOSE_TEMPLATE="${mock_template}" \
        bash "${script}"

    [ "${status}" -eq 0 ]
    [ -f "${custom_xdg}/goose/config.yaml" ]
    [ ! -e "${test_home}/.config/goose/config.yaml" ]
    [ "$(< "${custom_xdg}/goose/config.yaml")" = "mock-template-data" ]
}

@test "apps.just: install-ai-tools preserves existing goose config and does not overwrite" {
    local script="${WORKDIR}/install-ai-tools.sh"
    _extract_apps_recipe "install-ai-tools" "${script}"

    local mock_template="${WORKDIR}/mock-goose-config.yaml"
    echo "mock-template-data" > "${mock_template}"

    local test_home="${WORKDIR}/test-user-home"
    mkdir -p "${test_home}/.config/goose"
    echo "existing-custom-config" > "${test_home}/.config/goose/config.yaml"

    run env \
        PATH="${WORKDIR}/bin:${PATH}" \
        CALLS="${WORKDIR}/calls.log" \
        HOME="${test_home}" \
        GOOSE_TEMPLATE="${mock_template}" \
        bash "${script}"

    [ "${status}" -eq 0 ]
    grep -qF "brew bundle --file=/usr/share/ublue-os/homebrew/ai-tools.Brewfile" "${WORKDIR}/calls.log"
    [ -f "${test_home}/.config/goose/config.yaml" ]
    [ "$(< "${test_home}/.config/goose/config.yaml")" = "existing-custom-config" ]
    [[ "${output}" == *"Goose config already exists: ${test_home}/.config/goose/config.yaml"* ]]
    [[ "${output}" == *"Review "* ]]
    [[ "${output}" == *"and merge its linux-mcp-server extension if needed."* ]]
    [[ "${output}" != *"Goose configured with read-only Linux diagnostics."* ]]
}

@test "apps.just: install-ai-tools preserves existing config under XDG_CONFIG_HOME" {
    local script="${WORKDIR}/install-ai-tools.sh"
    _extract_apps_recipe "install-ai-tools" "${script}"

    local mock_template="${WORKDIR}/mock-goose-config.yaml"
    echo "mock-template-data" > "${mock_template}"

    local custom_xdg="${WORKDIR}/custom-xdg"
    mkdir -p "${custom_xdg}/goose"
    echo "existing-xdg-config" > "${custom_xdg}/goose/config.yaml"

    run env \
        PATH="${WORKDIR}/bin:${PATH}" \
        CALLS="${WORKDIR}/calls.log" \
        XDG_CONFIG_HOME="${custom_xdg}" \
        GOOSE_TEMPLATE="${mock_template}" \
        bash "${script}"

    [ "${status}" -eq 0 ]
    [ -f "${custom_xdg}/goose/config.yaml" ]
    [ "$(< "${custom_xdg}/goose/config.yaml")" = "existing-xdg-config" ]
    [[ "${output}" == *"Goose config already exists: ${custom_xdg}/goose/config.yaml"* ]]
}


# ---------------------------------------------------------------------------
# system.just: bluespeed recipe tests
# ---------------------------------------------------------------------------

SYSTEM_JUST="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/share/ublue-os/just/system.just"

_extract_system_recipe() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { in_recipe=1; next }
        in_recipe && /^[[:space:]]+#!\/usr\/bin\/env bash/ { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^[[:space:]]{4}/, ""); print }
    ' "${SYSTEM_JUST}" > "${out_file}"
}

@test "system.just: bluespeed fails when Homebrew is missing" {
    local script="${WORKDIR}/bluespeed.sh"
    _extract_system_recipe "bluespeed" "${script}"

    run env -i PATH="/usr/bin:/bin" CALLS="${WORKDIR}/calls.log" bash "${script}"

    [ "${status}" -eq 127 ]
    [[ "${output}" == *"bluespeed: Homebrew is required"* ]]
    [ ! -s "${WORKDIR}/calls.log" ]
}

@test "system.just: bluespeed runs brew bundle with --no-lock when Homebrew is present" {
    local script="${WORKDIR}/bluespeed.sh"
    _extract_system_recipe "bluespeed" "${script}"

    run env -i PATH="${WORKDIR}/bin:/usr/bin:/bin" CALLS="${WORKDIR}/calls.log" bash "${script}"

    [ "${status}" -eq 0 ]
    grep -qFx "brew bundle --no-lock --file=/usr/share/ublue-os/homebrew/ai-tools.Brewfile" "${WORKDIR}/calls.log"
}
