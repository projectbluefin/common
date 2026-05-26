# DX-Tools Homebrew bundle (installed by dx_run_tools / ujust dx-tools).
# Incus is NOT listed here — use menu "Incus" or ujust dx-incus (dx_run_incus).
# Flatpaks and VS Code cask are installed in dx-install-lib.sh after this bundle runs.

tap "ublue-os/experimental-tap"
tap "ublue-os/tap"


cask "android-platform-tools"
# flatpak "org.flatpak.Builder"
brew "git-svn"
brew "git-subrepo"
brew "bpftop"
brew "numactl"
brew "p7zip"
# lima/kind/ydotool/podman-* installed in dx_run_tools (podman link order conflicts during bundle)
#brew "sysprof"

# New (incus is installed via the Incus menu option / dx_run_incus, not DX-Tools)
# brew "squashfs" (macOS only, use system mksquashfs)
# brew "devcontainer" (Fails on Linux, installed via npm)
# vscode extensions: installed via `code` CLI in dx_run_tools (brew bundle needs a GUI)
# flatpak "io.podman_desktop.PodmanDesktop"

# Wall of shame
#iotop
#bcc
#bpftrace
#fonts todo
#nicstat
#osbuild-selinux
#podman-machine
#tiptop
#udica
#util-linux-script