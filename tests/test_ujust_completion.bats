#!/usr/bin/env bats
# Tests for ujust shell completions (bash, zsh, fish).
#
# Guards against regression to filename completion
# (projectbluefin/bluefin#1171): the old
# `just --completions <shell> | sed 's/just/ujust/'` generator emitted a
# dynamic loader bound to the `just` command name, so TAB after `ujust`
# completed files in the current directory instead of recipes.

REPO_ROOT="$BATS_TEST_DIRNAME/.."
BASH_COMPLETION="$REPO_ROOT/system_files/shared/usr/share/bash-completion/completions/ujust"
ZSH_COMPLETION="$REPO_ROOT/system_files/shared/usr/share/zsh/site-functions/_ujust"
FISH_COMPLETION="$REPO_ROOT/system_files/shared/usr/share/fish/vendor_completions.d/ujust.fish"
ENTRY_JUSTFILE="/usr/share/ublue-os/just/00-entry.just"
FLAGS_FILE="$REPO_ROOT/system_files/shared/usr/share/ublue-os/just/ujust-flags"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    : > "${WORKDIR}/calls.log"
    # Sandbox justfile and flags file: functional tests point the
    # UJUST_JUSTFILE / UJUST_FLAGS_FILE overrides here so they pass on
    # hosts without the image paths (e.g. CI runners).
    : > "${WORKDIR}/00-entry.just"
    printf '%s\n' --list --version -V --verbose > "${WORKDIR}/ujust-flags"

    # Mock `just`: answers --summary with a fixed recipe list and logs
    # every invocation so tests can assert the entry justfile is used.
    cat > "${WORKDIR}/bin/just" <<'EOF'
#!/usr/bin/bash
printf 'just %s\n' "$*" >> "${CALLS:-/dev/null}"
if [[ " $* " == *" --summary "* ]]; then
    echo "update upgrade rollback"
    exit 0
fi
echo "mock-just: unexpected args: $*" >&2
exit 1
EOF
    chmod +x "${WORKDIR}/bin/just"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Content assertions: the installed files must bind `ujust`, not `just`.
# Existence checks alone pass on the broken loader shims, so assert content.
# ---------------------------------------------------------------------------

@test "bash completion file binds the ujust command" {
    [ -f "${BASH_COMPLETION}" ]
    grep -qE '^complete -F _ujust ujust$' "${BASH_COMPLETION}"
    grep -qF "just --summary" "${BASH_COMPLETION}"
    grep -qF "UJUST_JUSTFILE" "${BASH_COMPLETION}"
}

@test "bash completion file is not a just dynamic-loader shim" {
    [ -f "${BASH_COMPLETION}" ]
    [ "$(grep -cF "JUST_COMPLETE" "${BASH_COMPLETION}" || true)" -eq 0 ]
    [ "$(grep -cF "_clap_complete_just" "${BASH_COMPLETION}" || true)" -eq 0 ]
}

@test "zsh completion file defines a ujust completer" {
    [ -f "${ZSH_COMPLETION}" ]
    grep -qE '^#compdef ujust$' "${ZSH_COMPLETION}"
    grep -qF "_ujust()" "${ZSH_COMPLETION}"
    grep -qF "just --summary" "${ZSH_COMPLETION}"
    grep -qF "UJUST_JUSTFILE" "${ZSH_COMPLETION}"
}

@test "zsh completion file offers flags for dash-prefixed words" {
    [ -f "${ZSH_COMPLETION}" ]
    grep -qF "ujust-flags" "${ZSH_COMPLETION}"
    grep -qF "_describe -t flags" "${ZSH_COMPLETION}"
}

@test "zsh completion file is not a just dynamic-loader shim" {
    [ -f "${ZSH_COMPLETION}" ]
    [ "$(grep -cF "JUST_COMPLETE" "${ZSH_COMPLETION}" || true)" -eq 0 ]
    [ "$(grep -cF "_clap_dynamic_completer_just" "${ZSH_COMPLETION}" || true)" -eq 0 ]
}

@test "fish completion file completes the ujust command" {
    [ -f "${FISH_COMPLETION}" ]
    grep -qE '^complete -c ujust ' "${FISH_COMPLETION}"
    grep -qF "just --summary" "${FISH_COMPLETION}"
    grep -qF "UJUST_JUSTFILE" "${FISH_COMPLETION}"
}

@test "fish completion file offers flags as well as recipes" {
    [ -f "${FISH_COMPLETION}" ]
    grep -qF "ujust-flags" "${FISH_COMPLETION}"
    grep -qF "__ujust_flags" "${FISH_COMPLETION}"
}

@test "completions default to the image entry justfile" {
    grep -qE '^[[:space:]]*local justfile=.*00-entry\.just' "${BASH_COMPLETION}"
    grep -qE '^[[:space:]]*local justfile=.*00-entry\.just' "${ZSH_COMPLETION}"
    grep -qE "^[[:space:]]*echo ${ENTRY_JUSTFILE}$" "${FISH_COMPLETION}"
}

@test "fish completion file is not a just dynamic-loader shim" {
    [ -f "${FISH_COMPLETION}" ]
    [ "$(grep -cF "JUST_COMPLETE" "${FISH_COMPLETION}" || true)" -eq 0 ]
}

@test "Containerfile does not generate completions via a just-to-ujust rename" {
    [ "$(grep -cF "just --completions" "$REPO_ROOT/Containerfile" || true)" -eq 0 ]
}

@test "ujust-flags data file lists one flag per line" {
    [ -f "${FLAGS_FILE}" ]
    grep -qx -- "--version" "${FLAGS_FILE}"
    grep -qx -- "-V" "${FLAGS_FILE}"
    grep -qx -- "--list" "${FLAGS_FILE}"
    [ "$(grep -c '^$' "${FLAGS_FILE}" || true)" -eq 0 ]
    [ "$(grep -c '^#' "${FLAGS_FILE}" || true)" -eq 0 ]
}

@test "completions read flags from the data file instead of embedding lists" {
    grep -qE '^[[:space:]]*local flags_file=.*ujust-flags' "${BASH_COMPLETION}"
    grep -qE '^[[:space:]]*local flags_file=.*ujust-flags' "${ZSH_COMPLETION}"
    grep -qE '^[[:space:]]*echo .*ujust-flags' "${FISH_COMPLETION}"
    ! grep -qF -- "--list-heading" "${BASH_COMPLETION}" "${ZSH_COMPLETION}" "${FISH_COMPLETION}"
}

@test "Containerfile gate validates executable completion configuration" {
    grep -qF "grep -qE '^complete -F _ujust ujust$'" "$REPO_ROOT/Containerfile"
    grep -qF "grep -qE '^#compdef ujust$'" "$REPO_ROOT/Containerfile"
    grep -qF "grep -qE '^complete -c ujust '" "$REPO_ROOT/Containerfile"
    grep -qF "grep -qE '^[[:space:]]*local flags_file=.*ujust-flags' /tmp/ujust-gate/ujust;" "$REPO_ROOT/Containerfile"
    grep -qF "grep -qE '^[[:space:]]*local flags_file=.*ujust-flags' /tmp/ujust-gate/_ujust;" "$REPO_ROOT/Containerfile"
    grep -qF "grep -qE '^[[:space:]]*echo .*ujust-flags'" "$REPO_ROOT/Containerfile"
}

# ---------------------------------------------------------------------------
# Functional tests: completions offer recipes from the entry justfile.
# ---------------------------------------------------------------------------

@test "bash completion offers matching recipes for a prefix" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust up)
            COMP_CWORD=1
            COMP_LINE="ujust up"
            COMP_POINT=8
            COMPREPLY=()
            _ujust ujust up ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [[ "${output}" == *update* ]]
    [[ "${output}" == *upgrade* ]]
    [[ "${output}" != *rollback* ]]
}

@test "bash completion lists all recipes on an empty word" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust "")
            COMP_CWORD=1
            COMP_LINE="ujust "
            COMP_POINT=6
            COMPREPLY=()
            _ujust ujust "" ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [[ "${output}" == *update* ]]
    [[ "${output}" == *upgrade* ]]
    [[ "${output}" == *rollback* ]]
}

@test "bash completion offers flags for a dash-prefixed word" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust --l)
            COMP_CWORD=1
            COMP_LINE="ujust --l"
            COMP_POINT=9
            COMPREPLY=()
            _ujust ujust --l ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [[ "${output}" == *--list* ]]
}

@test "bash completion finds flags next to the entry justfile by default" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust --l)
            COMP_CWORD=1
            COMP_LINE="ujust --l"
            COMP_POINT=9
            COMPREPLY=()
            _ujust ujust --l ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [[ "${output}" == *--list* ]]
}

@test "bash completion offers -V (version), distinct from -v (verbose)" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust -V)
            COMP_CWORD=1
            COMP_LINE="ujust -V"
            COMP_POINT=8
            COMPREPLY=()
            _ujust ujust -V ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [[ "${output}" == *-V* ]]
}

@test "bash completion queries recipes from the entry justfile" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" CALLS="${WORKDIR}/calls.log" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust "")
            COMP_CWORD=1
            COMP_LINE="ujust "
            COMP_POINT=6
            COMPREPLY=()
            _ujust ujust "" "" >/dev/null
        '

    [ "${status}" -eq 0 ]
    grep -qF "just --summary --justfile ${WORKDIR}/00-entry.just" "${WORKDIR}/calls.log"
}

@test "bash completion offers nothing when the justfile is missing" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/no-such.just" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust "")
            COMP_CWORD=1
            COMP_LINE="ujust "
            COMP_POINT=6
            COMPREPLY=()
            _ujust ujust "" ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "bash completion offers no flags when the flags file is missing" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/no-such-flags" BASH_COMPLETION="${BASH_COMPLETION}" \
        bash -c '
            source "${BASH_COMPLETION}"
            COMP_WORDS=(ujust --l)
            COMP_CWORD=1
            COMP_LINE="ujust --l"
            COMP_POINT=9
            COMPREPLY=()
            _ujust ujust --l ""
            printf "%s\n" "${COMPREPLY[@]}"
        '

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "zsh completion lists recipes from the entry justfile" {
    [ -n "$(command -v zsh)" ] || skip "zsh not installed"
    local out="${WORKDIR}/zsh-recipes.txt"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" OUT="${out}" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" ZSH_COMPLETION="${ZSH_COMPLETION}" \
        zsh -c '
            _call_program() { local _tag=$1; shift; "$@" }
            _describe() { print -r -- "${(P)${@[-1]}}" > "$OUT" }
            CURRENT=2
            words=(ujust "")
            source "${ZSH_COMPLETION}"
        '

    [ "${status}" -eq 0 ]
    grep -qw "update" "${out}"
    grep -qw "upgrade" "${out}"
    grep -qw "rollback" "${out}"
}

@test "zsh completion offers flags for a dash-prefixed word" {
    [ -n "$(command -v zsh)" ] || skip "zsh not installed"
    local out="${WORKDIR}/zsh-flags.txt"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" OUT="${out}" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" ZSH_COMPLETION="${ZSH_COMPLETION}" \
        zsh -c '
            _call_program() { local _tag=$1; shift; "$@" }
            _describe() { print -r -- "${(P)${@[-1]}}" > "$OUT" }
            CURRENT=2
            words=(ujust --l)
            source "${ZSH_COMPLETION}"
        '

    [ "${status}" -eq 0 ]
    grep -qw -- "--list" "${out}"
    grep -qw -- "-V" "${out}"
    [ "$(grep -cw "update" "${out}" || true)" -eq 0 ]
}

@test "zsh completion finds flags next to the entry justfile by default" {
    [ -n "$(command -v zsh)" ] || skip "zsh not installed"
    local out="${WORKDIR}/zsh-flags-default.txt"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" OUT="${out}" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" ZSH_COMPLETION="${ZSH_COMPLETION}" \
        zsh -c '
            _call_program() { local _tag=$1; shift; "$@" }
            _describe() { print -r -- "${(P)${@[-1]}}" > "$OUT" }
            CURRENT=2
            words=(ujust --l)
            source "${ZSH_COMPLETION}"
        '

    [ "${status}" -eq 0 ]
    grep -qw -- "--list" "${out}"
}

@test "zsh completion falls back to recipes when the flags file is missing" {
    [ -n "$(command -v zsh)" ] || skip "zsh not installed"
    local out="${WORKDIR}/zsh-flags-missing.txt"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" OUT="${out}" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/no-such-flags" ZSH_COMPLETION="${ZSH_COMPLETION}" \
        zsh -c '
            _call_program() { local _tag=$1; shift; "$@" }
            _describe() { print -r -- "${(P)${@[-1]}}" > "$OUT" }
            CURRENT=2
            words=(ujust --l)
            source "${ZSH_COMPLETION}"
        '

    [ "${status}" -eq 0 ]
    grep -qw "update" "${out}"
}

@test "fish completion offers matching recipes for a prefix" {
    [ -n "$(command -v fish)" ] || skip "fish not installed"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" FISH_COMPLETION="${FISH_COMPLETION}" \
        fish --private -c 'set -g fish_complete_path; source "$FISH_COMPLETION"; complete -C"ujust up"'

    [ "${status}" -eq 0 ]
    [[ "${output}" == *update* ]]
    [[ "${output}" == *upgrade* ]]
    [[ "${output}" != *rollback* ]]
}

@test "fish completion lists all recipes on an empty word" {
    [ -n "$(command -v fish)" ] || skip "fish not installed"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" FISH_COMPLETION="${FISH_COMPLETION}" \
        fish --private -c 'set -g fish_complete_path; source "$FISH_COMPLETION"; complete -C"ujust "'

    [ "${status}" -eq 0 ]
    [[ "${output}" == *update* ]]
    [[ "${output}" == *upgrade* ]]
    [[ "${output}" == *rollback* ]]
}

@test "fish completion offers flags for a dash-prefixed word" {
    [ -n "$(command -v fish)" ] || skip "fish not installed"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" FISH_COMPLETION="${FISH_COMPLETION}" \
        fish --private -c 'set -g fish_complete_path; source "$FISH_COMPLETION"; complete -C"ujust --l"'

    [ "${status}" -eq 0 ]
    [[ "${output}" == *--list* ]]
}

@test "fish completion finds flags next to the entry justfile by default" {
    [ -n "$(command -v fish)" ] || skip "fish not installed"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" FISH_COMPLETION="${FISH_COMPLETION}" \
        fish --private -c 'set -g fish_complete_path; source "$FISH_COMPLETION"; complete -C"ujust --l"'

    [ "${status}" -eq 0 ]
    [[ "${output}" == *--list* ]]
}

@test "fish completion offers -V (version)" {
    [ -n "$(command -v fish)" ] || skip "fish not installed"

    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" UJUST_JUSTFILE="${WORKDIR}/00-entry.just" UJUST_FLAGS_FILE="${WORKDIR}/ujust-flags" FISH_COMPLETION="${FISH_COMPLETION}" \
        fish --private -c 'set -g fish_complete_path; source "$FISH_COMPLETION"; complete -C"ujust -V"'

    [ "${status}" -eq 0 ]
    [[ "${output}" == *-V* ]]
}
