# Braille Printer Application maturity assessment

Evidence checked **2026-09-29** for [common#1233](https://github.com/projectbluefin/common/issues/1233),
a child of the OCI printer epic [common#1209](https://github.com/projectbluefin/common/issues/1209).
This is a maturity assessment, not a support announcement and not an image proposal.
No application was built or run in this agent environment; the proof build is
specified below, not performed. There is no physical embosser anywhere in scope,
so "physical output" is not a claim here.

## How to read this

- **Runnable** means source and build documentation exist; it does not mean a
  Bluefin OCI image has validated it.
- A recent commit is evidence of activity, not a support promise.
- The upstream `cups-brf` backend already writes processed BRF to a file, so the
  proof build in acceptance item 2 needs no hardware stub — the file *is* the
  byte-capturing sink.
- The wrapper is Apache-2.0, but the BRF translation stack it pulls in is
  predominantly copyleft. A redistributable image must honor each license; the
  wrapper license does not cover the stack.

## 1. Source and maintenance — development/prototype, no release line

| Fact | Value |
|---|---|
| Upstream | [OpenPrinting/braille-printer-app](https://github.com/OpenPrinting/braille-printer-app) (Arun Patwa, Samuel Thibault and contributors per README) |
| Source ref inspected | `master` @ [272d5471a980](https://github.com/OpenPrinting/braille-printer-app/commit/272d5471a980), "Cope with cups-config removal with cups 2.5", 2024-12-09 |
| Branches | `master` only |
| Tags / releases | None. `GET /tags` returns empty; `GET /git/tags` returns 404. |
| README version banner | `v2.0b1` (dated 2020 in the header, 2022 in CHANGES) — a beta by name, unreleased |
| Commit cadence | 2022: 16, 2023: 7, 2024: 7 commits |
| Last merged PR | [#9](https://github.com/OpenPrinting/braille-printer-app/pull/9), 2024-07-26 |
| Last PR activity | [#10](https://github.com/OpenPrinting/braille-printer-app/pull/10) "Integration of braille-printer-app with cups-filters" **closed unmerged** |

Verdict: the tree moves, but slowly and now stalled (no PR merged since 2024-07,
no release since the v2.0b1 banner). It is a development/prototype CUPS driver
package, not a maintained release line. This matches the issue's own precondition:
"do not label it production-ready without a build and verified BRF pipeline."

## 2. Dependency closure — runnable stack, copyleft-heavy

The package builds with autotools against a CUPS stack. Required and optional
runtime tools are named in `INSTALL`; the build-time libraries come from
`configure.ac`.

| Dependency | Role in the BRF path | License | Maintenance evidence |
|---|---|---|---|
| [PAPPL](https://github.com/michaelrsweet/pappl) 1.1+ | Application framework for `brf-printer-app` | Apache-2.0 | Active — [michaelrsweet/pappl](https://github.com/michaelrsweet/pappl), pushed 2026-09 |
| CUPS 2.2.2+ (`libcups`) | IPP spooler the app talks to | GPL-2.0-or-later | System CUPS; maintained upstream |
| cups-filters 2.0+ (`libcupsfilters`) | MIME/conversion layer | GPL-2.0-or-later | OpenPrinting; required by `configure.ac` |
| [libmagic](https://www.darwinsys.com/file) | Input file-type detection | BSD-2-Clause | Maintained |
| [liblouis](https://github.com/liblouis/liblouis) | `file2brl`/`lou_translate` — text and backup Braille translation | LGPL-2.1 | Active — [v3.39.0](https://github.com/liblouis/liblouis/releases/tag/v3.39.0), 2026-09 |
| [liblouisutdml](https://github.com/liblouis/liblouisutdml) | `file2brl` unstructured Braille transcription (the "best Braille" path) | GPL-3.0-or-later | Active — pushed 2026-09 |
| Optional tools | Freedots + `lou_translate` (musicxml), ImageMagick (raster), poppler (PDF), inkscape (vector), lynx (HTML), antiword (DOC) | vary | Per-format; none required to compile |

**License boundary (barrier to note, not a blocker yet):** the wrapper and
PAPPL/libmagic are permissive (Apache-2.0 / BSD), but the translation stack that
makes the device useful is LGPL-2.1 (liblouis) **and** GPL-3.0 (liblouisutdml),
sitting on top of GPL-2.0 CUPS and cups-filters. A redistributable FSDK image can
carry this with attribution and LICENSE/NOTICE retention plus copyleft compliance,
but it is a distinct audit from the four maintained printer applications and has
not been performed. Bundled filters, table data, and PPDs carry their own terms.

## 3. Embosser backend — the `cups-brf` backend is itself the byte-capturing sink

`backend/cups-brf.c` is the embosser backend. Its behavior, read from source:

- CUPS invokes it after the filter runs; it switches to the job's user
  (`setuid`/`setgid` to `argv[2]`).
- It creates `$HOME/BRF/` and opens `$HOME/BRF/<jobtitle>.XXXXXX.brf` via
  `mkstemps`.
- It streams the processed job bytes from stdin into that file and returns
  `CUPS_BACKEND_OK`.

There is **no** IPP-to-physical-embosser path in this backend: the processed BRF
bytes land in a file. So acceptance item 2 — "convert a known text fixture to BRF
and submit a synthetic IPP job to a byte-capturing sink without physical embosser
hardware" — maps directly onto this code. The pipeline is:

```
IPP job (lp -d cups-brf fixture.txt)
  -> CUPS selects filter texttobrf (application/vnd.cups-brf)
       texttobrf uses liblouis/liblouisutdml to transcribe text to BRF
  -> cups-brf backend writes $HOME/BRF/<job>.XXXXXX.brf
  -> verify file exists, non-empty, valid 8-dot BRF
```

No hardware emulation or device stub is required; the `.brf` file is the sink.

## 4. Proof build (acceptance item 2) — specified, not performed

**Could not run in this agent environment.** This shell has no container runtime
(podman/buildah/docker absent), no compiler toolchain
(gcc/make/autoconf/automake/libtool/pkg-config absent), and no package manager
(dnf/yum/apt absent); it is a Flatpak SDK runtime. The build therefore belongs in
the factory/CI (Fedora + podman), consistent with how the other printer
applications smoke-tested to a socket sink.

Specified factory harness (to be run and reported, not asserted here):

1. Fedora-based image with dev packages for CUPS 2.x, libcupsfilters 2.x, pappl,
   libmagic, liblouis, liblouisutdml.
2. Clone `master` @ 272d5471a980; `./autogen.sh && ./configure --enable-braille && make`.
3. Start `cupsd`; register a `cups-brf` queue (the backend advertises a virtual
   "CUPS-BRF" IPP Everywhere service via its `devices` output).
4. Write a known text fixture; `lp -o raw -d cups-brf fixture.txt`.
5. Confirm `$HOME/BRF/*.brf` exists, is non-empty, and is valid BRF (8-dot dot
   grammar); record the captured byte count.
6. Report the captured bytes as the verified BRF pipeline output. No physical
   embosser involved.

## 5. Decision (acceptance item 3) — recommend deferral, not an FSDK image yet

**Do not build a standalone Braille FSDK image now.** The issue gates the decision
on "a maintained runnable upstream path and actual test evidence," and neither
exists unconditionally today:

- **Maintained runnable upstream path** — absent. No release tag, beta by name
  since 2020, no PR merged since 2024-07. The tree compiles against a current CUPS
  (2024-12 cups-config fix) but has no maintained release line.
- **Actual test evidence** — absent. The item-2 harness above is specified but not
  run; a verified BRF conversion must come from the factory, not a local draft.
- **License audit** — outstanding. The GPL-2.0/GPL-3.0/LGPL-2.1 translation stack
  under an Apache-2.0 wrapper needs an explicit redistribution audit before an
  image ships.

**Gates to unblock a Braille OCI appliance:**

1. A maintained runnable upstream path — at minimum a release tag or resumed
   merged-PR activity after 2024-12.
2. A passing item-2 proof build in the factory — real BRF conversion + byte
   capture, reported with a byte count.
3. A completed redistribution license audit for the copyleft translation stack.

For contrast, the four maintained printer applications sit on Apache-2.0 PAPPL
retrofits with active releases; `braille-printer-app` sits on a GPL-branded CUPS
driver package with no release line. That is a different maturity class, which is
why the recommendation is deferral until the three gates clear, not a parallel
image.

## Open decision for maintainers

Build a Braille embosser OCI appliance once the three gates above are met, or
defer the lane entirely. This assessment records the investigation and specifies
the proof build; it does not itself commit Bluefin to either outcome.

---

Closes the investigation half of [common#1233](https://github.com/projectbluefin/common/issues/1233)
(item 1: source/maintenance/dependency/license). Items 2 and 3 remain gated on the
factory proof build and a maintainer decision, as documented above.

— hive: backend=omp model=lab-worker/ornith
