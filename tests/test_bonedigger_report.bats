#!/usr/bin/env bats

setup() {
    export BONEDIGGER_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/bonedigger-report"
    export UBLUE_IMAGE_REPO_BIN="$BATS_TEST_DIRNAME/../system_files/shared/usr/libexec/ublue-image-repo"
    export WORKDIR="$BATS_TEST_DIRNAME/.bonedigger-report-test-${BATS_TEST_NUMBER}-${$}"
    export HOME="$WORKDIR/home"
    export XDG_STATE_HOME="$WORKDIR/state"
    export XDG_RUNTIME_DIR="$WORKDIR/runtime"

    mkdir -p "$WORKDIR/bin" "$HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
}

teardown() {
    rm -rf "$WORKDIR"
}

@test "scrub_kernel_log redacts MAC, IP, UUID, and home paths" {
    run bash -c 'source "$1"; printf "%s\n" "$2" | scrub_kernel_log' _ \
        "$BONEDIGGER_SCRIPT" \
        "Device 00:1A:2B:3C:4D:5E from 192.168.1.100 on /home/alice/ UUID 123e4567-e89b-12d3-a456-426614174000"

    [ "$status" -eq 0 ]
    [ "$output" = "Device [MAC-REDACTED] from [IP-REDACTED] on /home/[REDACTED]/ UUID [UUID-REDACTED]" ]
}

@test "scrub_journal_log redacts user variables and email addresses" {
    run bash -c 'source "$1"; printf "%s\n" "$2" | scrub_journal_log' _ \
        "$BONEDIGGER_SCRIPT" "USER=jorge contacted jorge@example.com"

    [ "$status" -eq 0 ]
    [ "$output" = "USER=[REDACTED] contacted [REDACTED-email]" ]
}

@test "bug routing maps Bluefin-family, Dakota-family, and unknown images" {
    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin latest
    [ "$output" = "projectbluefin/bluefin" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin lts-42
    [ "$output" = "projectbluefin/bluefin-lts" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin-lts-hwe stable
    [ "$output" = "projectbluefin/bluefin-lts" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin-nvidia stable
    [ "$output" = "projectbluefin/bluefin" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" dakota latest
    [ "$output" = "projectbluefin/dakota" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" dakota-nvidia stable
    [ "$output" = "projectbluefin/dakota" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" unknown latest
    [ "$output" = "projectbluefin/common" ]
}

@test "read_boot_status derives image name, tag, and ref from a rebased booted deployment" {
    cat << 'EOF' > "$WORKDIR/bin/bootc"
#!/usr/bin/bash
if [[ "$1" == "status" && "$2" == "--json" ]]; then
    printf '%s' '{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota:stable"},"imageDigest":"sha256:deadbeef"}}}}'
    exit 0
fi
printf 'Booted: ghcr.io/projectbluefin/dakota:stable\n'
EOF
    chmod +x "$WORKDIR/bin/bootc"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        IMAGE_NAME="bluefin"
        IMAGE_TAG="latest"
        read_boot_status
        printf "%s|%s|%s" "$IMAGE_NAME" "$IMAGE_TAG" "$IMAGE_REF"
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [ "$output" = "dakota|stable|ghcr.io/projectbluefin/dakota:stable" ]
}

@test "read_boot_status strips the digest from a digest-pinned booted ref" {
    cat << 'EOF' > "$WORKDIR/bin/bootc"
#!/usr/bin/bash
if [[ "$1" == "status" && "$2" == "--json" ]]; then
    printf '%s' '{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota@sha256:deadbeef"},"imageDigest":"sha256:deadbeef"}}}}'
    exit 0
fi
printf 'Booted: ghcr.io/projectbluefin/dakota@sha256:deadbeef\n'
EOF
    chmod +x "$WORKDIR/bin/bootc"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        IMAGE_NAME="bluefin"
        IMAGE_TAG="latest"
        read_boot_status
        printf "%s|%s" "$IMAGE_NAME" "$IMAGE_TAG"
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [ "$output" = "dakota|latest" ]
}

@test "read_boot_status keeps the repository basename when the registry has a port" {
    cat << 'EOF' > "$WORKDIR/bin/bootc"
#!/usr/bin/bash
if [[ "$1" == "status" && "$2" == "--json" ]]; then
    printf '%s' '{"status":{"booted":{"image":{"image":{"image":"localhost:5000/bluefin:latest"},"imageDigest":"sha256:deadbeef"}}}}'
    exit 0
fi
printf 'Booted: localhost:5000/bluefin:latest\n'
EOF
    chmod +x "$WORKDIR/bin/bootc"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        IMAGE_NAME="dakota"
        IMAGE_TAG="stable"
        read_boot_status
        printf "%s|%s" "$IMAGE_NAME" "$IMAGE_TAG"
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [ "$output" = "bluefin|latest" ]
}


@test "human-only consent replaces prior analysis consent in the submitted body" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
case "$1" in
    choose) printf 'Human interaction only\n' ;;
    style) exit 0 ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    printf '%s\n' \
        '## Bluefin report' \
        '<!-- automation-preference: analysis -->' \
        > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        choose_automation_preference
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    grep -qF '<!-- automation-preference: human-only -->' "$WORKDIR/draft/issue.md"
    ! grep -qF '<!-- automation-preference: analysis -->' "$WORKDIR/draft/issue.md"
}


@test "network smart logs are redacted and bounded" {
    cat << 'EOF' > "$WORKDIR/bin/journalctl"
#!/usr/bin/bash
for _ in $(seq 1 80); do
    printf 'USER=jorge peer 192.168.1.8 MAC AA:BB:CC:DD:EE:FF /home/alice/private\n'
done
EOF
    cat << 'EOF' > "$WORKDIR/bin/nmcli"
#!/usr/bin/bash
printf 'wlan0:wifi:connected\n'
EOF
    chmod +x "$WORKDIR/bin/journalctl" "$WORKDIR/bin/nmcli"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        collect_profile Networking "$2/networking.md" 512
        grep -Fq "[IP-REDACTED]" "$2/networking.md"
        grep -Fq "[MAC-REDACTED]" "$2/networking.md"
        grep -Fq "USER=[REDACTED]" "$2/networking.md"
        ! grep -Fq "192.168.1.8" "$2/networking.md"
        test "$(wc -c < "$2/networking.md")" -le 512
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
}

@test "baseline bug-report draft includes hardware summary and load average" {
    mkdir -p "$WORKDIR/sys/class/dmi/id" "$WORKDIR/sys/class/net" "$WORKDIR/draft"
    printf 'TestVendor\n' > "$WORKDIR/sys/class/dmi/id/sys_vendor"
    printf 'TestModel\n' > "$WORKDIR/sys/class/dmi/id/product_name"
    printf 'eth0\n' > "$WORKDIR/sys/class/net/eth0"

    cat << 'EOF' > "$WORKDIR/bin/systemctl"
#!/usr/bin/bash
printf 'failed-example.service loaded failed failed\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/journalctl"
#!/usr/bin/bash
printf 'kernel: mock error\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
printf 'Model name: TestCorp CPU\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lspci"
#!/usr/bin/bash
printf '00:02.0 VGA compatible controller: TestCorp GPU\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/free"
#!/usr/bin/bash
printf 'Mem:           16Gi       2.0Gi        11Gi\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
printf 'nvme0 1.8T\n'
EOF
    chmod +x "$WORKDIR/bin/"*

    run env PATH="$WORKDIR/bin:$PATH" \
        DMI_ID_PATH="$WORKDIR/sys/class/dmi/id" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            DRAFT_DIR="$2"
            IMAGE_REF="ghcr.io/projectbluefin/dakota-nvidia-gaming"
            IMAGE_TAG="testing"
            IMAGE_VERSION="20260929"
            IMAGE_FLAVOR="gaming"
            BOOTED_DIGEST="sha256:abc"
            collect_baseline "Test title" "Test desc" "Test repro" < /dev/null
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ -f "$WORKDIR/draft/issue.md" ]
    grep -Fq 'TestVendor' "$WORKDIR/draft/issue.md"
    grep -Fq 'TestModel' "$WORKDIR/draft/issue.md"
    grep -Fq 'Hardware summary' "$WORKDIR/draft/issue.md"
    grep -Fq 'TestCorp CPU' "$WORKDIR/draft/issue.md"
    grep -Fq 'TestCorp GPU' "$WORKDIR/draft/issue.md"
}

@test "hardware smart log captures DMI, CPU, GPU, disk, and PCI inventory" {
    mkdir -p "$WORKDIR/sys/class/dmi/id" "$WORKDIR/sys/class/net"
    printf 'TestVendor\n' > "$WORKDIR/sys/class/dmi/id/sys_vendor"
    printf 'TestModel 9000\n' > "$WORKDIR/sys/class/dmi/id/product_name"
    printf 'TestFamily\n' > "$WORKDIR/sys/class/dmi/id/product_family"
    printf '1.0\n' > "$WORKDIR/sys/class/dmi/id/product_version"
    printf 'TestBIOS\n' > "$WORKDIR/sys/class/dmi/id/bios_vendor"
    printf '1.00\n' > "$WORKDIR/sys/class/dmi/id/bios_version"
    printf '3\n' > "$WORKDIR/sys/class/dmi/id/chassis_type"
    for iface in eth0 wlan0 lo; do
        printf 'state\n' > "$WORKDIR/sys/class/net/$iface"
    done

    cat << 'EOF' > "$WORKDIR/bin/lspci"
#!/usr/bin/bash
printf '00:02.0 VGA compatible controller: TestCorp UHD Graphics [1234:5678]\n'
printf '01:00.0 Network controller: TestCorp Wireless [DEAD:BEEF]\n'
EOF

    cat << 'EOF' > "$WORKDIR/bin/lsusb"
#!/usr/bin/bash
printf 'Bus 001 Device 001: ID 1d6b:0002 TestCorp Hub\n'
printf 'Bus 001 Device 002: ID CAFE:1234 TestCorp Keyboard\n'
EOF

    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
cat << 'CPU'
Architecture:        x86_64
Vendor ID:           GenuineIntel
Model name:          TestCorp i9-9900K
CPU(s):              8
Thread(s) per core:  2
Core(s) per socket:  4
Socket(s):           1
CPU max MHz:         3600.0000
CPU min MHz:         800.0000
L1d cache:           32K
L1i cache:           32K
L2 cache:            256K
L3 cache:            16384K
CPU
EOF

    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
cat << 'LSBLK'
NAME  SIZE ROTA TRAN MODEL
nvme0 1.8T    0  nvme TestCorp SSD
sda   1.8T    1  sata TestCorp HDD
LSBLK
EOF

    cat << 'EOF' > "$WORKDIR/bin/free"
#!/usr/bin/bash
cat << 'FREE'
              total        used        free      shared  buff/cache   available
Mem:           16Gi       2.0Gi        11Gi       100Mi       3.0Gi        14Gi
Swap:         4.0Gi          0B       4.0Gi
FREE
EOF

    cat << 'EOF' > "$WORKDIR/bin/gnome-shell"
#!/usr/bin/bash
printf 'GNOME Shell 99.0\n'
EOF

    chmod +x \
        "$WORKDIR/bin/lspci" \
        "$WORKDIR/bin/lsusb" \
        "$WORKDIR/bin/lscpu" \
        "$WORKDIR/bin/lsblk" \
        "$WORKDIR/bin/free" \
        "$WORKDIR/bin/gnome-shell"

    run env PATH="$WORKDIR/bin:$PATH" \
        DMI_ID_PATH="$WORKDIR/sys/class/dmi/id" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            collect_profile Hardware "$2/hardware.md" 16384
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq 'TestVendor' "$WORKDIR/hardware.md"
    grep -Fq 'TestModel 9000' "$WORKDIR/hardware.md"
    grep -Fq 'TestCorp i9-9900K' "$WORKDIR/hardware.md"
    grep -Fq 'Graphics devices' "$WORKDIR/hardware.md"
    grep -Fq 'PCI devices:    2' "$WORKDIR/hardware.md"
    grep -Fq 'USB devices:    2' "$WORKDIR/hardware.md"
    grep -Fq 'wlan0' "$WORKDIR/hardware.md"
    grep -Fq 'Network interfaces (name only): eth0,wlan0' "$WORKDIR/hardware.md"
    grep -Fq 'L1d cache' "$WORKDIR/hardware.md"
    grep -Fq 'L3 cache' "$WORKDIR/hardware.md"
    grep -Fq 'TestCorp SSD' "$WORKDIR/hardware.md"
}

@test "hardware smart log redacts home paths and identifiers" {
    mkdir -p "$WORKDIR/sys/class/dmi/id" "$WORKDIR/sys/class/net"
    printf 'TestVendor\n' > "$WORKDIR/sys/class/dmi/id/sys_vendor"
    printf 'TestModel\n' > "$WORKDIR/sys/class/dmi/id/product_name"
    printf 'eth0\n' > "$WORKDIR/sys/class/net/eth0"

    cat << 'EOF' > "$WORKDIR/bin/lspci"
#!/usr/bin/bash
printf '00:02.0 VGA compatible controller: TestCorp GPU from /home/alice/secret\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
printf 'Model name:          TestCorp from /home/bob/private\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
printf 'nvme0 1.8T 0 nvme TestCorp /home/alice/private\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lsusb"
#!/usr/bin/bash
printf 'Bus 001 Device 002: ID CAFE:1234 from /home/alice/path\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/free"
#!/usr/bin/bash
printf 'Mem:           16Gi       2.0Gi        11Gi\n'
EOF

    chmod +x \
        "$WORKDIR/bin/lspci" \
        "$WORKDIR/bin/lsusb" \
        "$WORKDIR/bin/lscpu" \
        "$WORKDIR/bin/lsblk" \
        "$WORKDIR/bin/free"

    run env PATH="$WORKDIR/bin:$PATH" \
        DMI_ID_PATH="$WORKDIR/sys/class/dmi/id" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            collect_profile Hardware "$2/hardware.md" 16384
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq '/home/[REDACTED]/' "$WORKDIR/hardware.md"
    ! grep -Fq '/home/alice/' "$WORKDIR/hardware.md"
    ! grep -Fq '/home/bob/' "$WORKDIR/hardware.md"
}

@test "collect_hardware_summary renders CPU, GPU, memory, disks, and network" {
    mkdir -p "$WORKDIR/sys/class/net"
    for iface in eth0 wlan0 lo; do
        printf 'state\n' > "$WORKDIR/sys/class/net/$iface"
    done

    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
printf 'Model name:          TestCorp i7-13700K\n'
EOF

    cat << 'EOF' > "$WORKDIR/bin/lspci"
#!/usr/bin/bash
printf '00:02.0 VGA compatible controller: TestCorp UHD 770\n'
EOF

    cat << 'EOF' > "$WORKDIR/bin/free"
#!/usr/bin/bash
printf '              total        used        free      shared  buff/cache   available\nMem:           32Gi       4.0Gi        25Gi       100Mi       3.0Gi        28Gi\n'
EOF

    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
cat << 'LSBLK'
nvme0n1 1.8T TestCorp SSD
sda 1.8T TestCorp HDD
LSBLK
EOF

    chmod +x \
        "$WORKDIR/bin/lscpu" \
        "$WORKDIR/bin/lspci" \
        "$WORKDIR/bin/free" \
        "$WORKDIR/bin/lsblk"

    run env PATH="$WORKDIR/bin:$PATH" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            collect_hardware_summary > "$2/hw.txt"
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq 'TestCorp i7-13700K' "$WORKDIR/hw.txt"
    grep -Fq 'TestCorp UHD 770' "$WORKDIR/hw.txt"
    grep -Fq '32Gi total / 28Gi available' "$WORKDIR/hw.txt"
    grep -Fq 'nvme0n1 1.8T TestCorp' "$WORKDIR/hw.txt"
    grep -Fq 'eth0,wlan0' "$WORKDIR/hw.txt"
}

@test "collect_hardware_summary keeps multi-word disk models intact" {
    mkdir -p "$WORKDIR/sys/class/net"
    printf 'state\n' > "$WORKDIR/sys/class/net/eth0"

    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
cat << 'LSBLK'
nvme0n1 1.8T Samsung SSD 980 PRO 1TB
sda 931.5G WDC WD10EZEX-08WN4A0
LSBLK
EOF
    chmod +x "$WORKDIR/bin/lsblk"

    run env PATH="$WORKDIR/bin:$PATH" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            collect_hardware_summary > "$2/hw.txt"
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq 'nvme0n1 1.8T Samsung SSD 980 PRO 1TB' "$WORKDIR/hw.txt"
    grep -Fq 'sda 931.5G WDC WD10EZEX-08WN4A0' "$WORKDIR/hw.txt"
}

@test "baseline hardware probes are redacted before reaching the issue draft" {
    mkdir -p "$WORKDIR/sys/class/dmi/id" "$WORKDIR/sys/class/net" "$WORKDIR/draft"
    printf 'TestVendor /home/alice/brand\n' > "$WORKDIR/sys/class/dmi/id/sys_vendor"
    printf 'TestModel /home/bob/model\n' > "$WORKDIR/sys/class/dmi/id/product_name"
    printf 'state\n' > "$WORKDIR/sys/class/net/eth0"

    cat << 'EOF' > "$WORKDIR/bin/systemctl"
#!/usr/bin/bash
printf ''
EOF
    cat << 'EOF' > "$WORKDIR/bin/journalctl"
#!/usr/bin/bash
printf ''
EOF
    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
printf 'Model name: TestCorp from /home/alice/cpu\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lspci"
#!/usr/bin/bash
printf '00:02.0 VGA compatible controller: TestCorp GPU /home/alice/gpu\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
printf 'nvme0n1 1.8T TestCorp /home/alice/disk\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/free"
#!/usr/bin/bash
printf '              total        used        free      shared  buff/cache   available\nMem:           32Gi       4.0Gi        25Gi       100Mi       3.0Gi        28Gi\n'
EOF
    chmod +x "$WORKDIR/bin/"*

    run env PATH="$WORKDIR/bin:$PATH" \
        DMI_ID_PATH="$WORKDIR/sys/class/dmi/id" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            DRAFT_DIR="$2"
            IMAGE_REF="ghcr.io/projectbluefin/dakota"
            IMAGE_TAG="testing"
            IMAGE_VERSION="20260929"
            IMAGE_FLAVOR="main"
            BOOTED_DIGEST="sha256:abc"
            collect_baseline "Test title" "Test desc" "Test repro" < /dev/null
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    ! grep -Fq '/home/alice/' "$WORKDIR/draft/issue.md"
    ! grep -Fq '/home/bob/' "$WORKDIR/draft/issue.md"
    grep -Fq '/home/[REDACTED]/' "$WORKDIR/draft/issue.md"
    # Memory appears once only, in the Hardware summary table.
    [ "$(grep -c '| Memory |' "$WORKDIR/draft/issue.md")" -eq 1 ]
    grep -Fq '32Gi total / 28Gi available' "$WORKDIR/draft/issue.md"
}

@test "collect_hardware_summary tolerates missing probes by reporting _unavailable_" {
    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
printf 'Model name: TestCorp\n'
EOF
    chmod +x "$WORKDIR/bin/lscpu"

    run env PATH="$WORKDIR/bin:$PATH" \
        SYS_CLASS_NET_PATH="$WORKDIR/missing-net-path" \
        bash -c '
            source "$1"
            collect_hardware_summary > "$2/hw.txt"
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq 'TestCorp' "$WORKDIR/hw.txt"
    grep -Fq '_unavailable_' "$WORKDIR/hw.txt"
}

@test "collect_hardware_summary survives a failing lscpu under set -e" {
    mkdir -p "$WORKDIR/sys/class/net"
    printf 'state\n' > "$WORKDIR/sys/class/net/eth0"

    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
exit 1
EOF
    chmod +x "$WORKDIR/bin/lscpu"

    run env PATH="$WORKDIR/bin:$PATH" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            set -euo pipefail
            source "$1"
            collect_hardware_summary > "$2/hw.txt"
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq '| CPU | `_unavailable_` |' "$WORKDIR/hw.txt"
    grep -Fq 'eth0' "$WORKDIR/hw.txt"
}

@test "collect_hardware_summary omits VPN, tunnel, and virtual interfaces" {
    mkdir -p "$WORKDIR/sys/class/net"
    for iface in eth0 lo tailscale0 wg0 proton0 tun0 docker0 virbr0 veth1a2b br-abc123; do
        printf 'state\n' > "$WORKDIR/sys/class/net/$iface"
    done

    run env PATH="$WORKDIR/bin:$PATH" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            collect_hardware_summary > "$2/hw.txt"
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
    grep -Fq '| Network interfaces | `eth0` |' "$WORKDIR/hw.txt"
    for hidden in tailscale0 wg0 proton0 tun0 docker0 virbr0 veth1a2b br-abc123; do
        ! grep -Fq "$hidden" "$WORKDIR/hw.txt"
    done
}

@test "hardware smart log is bounded by the per-profile byte cap" {
    mkdir -p "$WORKDIR/sys/class/dmi/id" "$WORKDIR/sys/class/net"
    printf 'TestVendor\n' > "$WORKDIR/sys/class/dmi/id/sys_vendor"
    printf 'eth0\n' > "$WORKDIR/sys/class/net/eth0"

    cat << 'EOF' > "$WORKDIR/bin/lspci"
#!/usr/bin/bash
printf '00:02.0 VGA compatible controller: GPU line one\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lscpu"
#!/usr/bin/bash
printf 'Model name: tiny\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lsblk"
#!/usr/bin/bash
printf 'nvme0 1.8T\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/lsusb"
#!/usr/bin/bash
printf 'Bus 001\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/free"
#!/usr/bin/bash
printf 'Mem: 16Gi\n'
EOF
    chmod +x \
        "$WORKDIR/bin/lspci" \
        "$WORKDIR/bin/lsusb" \
        "$WORKDIR/bin/lscpu" \
        "$WORKDIR/bin/lsblk" \
        "$WORKDIR/bin/free"

    run env PATH="$WORKDIR/bin:$PATH" \
        DMI_ID_PATH="$WORKDIR/sys/class/dmi/id" \
        SYS_CLASS_NET_PATH="$WORKDIR/sys/class/net" \
        bash -c '
            source "$1"
            collect_profile Hardware "$2/hardware.md" 256
            test "$(wc -c < "$2/hardware.md")" -le 256
        ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
}

@test "selected profile bundle is capped at two MiB" {
    cat << 'EOF' > "$WORKDIR/bin/journalctl"
#!/usr/bin/bash
for _ in $(seq 1 16000); do
    printf 'warning USER=jorge peer 192.168.1.8\n'
done
EOF
    chmod +x "$WORKDIR/bin/journalctl"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        BOOTC_STATUS="booted"
        SELECTED_PROFILES=(
            "Desktop / graphics"
            "Sleep / crash"
            "Update / boot"
            Networking
            "Flatpak / application"
        )
        collect_profiles
        total=0
        for file in "${PROFILE_FILES[@]}"; do
            bytes="$(wc -c < "$file")"
            test "$bytes" -le $((500 * 1024))
            total=$((total + bytes))
        done
        test "$total" -le $((2 * 1024 * 1024))
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
}

@test "persist_local_copy skips missing report files and keeps available copies" {
    mkdir -p "$WORKDIR/draft"
    printf 'summary\n' > "$WORKDIR/draft/issue.md"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    export DRAFT_DIR="$WORKDIR/draft"
    export LOCAL_REPORT_ROOT="$WORKDIR/state/ujust-report"

    run bash -c 'source "$1"; persist_local_copy' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(cat "$LOCAL_REPORT_ROOT/last/summary.md")" = "summary" ]
    [ ! -e "$LOCAL_REPORT_ROOT/last/journal.txt" ]
}

@test "ordinary reporters create issues without requesting label permissions" {
    cat << 'EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
for arg in "$@"; do
    if [[ "$arg" == --label ]]; then
        printf 'Reporter cannot set repository labels\n' >&2
        exit 1
    fi
done
printf 'https://github.com/projectbluefin/common/issues/99\n'
EOF
    chmod +x "$WORKDIR/bin/gh"
    mkdir -p "$WORKDIR/draft"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    printf 'Short title\n' > "$WORKDIR/draft/title.txt"
    printf '<!-- report-type: bug -->\n' > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        create_issue
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/projectbluefin/common/issues/99" ]
}

@test "confirmation accepts a GitHub issue URL and posts no device identifier" {
    cat << 'EOF' > "$WORKDIR/bin/systemctl"
#!/usr/bin/bash
printf 'failed-example.service loaded failed failed\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$CALLS_FILE"
if [[ "$1" == api ]]; then
    printf 'https://github.com/projectbluefin/dakota/issues/42#issuecomment-123\n'
fi
EOF
    chmod +x "$WORKDIR/bin/systemctl" "$WORKDIR/bin/gh"
    export CALLS_FILE="$WORKDIR/gh-calls"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        parse_confirm_target "https://github.com/projectbluefin/dakota/issues/42#comment" projectbluefin/common
        IMAGE_REF="ghcr.io/projectbluefin/dakota"
        IMAGE_TAG="latest"
        BOOTED_DIGEST="sha256:abc123"
        confirm_report "$CONFIRM_ISSUE" "$CONFIRM_REPO"
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Will post to: https://github.com/projectbluefin/dakota/issues/42"* ]]
    [[ "$output" == *"Digest: sha256:abc123"* ]]
    [[ "$output" != *"Device ID"* ]]
    grep -qF "issue comment 42 --repo projectbluefin/dakota --body" "$CALLS_FILE"
    grep -qF "https://github.com/projectbluefin/dakota/issues/42#issuecomment-123" <<< "$output"
}

@test "confirmation rejects invalid issue identifiers" {
    run bash -c 'source "$1"; parse_confirm_target "$2" projectbluefin/common' _ \
        "$BONEDIGGER_SCRIPT" 0
    [ "$status" -eq 1 ]
    [[ "$output" == *"issue-number-or-url"* ]]

    run bash -c 'source "$1"; parse_confirm_target "$2" projectbluefin/common' _ \
        "$BONEDIGGER_SCRIPT" "https://github.com/projectbluefin/common/issues/0"
    [ "$status" -eq 1 ]
}

@test "confirmation accepts a positive issue number for the routed repository" {
    run bash -c '
        source "$1"
        parse_confirm_target "$2" projectbluefin/bluefin-lts
        printf "%s|%s" "$CONFIRM_REPO" "$CONFIRM_ISSUE"
    ' _ "$BONEDIGGER_SCRIPT" 73

    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin-lts|73" ]
}

@test "declining submission preserves the draft and resume command" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == choose ]] && printf 'No preference\n'
if [[ "$1" == confirm ]]; then
    exit 1
fi
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    printf 'Short title\n' > "$WORKDIR/draft/title.txt"
    printf '## 🫐 Bluefin Bug Report\n' > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        PROFILE_FILES=()
        submit_draft
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ -f "$WORKDIR/draft/issue.md" ]
    [[ "$output" == *"Resume with: ujust report --resume $WORKDIR/draft"* ]]
}

@test "cancelling automation selection preserves the bug draft" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == choose ]] && exit 1
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    printf 'Short title\n' > "$WORKDIR/draft/title.txt"
    printf '## 🫐 Bluefin Bug Report\n' > "$WORKDIR/draft/issue.md"
    : > "$WORKDIR/draft/bug-report.txt"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        PROFILE_FILES=()
        submit_draft
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ -f "$WORKDIR/draft/issue.md" ]
    [[ "$output" == *"Resume with: ujust report --resume $WORKDIR/draft"* ]]
}

@test "feature requests draft against projectbluefin common" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
case "$1" in
    input)
        case "$*" in
            *"Short title"*) printf 'Improve the desktop\n' ;;
            *) printf 'Please add a useful setting.\n' ;;
        esac
        ;;
    confirm) exit 1 ;;
    choose) printf 'No preference\n' ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum"

    run env PATH="$WORKDIR/bin:$PATH" XDG_STATE_HOME="$XDG_STATE_HOME" \
        bash -c '
            source "$1"
            start_feature_request
            cat "$DRAFT_ROOT"/draft-*/repo.txt
        ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"projectbluefin/common"* ]]
}

@test "missing gh requests Homebrew installation before failing safely" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == confirm ]]
EOF
    cat << 'EOF' > "$WORKDIR/bin/brew"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$BREW_CALLS"
EOF
    chmod +x "$WORKDIR/bin/gum" "$WORKDIR/bin/brew"
    export BREW_CALLS="$WORKDIR/brew-calls"

    run env PATH="$WORKDIR/bin" BREW_CALLS="$BREW_CALLS" /usr/bin/bash -c '
        source "$1"
        ensure_gh_ready
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 1 ]
    grep -qFx 'install gh' "$BREW_CALLS"
}

@test "unauthenticated gh offers browser sign-in" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == confirm ]]
EOF
    cat << 'EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$GH_CALLS"
case "$1 $2" in
    "auth status") exit 1 ;;
    "auth login") exit 0 ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum" "$WORKDIR/bin/gh"
    export GH_CALLS="$WORKDIR/gh-calls"

    run env PATH="$WORKDIR/bin:$PATH" GH_CALLS="$GH_CALLS" /usr/bin/bash -c '
        source "$1"
        ensure_gh_ready
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 1 ]
    grep -qFx 'auth login --web --skip-ssh-key' "$GH_CALLS"
}

@test "help intent does not collect diagnostics or create an issue" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
if [[ "$1" == choose ]]; then
    printf 'Get help\n'
fi
EOF
    cat << 'EOF' > "$WORKDIR/bin/bootc"
#!/usr/bin/bash
printf 'bootc should not be called\n' >&2
exit 1
EOF
    chmod +x "$WORKDIR/bin/gum" "$WORKDIR/bin/bootc"

    run env PATH="$WORKDIR/bin:$PATH" HOME="$HOME" \
        XDG_STATE_HOME="$XDG_STATE_HOME" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        bash "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Bluefin Discussions"* ]]
    [[ "$output" == *"No issue was created."* ]]
    [[ "$output" != *"bootc should not be called"* ]]
}
