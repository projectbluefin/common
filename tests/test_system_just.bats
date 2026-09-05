#!/usr/bin/env bats
# Tests for system.just recipes: toggle-testing, toggle-vms, install-system-flatpaks
#
# Each recipe body is extracted out of the justfile into a standalone bash
# script, then run against mocked jq/gum/pkexec/bootc/flatpak/brew/just so the
# channel-mapping and confirmation logic can be exercised without touching the
# host.

SYSTEM_JUST="${BATS_TEST_DIRNAME}/../system_files/bluefin/usr/share/ublue-os/just/system.just"
WORKDIR=""
MOCKDIR=""
COMMAND_LOG=""

_extract_recipe() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]$].*)?:$") { in_recipe=1; next }
        in_recipe && /^    #!\/usr\/bin\/env bash/ { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${SYSTEM_JUST}" \
        | sed 's|{{ justfile() }}|${JUSTFILE_PATH}|g' > "${out_file}"
    chmod +x "${out_file}"
    # Guard against a recipe rename silently producing an empty test subject.
    [ -s "${out_file}" ]
}

_write_mock() {
    local name="$1"
    cat > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

_write_image_info() {
    local tag="$1" ref="$2"
    printf '{"image-tag":"%s","image-ref":"%s"}\n' "${tag}" "${ref}" \
        > "${WORKDIR}/image-info.json"
}

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test-system-just-${BATS_TEST_NUMBER}-$$"
    rm -rf "${WORKDIR}"
    MOCKDIR="${WORKDIR}/bin"
    COMMAND_LOG="${WORKDIR}/commands.log"
    mkdir -p "${MOCKDIR}"
    : > "${COMMAND_LOG}"

    _extract_recipe "toggle-testing" "${WORKDIR}/toggle-testing.sh"
    _extract_recipe "toggle-vms" "${WORKDIR}/toggle-vms.sh"
    _extract_recipe "install-system-flatpaks" "${WORKDIR}/install-system-flatpaks.sh"

    # jq -r '."image-tag"' < file — read the field the recipe asks for.
    _write_mock "jq" <<'MOCK'
#!/bin/bash
field="${2//[\".]/}"
python3 -c "import json,sys; print(json.load(sys.stdin).get('${field}',''))"
MOCK

    # gum confirm honours MOCK_CONFIRM (0 = yes, 1 = no).
    _write_mock "gum" <<'MOCK'
#!/bin/bash
echo "gum $*" >> "${COMMAND_LOG}"
[ "$1" = "confirm" ] && exit "${MOCK_CONFIRM:-0}"
exit 0
MOCK

    for cmd in pkexec bootc brew just; do
        _write_mock "${cmd}" <<MOCK
#!/bin/bash
echo "${cmd} \$*" >> "\${COMMAND_LOG}"
exit 0
MOCK
    done

    # flatpak list emits the VM stack only when MOCK_VMS_INSTALLED=1.
    _write_mock "flatpak" <<'MOCK'
#!/bin/bash
echo "flatpak $*" >> "${COMMAND_LOG}"
if [ "$1" = "list" ]; then
    [ "${MOCK_VMS_INSTALLED:-0}" = "1" ] && echo "org.virt_manager.virt-manager"
fi
exit 0
MOCK

    export COMMAND_LOG
    export IMAGE_INFO_FILE="${WORKDIR}/image-info.json"
    export JUSTFILE_PATH="${SYSTEM_JUST}"
    export HOME="${WORKDIR}/home"
    mkdir -p "${HOME}/.config/libvirt"
    : > "${HOME}/.config/libvirt/libvirt.conf"
    # A minimal PATH keeps a real bctl/flatpak on the runner from leaking in.
    export PATH="${MOCKDIR}:/usr/bin:/bin"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_run_recipe() {
    local script="$1"
    shift
    run env PATH="${PATH}" COMMAND_LOG="${COMMAND_LOG}" \
        IMAGE_INFO_FILE="${IMAGE_INFO_FILE}" JUSTFILE_PATH="${JUSTFILE_PATH}" \
        HOME="${HOME}" "$@" bash "${WORKDIR}/${script}"
}

# --- toggle-testing: stable -> testing direction -------------------------

@test "toggle-testing: stable switches to the testing tag" {
    _write_image_info "stable" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bootc switch --enforce-container-sigpolicy ghcr.io/ublue-os/bluefin:testing" "${COMMAND_LOG}"
}

@test "toggle-testing: latest switches to the testing tag" {
    _write_image_info "latest" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bluefin:testing$" "${COMMAND_LOG}"
}

@test "toggle-testing: lts switches to lts-testing" {
    _write_image_info "lts" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin-lts"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bluefin-lts:lts-testing$" "${COMMAND_LOG}"
}

@test "toggle-testing: lts-hwe switches to lts-hwe-testing" {
    _write_image_info "lts-hwe" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin-lts"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bluefin-lts:lts-hwe-testing$" "${COMMAND_LOG}"
}

@test "toggle-testing: an unrecognised channel refuses to switch" {
    _write_image_info "gts" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot toggle testing from channel 'gts'"* ]]
    ! grep -q "bootc switch" "${COMMAND_LOG}"
}

@test "toggle-testing: warns that testing images may be unstable" {
    _write_image_info "stable" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [[ "$output" == *"not recommended for daily use"* ]]
}

# --- toggle-testing: testing -> stable direction -------------------------

@test "toggle-testing: bare testing returns to stable" {
    _write_image_info "testing" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bluefin:stable$" "${COMMAND_LOG}"
}

@test "toggle-testing: lts-testing returns to lts, not stable" {
    _write_image_info "lts-testing" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin-lts"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bluefin-lts:lts$" "${COMMAND_LOG}"
}

@test "toggle-testing: lts-hwe-testing returns to lts-hwe" {
    _write_image_info "lts-hwe-testing" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin-lts"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bluefin-lts:lts-hwe$" "${COMMAND_LOG}"
}

# --- toggle-testing: transport prefixes and confirmation -----------------

@test "toggle-testing: strips an ostree-unverified-registry prefix" {
    _write_image_info "stable" "ostree-unverified-registry:ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bootc switch --enforce-container-sigpolicy ghcr.io/ublue-os/bluefin:testing" "${COMMAND_LOG}"
}

@test "toggle-testing: an untagged bare registry ref is left intact" {
    _write_image_info "stable" "ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    [ "$status" -eq 0 ]
    grep -q "bootc switch --enforce-container-sigpolicy ghcr.io/ublue-os/bluefin:testing" "${COMMAND_LOG}"
}

@test "toggle-testing: declining the prompt switches nothing" {
    _write_image_info "stable" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh" MOCK_CONFIRM=1
    [ "$status" -eq 0 ]
    ! grep -q "bootc switch" "${COMMAND_LOG}"
}

@test "toggle-testing: declining the testing-to-stable prompt switches nothing" {
    _write_image_info "testing" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh" MOCK_CONFIRM=1
    [ "$status" -eq 0 ]
    ! grep -q "bootc switch" "${COMMAND_LOG}"
}

@test "toggle-testing: the switch runs through pkexec" {
    _write_image_info "stable" "ostree-image-signed:docker://ghcr.io/ublue-os/bluefin"
    _run_recipe "toggle-testing.sh"
    grep -q "^pkexec bootc switch" "${COMMAND_LOG}"
}

# --- toggle-vms ----------------------------------------------------------

@test "toggle-vms: installs the stack when virt-manager is absent" {
    _run_recipe "toggle-vms.sh" MOCK_VMS_INSTALLED=0
    [ "$status" -eq 0 ]
    grep -q "gum confirm Install the VM stack" "${COMMAND_LOG}"
    grep -q "just --justfile .* setup-vms" "${COMMAND_LOG}"
}

@test "toggle-vms: removes the stack when virt-manager is present" {
    _run_recipe "toggle-vms.sh" MOCK_VMS_INSTALLED=1
    [ "$status" -eq 0 ]
    grep -q "gum confirm Remove the VM stack" "${COMMAND_LOG}"
    grep -q "flatpak uninstall --system --noninteractive org.virt_manager.virt-manager" "${COMMAND_LOG}"
    ! grep -q "setup-vms" "${COMMAND_LOG}"
}

@test "toggle-vms: uninstall also drops the QEMU extension" {
    _run_recipe "toggle-vms.sh" MOCK_VMS_INSTALLED=1
    grep -q "org.virt_manager.virt_manager.Extension.Qemu" "${COMMAND_LOG}"
}

@test "toggle-vms: declining the install prompt does nothing" {
    _run_recipe "toggle-vms.sh" MOCK_VMS_INSTALLED=0 MOCK_CONFIRM=1
    [ "$status" -eq 0 ]
    ! grep -q "setup-vms" "${COMMAND_LOG}"
}

@test "toggle-vms: declining the removal prompt keeps the stack" {
    _run_recipe "toggle-vms.sh" MOCK_VMS_INSTALLED=1 MOCK_CONFIRM=1
    [ "$status" -eq 0 ]
    ! grep -q "flatpak uninstall" "${COMMAND_LOG}"
}

@test "toggle-vms: removal strips the session uri_default from libvirt.conf" {
    printf 'uri_default = "qemu:///session"\nkeep_me = 1\n' \
        > "${HOME}/.config/libvirt/libvirt.conf"
    _run_recipe "toggle-vms.sh" MOCK_VMS_INSTALLED=1
    [ "$status" -eq 0 ]
    ! grep -q "uri_default" "${HOME}/.config/libvirt/libvirt.conf"
    grep -q "keep_me" "${HOME}/.config/libvirt/libvirt.conf"
}

# --- install-system-flatpaks --------------------------------------------

@test "install-system-flatpaks: confirm=0 skips the prompt and installs" {
    _run_recipe "install-system-flatpaks.sh" confirm=0
    [ "$status" -eq 0 ]
    ! grep -q "gum confirm" "${COMMAND_LOG}"
    grep -q "brew bundle --file=/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile" "${COMMAND_LOG}"
}

@test "install-system-flatpaks: confirm=1 prompts before installing" {
    _run_recipe "install-system-flatpaks.sh" confirm=1
    [ "$status" -eq 0 ]
    grep -q "gum confirm Install system flatpaks?" "${COMMAND_LOG}"
    grep -q "brew bundle" "${COMMAND_LOG}"
}

@test "install-system-flatpaks: declining the prompt installs nothing" {
    _run_recipe "install-system-flatpaks.sh" confirm=1 MOCK_CONFIRM=1
    [ "$status" -eq 0 ]
    ! grep -q "brew bundle" "${COMMAND_LOG}"
}

@test "install-system-flatpaks: TARGET_FLATPAK_FILE overrides the Brewfile" {
    _run_recipe "install-system-flatpaks.sh" confirm=0 \
        TARGET_FLATPAK_FILE="${WORKDIR}/custom.Brewfile"
    [ "$status" -eq 0 ]
    grep -q "brew bundle --file=${WORKDIR}/custom.Brewfile" "${COMMAND_LOG}"
}
