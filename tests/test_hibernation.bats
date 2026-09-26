#!/usr/bin/env bats

setup() {
    export WORKDIR="$BATS_TEST_TMPDIR"
    export HELPER="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/bluefin-hibernation"
    mkdir -p "$WORKDIR/bin" "$WORKDIR/efi"
    printf 'MemTotal: 8388609 kB\n' > "$WORKDIR/meminfo"
    echo 'freeze mem disk' > "$WORKDIR/power"
    echo quiet > "$WORKDIR/cmdline"
    cat > "$WORKDIR/driver" <<'DRIVER'
#!/usr/bin/bash
source "$HELPER"
state=$WORKDIR/state
swapdir=$WORKDIR/swap
swapfile=$swapdir/swapfile
unit=var-swap-swapfile.swap
unitfile=$WORKDIR/etc/systemd/system/$unit
lid=$WORKDIR/etc/systemd/logind.conf.d/60-bluefin-hibernation.conf
sleep=$WORKDIR/etc/systemd/sleep.conf.d/60-bluefin-hibernation.conf
suspend=$WORKDIR/etc/systemd/system/systemd-suspend.service.d/60-bluefin-hibernation.conf
meminfo=$WORKDIR/meminfo
power_state=$WORKDIR/power
cmdline=$WORKDIR/cmdline
efivars=$WORKDIR/efi
command() {
    if [[ ${NO_GNOME:-0} == 1 && $* == '-v gnome-shell' ]]; then return 1; fi
    builtin command "$@"
}
"$@"
DRIVER
    cat > "$WORKDIR/bin/stub" <<'STUB'
#!/usr/bin/bash
set -eu
name=${0##*/}
echo "$name $*" >> "$WORKDIR/calls"
case "$name" in
    findmnt)
        [[ $* != *--fstab* ]] || { echo "${FSTAB_SOURCE:-}"; exit; }
        echo "${FSTYPE:-btrfs}" ;;
    btrfs)
        case "$1 $2" in
            'subvolume create') mkdir "$3" ;;
            'subvolume show') test -d "$3" ;;
            'subvolume delete') rmdir "$3" ;;
            'inspect-internal map-swapfile') exit "${MAP_FAIL:-0}" ;;
        esac ;;
    mkswap)
        [[ $1 != --help ]] || { echo --file; exit; }
        touch "${@: -1}"
        exit "${ALLOC_FAIL:-0}" ;;
    systemctl)
        case "$1" in
            show) echo not-found ;;
            enable) touch "$WORKDIR/active" "$WORKDIR/enabled" ;;
            disable)
                [[ ${STOP_FAIL:-0} == 0 ]] || exit 1
                rm -f "$WORKDIR/active" "$WORKDIR/enabled" ;;
            is-active) test -f "$WORKDIR/active" ;;
            is-enabled) test -f "$WORKDIR/enabled" ;;
        esac ;;
    swapon)
        [[ ${SWAPON_FAIL:-0} == 0 ]] || exit 1
        if [[ -f $WORKDIR/active ]]; then echo "$WORKDIR/swap/swapfile"; fi ;;
    swapoff)
        [[ ${STOP_FAIL:-0} == 0 ]] || exit 1
        rm -f "$WORKDIR/active" ;;
    busctl) printf 's "%s"\n' "${CAPABILITY:-yes}" ;;
    chattr|restorecon|gnome-shell) ;;
esac
STUB
    chmod +x "$WORKDIR/driver" "$WORKDIR/bin/stub"
    for name in findmnt btrfs mkswap systemctl swapon swapoff busctl chattr restorecon gnome-shell; do
        ln -s stub "$WORKDIR/bin/$name"
    done
    export PATH="$WORKDIR/bin:$PATH"
}

@test "help and invalid actions do not call privileged tools" {
    run bash "$HELPER" help
    [ "$status" -eq 0 ]
    [[ $output == *'status|enable|disable'* ]]
    run bash "$HELPER" 'enable; touch BAD'
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/calls" ]
}

@test "size rounds up and handles each RAM range" {
    for pair in '1048576 2G' '2097152 3G' '8388609 9G'; do
        read -r ram size <<< "$pair"
        echo "MemTotal: $ram kB" > "$WORKDIR/meminfo"
        run "$WORKDIR/driver" swap_size
        [ "$status" -eq 0 ]
        [ "$output" = "$size" ]
    done
}

@test "enable preserves idle policy and existing files; disable reverses owned resources" {
    mkdir -p "$WORKDIR/etc/systemd/logind.conf.d"
    echo admin > "$WORKDIR/etc/systemd/logind.conf.d/lid.conf"
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    run "$WORKDIR/driver" status
    [ "$output" = enabled ]
    grep -q 'HandleLidSwitch=suspend-then-hibernate' "$WORKDIR/etc/systemd/logind.conf.d/60-bluefin-hibernation.conf"
    ! grep -R -E 'IdleAction|HandlePowerKey|IgnoreInhibited|gsettings|uupd' "$WORKDIR/etc"
    grep -q 'systemd-sleep suspend-then-hibernate' "$WORKDIR/etc/systemd/system/systemd-suspend.service.d/60-bluefin-hibernation.conf"
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    [ "$(grep -c 'btrfs subvolume create' "$WORKDIR/calls")" -eq 1 ]
    run "$WORKDIR/driver" disable
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/swap" ]
    [ ! -e "$WORKDIR/state" ]
    [ "$(cat "$WORKDIR/etc/systemd/logind.conf.d/lid.conf")" = admin ]
    run "$WORKDIR/driver" disable
    [ "$status" -eq 0 ]
}

@test "existing swap directory is never adopted or deleted" {
    mkdir "$WORKDIR/swap"
    echo valuable > "$WORKDIR/swap/swapfile"
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    run "$WORKDIR/driver" disable
    [ "$status" -eq 0 ]
    [ "$(cat "$WORKDIR/swap/swapfile")" = valuable ]
}

@test "unsupported filesystem, kernel, EFI and resume arguments fail before mutation" {
    export FSTYPE=ext4
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    unset FSTYPE
    echo mem > "$WORKDIR/power"
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    echo 'mem disk' > "$WORKDIR/power"
    rmdir "$WORKDIR/efi"
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    mkdir "$WORKDIR/efi"
    echo 'quiet resume=/dev/test' > "$WORKDIR/cmdline"
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
}

@test "existing configuration and fstab entries are refused" {
    export FSTAB_SOURCE="$WORKDIR/swap/swapfile"
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    unset FSTAB_SOURCE
    mkdir -p "$WORKDIR/etc/systemd/sleep.conf.d"
    echo admin > "$WORKDIR/etc/systemd/sleep.conf.d/60-bluefin-hibernation.conf"
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
}

@test "allocation or Btrfs validation failure remains recoverable" {
    for failure in ALLOC_FAIL MAP_FAIL; do
        export "$failure=1"
        run "$WORKDIR/driver" enable
        [ "$status" -ne 0 ]
        [ ! -e "$WORKDIR/active" ]
        run "$WORKDIR/driver" status
        [ "$output" = incomplete ]
        run "$WORKDIR/driver" disable
        [ "$status" -eq 0 ]
        [ ! -e "$WORKDIR/swap" ]
        unset "$failure"
    done
}

@test "logind capability rejection leaves suspend unchanged and can be cleaned up" {
    export CAPABILITY=no
    run "$WORKDIR/driver" enable
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/etc/systemd/logind.conf.d/60-bluefin-hibernation.conf" ]
    run "$WORKDIR/driver" disable
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/swap" ]
}

@test "failed swap deactivation preserves swapfile and permits a later retry" {
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    export STOP_FAIL=1
    run "$WORKDIR/driver" disable
    [ "$status" -ne 0 ]
    [ -f "$WORKDIR/swap/swapfile" ]
    [ -f "$WORKDIR/state/owned" ]
    run "$WORKDIR/driver" status
    [ "$output" = incomplete ]
    unset STOP_FAIL
    run "$WORKDIR/driver" disable
    [ "$status" -eq 0 ]
}

@test "cleanup refuses additional data in the swap subvolume" {
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    echo valuable > "$WORKDIR/swap/other"
    run "$WORKDIR/driver" disable
    [ "$status" -ne 0 ]
    [ "$(cat "$WORKDIR/swap/other")" = valuable ]
    [ -f "$WORKDIR/swap/swapfile" ]
}

@test "status detects inactive swap and missing configuration" {
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    rm "$WORKDIR/active"
    run "$WORKDIR/driver" status
    [ "$output" = incomplete ]
    touch "$WORKDIR/active"
    rm "$WORKDIR/etc/systemd/sleep.conf.d/60-bluefin-hibernation.conf"
    run "$WORKDIR/driver" status
    [ "$output" = incomplete ]
}

@test "non-GNOME setup skips the suspend override" {
    export NO_GNOME=1
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/state/gnome" ]
    [ ! -e "$WORKDIR/etc/systemd/system/systemd-suspend.service.d/60-bluefin-hibernation.conf" ]
    run "$WORKDIR/driver" status
    [ "$output" = enabled ]
    run "$WORKDIR/driver" disable
    [ "$status" -eq 0 ]
}

@test "failure to inspect active swap prevents deletion" {
    run "$WORKDIR/driver" enable
    [ "$status" -eq 0 ]
    export SWAPON_FAIL=1
    run "$WORKDIR/driver" disable
    [ "$status" -ne 0 ]
    [ -f "$WORKDIR/swap/swapfile" ]
    [ -f "$WORKDIR/state/owned" ]
}

@test "ujust recipe and alias pass arguments literally to the helper" {
    command -v just >/dev/null || skip 'just not installed'
    sed -n '/^alias toggle-hibernation := hibernation/,$p' \
        "$BATS_TEST_DIRNAME/../system_files/bluefin/usr/share/ublue-os/just/system.just" |
        sed "s|/usr/libexec/bluefin-hibernation|$HELPER|" > "$WORKDIR/hibernation.just"
    run just --justfile "$WORKDIR/hibernation.just" toggle-hibernation help
    [ "$status" -eq 0 ]
    [[ $output == *'Usage: ujust hibernation'* ]]
    run just --justfile "$WORKDIR/hibernation.just" hibernation "\$(touch $WORKDIR/injected)"
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/injected" ]
}
