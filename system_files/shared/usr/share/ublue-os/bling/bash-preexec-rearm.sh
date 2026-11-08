#!/usr/bin/env bash
# Re-arm the bash-preexec DEBUG trap on every prompt.
#
# Fedora (bash >= 5.1) exposes PROMPT_COMMAND as an *array*. bash-preexec 0.6.0
# defers its own installation by appending a string to PROMPT_COMMAND:
#
#   __bp_trap_string="$(trap -p DEBUG)"; trap - DEBUG; __bp_install
#
# __bp_install is supposed to delete that string again, but it only ever reads
# and rewrites "${PROMPT_COMMAND}" — which expands to element [0] alone. Once
# another hook (direnv, starship, mise, zoxide, vte, systemd) has pushed the
# installer into a later array element, it is never removed and therefore runs
# on *every* prompt. Its first act is `trap - DEBUG`, and __bp_install then
# returns early because PROMPT_COMMAND already contains __bp_precmd_invoke_cmd.
# From the second prompt onward the DEBUG trap is permanently empty, so every
# preexec consumer silently stops firing — atuin loads and CTRL+R works, but no
# command is ever recorded.
#
# Re-arming the trap at the end of each prompt cycle restores the invariant
# bash-preexec assumes without patching or vendoring bash-preexec itself.
#
# See: https://github.com/projectbluefin/common/issues/869
#      https://github.com/rcaloras/bash-preexec/issues/188
#      https://github.com/rcaloras/bash-preexec/issues/186

# Only meaningful when bash-preexec is actually loaded, and only safe when we
# are allowed to write PROMPT_COMMAND (bash-preexec bails out in that case too).
if [[ "$(type -t __bp_preexec_invoke_exec)" == "function" ]] &&
    (unset PROMPT_COMMAND) 2>/dev/null; then

    # Re-install the exact trap bash-preexec installs in __bp_install. A prior,
    # non-bash-preexec DEBUG trap is not lost: bash-preexec preserves it as
    # __bp_original_debug_trap inside preexec_functions.
    __bling_rearm_bp_debug_trap() {
        trap '__bp_preexec_invoke_exec "$_"' DEBUG
    }

    # Idempotent — sourcing bling.sh twice must not queue the hook twice.
    if [[ "${PROMPT_COMMAND[*]-}" != *__bling_rearm_bp_debug_trap* ]]; then
        if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
            PROMPT_COMMAND+=('__bling_rearm_bp_debug_trap')
        elif [[ -n "${PROMPT_COMMAND:-}" ]]; then
            PROMPT_COMMAND="${PROMPT_COMMAND}"$'\n'"__bling_rearm_bp_debug_trap"
        else
            PROMPT_COMMAND="__bling_rearm_bp_debug_trap"
        fi
    fi
fi
