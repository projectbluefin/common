# Opt-in hibernation

`ujust hibernation [enable [--yes]|disable|status]` (alias `toggle-hibernation`) calls
Bluefin's `/usr/libexec/bluefin-hibernation`. With no argument it prompts.
This is opt-in: installing the image does not create swap or change sleep.

> **Hardware validation status:** the automated tests mock every privileged
> operation. Suspend-then-hibernate and resume have not yet been verified on
> real hardware. Save your work before testing and follow the validation steps
> below.

## Security: the hibernation image is not encrypted by this recipe

Hibernation writes the full contents of RAM — including passwords, keys, and
open documents — to `/var/swap/swapfile`. On systems without full-disk
encryption (LUKS), that data is stored unencrypted on disk.

Before creating anything, the helper checks whether the block device behind
`/var` sits on a dm-crypt (LUKS) mapping. If it does not, it prints a warning
and asks for confirmation (default: no); declining leaves the system unchanged.
For non-interactive use, `ujust hibernation enable --yes` accepts the
unencrypted image explicitly.

## Requirements

The helper requires Btrfs under `/var`, writable UEFI variables, kernel
hibernation support, and `mkswap --file`. It refuses an existing `/var/swap`,
resume kernel arguments, or conflicting recipe-owned paths.

Swap size rounds up to whole GiB: twice RAM below 2 GiB, 1.5 times below
8 GiB, otherwise RAM. Before allocating anything, the helper checks that `/var`
has room for the swapfile plus a 4 GiB reserve, so setup never drives the Btrfs
volume near full.

The dedicated `var-swap-swapfile.swap` unit persists activation without editing
fstab. No kernel arguments, SELinux policy, Secure Boot settings, GNOME
settings, or `uupd-resume.timer` are changed.

## Behavior

GNOME retains its AC/battery idle timeouts. On GNOME installations, a drop-in
makes `systemd-suspend.service` perform suspend-then-hibernate; this also
affects other callers of that service. Lid handling uses logind's normal
inhibitor and docked/external-power behavior. The recipe sets a 60-minute
hibernation delay, but does not change the power button or logind idle policy.
Reboot after either enabling or disabling to apply logind configuration without
restarting sessions.

Ownership lives in `/var/lib/bluefin-hibernation`; configuration uses
`60-bluefin-hibernation.conf` drop-ins. `status` reports `disabled`, `enabled`,
or `incomplete` for the recipe's setup, not a guarantee of hardware resume.
After interrupted setup, run `disable` before retrying `enable`. Cleanup stops
swap successfully before deleting it and refuses to remove unrelated files in
the subvolume. Setup and cleanup are serialized with the same lock.

## Manual hardware validation

Automatic resume depends on a working systemd hibernate-resume generator in the
image's initramfs, which cannot be verified from this repository. On an updated
Bluefin UEFI/Btrfs system:

1. Save your work, run `ujust hibernation enable`, and reboot.
2. Verify `systemctl hibernate` resumes with the session intact.
3. Test GNOME idle suspend on AC and battery, and lid close through the delay.
4. Check encrypted-storage unlock and GPU resume on the actual machine.
5. Run `ujust hibernation disable`, reboot, and verify original suspend
   behavior and unrelated configuration survive.

Do not weaken kernel lockdown or SELinux if capability checks fail; inspect the
journal instead.

## References

- [systemd resume generator](https://github.com/systemd/systemd/blob/main/man/systemd-hibernate-resume-generator.xml): automatic EFI resume discovery.
- [systemd swap units](https://github.com/systemd/systemd/blob/main/man/systemd.swap.xml): path-derived names and automatic mount dependencies.
- [Btrfs swapfile requirements](https://github.com/kdave/btrfs-progs/blob/devel/Documentation/Swapfile.rst): `map-swapfile` validates layout before activation.
- [mkswap implementation](https://github.com/util-linux/util-linux/blob/master/disk-utils/mkswap.c): labels the swapfile `swapfile_t`; do not undo that with `restorecon` on the file.
