# Printer application testing-to-stable promotion proof

Part of [release-promotion](../SKILL.md) — end-to-end evidence that the
printer-application `testing`→`stable` promotion fast-forwards protected
`stable` with `github.token` and that immutable version-tag publication stays
signature/SBOM/provenance verified. Tracked by
[common#1243](https://github.com/projectbluefin/common/issues/1243), a child of
the printer epic [common#1209](https://github.com/projectbluefin/common/issues/1209).

> Scope note: this covers **promotion** (moving a verified `testing` commit
> onto `stable`). Upstream source-code baseline and lag live in
> [printer-app-source-baseline.md](./printer-app-source-baseline.md)
> (tracked by common#1244). Do not duplicate that ownership here.

## How the promotion works

Each printer-app repo ships a `promote-stable.yml` triggered by
`workflow_dispatch` with a single required input, `testing_sha`:

1. Rebuild the exact `testing_sha` on **both** native architectures
   (x86_64 on `ubuntu-24.04`, aarch64 on `ubuntu-24.04-arm`) and smoke-test the
   OCI image to the socket-sink print harness.
2. On success, the `promote` job fast-forwards protected `stable` to
   `testing_sha` using the workflow's `github.token`, under a
   `*-stable-promotion` concurrency group (`cancel-in-progress: false`).
3. Immutable `<VERSION>[-arch]` tags publish signed multiarch GHCR indexes with
   SPDX SBOM + SLSA provenance, then release/verify by digest.

`on: {}` + `permissions: {}` at the top level mean the workflow only ever runs
by manual dispatch — there is no unreviewed push path.

## Empirical verification (as of 2026-09-25)

### Ghostscript — PROVEN end to end

`Promote verified Ghostscript testing commit to stable` (workflow id
`367206784`) ran once by `workflow_dispatch`:

- Run `36174096890`, `head_branch: testing`, `head_sha`
  `f667ca71158e81ee3baf5ecf035347f6e69aa162`, `2026-09-25T18:32:38Z`.
- Jobs — `Verify OCI image (x86_64)`, `Verify OCI image (aarch64)`, and
  `promote` — all **success**.
- `stable` HEAD is now `f667ca71158e81ee3baf5ecf035347f6e69aa162`, i.e. **exactly
  the tested `testing` commit**. The fast-forward landed, required status
  contexts were satisfied, and no force-push/deletion or review bypass occurred.

**Branch-protection finding:** the `github.token` push to protected `stable`
succeeded on the first try. No least-privilege GitHub App or reviewed-stable-PR
fallback was required. The protected push is not a blocker for this family.

### HPLIP, Gutenprint, PostScript — mechanism present, current HEAD not yet promoted

All three have an active `promote-stable.yml` (`workflow_dispatch`, same
design as Ghostscript), but their *current* `testing` HEADs have **not** been
run through it yet — `stable` trails `testing`:

| Fork | `stable` HEAD | `testing` HEAD | Lag |
|---|---|---|---|
| [`hplip-printer-app`](https://github.com/projectbluefin/hplip-printer-app) | `b483227` | `422f572` | testing 7 ahead |
| [`gutenprint-printer-app`](https://github.com/projectbluefin/gutenprint-printer-app) | `64bc5bc` | `70c64be` | testing 1 ahead |
| [`ps-printer-app`](https://github.com/projectbluefin/ps-printer-app) | `b1dfb3b` | `8ed0ee8` | testing 11 ahead |

### Immutable version-tag publication stays verified

Published printer images remain immutable and independently verifiable, per the
release audit [common#1217](https://github.com/projectbluefin/common/issues/1217):
`cosign verify` succeeds, `oras discover` finds an SPDX SBOM + SLSA provenance
bundle, `gh attestation verify` (keyless, post-2026-06-11) exits 0, and the
image resolves to an unauthenticated GHCR index. Nothing here mutates a
published tag.

## Hard holds — do not bypass

- **PostScript is under a security-review hold.**
  [ps-printer-app#27](https://github.com/projectbluefin/ps-printer-app/issues/27)
  ("Clear upstream security review before PS release") is **open**
  (`area/release`, `needs-decision`, `security`). Per common#1243 do **not**
  create a PS `v*` tag, promote PS `testing`→`stable`, or relax its tag hold
  until #27 clears.

## What remains (human action, not common code)

- **HPLIP + Gutenprint:** a human triggers `promote-stable.yml`
  (`workflow_dispatch`) with the current `testing` SHA for each safe-to-release
  family to record a live promotion the same way Ghostscript did. This is an
  operational action in those repos, not a change `common` can make.
- **PostScript:** blocked on ps-printer-app#27.

No `common` workflow or config change is required — the promotion lives in the
printer-app repos and is already proven for Ghostscript.
