# vim: set ft=make :
# This file should only contain bluefin specific stuff

# Configure Bluefin-CLI Terminal Experience with Brew
[group('System')]
bluefin-cli:
    @ublue-bling
    brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile

# alias for toggle-devmode
devmode:
    @ujust toggle-devmode

# Toggle between Bluefin and the Developer Experience
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    set -e
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_NAME="$(jq -rc '."image-name"' "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -rc '."image-ref"' "${IMAGE_INFO_FILE}" | sed "s/.*ghcr/ghcr/")"
    CURRENT_IMAGE="${IMAGE_REF}:$(jq -rc '."image-tag"' "${IMAGE_INFO_FILE}")"
    IMAGE_BASE_NAME="$(cut -f1 -d\- <<< "${IMAGE_NAME}")"
    set +e

    if grep -q -E -e "dx$" <<< "${IMAGE_NAME}" ; then
        gum confirm "Would you like to disable developer mode?" || exit 0
        echo "Rebasing to a non developer image"
        NEW_IMAGE="$(sed "s/\-dx//" <<< $CURRENT_IMAGE)"
        pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
        exit 0
    fi

    gum confirm "Would you like to enable developer mode?" || exit 0
    echo "Rebasing to a developer image"
    NEW_IMAGE="$(sed "s/${IMAGE_BASE_NAME}/${IMAGE_BASE_NAME}-dx/" <<< "${CURRENT_IMAGE}")"
    pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
    if gum confirm "Do you want to also install the default development flatpaks?" ; then
        ADD_DEVMODE=1 ujust install-system-flatpaks 0 1
    fi
    if gum confirm "Do you want to install extra monospace fonts?" ; then
        brew bundle install --file=/usr/share/ublue-os/homebrew/fonts.Brewfile
    fi
    echo "Use ujust dx-group to add your user to the correct groups and complete the installation after rebooting into the development image"

# Toggle between stable and testing images (LTS only)
[group('System')]
toggle-testing:
    #!/usr/bin/env bash
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_TAG="$(jq -rc '."image-tag"' "${IMAGE_INFO_FILE}")"

    # Guard: only LTS images have testing variants
    if ! grep -q "^lts" <<< "${IMAGE_TAG}" ; then
        echo "toggle-testing is only available on Bluefin LTS images."
        echo "Current image tag: ${IMAGE_TAG}"
        exit 0
    fi

    # Detect current booted image reference via bootc
    BOOTED_IMAGE="$(sudo bootc status --json | jq -rc '.status.booted.image.image.image')"
    if [ -z "${BOOTED_IMAGE}" ] || [ "${BOOTED_IMAGE}" == "null" ] ; then
        echo "Error: Could not determine current booted image from bootc status."
        exit 1
    fi

    # Split into registry/name and tag
    IMAGE_BASE="${BOOTED_IMAGE%%:*}"
    CURRENT_TAG="${BOOTED_IMAGE##*:}"

    if grep -q "\-testing" <<< "${CURRENT_TAG}" ; then
        STABLE_TAG="${CURRENT_TAG%-testing}"
        TARGET="${IMAGE_BASE}:${STABLE_TAG}"
        echo "You are currently on a testing image."
        echo "  Current: ${BOOTED_IMAGE}"
        echo "  Target:  ${TARGET}"
        gum confirm "Switch from testing to stable?" || exit 0
    else
        TESTING_TAG="${CURRENT_TAG}-testing"
        TARGET="${IMAGE_BASE}:${TESTING_TAG}"
        echo "You are currently on a stable image."
        echo "  Current: ${BOOTED_IMAGE}"
        echo "  Target:  ${TARGET}"
        gum confirm "Switch from stable to testing? Testing images may be less stable." || exit 0
    fi

    # --enforce-container-sigpolicy is MANDATORY for security (container signature verification)
    pkexec bootc switch --enforce-container-sigpolicy "${TARGET}"
    echo "Reboot to apply the change."

# Configure docker,incus-admin,libvirt, container manager, serial permissions
[group('System')]
dx-group:
    #!/usr/bin/pkexec bash
    append_group() {
        local group_name="$1"
        if ! grep -q "^$group_name:" /etc/group; then
            echo "Appending $group_name to /etc/group"
            grep "^$group_name:" /usr/lib/group | sudo tee -a /etc/group > /dev/null
        fi
    }

    GROUPS_ADD=("docker" "incus-admin" "libvirt" "dialout")

    for GROUP_ADD in "${GROUPS_ADD[@]}" ; do
        append_group $GROUP_ADD
        usermod -aG $GROUP_ADD {{ `id -un` }}
    done

    echo "Reboot system and log back in to use docker, libvirt, incus, and serial connections."

# Install system flatpaks for rebasers
[group('System')]
install-system-flatpaks $confirm="1" $dx_only="0":
    #!/usr/bin/env bash
    if [[ "$(jq '."image-flavor"' /usr/share/ublue-os/image-info.json)" =~ dx ]] ; then
        ADD_DEVMODE="${ADD_DEVMODE:-1}"
    fi
    if [ "${ADD_DEVMODE:-0}" == "1" ] ; then
        if [ "$confirm" != 0 ] ; then
            gum confirm "Install development flatpaks?" || exit 0
        fi
        brew bundle --file="${TARGET_FLATPAK_FILE:-/usr/share/ublue-os/homebrew/system-dx-flatpaks.Brewfile}"
    fi
    [ "$dx_only" == 1 ] && exit 0
    if [ "$confirm" != 0 ] ; then
        gum confirm "Install system flatpaks?" || exit 0
    fi
    brew bundle --file="${TARGET_FLATPAK_FILE:-/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile}"

# Install default system flatpaks (alias for install-system-flatpaks)

# For additional applications, use: ujust bbrew
[group('System')]
bluefin-apps:
    echo "Installing default system flatpaks..."
    @ujust install-system-flatpaks

alias switch-stream := rebase-helper
alias switch-streams := rebase-helper
alias rollback-helper := rebase-helper

# Rebase assistant
[group('System')]
rebase-helper:
    @/usr/bin/ublue-rollback-helper

# Factory reset this device (experimental)
[group('System')]
powerwash:
    #!/usr/bin/bash
    FIRST_CONFIRMATION=$(gum choose --header='Warning: This is an experimental feature that will reset this device to its factory state.' "No" "Yes - wipe this machine")
    if [[ "$FIRST_CONFIRMATION" != "Yes - wipe this machine" ]]; then
        echo "Powerwash cancelled."
        exit 0
    fi
    SECOND_CONFIRMATION=$(gum choose --header='Are you sure?' "No" "Yes - wipe this machine")
    if [[ "$SECOND_CONFIRMATION" != "Yes - wipe this machine" ]]; then
        echo "Powerwash cancelled."
        exit 0
    fi
    sudo bootc install reset --experimental
