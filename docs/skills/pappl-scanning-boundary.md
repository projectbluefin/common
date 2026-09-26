---
name: pappl-scanning-boundary
version: "0.1"
last_updated: "2026-09-25"
id: pappl-scanning-boundary
one_line_purpose: Track upstream PAPPL scanning API status and the ownership boundary between PAPPL, SANE, and eSCL scanner tooling.
entry_point: docs/skills/pappl-scanning-boundary.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [scanner, pappl, sane, escl, upstream, architecture]
description: >-
  Upstream tracking for michaelrsweet/pappl's scanning API (PR #425):
  merge/tag status, the maintainer-stated PAPPL vs. SANE ownership
  boundary, scanApp POC licensing posture, and the compatibility gate
  before a Scanner Application ships.
metadata:
  type: reference
---

# PAPPL scanning API — upstream status and ownership boundary

**Status**: Tracking only — no production Scanner Application should be proposed until the
acceptance criteria below are met.
**Tracking**: common#1213 (child of common#1210, "Epic: OCI scanner applications and legacy
scanner driver inventory", itself a child of common#1209)

## Why this document exists

`common` has no physical scanner hardware to verify against. Any claim about scanner support
in this repo must be sourced from upstream state, not assumed. This doc is the durable record
of that upstream state so agents and maintainers do not re-derive it from scratch, and do not
accidentally ship an image that implies scanning support PAPPL does not yet provide.

Do not claim printer applications built on PAPPL already implement scanning. They do not, as
of this writing.

## Upstream evidence

- Investigative PR: <https://github.com/michaelrsweet/pappl/pull/425>
- Design discussion: <https://github.com/michaelrsweet/pappl/discussions/424>
- Related upstream issues: [#130](https://github.com/michaelrsweet/pappl/issues/130),
  [#132](https://github.com/michaelrsweet/pappl/issues/132),
  [#133](https://github.com/michaelrsweet/pappl/issues/133),
  [#134](https://github.com/michaelrsweet/pappl/issues/134)
- Prior closed attempts: [#249](https://github.com/michaelrsweet/pappl/pull/249),
  [#349](https://github.com/michaelrsweet/pappl/pull/349),
  [#371](https://github.com/michaelrsweet/pappl/pull/371)
- Third-party proof of concept: <https://github.com/Kappuccino111/scanApp>

## Merge/tag status (checked 2026-09-25)

- PR #425 is **open**, not merged, not tagged into any PAPPL release.
- No PAPPL release currently ships a scanning API.
- Maintainer Michael Sweet has stated PAPPL 2.1 is the earliest realistic target, and that
  target is not committed — it depends on the PR being reworked to his requested design.

## The ownership boundary (maintainer-stated)

This is the load-bearing fact for any downstream decision:

> "PAPPL is for Printer Applications." — Michael Sweet, on discussion #424 / PR #425

Sweet has explicitly scoped PAPPL's scanning support to **multifunction printers**, not
standalone scanners, and has pushed back on designs that treat scanning as a general,
separate subsystem:

- Scanning must integrate as callbacks on the existing printer driver data structure
  (`pappl_pr_driver_data_t`), with scan jobs coexisting with print jobs on the same printer
  object, and eSCL endpoints exposed through resource callbacks — not a standalone scan
  service bolted alongside PAPPL.
- Standalone scanner support is explicitly **out of scope for PAPPL** because SANE already
  serves that case. Contributor pushback (tillkamppeter) arguing for broader eSCL-based
  scanner-application support did not change this position.
- Kappuccino111 (PR #425 author) acknowledged the requested restructuring (~2026-07-20) and
  was reworking the PR toward the callback-based design as of the last available upstream
  activity.

**Consequence for this repo**: a PAPPL-based Printer Application in this factory's image set
can, at most, eventually gain scan support for genuine multifunction printer hardware once
PR #425 lands in that form. A general-purpose, standalone Scanner Application is **not**
PAPPL's problem to solve upstream — that path runs through SANE / `ipp-usb` / eSCL bridging
tooling instead (see common#1210 for the fuller inventory of that space).

## Licensing and support posture of the proof of concept

`Kappuccino111/scanApp` is a personal proof-of-concept repository, not an upstream PAPPL
deliverable:

- It is not maintained by Michael Sweet or under the `michaelrsweet` org.
- It has no stated support commitment, release cadence, or security response process.
- Its license and packaging maturity have not been reviewed by this project. Do not vendor,
  package, or ship it in a production image without a separate licensing/security review
  captured as its own issue.

## Compatibility prototype gate

Per the parent epic (common#1210) and this issue's acceptance criteria, a production Scanner
Application image must not be proposed until all of the following are recorded, ideally by
updating this document with dated entries:

- [ ] PR #425 (or its successor) is merged into a tagged PAPPL release.
- [ ] The merged API's scope (multifunction-printer-only vs. broader) matches what a proposed
      image actually needs.
- [ ] A licensing review of whatever scanning-capable code is vendored (PAPPL itself is
      Apache-2.0; any third-party bridge code, including `scanApp` if still relevant, needs
      its own check).
- [ ] A compatibility prototype has been built and run against at least one real eSCL/SANE
      device or a virtual MFP fixture (e.g. `OpenPrinting/go-mfp`), with results recorded.

No hardware is available in this repo's CI to validate scanner behavior. Any hardware claim
made against this doc must be marked unverified until a contributor with real hardware files
a report.

## Related tracking

- Parent epic: common#1210
- Grandparent epic: common#1209
- SANE backends (working, separate from PAPPL): <https://gitlab.com/sane-project/backends>
- USB IPP/eSCL bridge (separate from PAPPL): <https://github.com/OpenPrinting/ipp-usb>
- Virtual MFP fixture for compatibility testing: <https://github.com/OpenPrinting/go-mfp>

## Revisit trigger

Re-check upstream state (PR #425 status, discussion #424) whenever:

- This issue is reopened or referenced by a new scanner-related issue.
- Someone proposes a Scanner Application or scanning feature in a Printer Application image.
- A PAPPL release with a version >= 2.1 ships.
