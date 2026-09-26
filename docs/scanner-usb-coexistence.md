# ipp-usb and raw USB scanner/printer ownership coexistence

> Issue: [projectbluefin/common#1214](https://github.com/projectbluefin/common/issues/1214)
> Parent epic: [projectbluefin/common#1210](https://github.com/projectbluefin/common/issues/1210)
> Status: **design note**. The synthetic coverage this PR once shipped was
> dropped in review (see below): it asserted properties of a resolver written
> inside the test file, and `common` ships no `ipp-usb` config for a test to
> validate, so it could not catch a regression. This document records the model
> and the reversible policy knob; the coverage is re-provable only once Bluefin
> ships a real `ipp-usb` policy.

How a single multifunction (MFP) USB device — printer **and** scanner on one
USB body — is owned without two user-space consumers fighting over the same
logical interface.

## The conflict

A multifunction device exposes several **logical USB interfaces** on one
physical USB device. Three consumers can claim them:

| Consumer | Path | Claims |
|----------|------|--------|
| `ipp-usb` | `libusb` — opens the device, detaches the kernel driver from each interface, then claims it | serves IPP/eSCL over the IPP-over-USB interfaces it claims |
| `cups` (usb backend) | kernel `usblp` driver | raw printer interface |
| `sane` (raw backend) | `libusb` interface claim | raw scanner interface |

`ipp-usb` and the SANE raw backend both use `libusb` interface claims, so they
are mutually exclusive **per interface**: once `ipp-usb` claims an interface,
the same `libusb` claim cannot also be held by SANE on it. So an interface has
exactly one `libusb` owner — or the two consumers collide.

## How `ipp-usb` actually takes a device

`ipp-usb` does **not** bind interfaces to a kernel driver via `configfs`. It:

1. opens the device with `libusb`;
2. detaches the kernel driver from every interface in the configuration
   (`detachKernelDriver` in `usbio_libusb.go`);
3. claims the interfaces it serves with `libusb_claim_interface`.

It only claims **IPP-over-USB** interfaces — USB interface class 7 (printer),
subclass 1, protocol 4, plus `255/9/3` on some HP models (`IsIppOverUsb` in
`usbcommon.go`). eSCL scanning travels over those same claimed interfaces; there
is no separate scanner interface that `ipp-usb` claims on top of printing.

Two misconceptions in the earlier draft are worth pinning down, because a test
built on them proves nothing:

- **There is no kernel `usbscanner` driver.** Current kernels ship `usblp`
  (printer) and `usbip-host` (the USB/IP backend `ipp-usb` uses only in its own
  CI, where it attaches an emulated printer). SANE talks to USB scanners
  directly through `libusb`, not through a scanner kernel driver.
- **`ipp-usb` does not bind via `configfs`/`usbip-host` in the field.** The
  `usbip-host` picture holds only inside `ipp-usb`'s CI emulator.

## The principle: one owner per logical interface

Coexistence is possible precisely because the printer and scanner are
**different logical interfaces** — or, on most MFPs, because `ipp-usb` serves
only the printer interface and leaves the scanner to SANE. The rule:

> Each logical USB interface on a device has exactly one owner. Different
> consumers may own different interfaces of the same physical device without
> conflict.

- Printer interface → owned by `ipp-usb` (IPP) **or** `cups` (`usblp`).
- Scanner interface → owned by `ipp-usb` (eSCL, over the IPP-over-USB
  interfaces) **or** `sane` (raw `libusb`).
- A `mass_storage` / card-reader interface has no print/scan owner.

When `ipp-usb` serves the printer but **does not claim** the scanner (the
scanner has no eSCL function, or the device policy says so), `ipp-usb` owns the
printer and `sane` owns the scanner on the same physical device — coexistence.

## The reversible policy knob: ipp-usb quirks

`ipp-usb` has no global "scan-skip" setting. The real, reversible controls live
as drop-in configs in **`/etc/ipp-usb/quirks/*.conf`**:

| Quirk | Effect |
|-------|--------|
| `disable-scan` | `ipp-usb` stops offering eSCL but **keeps its interfaces claimed**. The scanner interface stays with `ipp-usb`; SANE cannot claim it. |
| `blacklist = true` | `ipp-usb` leaves the device alone entirely. The whole device (printer and scanner) is free for `cups`/`sane`. |

These are the two knobs a reversible Bluefin policy can expose. `blacklist` is
the coarse one that actually releases the scanner to SANE; `disable-scan` only
removes the eSCL function while still holding the interfaces. A per-device
quirk is intentionally coarse — that is the documented ceiling; a
per-interface ACL would need a real device to justify.

## Hardware effects: unverified

No physical scanner is available. The following remain **unverified** and must
be reported as such (per the issue scope):

- the actual `libusb` claim vs. `usblp` kernel race on a real MFP;
- whether a specific device's scanner exposes an eSCL function that `ipp-usb`
  will try to serve;
- SANE backend selection (`auto`/`airscan`/`raw`) once `ipp-usb` is running;
- which quirk (`disable-scan` vs `blacklist`) a given device needs to release
  the scanner to SANE without also losing the printer.

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
   then `usbip attach`) rather than a hand-written resolver.

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
