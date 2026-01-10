just := just_executable()

# Build the bluefin-common container locally
build:
    git submodule update --init --recursive
    podman build -t localhost/bluefin-common:latest -f ./Containerfile .

check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
      echo "Checking syntax: $file"
      {{ just }} --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
        {{ just }} --unstable --fmt --check -f Justfile

fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
      echo "Fixing syntax: $file"
      {{ just }} --unstable --fmt -f $file
    done
    echo "Fixing syntax: Justfile"
    {{ just }} --unstable --fmt -f Justfile || { exit 1; }

# Inspect the directory structure of an OCI image
tree IMAGE="localhost/bluefin-common:latest":
    echo "FROM alpine:latest" > TreeContainerfile
    echo "RUN apk add --no-cache tree" >> TreeContainerfile
    echo "COPY --from={{ IMAGE }} / /mnt/root" >> TreeContainerfile
    echo "CMD tree /mnt/root" >> TreeContainerfile
    podman build -t tree-temp -f TreeContainerfile .
    podman run --rm tree-temp
    rm TreeContainerfile
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

