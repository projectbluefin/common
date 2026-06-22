just := just_executable()

# Run unit tests (pytest for hooks.py, bats for shell scripts)
# test_libvirt_helper.bats is excluded — requires a running libvirtd session
test:
    python3 -m pytest tests/test_hooks.py tests/test_check_oci_refs.py tests/test_bazaar_hook.py -v --cov=tests --cov-report=term-missing
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
