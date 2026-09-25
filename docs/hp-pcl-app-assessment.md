# HP Printer Application (native PAPPL PCL) vs. HPLIP Printer Application

Evidence checked **2026-09-25** for [common#1232](https://github.com/projectbluefin/common/issues/1232),
part of the printer/scanner epic [common#1209](https://github.com/projectbluefin/common/issues/1209).
This is a source-and-documentation assessment, not a support announcement. No
image was built or run for this assessment, and no physical HP printer was
available; the coverage comparison below is derived from each project's own
README, man page, and source, not from measured hardware output.

## Question

Does [michaelrsweet/hp-printer-app](https://github.com/michaelrsweet/hp-printer-app)
(a native PAPPL example application for HP PCL printers) provide printer
coverage that the planned [OpenPrinting/hplip-printer-app](https://github.com/OpenPrinting/hplip-printer-app)
appliance (tracked by [common#1209](https://github.com/projectbluefin/common/issues/1209)
and [hplip-printer-app#1](https://github.com/projectbluefin/hplip-printer-app/issues/1))
does not already provide, such that a second, redundant HP-focused OCI image
would be justified?

## Coverage mapping

| Axis | `hp-printer-app` (native PAPPL PCL) | `hplip-printer-app` (HPLIP-backed) |
|---|---|---|
| Driver model | A handful of **generic** drivers keyed to PCL dialect, not per-model: `hp_deskjet`, `hp_laserjet` (PCL 5), `hp_generic` (PCL 5, any vendor), `hp_generic6`/`hp_generic6c` (PCL 6, experimental, build-time opt-in). | A **per-model PPD/driver database** inherited wholesale from HPLIP's `hpcups`/`hpps` filters and the `hp`/`hp-probe` backend — "most USB and network printers from HP and Apollo," matching whatever model list HP ships in HPLIP. |
| PCL 6 | Explicitly **experimental**; upstream warns a subset of PCL6-labeled printers only implement black-and-white output even when advertised as color, and the `--enable-experimental` build flag that turns PCL 6 on was itself still buggy until v1.3.1. | Not driven by PCL dialect at all — HPLIP selects the correct filter/PPD per model, so PCL 5 vs. PCL 6 capability differences are absorbed into the per-model definition rather than exposed as a build-time experimental flag. |
| Non-HP PCL5 printers | Covers third-party PCL5-compatible lasers (Canon, IBM, Lexmark, Kyocera, Ricoh, Xerox) through the same generic `hp_generic` driver — this is the one place it has breadth HPLIP does not, but it is out of scope for an "HP printer" appliance and overlaps instead with the generic PCL raster path already inventoried under the Ghostscript Printer Application ([common#1221](https://github.com/projectbluefin/common/pull/1221)). | HP/Apollo hardware only; does not claim third-party PCL coverage. |
| Proprietary plugin / firmware | Not applicable — has no concept of HP's proprietary plugin because it never touches HPLIP. | Some HP lasers require HP's proprietary plugin (firmware-on-boot or proprietary print data) which is **not** open source and is **not** auto-installed by the app today; the app's own docs list plugin auto-download/install as a "To Do" item. Bluefin's existing HPLIP OCI plan must not imply plugin support is solved. |
| Scanning | Not applicable — print-only, no scan support anywhere in the project. | Also print-only today; scanning is HPLIP's own "To Do," tracked separately by [common#1220](https://github.com/projectbluefin/common/pull/1220) / [common#1218](https://github.com/projectbluefin/common/pull/1218) — neither app should be represented as covering scan. |
| Maintenance | Apache-2.0, single maintainer (Michael R Sweet), latest tag `v1.3.1`; framed by upstream as an **example/reference application for PAPPL**, not a product; slow but continuing cadence (v1.2.0 → v1.3.0 → v1.3.1). | Apache-2.0 with a GPLv2/LGPLv2 linking exception (needed for CUPS/cups-filters compatibility); derives from HPLIP, which HP itself continues to update with new models; the `hplip-printer-app` wrapper is an actively evolving OpenPrinting project accepting outside contributions. |
| License permits redistribution | Yes — Apache-2.0, no bundled proprietary component. Safe to build and ship a source-built image if there were a coverage reason to. | Yes for the open-source HPLIP driver stack (Apache-2.0 wrapper + HPLIP's own license); the **proprietary plugin is a separate, non-redistributable component** that must never be bundled into a published OCI image regardless of which app ships it. |

## Findings

1. **No unique HP-model coverage.** For genuine HP hardware, `hplip-printer-app`
   already provides broader, HP-maintained, per-model driver coverage via
   HPLIP's own PPD/filter database. `hp-printer-app`'s generic `hp_laserjet`/
   `hp_deskjet`/`hp_generic*` drivers are a coarser fallback, not an
   enhancement, and its own upstream frames the project as an example PAPPL
   application rather than a maintained HP driver database.
2. **PCL 6 is not a differentiator.** `hp-printer-app`'s PCL 6 path is
   explicitly experimental and opt-in at build time; it does not close a gap
   HPLIP leaves open, since HPLIP resolves PCL-generation choice per model
   rather than exposing it as an all-or-nothing dialect switch.
3. **The one real breadth advantage — third-party PCL5-compatible lasers
   (Canon/Lexmark/Kyocera/Ricoh/Xerox/IBM) — is out of scope for an "HP
   printer" appliance.** That overlaps the generic-PCL-raster territory
   already being inventoried for the Ghostscript Printer Application
   (common#1221) and Foomatic/legacy filters, and should be tracked there
   if it is pursued at all, not duplicated into an HP-branded image.
4. **License and maintenance both permit a build if one were needed** —
   Apache-2.0, no proprietary component, and upstream is still tagging
   releases — but permission to build is not the same as a coverage reason
   to build.
5. Per the acceptance criteria in common#1232, since no unique coverage is
   proven for HP hardware, this assessment **does not** produce a rootless
   FSDK OCI prototype for `hp-printer-app`. HP printer driver needs route to
   the existing/planned HPLIP Printer Application work
   ([common#1209](https://github.com/projectbluefin/common/issues/1209),
   [hplip-printer-app#1](https://github.com/projectbluefin/hplip-printer-app/issues/1)).
   That image must continue to be honest that it does not bundle HP's
   proprietary plugin and does not yet scan.

## Decision

**Do not build a separate `hp-printer-app` OCI image.** Treat HP/Apollo
printer coverage as owned entirely by the HPLIP Printer Application track.
If a future need surfaces for driverless PCL support on non-HP PCL5-only
laser printers with no other driver path, scope that as a Ghostscript/legacy
PCL raster follow-on (see common#1221's Ghostscript row), not as an
HP-branded appliance, and do not imply HP proprietary plugin support from
either app.

## Sources

- [michaelrsweet/hp-printer-app README](https://github.com/michaelrsweet/hp-printer-app/blob/master/README.md)
- [hp-printer-app.1 man page](https://github.com/michaelrsweet/hp-printer-app/blob/master/hp-printer-app.1)
- [hp-printer-app releases](https://github.com/michaelrsweet/hp-printer-app/releases)
- [hp-printer-app.c source header](https://github.com/michaelrsweet/hp-printer-app/blob/master/hp-printer-app.c)
- [HP Printer Application docs (msweet.org)](https://www.msweet.org/hp-printer-app/hp-printer-app.html)
- [OpenPrinting/hplip-printer-app README](https://github.com/OpenPrinting/hplip-printer-app/blob/master/README.md)
- [hplip-printer-app.1 man page](https://github.com/OpenPrinting/hplip-printer-app/blob/master/hplip-printer-app.1)
- [hplip-printer-app.c source header](https://github.com/OpenPrinting/hplip-printer-app/blob/master/hplip-printer-app.c)
- [common#1221 printer/scanner source inventory (open PR)](https://github.com/projectbluefin/common/pull/1221)
