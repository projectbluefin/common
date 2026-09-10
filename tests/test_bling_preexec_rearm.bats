#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/bling/bash-preexec-rearm.sh
#
# Regression coverage for https://github.com/projectbluefin/common/issues/869:
# with Fedora's array-valued PROMPT_COMMAND, bash-preexec 0.6.0 fails to remove
# its deferred installer from PROMPT_COMMAND whenever another hook has pushed it
# out of element [0]. The leftover installer runs `trap - DEBUG` on every prompt
# while __bp_install returns early, so the DEBUG trap stays gone and atuin (and
# every other preexec consumer) silently stops recording.
#
# These tests use a minimal stand-in for bash-preexec 0.6.0 that mirrors the
# upstream install semantics verbatim (install string, __bp_install early return,
# and the fact that __bp_install only sanitizes "${PROMPT_COMMAND}" — element
# [0]). "bash-preexec bug reproduces without the re-arm hook" pins that stand-in
# to the real failure, so the other tests cannot pass vacuously.
#
# Prompt cycles are simulated by eval-ing PROMPT_COMMAND entries at *top level*.
# That matters: bash does not inherit the DEBUG trap into shell functions, so
# running the cycle inside a helper function would hide the clobber entirely.
#
# Run: bats tests/test_bling_preexec_rearm.bats

BLING_LIB="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/bling"
BASH_BIN="$(command -v bash)"
WORKDIR=""
MOCKDIR=""
BASEBIN=""

setup() {
    WORKDIR="$BATS_TEST_DIRNAME/.tmp/test_bling_preexec_rearm_${BATS_TEST_NUMBER}_$$"
    MOCKDIR="$WORKDIR/mockbin"
    BASEBIN="$WORKDIR/basebin"

    mkdir -p "$MOCKDIR" "$BASEBIN" "$WORKDIR/home" "$WORKDIR/brew/etc/profile.d"
    ln -s "$(command -v basename)" "$BASEBIN/basename"
    ln -s "$(command -v readlink)" "$BASEBIN/readlink"

    write_bash_preexec_stub "$WORKDIR/brew/etc/profile.d/bash-preexec.sh"
}

teardown() {
    rm -rf "$WORKDIR"
}

# Minimal stand-in for bash-preexec 0.6.0. Only the parts that decide whether the
# DEBUG trap survives are reproduced; they are copied from upstream 0.6.0.
write_bash_preexec_stub() {
    cat > "$1" <<'STUB'
__bp_install_string=$'__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'
preexec_functions=()
precmd_functions=()
__bp_preexec_invoke_exec() {
    local cmd="$BASH_COMMAND" f
    [[ -n "${__bp_preexec_interactive_mode:-}" ]] || return 0
    __bp_preexec_interactive_mode=""
    for f in "${preexec_functions[@]}"; do [[ -n "$f" ]] && "$f" "$cmd"; done
    return 0
}
__bp_interactive_mode() { __bp_preexec_interactive_mode=1; }
__bp_precmd_invoke_cmd() {
    local f
    for f in "${precmd_functions[@]}"; do [[ -n "$f" ]] && "$f"; done
    return 0
}
__bp_install() {
    [[ "${PROMPT_COMMAND[*]:-}" == *"__bp_precmd_invoke_cmd"* ]] && return 1
    trap '__bp_preexec_invoke_exec "$_"' DEBUG
    unset __bp_trap_string
    local existing="${PROMPT_COMMAND:-}"
    existing="${existing//$__bp_install_string/:}"
    [[ "${existing:-:}" == ":" ]] && existing=
    PROMPT_COMMAND='__bp_precmd_invoke_cmd'
    PROMPT_COMMAND+=${existing:+$'\n'$existing}
    PROMPT_COMMAND+=('__bp_interactive_mode')
    __bp_precmd_invoke_cmd
    __bp_interactive_mode
}
__bp_install_after_session_init() {
    local s="${PROMPT_COMMAND:-}"
    [[ -n "$s" ]] && PROMPT_COMMAND="$s"$'\n'
    PROMPT_COMMAND+=${__bp_install_string}
}
__bp_install_after_session_init
STUB
}

# Run a snippet in a clean bash with only the mocked PATH visible.
run_shell() {
    printf '%s\n' "$1" > "$WORKDIR/script.bash"
    run env -i \
        PATH="$MOCKDIR:$BASEBIN" \
        HOME="$WORKDIR/home" \
        HOMEBREW_PREFIX="$WORKDIR/brew" \
        BLING_DIR="$BLING_LIB" \
        "$BASH_BIN" --noprofile --norc "$WORKDIR/script.bash"
}

# Prelude: array-valued PROMPT_COMMAND plus a hook queued ahead of bash-preexec's
# installer, which is what pushes the installer out of element [0] on Fedora.
ARRAY_SETUP='
__vte_precmd() { :; }
_pre_hook() { :; }
PROMPT_COMMAND=("__vte_precmd")
source "${BLING_DIR}/bling.sh"
PROMPT_COMMAND=("_pre_hook" "${PROMPT_COMMAND[@]}")
'

# Simulated prompt cycle. MUST stay at top level — see header note on functrace.
CYCLE='for __e in "${PROMPT_COMMAND[@]}"; do eval "$__e"; done'

# ---------------------------------------------------------------------------
# The upstream defect itself — pins the stand-in to real behaviour
# ---------------------------------------------------------------------------

@test "bash-preexec bug reproduces without the re-arm hook" {
    run_shell '
__vte_precmd() { :; }
_pre_hook() { :; }
PROMPT_COMMAND=("__vte_precmd")
source "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh"
PROMPT_COMMAND=("_pre_hook" "${PROMPT_COMMAND[@]}")
'"$CYCLE"'
echo "one:[$(trap -p DEBUG)]"
'"$CYCLE"'
echo "two:[$(trap -p DEBUG)]"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"one:[trap -- '__bp_preexec_invoke_exec \"\$_\"' DEBUG]"* ]]
    [[ "$output" == *"two:[]"* ]]
}

# ---------------------------------------------------------------------------
# Array-valued PROMPT_COMMAND — the reported failure mode
# ---------------------------------------------------------------------------

@test "array PROMPT_COMMAND: DEBUG trap survives repeated prompts" {
    run_shell "$ARRAY_SETUP$CYCLE"'
echo "one:[$(trap -p DEBUG)]"
'"$CYCLE"'
echo "two:[$(trap -p DEBUG)]"
'"$CYCLE"'
echo "three:[$(trap -p DEBUG)]"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"one:[trap -- '__bp_preexec_invoke_exec \"\$_\"' DEBUG]"* ]]
    [[ "$output" == *"two:[trap -- '__bp_preexec_invoke_exec \"\$_\"' DEBUG]"* ]]
    [[ "$output" == *"three:[trap -- '__bp_preexec_invoke_exec \"\$_\"' DEBUG]"* ]]
}

@test "array PROMPT_COMMAND: atuin-style preexec hook keeps firing" {
    run_shell "$ARRAY_SETUP"'
_atuin_count=0
_atuin_preexec() { _atuin_count=$((_atuin_count + 1)); }
preexec_functions+=(_atuin_preexec)
'"$CYCLE"'
'"$CYCLE"'
'"$CYCLE"'
echo "count=$_atuin_count"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=3"* ]]
}

@test "array PROMPT_COMMAND: preexec stops firing without the re-arm hook" {
    run_shell '
__vte_precmd() { :; }
_pre_hook() { :; }
PROMPT_COMMAND=("__vte_precmd")
source "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh"
PROMPT_COMMAND=("_pre_hook" "${PROMPT_COMMAND[@]}")
_atuin_count=0
_atuin_preexec() { _atuin_count=$((_atuin_count + 1)); }
preexec_functions+=(_atuin_preexec)
'"$CYCLE"'
'"$CYCLE"'
'"$CYCLE"'
echo "count=$_atuin_count"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=1"* ]]
}

@test "array PROMPT_COMMAND: re-arm hook is queued after the stale installer" {
    run_shell "$ARRAY_SETUP"'
installer=-1; rearm=-1
for i in "${!PROMPT_COMMAND[@]}"; do
    [[ "${PROMPT_COMMAND[i]}" == *"trap - DEBUG"* ]] && installer=$i
    [[ "${PROMPT_COMMAND[i]}" == *"__bling_rearm_bp_debug_trap"* ]] && rearm=$i
done
echo "installer=$installer rearm=$rearm"
'
    [ "$status" -eq 0 ]
    [[ "$output" =~ installer=([0-9]+)\ rearm=([0-9]+) ]]
    [ "${BASH_REMATCH[2]}" -gt "${BASH_REMATCH[1]}" ]
}

# ---------------------------------------------------------------------------
# Scalar PROMPT_COMMAND must not regress
# ---------------------------------------------------------------------------

@test "scalar PROMPT_COMMAND: DEBUG trap survives repeated prompts" {
    run_shell '
_legacy_hook() { :; }
PROMPT_COMMAND="_legacy_hook"
source "${BLING_DIR}/bling.sh"
'"$CYCLE"'
echo "one:[$(trap -p DEBUG)]"
'"$CYCLE"'
echo "two:[$(trap -p DEBUG)]"
echo "kept:${PROMPT_COMMAND[*]}"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"one:[trap -- '__bp_preexec_invoke_exec \"\$_\"' DEBUG]"* ]]
    [[ "$output" == *"two:[trap -- '__bp_preexec_invoke_exec \"\$_\"' DEBUG]"* ]]
    [[ "$output" == *"kept:"*"_legacy_hook"* ]]
}

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

@test "sourcing bling.sh twice queues the re-arm hook only once" {
    run_shell "$ARRAY_SETUP"'
source "${BLING_DIR}/bling.sh"
count=0
for e in "${PROMPT_COMMAND[@]}"; do
    [[ "$e" == *"__bling_rearm_bp_debug_trap"* ]] && count=$((count + 1))
done
echo "count=$count"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=1"* ]]
}

@test "sourcing the re-arm helper twice queues the hook only once" {
    run_shell '
source "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh"
source "${BLING_DIR}/bash-preexec-rearm.sh"
source "${BLING_DIR}/bash-preexec-rearm.sh"
count=0
for e in "${PROMPT_COMMAND[@]}"; do
    [[ "$e" == *"__bling_rearm_bp_debug_trap"* ]] && count=$((count + 1))
done
echo "count=$count"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=1"* ]]
}

# ---------------------------------------------------------------------------
# Graceful degradation
# ---------------------------------------------------------------------------

@test "no bash-preexec installed: bling.sh sources cleanly and adds no hook" {
    rm -f "$WORKDIR/brew/etc/profile.d/bash-preexec.sh"
    run_shell '
set -u
PROMPT_COMMAND=("__noop"); __noop() { :; }
source "${BLING_DIR}/bling.sh"
echo "pc:${PROMPT_COMMAND[*]}"
echo "done"
'
    [ "$status" -eq 0 ]
    [[ "$output" != *"__bling_rearm_bp_debug_trap"* ]]
    [[ "$output" == *"done"* ]]
}

@test "no bash-preexec installed: re-arm helper is a no-op with PROMPT_COMMAND unset" {
    run_shell '
set -u
unset PROMPT_COMMAND
source "${BLING_DIR}/bash-preexec-rearm.sh"
echo "declared:$(declare -p PROMPT_COMMAND 2>/dev/null)"
echo "done"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"declared:"* ]]
    [[ "$output" != *"__bling_rearm_bp_debug_trap"* ]]
    [[ "$output" == *"done"* ]]
}

@test "re-arm helper does not error when PROMPT_COMMAND is readonly" {
    run_shell '
source "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh"
readonly PROMPT_COMMAND
source "${BLING_DIR}/bash-preexec-rearm.sh" 2>"$HOME/err.log"
echo "stderr:[$(cat "$HOME/err.log")]"
echo "done"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"stderr:[]"* ]]
    [[ "$output" == *"done"* ]]
}

@test "zsh can still source bling.sh without the bash-only helper" {
    command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
    run env -i \
        PATH="$MOCKDIR:$BASEBIN:$(dirname "$(command -v zsh)")" \
        HOME="$WORKDIR/home" \
        BLING_DIR="$BLING_LIB" \
        zsh -c 'source "${BLING_DIR}/bling.sh"; echo done'
    [ "$status" -eq 0 ]
    [[ "$output" == *"done"* ]]
}

@test "helper defines no function when bash-preexec is absent" {
    rm -f "$WORKDIR/brew/etc/profile.d/bash-preexec.sh"
    run_shell '
source "${BLING_DIR}/bash-preexec-rearm.sh"
echo "type:$(type -t __bling_rearm_bp_debug_trap)"
'
    [ "$status" -eq 0 ]
    [[ "$output" == "type:" ]]
}

@test "bling.sh tolerates a missing re-arm helper" {
    run_shell '
BLING_DIR="$HOME/nowhere"
source "'"$BLING_LIB"'/bling.sh"
echo "done"
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"done"* ]]
}
