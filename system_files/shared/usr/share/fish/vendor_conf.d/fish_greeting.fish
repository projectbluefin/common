function fish_greeting
    if test ! -e $HOME/.config/no-show-user-motd
        if test -z "$UBLUE_MOTD_SHOWN" -or "$UBLUE_MOTD_SHOWN" != "1"
            set -gx UBLUE_MOTD_SHOWN 1
            ublue-motd
        end
    end
end
