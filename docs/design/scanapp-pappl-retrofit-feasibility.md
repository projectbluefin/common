# Feasibility Report — scanApp Proof of Concept and pappl-retrofit Scanning

**Status:** Investigation complete — no production work authorized
**Filed:** [common#1216](https://github.com/projectbluefin/common/issues/1216)
**Parent:** [common#1210](https://github.com/projectbluefin/common/issues/1210) — Epic: OCI scanner
applications and legacy scanner driver inventory
**Scope:** No physical scanner available in this evaluation. Any statement about
behavior with real hardware is explicitly marked unverified.

## Summary

Neither [Kappuccino111/scanApp](https://github.com/Kappuccino111/scanApp) nor
[OpenPrinting/pappl-retrofit](https://github.com/OpenPrinting/pappl-retrofit) is
ready to be packaged as a production OCI Scanner Application today. `scanApp` has
no license, and its build depends on an unmerged, personally-forked branch of
PAPPL rather than any upstream release. `pappl-retrofit` is a real, Apache-2.0
licensed, buildable project, but it implements printing only — it carries no
scanning/eSCL code at all. Scanning is being developed as a separate, still
unmerged effort against PAPPL core. This closes the acceptance criteria for
common#1216 with explicit blockers; it does not produce a runnable image.

## scanApp — license and ownership

- Repository: `Kappuccino111/scanApp`, owned by Akarshan Kapoor (GitHub handle
  `Kappuccino111`), a two-time OpenPrinting Google Summer of Code contributor
  (GSoC 2023 "Sand-Boxed Scanner Application Framework", GSoC 2024 "PAPPL Scan
  API Bridging"). It is an original repository, not a fork of another project
  (`fork: false` per the GitHub API).
- **License: none.** `git clone` of the repository contains no `LICENSE`,
  `COPYING`, or `NOTICE` file, and the GitHub API confirms it directly:
  `"license": null`. Under GitHub's terms of service, a public repository with
  no license grants only the right to view and fork the code on GitHub — not to
  copy, modify, or redistribute it, including inside an OCI image. This alone
  blocks any redistribution of scanApp source or binaries in a Bluefin image or
  repo.
- README explicitly frames it as a personal proof of concept: "intended as a
  proof of concept and a reference for building production Scanner
  Applications, likely through pappl-retrofit once that work is ready" — the
  author does not represent it as production-ready or license-cleared for
  downstream packaging.

## scanApp — buildability

- Build is a plain `make` using `pkg-config` against `pappl2`, `sane-backends`,
  and `libjpeg`.
- The `pappl2` dependency is **not upstream PAPPL**. The README requires
  `https://github.com/Kappuccino111/pappl/tree/scanning-v2` — the
  author's personal fork/branch, confirmed to exist via
  `git ls-remote` (`refs/heads/scanning`, `refs/heads/scanning-v2`,
  `refs/heads/old-scanning`), none of which are merged into
  `michaelrsweet/pappl` (upstream PAPPL). There is no tagged/pinned release of
  this fork; building against it means tracking a moving personal branch with
  no upstream review or stability guarantee.
- Given the license and fork-dependency issues above, this evaluation did not
  attempt to vendor and build scanApp against the fork. Doing so would mean
  shipping unlicensed code built against an unreviewed upstream branch — both
  independently disqualifying for a production image regardless of build
  success.

## pappl-retrofit — license and scanning scope

- Repository: `OpenPrinting/pappl-retrofit`, licensed **Apache License 2.0**
  (with an exception permitting linking GPL2/LGPL2 CUPS filter code),
  copyright Till Kamppeter. Confirmed via the repo's own `LICENSE` and `NOTICE`
  files. This license is compatible with redistribution in an OCI image.
- Confirmed via source inspection: `pappl-retrofit/pappl-retrofit.c` (the
  library's core) contains **zero references to eSCL or scanning** —
  `grep -ci escl pappl-retrofit.c` returns 0. pappl-retrofit converts classic
  CUPS PPD/filter/backend printer drivers into driverless-IPP Printer
  Applications; it has no scanner-side functionality.
- Scanning support is a separate, parallel effort happening directly against
  PAPPL core (`michaelrsweet/pappl`), primarily through GSoC work:
  - [pappl#133](https://github.com/michaelrsweet/pappl/issues/133) is the
    open tracking issue for eSCL/scanning support in PAPPL; nothing from it
    has merged.
  - The GSoC 2024 ("PAPPL Scan API Bridging") effort scanApp exercises went
    through PR [pappl#249](https://github.com/michaelrsweet/pappl/pull/249)
    and later PR [pappl#371](https://github.com/michaelrsweet/pappl/pull/371),
    both of which are **closed**, not merged. The current, still-open scanning
    API PR is [pappl#425](https://github.com/michaelrsweet/pappl/pull/425).
  - common#1213 tracks `michaelrsweet/pappl#425` directly and is the right
    place to watch for a merged/tagged scanning API landing in PAPPL.
- **Conclusion:** there is currently no scanning-capable release of either
  PAPPL or pappl-retrofit to retrofit against. "pappl-retrofit scanning" does
  not exist as a shippable feature yet.

## Synthetic eSCL scan output — feasibility without physical hardware

[OpenPrinting/go-mfp](https://github.com/OpenPrinting/go-mfp) provides a
software-only virtual MFP that can serve real eSCL over HTTP without any
physical scanner:

- `modeling.Model` + `NewESCLServer` build an in-process eSCL HTTP server
  backed by an `abstract.VirtualScanner`, so a genuine eSCL `ScannerCapabilities`
  / `Scan` exchange can be captured and verified against a standard eSCL client
  (e.g. `scanimage` with the airscan backend) with no hardware involved.
- `mfp-virtual --usbip` goes further, emulating a full virtual USB MFP so the
  standard Linux print/scan stack (including `ipp-usb`) can enumerate and use
  it as if it were a real device.
- This evaluation did not stand up a working scanApp+PAPPL-fork+go-mfp
  integration end to end, because scanApp's license blocks packaging it at
  all — running the unlicensed binary locally to produce a demo artifact would
  not change that blocker, and this repo does not vendor or build unlicensed
  third-party source even for a throwaway demo. go-mfp itself is confirmed
  usable as the synthetic eSCL fixture once a licensed, buildable scanning
  server exists to test against (tracked by common#1213/common#1215's sibling
  investigations).

## Explicit blockers before any production image or repo is authorized

1. **License** — scanApp ships no license. It cannot be vendored, built into,
   or redistributed as part of any Bluefin OCI image or repo unless the
   upstream author adds an OSI-approved license, or the functionality is
   reimplemented independently against licensed dependencies.
2. **Upstream dependency stability** — scanApp requires an unmerged personal
   fork/branch of PAPPL (`Kappuccino111/pappl@scanning-v2`) with no tag, no
   release, and no upstream review. There is nothing pinned or stable to build
   against.
3. **No scanning support in pappl-retrofit** — the actual OpenPrinting
   `pappl-retrofit` project (Apache-2.0, buildable, real) has no scanning code.
   Framing this as "pappl-retrofit scanning" is inaccurate until PAPPL's own
   scanning API PR (`michaelrsweet/pappl#425`, tracked in common#1213) merges
   and pappl-retrofit is extended to use it.
4. **No hardware verification** — this evaluation had no physical MFP/scanner
   available; any claim about real-device behavior beyond go-mfp's simulated
   eSCL server is unverified and must stay unverified until hardware is
   available.

**Recommendation:** do not authorize a production Scanner Application image
based on scanApp or pappl-retrofit at this time. Continue tracking
`michaelrsweet/pappl#425` via common#1213; revisit this evaluation once PAPPL
ships a tagged release with scanning support and scanApp (or a successor) has
an OSI-approved license.
