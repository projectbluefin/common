#!/usr/bin/env bats
# Tests for the NVIDIA suspend quirk in system_files/shared:
#   usr/lib/modprobe.d/zz-nvidia-suspend.conf
#   usr/lib/tmpfiles.d/nvidia-suspend.conf
#
# With NVreg_UseKernelSuspendNotifiers=1 the driver writes its VRAM save file
# from systemd-sleep (SELinux domain systemd_sleep_t). That domain may only
# write systemd_sleep_var_lib_t (/var/lib/systemd/sleep), so the save path must
# be that directory, and something must create it (utah#533).
#
# Run: bats tests/test_nvidia_suspend.bats

SHARED="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib"
MODPROBE="$SHARED/modprobe.d/zz-nvidia-suspend.conf"
TMPFILES="$SHARED/tmpfiles.d/nvidia-suspend.conf"

save_path() {
    awk '$1 == "options" && $2 == "nvidia" {
        for (i = 3; i <= NF; i++) if ($i ~ /^NVreg_TemporaryFilePath=/) { sub(/^[^=]*=/, "", $i); p = $i }
    } END { print p }' "$MODPROBE"
}

@test "kernel suspend notifiers stay pinned on" {
    grep -Eq '^options nvidia .*NVreg_UseKernelSuspendNotifiers=1' "$MODPROBE"
}

@test "VRAM save path is the systemd_sleep_var_lib_t directory" {
    [ "$(save_path)" = "/var/lib/systemd/sleep" ]
}

@test "VRAM save path is not a tmp_t or tmpfs location" {
    case "$(save_path)" in
        /tmp|/tmp/*|/var/tmp|/var/tmp/*|"") false ;;
    esac
}

@test "tmpfiles.d creates the VRAM save directory root-only" {
    run awk -v p="$(save_path)" '$1 == "d" && $2 == p { print $3, $4, $5 }' "$TMPFILES"
    [ "$status" -eq 0 ]
    [ "$output" = "0700 root root" ]
}
