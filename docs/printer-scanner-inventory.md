# Printer and scanner source inventory

Evidence checked **2026-09-25** for [common#1211](https://github.com/projectbluefin/common/issues/1211),
part of [common#1210](https://github.com/projectbluefin/common/issues/1210).
This is a source inventory and a set of proposed OCI experiments, not a support
announcement. No application was built or run for this inventory. No physical
scanner was available; printing, scanning, USB ownership, hotplug, ADF, duplex,
and device-specific output quality remain **unverified**.

## How to read the inventory

The discovery scope is the [OpenPrinting repositories](https://github.com/OpenPrinting?tab=repositories)
and [Michael Sweet's repositories](https://github.com/michaelrsweet?tab=repositories),
plus the scanner dependencies named by the parent issue. “Runnable” means source
and upstream build/run documentation exist, not that Bluefin has validated an OCI
image. A release, a development snapshot, and a proof of concept are different
packaging inputs. A recent commit is evidence of activity, not a support promise.

Maintainer names below identify the upstream project or documented author to
contact; they do not imply a commitment to maintain Bluefin images. Licenses are
for the named source project. Bundled filters, firmware, PPDs and libraries need
their own inventory before redistribution; a wrapper's license does not cover
its entire image.

## Printer applications and driver families

For the four retrofit applications, upstream documents runnable source and Snap
packaging but exposes no GitHub release or tag at this check. Commit links record
the inspected snapshot. Their README legal sections describe Apache-2.0 with a
GPL/LGPL linking exception; retain each project's LICENSE and NOTICE.

| Family / source and ownership | Release or maintenance evidence | Source license and boundary | Proposed bounded OCI slice |
|---|---|---|---|
| [Ghostscript Printer Application](https://github.com/OpenPrinting/ghostscript-printer-app#readme) — OpenPrinting / Till Kamppeter | Runnable retrofit app; [52decb43cea5](https://github.com/OpenPrinting/ghostscript-printer-app/commit/52decb43cea5), 2026-09-14. Its README explicitly says many underlying drivers are unmaintained. | [Apache-2.0 + exception](https://github.com/OpenPrinting/ghostscript-printer-app/blob/master/LICENSE) for wrapper; Ghostscript and bundled filters have separate terms. | One print-only image with PAPPL, pappl-retrofit and Ghostscript, initially exercising one PCL raster path into a captured output file. Add the legacy filters only after a per-component license/input audit. |
| [Gutenprint Printer Application](https://github.com/OpenPrinting/gutenprint-printer-app#readme) — OpenPrinting / Till Kamppeter; driver from Gutenprint | Runnable retrofit app; [8712a9f1f1a4](https://github.com/OpenPrinting/gutenprint-printer-app/commit/8712a9f1f1a4), 2026-01-09. Upstream identifies Gutenprint as actively maintained. | [Apache-2.0 + exception](https://github.com/OpenPrinting/gutenprint-printer-app/blob/master/LICENSE) for wrapper; Gutenprint and rendering dependencies separate. | One Gutenprint image generating its PPDs and rendering a fixed raster job for one inkjet model to a file. Defer USB dye-sublimation backend verification to hardware. |
| [HPLIP Printer Application](https://github.com/OpenPrinting/hplip-printer-app#readme) — OpenPrinting / Till Kamppeter; HPLIP from HP | Runnable print app; [b3fc7f3a83dd](https://github.com/OpenPrinting/hplip-printer-app/commit/b3fc7f3a83dd), 2026-01-09. Scanning is in its TODO section. | [Apache-2.0 + exception](https://github.com/OpenPrinting/hplip-printer-app/blob/master/LICENSE) for wrapper; HPLIP components and proprietary plugin/firmware are separate. | One print-only hpcups image for a plugin-free model, with rendered output captured. Do not bundle the proprietary plugin or advertise an eSCL scanner. |
| [PostScript Printer Application](https://github.com/OpenPrinting/ps-printer-app#readme) — OpenPrinting / Till Kamppeter | Runnable retrofit app; [e54d07c8b27f](https://github.com/OpenPrinting/ps-printer-app/commit/e54d07c8b27f), 2026-01-09. | [Apache-2.0 + exception](https://github.com/OpenPrinting/ps-printer-app/blob/master/LICENSE); manufacturer PPD terms vary. | One PostScript image using a redistributable generic PPD, testing IPP job acceptance and captured PostScript output. |
| [HP Printer Application](https://github.com/michaelrsweet/hp-printer-app#readme) — Michael R Sweet | Active release [v1.3.1](https://github.com/michaelrsweet/hp-printer-app/releases/tag/v1.3.1), 2026-06-08. Native PCL implementation, distinct from HPLIP Printer Application; PCL 6 support is experimental. | [Apache-2.0](https://github.com/michaelrsweet/hp-printer-app/blob/master/LICENSE). | One release-pinned PCL 5 image with PAPPL; submit a raster fixture and capture PCL output. Exclude experimental PCL 6 from the initial claim. |
| [LPrint](https://github.com/michaelrsweet/lprint#readme) — Michael R Sweet | Active release [v1.4.0](https://github.com/michaelrsweet/lprint/releases/tag/v1.4.0), 2026-06-08. Upstream warns against packaging current master. | [Apache-2.0](https://github.com/michaelrsweet/lprint/blob/master/LICENSE). | One release-pinned label/receipt image, beginning with a ZPL output fixture. Keep experimental Brother PT/QL and CPCL drivers out of the initial support scope. |
| [Braille Printer Application](https://github.com/OpenPrinting/braille-printer-app#readme) — OpenPrinting; Arun Patwa, Samuel Thibault and contributors named in README | Development/prototype source: [272d5471a980](https://github.com/OpenPrinting/braille-printer-app/commit/272d5471a980), 2024-12-09; no release/tag found. README describes both an application and classic CUPS packaging, so stable application readiness is unconfirmed. | [LICENSE](https://github.com/OpenPrinting/braille-printer-app/blob/master/LICENSE), [COPYING](https://github.com/OpenPrinting/braille-printer-app/blob/master/COPYING), NOTICE and individual filters must be checked together; README identifies Apache-2.0 application code. | Research-only build and BRF conversion fixture; establish the working application entry point before proposing a maintained embosser image. |

The Ghostscript bundle includes additional families (foo2zjs, SpliX, brlaser,
pnm2ppa, pxljr, c2esp, label and other legacy filters); they are not all actively
maintained just because the wrapper is. [foo2zjs](https://github.com/OpenPrinting/foo2zjs#readme)
has a [20260206 release](https://github.com/OpenPrinting/foo2zjs/releases/tag/20260206)
and GPL-2.0-or-later source. [SpliX](https://github.com/OpenPrinting/splix#readme)
has a [2.0.2 release](https://github.com/OpenPrinting/splix/releases/tag/2.0.2)
but explicitly describes development as discontinued (GPL-2.0 source).
[legacy-drivers](https://github.com/OpenPrinting/legacy-drivers#readme) is a
preservation collection with per-directory licenses, not a maintained new driver
family. Keep these within separately audited Ghostscript image extensions rather
than promising one supported image per abandoned driver.

[PAPPL](https://github.com/michaelrsweet/pappl#readme) (Michael R Sweet,
[Apache-2.0 with exception](https://github.com/michaelrsweet/pappl/blob/master/LICENSE),
[v1.4.12](https://github.com/michaelrsweet/pappl/releases/tag/v1.4.12), 2026-08-20)
and [pappl-retrofit](https://github.com/OpenPrinting/pappl-retrofit#readme)
(OpenPrinting / Till Kamppeter,
[Apache-2.0 with exception](https://github.com/OpenPrinting/pappl-retrofit/blob/master/LICENSE))
are framework libraries, not additional hardware driver families. The latter's
latest GitHub release is [1.0b2](https://github.com/OpenPrinting/pappl-retrofit/releases/tag/1.0b2)
from 2023-02-07 (a beta by name, despite GitHub's non-prerelease flag), with
[development continuing in 2026](https://github.com/OpenPrinting/pappl-retrofit/commit/49ad525a3715).
Pin and validate these dependencies independently of each app.

## Scanner backends, USB bridge, and demos

| Project / maintainer | Runnable scope and evidence | Source license | Proposed bounded OCI slice / limit |
|---|---|---|---|
| [SANE backends](https://gitlab.com/sane-project/backends) — SANE project and per-backend maintainers in [AUTHORS](https://gitlab.com/sane-project/backends/-/blob/1.4.0/AUTHORS) | Released [1.4.0](https://gitlab.com/sane-project/backends/-/tags/1.4.0), 2025-05-25 UTC. Provides actual scanner drivers, scanimage client and saned server; not a PAPPL scanner application. | [LICENSE](https://gitlab.com/sane-project/backends/-/blob/1.4.0/LICENSE): GPL frontend programs; most backend libraries have a linking exception, but individual source headers override the summary. | One SANE diagnostic image with scanimage and the synthetic test backend first; validate generated image dimensions. Extend it with one selected backend and explicit device access per hardware experiment; do not equate the entire backend collection with maintained model support. |
| [sane-airscan](https://github.com/alexpevzner/sane-airscan#readme) — Alexander Pevzner and contributors | Released source tag [0.99.38](https://github.com/alexpevzner/sane-airscan/tree/0.99.38); runnable SANE backend for eSCL and WSD. Network client, not a server for legacy scanners. | [GPL-2.0-or-later with linking exception](https://github.com/alexpevzner/sane-airscan/blob/master/LICENSE). | One driverless scanning client image with scanimage, sane-airscan and discovery dependencies; scan against a virtual eSCL fixture. WSD needs its own fixture coverage. |
| [ipp-usb](https://github.com/OpenPrinting/ipp-usb#readme) — OpenPrinting / Alexander Pevzner | Released source tag [0.9.34](https://github.com/OpenPrinting/ipp-usb/tree/0.9.34); runnable daemon bridging device-provided IPP/eSCL over USB. It does not supply a legacy scanner driver. | [BSD-2-Clause](https://github.com/OpenPrinting/ipp-usb/blob/master/LICENSE). | One USB bridge experiment paired with the scanning client image; first exercise a virtual USB/IP MFP. Physical USB access, discovery across container networking, hotplug and ownership coexistence need separate validation. |
| [go-mfp](https://github.com/OpenPrinting/go-mfp#readme) — OpenPrinting / Alexander Pevzner | Active work in progress, [e8bcc92c95bb](https://github.com/OpenPrinting/go-mfp/commit/e8bcc92c95bb), 2026-09-24; no release/tag. Runnable mfp-virtual fixture plus discovery/proxy tools; upstream calls protocol implementations partially complete. | [BSD-2-Clause](https://github.com/OpenPrinting/go-mfp/blob/master/LICENSE). | One commit-pinned virtual MFP test image to return synthetic scan data. Network tests first; USB/IP mode is a separate kernel-dependent test lane. This is a fixture, not evidence of real scanner compatibility. |
| [scanApp](https://github.com/Kappuccino111/scanApp#readme) — Kappuccino111 | Proof of concept, [496af65f4648](https://github.com/Kappuccino111/scanApp/commit/496af65f4648), 2026-06-24; no release/tag. SANE-to-eSCL demo depending on the author's PAPPL scanning-v2 fork. README reports upstream platen testing, missing PDF output and incomplete ADF support. | No repository-level license file or declared license found in the inspected tree. Do not infer permission from PAPPL's license. | No redistributable image proposed until licensing is clarified. Track as a research demo; upstream's hardware report is not a Bluefin test result. |
| PAPPL scanning API / future SANE retrofit application | [PAPPL PR #425](https://github.com/michaelrsweet/pappl/pull/425) is **open and unmerged** at this check. Michael Sweet limits his intended support to printers/MFPs. No released SANE-to-PAPPL scanner wrapper was found in the inspected pappl-retrofit source. | PAPPL's license covers its own code, not an absent wrapper or the scanApp demo. | Upstream tracking only. Do not publish a placeholder Scanner Application or claim HPLIP Printer Application already scans. |

For legacy hardware, SANE's [backend descriptions](https://gitlab.com/sane-project/backends/-/tree/1.4.0/doc/descriptions)
and AUTHORS are the model/maintainer inventory, rather than vendor names alone.
Concrete follow-on slices can reuse the SANE diagnostic image:

| Backend family | Named maintainers in SANE 1.4.0 AUTHORS | Single bounded extension |
|---|---|---|
| genesys | Gerhard Jaeger, Povilas Kanapickas | Enable genesys for one listed USB model, record firmware needs, then require a physical platen test. |
| epson2 | Wolfram Sang | Enable epson2 for one supported Epson device and one documented transport. |
| fujitsu / epjitsu / canon_dr | m. allan noah | Select one backend/model per experiment; defer ADF and duplex claims until physical tests. |
| escl | Thierry HUCHARD | Exercise the SANE eSCL backend against the virtual fixture as an alternative to sane-airscan, not a second legacy scanner server. |

These are bounded examples, not an assertion that every historical SANE backend
is maintained. HP's HPLIP scanning path also needs an independent hpaio/backend
and plugin audit; the print-only HPLIP wrapper above supplies no such evidence.

## Acceptance boundary for follow-on work

Each image proposal still needs a pinned source/dependency manifest, complete
license inventory, executable startup test and a protocol/output assertion.
For print images, use a controlled output sink; for scanner images, distinguish
synthetic data from a physical scan. Record whether discovery was tested or an
explicit endpoint was used. No host networking, privileged execution, USB device
mounting, or production packaging policy is selected by this inventory.

The first scanner slice can be the go-mfp fixture paired with the sane-airscan
client. A SANE test-backend image can independently validate the client toolchain.
Neither waits on PAPPL scanning. A production PAPPL scanner application does wait
on upstream API work and a maintained, licensed wrapper. Device ownership between
ipp-usb and legacy USB backends remains a separate experiment under the parent
issue, not a readiness claim here.
