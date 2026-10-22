#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

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
        [[ $* != *SOURCE* ]] || { echo "${VAR_SOURCE:-/dev/mapper/luks-test[/root]}"; exit; }
        echo "${FSTYPE:-btrfs}" ;;
    lsblk) printf '%b\n' "${LSBLK_TYPES:-crypt\npart\ndisk}" ;;
    gum) exit "${GUM_CONFIRM:-1}" ;;
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
        [[ ${STOP_FAIL:-0} == 0 && ${SWAPOFF_FAIL:-0} == 0 ]] || exit 1
        rm -f "$WORKDIR/active" ;;
    df) printf 'Avail\n%s\n' "${AVAIL_MIB:-102400}" ;;
    busctl) printf 's "%s"\n' "${CAPABILITY:-yes}" ;;
    chattr|restorecon|gnome-shell) ;;
esac
STUB
    chmod +x "$WORKDIR/driver" "$WORKDIR/bin/stub"
    for name in df findmnt lsblk gum btrfs mkswap systemctl swapon swapoff busctl chattr restorecon gnome-shell; do
        ln -s stub "$WORKDIR/bin/$name"
    done
    export PATH="$WORKDIR/bin:$PATH"
}

@test "help and invalid actions do not call privileged tools" {
    run bash "$HELPER" help
    [ "$status" -eq 0 ]
    [[ $output == *'status|enable [--yes]|disable'* ]]
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
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    run "$WORKDIR/driver" status
    [ "$output" = enabled ]
    grep -q 'HandleLidSwitch=suspend-then-hibernate' "$WORKDIR/etc/systemd/logind.conf.d/60-bluefin-hibernation.conf"
    run ! grep -R -E 'IdleAction|HandlePowerKey|IgnoreInhibited|gsettings|uupd' "$WORKDIR/etc"
    grep -q 'systemd-sleep suspend-then-hibernate' "$WORKDIR/etc/systemd/system/systemd-suspend.service.d/60-bluefin-hibernation.conf"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    [ "$(grep -c 'btrfs subvolume create' "$WORKDIR/calls")" -eq 1 ]
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/swap" ]
    [ ! -e "$WORKDIR/state" ]
    [ "$(cat "$WORKDIR/etc/systemd/logind.conf.d/lid.conf")" = admin ]
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
}

@test "existing swap directory is never adopted or deleted" {
    mkdir "$WORKDIR/swap"
    echo valuable > "$WORKDIR/swap/swapfile"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
    [ "$(cat "$WORKDIR/swap/swapfile")" = valuable ]
}

@test "unsupported filesystem, kernel, EFI and resume arguments fail before mutation" {
    export FSTYPE=ext4
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    unset FSTYPE
    echo mem > "$WORKDIR/power"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    echo 'mem disk' > "$WORKDIR/power"
    rmdir "$WORKDIR/efi"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    mkdir "$WORKDIR/efi"
    echo 'quiet resume=/dev/test' > "$WORKDIR/cmdline"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
}

@test "insufficient free space on /var fails before mutation" {
    # 9G swap + 4G reserve = 13312 MiB required.
    export AVAIL_MIB=13311
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [[ $output == *'free space'* ]]
    [ ! -e "$WORKDIR/state" ]
    export AVAIL_MIB=13312
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
}

@test "LUKS-backed /var enables without an unencrypted-image prompt" {
    run bash "$HELPER" help
    [[ $output == *'LUKS'* ]]
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    [[ $output != *'unencrypted'* ]]
    grep -Fxq 'lsblk -n -s -o TYPE -- /dev/mapper/luks-test' "$WORKDIR/calls"
    run grep -q '^gum ' "$WORKDIR/calls"
    [ "$status" -ne 0 ]
}

@test "unencrypted /var requires confirmation before any mutation" {
    export LSBLK_TYPES='part\ndisk' VAR_SOURCE='/dev/sda3[/root]'
    export GUM_CONFIRM=1
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [[ $output == *'unencrypted'* ]]
    [[ $output == *'no changes'* ]]
    [ ! -e "$WORKDIR/state" ]
    [ ! -e "$WORKDIR/swap" ]
    export GUM_CONFIRM=0
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    [[ $output == *'unencrypted'* ]]
    run "$WORKDIR/driver" status
    [ "$output" = enabled ]
}

@test "unencrypted /var accepts --yes without prompting" {
    export LSBLK_TYPES='part\ndisk'
    run "$WORKDIR/driver" enable_hibernation --yes
    [ "$status" -eq 0 ]
    [[ $output == *'unencrypted'* ]]
    run grep -q '^gum ' "$WORKDIR/calls"
    [ "$status" -ne 0 ]
}

@test "unencrypted /var without gum or --yes fails before mutation" {
    export LSBLK_TYPES='part\ndisk'
    rm "$WORKDIR/bin/gum"
    command -v gum >/dev/null && skip 'system gum present'
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [[ $output == *'--yes'* ]]
    [ ! -e "$WORKDIR/state" ]
}

@test "--yes is rejected outside enable and extra arguments fail before sudo" {
    for args in 'disable --yes' 'status --yes' 'enable --force' 'enable --yes extra'; do
        read -ra argv <<< "$args"
        run bash "$HELPER" "${argv[@]}"
        [ "$status" -ne 0 ]
    done
    [ ! -e "$WORKDIR/calls" ]
}

@test "existing configuration and fstab entries are refused" {
    export FSTAB_SOURCE="$WORKDIR/swap/swapfile"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
    unset FSTAB_SOURCE
    mkdir -p "$WORKDIR/etc/systemd/sleep.conf.d"
    echo admin > "$WORKDIR/etc/systemd/sleep.conf.d/60-bluefin-hibernation.conf"
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/state" ]
}

@test "allocation or Btrfs validation failure remains recoverable" {
    for failure in ALLOC_FAIL MAP_FAIL; do
        export "$failure=1"
        run "$WORKDIR/driver" enable_hibernation
        [ "$status" -ne 0 ]
        [ ! -e "$WORKDIR/active" ]
        run "$WORKDIR/driver" status
        [ "$output" = incomplete ]
        run "$WORKDIR/driver" disable_hibernation
        [ "$status" -eq 0 ]
        [ ! -e "$WORKDIR/swap" ]
        unset "$failure"
    done
}

@test "logind capability rejection leaves suspend unchanged and can be cleaned up" {
    export CAPABILITY=no
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/etc/systemd/logind.conf.d/60-bluefin-hibernation.conf" ]
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/swap" ]
}

@test "failed swap deactivation preserves swapfile and permits a later retry" {
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    export STOP_FAIL=1
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -ne 0 ]
    [ -f "$WORKDIR/swap/swapfile" ]
    [ -f "$WORKDIR/state/owned" ]
    run "$WORKDIR/driver" status
    [ "$output" = incomplete ]
    unset STOP_FAIL
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
}

@test "direct swapoff failure without a unit file preserves swapfile" {
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    rm "$WORKDIR/etc/systemd/system/var-swap-swapfile.swap"
    export SWAPOFF_FAIL=1
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -ne 0 ]
    grep -Fxq "swapoff $WORKDIR/swap/swapfile" "$WORKDIR/calls"
    [ -f "$WORKDIR/swap/swapfile" ]
    [ -f "$WORKDIR/state/owned" ]
    unset SWAPOFF_FAIL
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/swap" ]
}

@test "cleanup refuses additional data in the swap subvolume" {
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    echo valuable > "$WORKDIR/swap/other"
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -ne 0 ]
    [ "$(cat "$WORKDIR/swap/other")" = valuable ]
    [ -f "$WORKDIR/swap/swapfile" ]
}

@test "status detects inactive swap and missing configuration" {
    run "$WORKDIR/driver" enable_hibernation
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
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    [ ! -e "$WORKDIR/state/gnome" ]
    [ ! -e "$WORKDIR/etc/systemd/system/systemd-suspend.service.d/60-bluefin-hibernation.conf" ]
    run "$WORKDIR/driver" status
    [ "$output" = enabled ]
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -eq 0 ]
}

@test "failure to inspect active swap prevents deletion" {
    run "$WORKDIR/driver" enable_hibernation
    [ "$status" -eq 0 ]
    export SWAPON_FAIL=1
    run "$WORKDIR/driver" disable_hibernation
    [ "$status" -ne 0 ]
    [ -f "$WORKDIR/swap/swapfile" ]
    [ -f "$WORKDIR/state/owned" ]
}

@test "ujust recipe and alias pass arguments literally to the helper" {
    command -v just >/dev/null || skip 'just not installed'
    sed -n '/^alias toggle-hibernation := hibernation/,/^    @\/usr\/libexec\/bluefin-hibernation /p' \
        "$BATS_TEST_DIRNAME/../system_files/bluefin/usr/share/ublue-os/just/system.just" |
        sed "s|/usr/libexec/bluefin-hibernation|$HELPER|" > "$WORKDIR/hibernation.just"
    run just --justfile "$WORKDIR/hibernation.just" toggle-hibernation help
    [ "$status" -eq 0 ]
    [[ $output == *'Usage: ujust hibernation'* ]]
    run just --justfile "$WORKDIR/hibernation.just" hibernation "\$(touch $WORKDIR/injected)"
    [ "$status" -ne 0 ]
    [ ! -e "$WORKDIR/injected" ]
    run just --justfile "$WORKDIR/hibernation.just" hibernation status --yes
    [ "$status" -ne 0 ]
    [[ $output == *'only valid with enable'* ]]
    [ "$(grep -c '^hibernation ' "$WORKDIR/hibernation.just")" -eq 1 ]
}
