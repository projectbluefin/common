#!/usr/bin/env bats

BLUEFIN="${BATS_TEST_DIRNAME}/../system_files/bluefin"

@test "compiled GNOME defaults reserve Super+Space for Compass and preserve existing shortcuts" {
    for tool in glib-compile-schemas gsettings dconf; do
        command -v "$tool" >/dev/null || skip "$tool is required"
    done
    run gsettings list-schemas
    [[ "$output" == *org.gnome.shell* ]] || skip "GNOME schemas are required"

    local schemas="${BATS_TEST_TMPDIR}/schemas"
    mkdir -p "$schemas"
    cp /usr/share/glib-2.0/schemas/*.xml "$schemas/"
    cp "${BLUEFIN}/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override" "$schemas/"
    glib-compile-schemas --strict "$schemas"
    export GSETTINGS_SCHEMA_DIR="$schemas" GSETTINGS_BACKEND=memory

    run gsettings get org.gnome.shell enabled-extensions
    [ "$status" -eq 0 ]
    [[ "$output" == *"'compass@tunaos.org'"* ]]
    [[ "$output" != *search-light* ]]
    run gsettings get org.gnome.desktop.wm.keybindings switch-input-source
    [ "$status" -eq 0 ]
    [ "$output" = "['XF86Keyboard']" ]
    run gsettings get org.gnome.desktop.wm.keybindings switch-input-source-backward
    [ "$status" -eq 0 ]
    [ "$output" = "['<Shift>XF86Keyboard']" ]
    run gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
    [ "$status" -eq 0 ]
    for shortcut in custom0 custom1 custom2 custom3 custom4 compass; do
        [[ "$output" == *"'/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${shortcut}/'"* ]]
    done

    export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
    export DCONF_PROFILE="${BATS_TEST_TMPDIR}/profile"
    mkdir -p "${XDG_CONFIG_HOME}/dconf"
    printf 'user-db:compass-test\n' > "$DCONF_PROFILE"
    dconf compile "${XDG_CONFIG_HOME}/dconf/compass-test" "${BLUEFIN}/etc/dconf/db/distro.d"
    run dconf read /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/compass/command
    [ "$status" -eq 0 ]
    [ "$output" = "'/home/linuxbrew/.linuxbrew/bin/compass toggle'" ]
    run dconf read /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/compass/binding
    [ "$status" -eq 0 ]
    [ "$output" = "'<Super>space'" ]
}
