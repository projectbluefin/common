just := just_executable()

# Run unit tests (pytest for hooks.py, bats for shell scripts)
# test_libvirt_helper.bats is excluded — requires a running libvirtd session
test:
    python3 -m pytest tests/test_hooks.py tests/test_check_oci_refs.py tests/test_bazaar_hook.py tests/test_curated_config.py -v --cov=tests --cov-report=term-missing
    bats tests/test_libsetup.bats
    bats tests/test_setup_scripts.bats
    bats tests/test_privileged_setup.bats
    bats tests/test_bling.bats
    bats tests/test_bling_sh.bats
    bats tests/test_luks_tpm2.bats
    bats tests/test_rechunker_group_fix.bats
    bats tests/test_bling_fastfetch.bats
    bats tests/test_changelog.bats
    bats tests/test_update_just.bats
    bats tests/test_ublue_fastfetch.bats
    bats tests/test_ublue_motd.bats
    bats tests/test_ublue_image_info.bats
    bats tests/test_profile_d.bats
    bats tests/test_dynamic_wallpaper.bats
    bats tests/test_geoclue_latitude.bats
    bats tests/test_brew_preinstall.bats
    bats tests/test_hardware_hooks.bats
    bats tests/test_nvidia_flatpak_sync.bats

# Preview Bazaar config from this checkout on the local machine (passwordless, no sudo, hot-reload, auto-refresh)
bazaar-preview:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Stopping any running Bazaar processes..."
    # Find and kill any running bazaar/Bazaar daemons using PIDs (excluding our own just command)
    RUNNING_PIDS=$(ps -ef | grep -E 'bazaar|Bazaar' | grep -v -E 'grep|just|bazaar-preview' | awk '{print $2}' || true)
    if [[ -n "$RUNNING_PIDS" ]]; then
        kill $RUNNING_PIDS || true
    fi

    echo "Clearing Bazaar's Flatpak app cache to force fresh configuration and article reloads..."
    rm -rf ~/.var/app/io.github.kolunmi.Bazaar/cache/* || true

    echo "Blocking Bazaar from appending the built-in development example page..."
    rm -rf ~/.var/app/io.github.kolunmi.Bazaar/data/example.yaml || true
    mkdir -p ~/.var/app/io.github.kolunmi.Bazaar/data/example.yaml || true

    echo "Regenerating local curated-dev.yaml based on repository curated.yaml..."
    sed 's|file:\/\/\/run/host/etc/bazaar/|file:\/\/\/var/home/jorge/src/common/system_files/bluefin/etc/bazaar/|g' system_files/bluefin/etc/bazaar/curated.yaml > system_files/bluefin/etc/bazaar/curated-dev.yaml

    echo "Creating GNOME Desktop menu override so launching Bazaar always loads local curated-dev.yaml..."
    mkdir -p ~/.local/share/applications
    SRC_DESKTOP=""
    for p in "/var/home/jorge/.local/share/flatpak/exports/share/applications/io.github.kolunmi.Bazaar.desktop" \
             "/var/lib/flatpak/exports/share/applications/io.github.kolunmi.Bazaar.desktop"; do
        if [[ -f "$p" ]]; then
            SRC_DESKTOP="$p"
            break
        fi
    done

    if [[ -n "$SRC_DESKTOP" ]]; then
        cp "$SRC_DESKTOP" ~/.local/share/applications/io.github.kolunmi.Bazaar.desktop
        # Insert extra flags into Exec= lines (avoid double insertions if run multiple times)
        sed -i 's|Exec=/usr/bin/flatpak run|Exec=/usr/bin/flatpak run --nofilesystem=host --filesystem=home|g' ~/.local/share/applications/io.github.kolunmi.Bazaar.desktop
        sed -i 's|io.github.kolunmi.Bazaar |io.github.kolunmi.Bazaar --extra-content-config=/var/home/jorge/src/common/system_files/bluefin/etc/bazaar/curated-dev.yaml |g' ~/.local/share/applications/io.github.kolunmi.Bazaar.desktop
        echo "GNOME menu shortcut successfully configured with hot-reload!"
    else
        echo "Warning: Could not locate a source Bazaar desktop file to override. GNOME launcher shortcut will not be overridden."
    fi

    echo "Launching isolated Bazaar (master) pointing to your local curated-dev.yaml..."
    if command -v setsid >/dev/null 2>&1; then
        setsid -f flatpak run --nofilesystem=host --filesystem=home io.github.kolunmi.Bazaar//master --extra-content-config=/var/home/jorge/src/common/system_files/bluefin/etc/bazaar/curated-dev.yaml >/dev/null 2>&1
    else
        nohup flatpak run --nofilesystem=host --filesystem=home io.github.kolunmi.Bazaar//master --extra-content-config=/var/home/jorge/src/common/system_files/bluefin/etc/bazaar/curated-dev.yaml >/dev/null 2>&1 &
    fi
    echo "Bazaar preview successfully updated, cache cleared, and launched in background!"

# Build the bluefin-common container locally
build:
    git submodule update --init bluefin-branding
    podman build -t localhost/bluefin-common:latest -f ./Containerfile .

_fmt mode verb:
    #!/usr/bin/bash
    failed=0
    while read -r file; do
      echo "{{ verb }} syntax: $file"
      {{ just }} --unstable --fmt {{ mode }} -f "$file" || failed=1
    done < <(find . -type f -name "*.just")
    echo "{{ verb }} syntax: Justfile"
    {{ just }} --unstable --fmt {{ mode }} -f Justfile || failed=1
    exit "$failed"

check: (_fmt "--check" "Checking")

fix: (_fmt "" "Fixing")

# Inspect the directory structure of an OCI image
tree IMAGE="localhost/bluefin-common:latest":
    #!/usr/bin/env bash
    cat > TreeContainerfile <<'EOF'
    FROM alpine:latest
    RUN apk add --no-cache tree
    COPY --from={{ IMAGE }} / /mnt/root
    CMD tree /mnt/root
    EOF
    podman build -t tree-temp -f TreeContainerfile .
    podman run --rm tree-temp
    rm -f TreeContainerfile
    podman rmi tree-temp

overlay $BLUEFIN_MERGE="1" $SOURCE="dir":
    #!/usr/bin/env bash
    ROOTFS_DIR="$(mktemp -d --tmpdir="${ROOTFS_BASE:-/tmp}")"
    trap 'rm -rf "${ROOTFS_DIR}"' EXIT
    NAME_TRIMMED=bfincommon

    if [ "$SOURCE" == "dir" ] ; then
        cp -a ./system_files/shared/. "${ROOTFS_DIR}"
        if [ "${BLUEFIN_MERGE}" == "1" ] ; then
            cp -a ./system_files/bluefin/. "${ROOTFS_DIR}"
        fi
    elif [ "$SOURCE" == "image" ] ; then
        podman export "$(podman create ghcr.io/projectbluefin/common:latest)" -o - | tar -xvf - -C "${ROOTFS_DIR}"
    fi

    install -d -m0755 "${ROOTFS_DIR}/usr/lib/extension-release.d"
    tee "${ROOTFS_DIR}/usr/lib/extension-release.d/extension-release.${NAME_TRIMMED}" <<EOF
    ID="_any"
    ARCHITECTURE="$(sed 's/_/-/g' <<< "$(arch)")"
    EOF

    if [ -e "${ROOTFS_DIR}/system_files" ] ; then
        cp -a "${ROOTFS_DIR}/system_files/shared/." "${ROOTFS_DIR}"
        if [ "${BLUEFIN_MERGE}" == "1" ] ; then
            cp -a "${ROOTFS_DIR}/system_files/bluefin/." "${ROOTFS_DIR}"
        fi
        rm -r "${ROOTFS_DIR}/system_files"
    fi

    if [ -d "${ROOTFS_DIR}/etc" ] ; then
        mv --no-clobber "${ROOTFS_DIR}/etc" "${ROOTFS_DIR}/usr/etc"
    fi

    for dir in "var" "run"; do
        if [ -d "${ROOTFS_DIR}"/"${dir}" ] ; then
            rm -r "${ROOTFS_DIR:?}/${dir}"
        fi
    done
    filecontexts="/etc/selinux/targeted/contexts/files/file_contexts"
    sudo setfiles -r "${ROOTFS_DIR}" "${filecontexts}" "${ROOTFS_DIR}"
    sudo chcon --user=system_u --recursive "${ROOTFS_DIR}"
    mkfs.erofs "${NAME_TRIMMED}.raw" "${ROOTFS_DIR}"
