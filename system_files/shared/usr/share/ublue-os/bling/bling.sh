#!/usr/bin/env sh

# KEEP THIS POSIX - Needs to work on Bash and ZSH

# Check if bling has already been sourced so that we dont break atuin. https://github.com/atuinsh/atuin/issues/380#issuecomment-1594014644
[ "${BLING_SOURCED:-0}" -eq 1 ] && return
BLING_SOURCED=1

# ls aliases
if [ "$(command -v eza)" ]; then
    alias ll='eza -l --icons=auto --group-directories-first'
    alias l.='eza -d .*'
    alias ls='eza'
    alias l1='eza -1'
fi

# ugrep for grep
if [ "$(command -v ug)" ]; then
    alias grep='ug'
    alias egrep='ug -E'
    alias fgrep='ug -F'
    alias xzgrep='ug -z'
    alias xzegrep='ug -zE'
    alias xzfgrep='ug -zF'
fi

# bat for cat
if [ "$(command -v bat)" ]; then
    alias cat='bat --style=plain --pager=never'
fi

# open → xdg-open (familiar macOS-style file/URL opener)
if [ "$(command -v xdg-open)" ]; then
    alias open='xdg-open >/dev/null 2>&1'
fi

BLING_SHELL="$(basename "$(readlink /proc/$$/exe)")"

# Initialize direnv before bash-preexec to avoid PROMPT_COMMAND conflicts
# See: https://github.com/rcaloras/bash-preexec/pull/143
if [ "${BLING_SHELL}" = "bash" ]; then
    # shellcheck source=/dev/null
    [ -f "/etc/profile.d/bash-preexec.sh" ] && . "/etc/profile.d/bash-preexec.sh"
    # shellcheck source=/dev/null
    [ -f "/usr/share/bash-prexec" ] && . "/usr/share/bash-prexec"
    # shellcheck source=/dev/null
    [ -f "/usr/share/bash-prexec.sh" ] && . "/usr/share/bash-prexec.sh"
    # shellcheck source=/dev/null
    [ -f "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh" ] && . "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh"
fi

[ "$(command -v direnv)" ] && eval "$(direnv hook "${BLING_SHELL}")"
[ "$(command -v starship)" ] && eval "$(starship init "${BLING_SHELL}")"
[ "$(command -v zoxide)" ] && eval "$(zoxide init "${BLING_SHELL}")"

if command -v mise >/dev/null 2>&1; then
  # Check for Bash
  if [ "${BLING_SHELL}" = "bash" ]; then
    if [ "$MISE_BASH_AUTO_ACTIVATE" != "0" ]; then
      eval "$(mise activate bash)"
    fi

    # Check for Zsh
  elif [ "${BLING_SHELL}" = "zsh" ]; then
    if [ "$MISE_ZSH_AUTO_ACTIVATE" != "0" ]; then
      eval "$(mise activate zsh)"
    fi
  fi
fi
