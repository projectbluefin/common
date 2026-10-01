# ipp-usb and raw USB scanner/printer ownership coexistence

> Issue: [projectbluefin/common#1214](https://github.com/projectbluefin/common/issues/1214)
> Parent epic: [projectbluefin/common#1210](https://github.com/projectbluefin/common/issues/1210)
> Status: **design note**. `common` ships no `ipp-usb` configuration today, so
> there is nothing in the image for a test to validate; this document records
> the ownership model and the reversible policy knobs for when Bluefin does.

How a single multifunction (MFP) USB device — printer **and** scanner on one
USB body — is owned without two user-space consumers fighting over the same
logical interface.

## The conflict

A multifunction device exposes several **logical USB interfaces** on one
physical USB device. Three consumers can claim them:

| Consumer | Path | Claims |
|----------|------|--------|
| `ipp-usb` | `libusb` — opens the device, detaches the kernel driver from each interface, then claims it | serves IPP/eSCL over the IPP-over-USB interfaces it claims |
| `cups` (usb backend) | `libusb` interface claim (Fedora builds `cups` against `libusb-1.0`; the kernel `usblp` path is used only when CUPS is built without it) | raw printer interface |
| `sane` (raw backend) | `libusb` interface claim | raw scanner interface |

All three use `libusb` interface claims, so they are mutually exclusive **per
interface**: once one consumer claims an interface, no other consumer can claim
that same interface. So an interface has exactly one `libusb` owner — or the
consumers collide.

## How `ipp-usb` actually takes a device

`ipp-usb` does **not** bind interfaces to a kernel driver via `configfs`. It:

1. opens the device with `libusb`;
2. detaches the kernel driver from every interface in the configuration
   (`detachKernelDriver` in `usbio_libusb.go`);
3. claims the interfaces it serves with `libusb_claim_interface`.

It only claims **IPP-over-USB** interfaces — USB interface class 7 (printer),
subclass 1, protocol 4, plus `255/9/1` on some HP devices (vendor `0x03f0`)
(`IsIppOverUsb` in `usbcommon.go`). eSCL scanning travels over those same
claimed interfaces; there is no separate scanner interface that `ipp-usb` claims
on top of printing. Because step 2 detaches the kernel driver from **every**
interface, `usblp` is not bound to any interface while `ipp-usb` holds the
device.

Two points worth pinning down:

- **There is no kernel `usbscanner` driver.** Current kernels ship `usblp`
  (printer) for the print path; SANE talks to USB scanners directly through
  `libusb`, not through a scanner kernel driver.
- **`ipp-usb` does not bind via `configfs` or USB/IP in the field.** USB/IP
  appears only inside `ipp-usb`'s own CI, and only on the *client* side: the
  emulated printer is a userspace USB/IP server (`mfp-virtual --usbip`), and
  the CI attaches it with `usbip attach` through the kernel's `vhci_hcd`
  virtual host-controller driver. The export-side `usbip-host` driver is not
  involved, because no real local device is being exported.

## The principle: one owner per logical interface

Coexistence is possible only where the printer and scanner functions sit on
**different logical interfaces**: `ipp-usb` claims the IPP-over-USB interfaces,
and a separate vendor-specific scanner interface, if the device has one, is left
unclaimed for SANE to take. On devices whose only scan path is eSCL over the
IPP-over-USB interfaces, there is nothing for SANE's raw backend to claim while
`ipp-usb` runs. The rule:

> Each logical USB interface on a device has exactly one owner. Different
> consumers may own different interfaces of the same physical device without
> conflict.

- Printer interface → owned by `ipp-usb` (IPP) **or** `cups` (usb backend).
- Scanner interface → owned by `ipp-usb` (eSCL, over the IPP-over-USB
  interfaces) **or** `sane` (raw `libusb`).
- A `mass_storage` / card-reader interface has no print/scan owner.

When `ipp-usb` serves the IPP-over-USB interfaces and the scanner is a separate
vendor-specific interface, `ipp-usb` owns the printer and `sane` owns the
scanner on the same physical device — coexistence.

## The reversible policy knob: ipp-usb quirks

`ipp-usb` has no global "scan-skip" setting. The real, reversible controls live
as drop-in configs in **`/etc/ipp-usb/quirks/*.conf`**:

| Quirk | Effect |
|-------|--------|
| `disable-scan = true` | `ipp-usb` stops offering eSCL but **keeps its interfaces claimed**. The scanner interface stays with `ipp-usb`; SANE cannot claim it. |
| `blacklist = true` | `ipp-usb` leaves the device alone entirely (checked before it detaches kernel drivers or claims anything). The whole device (printer and scanner) is free for `cups`/`sane`. |

Quirk files use INI syntax; the section name selects the device by USB HWID
(`VID:PID` from `lsusb`) or by model name (from `ipp-usb check`). A HWID match
is the most specific and is applied before `ipp-usb` reads the model name:

```ini
# /etc/ipp-usb/quirks/local-release.conf
# Replace 04b8:1234 with the device's VID:PID from lsusb.
[04b8:1234]
  blacklist = true
```

Deleting the file and restarting `ipp-usb.service` restores the default.
Stopping or masking `ipp-usb.service` is the system-wide equivalent for every
device.

These are the knobs a reversible Bluefin policy can expose. `blacklist` is
the one that actually releases the scanner to SANE; `disable-scan` only
removes the eSCL function while still holding the interfaces. A per-device
quirk is intentionally coarse — that is the documented ceiling; a
per-interface ACL would need a real device to justify.

## Host vs. rootless Podman consumers

Bluefin users reach these devices from two places: host services (`ipp-usb`,
host `cups`, host `sane`) and containers, typically a **rootless Podman** CUPS
or SANE image with `--device /dev/bus/usb/...`. The containerized case does not
change the ownership rule, because two gates apply in order:

1. **Claim exclusivity is kernel-enforced on the `usbfs` node, not per
   namespace.** A `libusb` interface claim is recorded by the kernel against
   the `/dev/bus/usb/BBB/DDD` character device. A container gets the *same*
   device node as the host, just mapped into its mount namespace, so a
   containerized CUPS or SANE contends for exactly the same interface as host
   `ipp-usb`. If `ipp-usb` holds the IPP-over-USB interfaces, the container's
   claim fails with `LIBUSB_ERROR_BUSY` — identical to the host-vs-host case.
   Containerization is not an escape hatch; the quirks above are still the
   knob.
2. **Rootless adds a udev/`uaccess` ACL gate on top.** Rootless Podman runs the
   container process as the invoking user's UID, so it can only open the device
   node if that UID can open it on the host. USB device nodes are `root:root`
   `0664` by default; access for a normal user comes from the `uaccess` tag
   that `systemd-udev` applies to the local seat's session user as a POSIX ACL.
   A device tagged `uaccess` is reachable by the logged-in desktop user, and
   therefore by their rootless container; a device not tagged (or a user with
   no local seat session, e.g. over SSH or from a system-level Quadlet running
   as another UID) gets `EACCES` on open, before any claim is attempted.
   Rootful Podman bypasses gate 2 but not gate 1.

Practical consequence: a rootless containerized scanner stack needs both the
ACL (a local seat session, or an explicit udev rule granting the UID) **and**
an unclaimed interface (`blacklist = true`, or a device whose scanner is a
separate vendor-specific interface). Neither gate substitutes for the other.

This section is reasoned from the claim and ACL mechanisms, not measured — see
the unverified list below.

## Hardware effects: unverified

No physical scanner is available. The following remain **unverified** and must
be reported as such (per the issue scope):

- the actual `libusb` claim vs. `usblp` kernel race on a real MFP;
- whether a specific device's scanner exposes an eSCL function that `ipp-usb`
  will try to serve;
- SANE backend selection (`auto`/`airscan`/`raw`) once `ipp-usb` is running;
- which quirk (`disable-scan` vs `blacklist`) a given device needs to release
  the scanner to SANE without also losing the printer;
- the rootless Podman path end to end: the `uaccess` ACL outcome for the
  container's host UID, and hotplug re-claim races between a container backend
  and host `ipp-usb` when the device is re-plugged.

## Recommendation

1. `ipp-usb` is enabled by default for driverless printing/eSCL.
2. A documented, reversible toggle — a drop-in
   `/etc/ipp-usb/quirks/*.conf` with `blacklist = true` for the affected
   device — lets a user release the whole device to `cups`/`sane`, and removing
   the file restores `ipp-usb`. Document the one-command rollback in the
   Bluefin docs so the change is reversible and auditable.
3. Do **not** ship a synthetic virtual-MFP resolver as coverage: it asserts
   properties of code that lives only in the test, and `common` ships no
   `ipp-usb` config for it to validate, so it cannot catch a regression. Re-add
   real coverage once Bluefin installs a real `ipp-usb` policy — modelled on
   `ipp-usb`'s own CI, which runs the `go-mfp` emulator (`mfp-virtual --usbip`,
   then `usbip attach` via `vhci_hcd`) rather than a hand-written resolver.

## Evidence

- [OpenPrinting/ipp-usb](https://github.com/OpenPrinting/ipp-usb) — `libusb`
  take-over model (`usbio_libusb.go`, `usbcommon.go`), quirks in
  `/etc/ipp-usb/quirks/`.
- [OpenPrinting/go-mfp](https://github.com/OpenPrinting/go-mfp) — virtual MFP
  emulator used by `ipp-usb`'s own CI and the sibling scanner-fixture issue
  [#1212](https://github.com/projectbluefin/common/issues/1212).
- [SANE backends](https://gitlab.com/sane-project/backends) — raw backend.
- [kernel `usblp`](https://www.kernel.org/doc/html/latest/drivers/usb/usbindex.html) —
  the printer kernel driver; there is no `usbscanner` module.
- [`systemd-udev` `uaccess`](https://www.freedesktop.org/software/systemd/man/latest/systemd-udevd.service.html) —
  the seat ACL that gates a rootless container's access to a USB device node.
