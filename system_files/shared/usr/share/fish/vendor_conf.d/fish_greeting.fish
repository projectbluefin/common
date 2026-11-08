function fish_greeting

    if test -e ~/.config/no-show-user-motd
        mkdir -p ~/.config/uwelcome
        mv ~/.config/no-show-user-motd ~/.config/uwelcome/disabled 2>/dev/null
    end

    # Skip for root (no desktop session, portal lookups can stall), and skip
    # when a parent shell already greeted (bash login shell starting fish).
    if test (id -u) = 0
        return
    end
    if set -q UWELCOME_SHOWN
        return
    end
    set -gx UWELCOME_SHOWN 1

    uwelcome
end
