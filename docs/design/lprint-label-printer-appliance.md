# Decision Record — LPrint as an FSDK OCI Label-Printer Appliance

**Status:** `OPEN` — pending maintainer decision (Design Gate, [`docs/skills/human-gates.md`](../skills/human-gates.md))
**Decision owner:** `@projectbluefin/maintainers` (fill in §8)
**Filed:** [common#1231](https://github.com/projectbluefin/common/issues/1231) (2026-08)
**Epic:** [common#1209](https://github.com/projectbluefin/common/issues/1209) — *OCI Printer Applications and scanner ecosystem*
**Siblings:** [common#1232](https://github.com/projectbluefin/common/issues/1232) (native PAPPL HP PCL app), [common#1233](https://github.com/projectbluefin/common/issues/1233) (Braille Printer Application maturity), [ghostscript-printer-app](https://github.com/projectbluefin/ghostscript-printer-app) (core raster/legacy drivers)
**Scope question:** New standalone FSDK image, or embed label drivers into an existing printer-app image?

---

## 1. The decision being requested

One explicit maintainer decision: **whether Bluefin-family images ship a
standalone LPrint-based FSDK OCI "label-printer appliance", or whether label
printing is handled by embedding label drivers into an existing printer-app
image (currently the Ghostscript app), or neither (defer).**

This record exists so the decision stops being deferred by review latency.
Until §8 is filled in, the standing position is **no change**: no dedicated
LPrint image ships, and label-printer support stays at whatever the owning
printer-app repos currently publish.

The evaluation in §2 is evidence, not the decision. The decision in §3 is a
product/build architecture choice. The two must not be conflated: a strong
device-coverage case for LPrint does not by itself decide *where the code
lives*.

## 2. LPrint v1.4.0 evaluation (the fact-finding)

Per the issue's explicit instruction, a **released tag** is pinned and
verified — never a moving `master` snapshot.

| Attribute | Verified value | Source |
|---|---|---|
| Release pinned | `v1.4.0` — commit `39948c1957e50950dcdc3730cc54f06b745a4713` (latest published release) | [michaelrsweet/lprint releases](https://github.com/michaelrsweet/lprint/releases) |
| Source license | **Apache License 2.0 (`ASL 2.0`)** | `LICENSE` at tag, `lprint.spec` `License: ASL 2.0`, `configure.ac` "Licensed under Apache License v2.0" |
| Build dependency (ABI) | **PAPPL ≥ 1.2** (Printer Access Programming Library, M. R. Sweet / OpenPrinting) | `configure.ac` (`PKGCONFIG --exists pappl --atleast-version 1.2`) |
| Device / protocol drivers | `dymo`, `escpos`, `epl2`, `zpl`, `tspl`, `sii` (Seiko), `brother`, `cpcl` | source tree at tag |

Notable v1.4.0 changes relevant to the decision:

- **Added ESC/POS driver** — the headline feature of this release.
- **Added DYMO LabelWriter Twin Turbo driver** — directly overlaps the
  Ghostscript app's existing DYMO raster payload (see §5).
- Updated TSPL max label width to 105 mm; ZPL status-command auto-disable;
  DYMO margin fixes.

**License note (worth stating plainly).** LPrint switched from its historical
GPLv2 heritage to **Apache-2.0** as of this release. That is *more* permissive
than GPLv2 for embedding and does not introduce copyleft into a consuming
image — a positive for the "embed" option. The PAPPL dependency carries its
own license; verify PAPPL's current license text before shipping, since the
ABI link is a hard build requirement.

## 3. Options

| Option | Meaning | Consequences |
|---|---|---|
| **A — Standalone FSDK image** | A new `lprint-printer-app` OCI image, source-built from the immutable `v1.4.0` ref, published through the same `testing`→`stable` promotion, signatures, SBOM and provenance flow as the four core apps | Clean separation of label/receipt printing from generic raster; own version line; more images to build, sign, test and promote; new maintenance surface |
| **B — Embed label drivers** | Add LPrint-style label/receipt drivers (or a bundled `lprint` binary) into the existing Ghostscript printer-app image, layered on the current Dymo/raster payload | Fewer images to operate; label + generic printing under one service; risk of muddying the Ghostscript app's single-responsibility scope and inflating its build/test surface |
| **C — Defer / no image** | Keep the standing "no change" position; label printing stays with whatever the owning repos publish today; revisit only after the overlap analysis in §5 is lab-verified | No new surface; Dymo/ESC-POS/TSPL/EPL2/ZPL/Seiko coverage gap (vs. LPrint) remains unaddressed; issue closed as deferred with a documented rationale |

Option C is a legitimate outcome of this record, and so is "Option A now,
revisit Option B later" or vice-versa. The choice is not "merge something or
not" — it is *where, whether, and on what evidence*.

## 4. Proof-build plan (rootless, socket-sink, no physical hardware)

The epic states no printer hardware exists; physical output is reported as
**unverified**. The proof build reuses the existing Ghostscript
socket-sink print harness referenced by common#1209 rather than inventing a
new one.

1. **Image.** Source-build LPrint `v1.4.0` in a minimal image linking PAPPL
   ≥ 1.2. Pin the immutable tag (Option A) or the driver sources (Option B).
2. **Rootless start.** Launch the image rootless (Podman); LPrint serves its
   PAPPL web/IPP interface over loopback.
3. **Deterministic job.** Submit a synthetic, byte-stable label/receipt IPP
   job (`lprint-submit` / IPP `print-job`) to a device language the target
   driver owns (e.g. ESC/POS receipt, or EPL2/ZPL label). The job must be
   deterministic so output is byte-capturable.
4. **Socket sink.** Route the device backend to the existing socket sink and
   capture the emitted bytes; assert the job reaches **completed** state and
   the sink received the expected frame (media/darkness parameters applied).
5. **State survives restart.** Stop the container, restart rootless, re-read
   the queue/config from persistent state, and re-confirm media + darkness
   settings survived — the issue's explicit acceptance item.

This proves *rootless start, deterministic IPP processing, byte-capturing
output, and state persistence*. It does **not** prove physical printer
output.

## 5. Overlap with the current Ghostscript Dymo payload

The decision hinges partly on measured overlap, not assumption:

- The Ghostscript app already carries a **DYMO** payload (raster/PostScript
  path). v1.4.0 adds a native **DYMO** driver — **direct overlap** on DYMO.
- LPrint adds coverage the Ghostscript app does **not** provide: native
  **ESC/POS** (receipts), **TSPL**, **EPL2**, **ZPL**, **Seiko (SII)**,
  **Brother**, **CPCL** — device languages distinct from generic raster.
- **User-visible benefit** = adding those device languages + ESC/POS without
  a separate image (Option B), or a clean dedicated appliance (Option A).

This overlap must be **measured**, not asserted: verify each image's upstream
driver inventory and real print behavior against the socket sink before
claiming benefit, exactly as the epic requires. "Distinct from generic raster
filters" is the issue's framing — confirm it holds for the specific drivers
under consideration.

## 6. Supply-chain / pinning notes

- Pin the **immutable release tag** `v1.4.0` (commit `39948c1…`), not a
  branch or snapshot. The issue explicitly warns against packaging master.
- License is **Apache-2.0**; confirm PAPPL's license before shipping (ABI
  hard dependency, `>= 1.2`).
- Renovate pinning is appropriate only for the non-overlapping upstream ref;
  do not let an automation bot chase a moving target onto a snapshot.
- If Option A, the new image inherits the four-core-apps publication contract:
  immutable version tags, signed multiarch GHCR indexes, SPDX SBOM and SLSA
  provenance, `testing`→`stable` promotion, amd64 + arm64.

## 7. Gate checklist

The record may move from `OPEN` to a shipped state only when **all** of the
following are addressed:

- [ ] §8 filled in by a maintainer (option, scope, date).
- [ ] The overlap in §5 is measured against the socket-sink harness, not
      asserted.
- [ ] The proof build in §4 runs rootless and passes (byte-capture + state
      survives restart), documented with real output sizes — no fabricated
      hardware evidence.
- [ ] PAPPL license confirmed as compatible with the consuming image.
- [ ] If an image ships: amd64 + arm64 build, signatures, SBOM, provenance,
      and promotion are live (Option A), or the embed is covered by the host
      app's existing contract (Option B).
- [ ] ChairLift per-printer ownership semantics documented so exactly one
      service advertises a given physical printer (epic acceptance).
- [ ] The decision is recorded here and referenced from the downstream
      repo(s) affected, so it propagates to all variants.

## 8. Decision (maintainers fill in)

| Field | Value |
|---|---|
| **Decision** | _pending_ (Option A / B / C) |
| **Scope** | _pending_ (standalone image / embed / defer) |
| **Decider** | _pending_ |
| **Date** | _pending_ |
| **Image(s) affected** | _pending_ |
| **Proof-build evidence** | _pending_ (§4) |
| **Overlap finding** | _pending_ (§5) |
| **PAPPL license confirmation** | _pending_ (§6) |
| **Conditions / exit criteria** | _pending_ |

## References

- [common#1231](https://github.com/projectbluefin/common/issues/1231) — the issue this record evaluates
- [common#1209](https://github.com/projectbluefin/common/issues/1209) — epic; socket-sink harness, no-hardware gate, testing→stable contract
- [michaelrsweet/lprint@v1.4.0](https://github.com/michaelrsweet/lprint/tree/v1.4.0) — pinned release (ASL 2.0, PAPPL ≥ 1.2)
- [common#1232](https://github.com/projectbluefin/common/issues/1232) — native PAPPL HP PCL app (sibling evaluation)
- [`docs/skills/human-gates.md`](../skills/human-gates.md) — Design Gate for product-defining decisions
- [`docs/TESTING.md`](../TESTING.md) — testing contract for any shipped image's upgrade path
