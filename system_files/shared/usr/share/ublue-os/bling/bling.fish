#!/usr/bin/env fish

if status is-interactive
    test "$BLING_SOURCED" = 1; and return; or set -g BLING_SOURCED 1

    # bluefin-cli (https://github.com/tuna-os/bluefin-cli) replaces bling
    # (projectbluefin/common#1719): where it is installed, config.fish files
    # that still source this file get its shell experience instead.
    if type -q bluefin-cli
        bluefin-cli init fish | source
        return
    end

    function __bling_abbr -d "Create an abbreviation or alias"
        test "$BLING_USE_ABBR" != 0; and abbr -a $argv; or alias $argv
    end

    # ls aliases
    if type -q eza
        __bling_abbr ll 'eza -l --icons=auto --group-directories-first'
        __bling_abbr l. 'eza -d .*'
        __bling_abbr ls 'eza'
        __bling_abbr l1 'eza -1'
    end

    # ugrep for grep
    if type -q ug
        __bling_abbr grep 'ug'
        __bling_abbr egrep 'ug -E'
        __bling_abbr fgrep 'ug -F'
        __bling_abbr xzgrep 'ug -z'
        __bling_abbr xzegrep 'ug -zE'
        __bling_abbr xzfgrep 'ug -zF'
    end

    # bat for cat
    if type -q bat
        __bling_abbr cat 'bat --style=plain --pager=never'
    end

    type -q direnv; and direnv hook fish | source

    type -q starship; and starship init fish | source

    type -q zoxide; and zoxide init fish | source

    type -q mise; and test "$MISE_FISH_AUTO_ACTIVATE" != 0; and mise activate fish | source
end
