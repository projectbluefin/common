# vim: set ft=make :
# This file should only contain bluefin specific stuff

# Configure Bluefin-CLI Terminal Experience with Brew
[group('System')]
bluefin-cli:
    @/usr/libexec/ublue-bling

# alias for toggle-devmode
devmode:
    @ujust toggle-devmode

# Toggle between Bluefin and the Developer Experience
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_IMAGE=$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference"')
    if grep -q "/var/ublue-os/image" <<< $CURRENT_IMAGE ; then
        bash -c "cat <<EOF
    Before we can switch to the Bluefin Developer Experience
    the current system needs an update. Please run 'ujust update'
    and reboot your system when the update is finished
    EOF"
        exit
    fi
    if /bin/grep -q "\-dx" <<< $CURRENT_IMAGE ; then
        CURRENT_STATE="enabled"
    else
        CURRENT_STATE="disabled"
    fi
    echo "Developer mode is currently ${CURRENT_STATE}"
    echo "Enable or Disable developer mode"
    OPTION=$(Choose Enable Disable)
    if [[ "${OPTION,,}" =~ ^enable ]]; then
        if [ "$CURRENT_STATE" = "enabled" ] ; then
            echo "You are already on a developer image"
            exit 0
        fi
        echo "Rebasing to a developer image"
        NEW_IMAGE=$(sed "s/bluefin/bluefin-dx/" <<< $CURRENT_IMAGE)
        rpm-ostree rebase $NEW_IMAGE
        echo -e "\nUse `ujust dx-group` to add your user to the correct groups and complete the installation"
    fi
    if [[ "${OPTION,,}" =~ ^disable ]]; then
        if [ "$CURRENT_STATE" != "enabled" ]; then
            echo "You are currently not on a developer image"
            exit 0
        fi
        echo "Rebasing to a non developer image"
        # Remove -dx suffix from image, specifies ":" to mark the end of the image name
        NEW_IMAGE=$(sed "s/\-dx//" <<< $CURRENT_IMAGE)
        rpm-ostree rebase $NEW_IMAGE
    fi
    if gum choose "Do you want to also install the default development flatpaks?" ; then
        ujust install-system-flatpaks 1
    fi
    if gum choose "Do you want to install extra monospace fonts?" ; then
        brew bundle install --file=/usr/share/ublue-os/homebrew/fonts.Brewfile
    fi

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
install-system-flatpaks $dx="dynamic":
    #!/usr/bin/bash
    TARGET_FLATPAK_FILE="${TARGET_FLATPAK_FILE:-/etc/ublue-os/system-flatpaks.list}"
    TARGET_DEVMODE_FILE="${TARGET_DEVMODE_FILE:-/etc/ublue-os/system-flatpaks-dx.list}"
    case "$dx" in
        "0"|"1")
            ADD_DEVMODE="$dx"
            ;;
        "dynamic")
            if [[ $(jq '."image-flavor"' /usr/share/ublue-os/image-info.json) =~ dx ]] ; then
                ADD_DEVMODE=1
            fi
            ;;
        *)
            echo "Unsupported option"
            exit 1
            ;;
    esac

    flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo
    xargs flatpak --system -y install --or-update < $TARGET_FLATPAK_FILE
    if [ "$ADD_DEVMODE" == "1" ] ; then
        xargs flatpak --system -y install --or-update < $TARGET_DEVMODE_FILE
    fi

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

# FIXME: apparently this is broken since F43
# Enable automatic LUKS unlock via TPM
setup-luks-tpm-unlock:
    #!/usr/bin/bash
    sudo /usr/libexec/luks-enable-tpm2-autounlock

# Disable automatic LUKS unlock via TPM
remove-luks-tpm-unlock:
    #!/usr/bin/bash
    sudo /usr/libexec/luks-disable-tpm2-autounlock

