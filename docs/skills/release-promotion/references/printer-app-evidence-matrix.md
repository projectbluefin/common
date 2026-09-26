# Printer application release-contract evidence matrix

Part of [release-promotion](../SKILL.md) — evidence audit for the four FSDK OCI
Printer Applications tracked by
[common#1209](https://github.com/projectbluefin/common/issues/1209), answering
[common#1217](https://github.com/projectbluefin/common/issues/1217).

No physical printers are available to this factory. Every row below is derived
from source (commits, tags, GHCR manifests, workflow runs) as of 2026-09-25 —
do not update this table from memory; re-derive it the same way each time it
is refreshed. Anything that could not be confirmed from source is marked
**unverified**, not assumed passing.

## Repositories audited

| App | Repo | Snap reference (`snap/snapcraft.yaml`, still committed) |
|---|---|---|
| `ps-printer-app` | [projectbluefin/ps-printer-app](https://github.com/projectbluefin/ps-printer-app) | `20240504-11` |
| `hplip-printer-app` | [projectbluefin/hplip-printer-app](https://github.com/projectbluefin/hplip-printer-app) | `3.22.10-13` |
| `gutenprint-printer-app` | [projectbluefin/gutenprint-printer-app](https://github.com/projectbluefin/gutenprint-printer-app) | `5.3.4-9` |
| `ghostscript-printer-app` | [projectbluefin/ghostscript-printer-app](https://github.com/projectbluefin/ghostscript-printer-app) | `10.08.0-1` |

Snap versions are the OpenPrinting-maintained Snap Store releases still
recorded in each repo's own `snap/snapcraft.yaml` (kept for driver/version
provenance, not built). Snap Store revision numbers and architectures are not
committed anywhere in these repos and are marked unverified below.

## Release-contract status per app

| Criterion | `ps-printer-app` | `hplip-printer-app` | `gutenprint-printer-app` | `ghostscript-printer-app` |
|---|---|---|---|---|
| GHCR image published | ❌ none — `ghcr.io/projectbluefin/<repo>` returns `NAME_UNKNOWN` | ❌ none | ❌ none | ✅ `10.07.1-1`, `10.07.1-1-x86_64`, `10.07.1-1-aarch64` (GHCR tags carry no `v` prefix; only the git tag does) |
| Source commit / FSDK revision on record | unverified — no tag exists to pin | unverified | unverified | ✅ tag `v10.07.1-1` → tag object `6ba8963416eb89e30cfbe3b6ec1f44fac09969df` → commit `17d44ec7decd562930e46407dd022c6afd9e0c8b` ("Merge pull request #9", 2026-09-17 03:39 UTC) |
| amd64 + arm64 digests | unverified — nothing published | unverified | unverified | ✅ both architecture tags present in the GHCR tag list; combined into an OCI index, re-verified by merged [PR #10](https://github.com/projectbluefin/ghostscript-printer-app/pull/10) |
| Synthetic filter/backend job output | unverified — no image to run | unverified | unverified | ✅ `tests/appliance-parity.sh` (`just verify`) asserts the full advertised Ghostscript driver/backend/PPD-provider list against the built image; `tests/socket-sink.py` exercises print jobs against a synthetic socket sink |
| GHCR Actions registered on default branch | ❌ `total_count: 0` via `actions/workflows` API despite `registry-actions.yml`/`ci.yml`/`auto-update.yml` files existing in the tree | 7 active workflows registered, 24 recorded runs (not zero; none is named `ci.yml`/`registry-actions.yml`) | 12 active workflows registered, 27 recorded runs (not zero; none is named `ci.yml`/`registry-actions.yml`) | ✅ `ci.yml`, `registry-actions.yml`, `update-fsdk-sources.yml`, `auto-update.yml` all `active` with run history |
| Index signature (cosign / keyless OIDC) | unverified | unverified | unverified | ✅ verified against the published index, per PR #10's re-verification (`cosign verify`) |
| SPDX SBOM discoverable | unverified | unverified | unverified | ✅ `sha256-ae66f00a84a81568908b8d344b5638f6b19fcca0ec340ff2414dec183ef90784` referrer tag resolves via `oras discover --format json` `.referrers[]` (fixed in PR #10 — the verifier previously queried the wrong `.manifests` key) |
| SLSA provenance | unverified | unverified | unverified | recorded as verified in PR #10 (`gh attestation verify`); not independently re-verified here — `gh attestation verify` is outside this environment's permitted command surface |
| Testing → stable promotion evidence | unverified — repo has no `stable` release history yet | unverified | unverified | branches `testing` and `stable` both exist; `v10.07.1-1` was cut from `stable` per the tag/release naming, but no dedicated promotion-diff evidence beyond the tag itself was located |
| Rollback path documented | unverified | unverified | unverified | unverified — no rollback runbook found in-repo |

## Blocking gap

`ps-printer-app`, `hplip-printer-app`, and `gutenprint-printer-app` each carry
their own open issue #7, "Publish immutable signed OCI releases from verified
stable branch," and none has ever produced a GHCR image, a version tag, or a
registered GitHub Actions run. There is no image, digest, signature, SBOM, or
provenance to audit for these three apps yet — that is a release-pipeline gap
in those repos, not a false pass here. `ghostscript-printer-app` is the only
one of the four with a real, previously-audited release contract. The release
itself was cut from commit `17d44ec7decd562930e46407dd022c6afd9e0c8b` (tag
`v10.07.1-1`); merged [PR #10](https://github.com/projectbluefin/ghostscript-printer-app/pull/10)
landed five hours later and re-verified that already-published release's
index/SBOM referrer resolution rather than producing it. Open
[PR #26](https://github.com/projectbluefin/ghostscript-printer-app/pull/26)
adds a Snap driver/version parity matrix for that image specifically, tracking
open issue [ghostscript-printer-app#19](https://github.com/projectbluefin/ghostscript-printer-app/issues/19).

## Known version drift (ghostscript-printer-app only)

Per the driver/version parity work in progress in
[PR #26](https://github.com/projectbluefin/ghostscript-printer-app/pull/26)
(tracking issue [ghostscript-printer-app#19](https://github.com/projectbluefin/ghostscript-printer-app/issues/19)):

- Ghostscript/ghostpdl: OCI image pins `10.07.1` (IJS-only) vs. Snap `10.08.0`.
- brlaser: OCI image pins upstream `pdewacht/brlaser` `v6` vs. Snap's
  `Owl-Maintain` fork `v6.2.8`.
- SpliX: OCI image pins `debian/2.0.1-1` vs. Snap `debian/2.0.1-2`.

Components inherited from the `freedesktop-sdk.bst` junction (Ghostscript
binary, CUPS, libcupsfilters, libppd, cups-filters, foomatic-db) are treated
as unknown/inherited rather than guessed, consistent with this issue's
acceptance criteria.

## Re-deriving this matrix

```bash
# GHCR tag list (anonymous, public images only)
for r in ps-printer-app hplip-printer-app gutenprint-printer-app ghostscript-printer-app; do
  token=$(curl -s "https://ghcr.io/token?scope=repository:projectbluefin/$r:pull" | jq -r .token)
  curl -s -H "Authorization: Bearer $token" \
    "https://ghcr.io/v2/projectbluefin/$r/tags/list"
done

# Registered Actions workflows and run history
gh api repos/projectbluefin/<repo>/actions/workflows
gh run list --repo projectbluefin/<repo> --workflow registry-actions.yml --limit 5

# Release tags
gh api repos/projectbluefin/<repo>/tags
```

## Verification

- [ ] Re-run the GHCR tag-list check for all four repos before trusting this
      matrix — a new release on any of the three unpublished apps changes its
      row entirely.
- [ ] When any of `ps-printer-app`, `hplip-printer-app`, or
      `gutenprint-printer-app` publishes its first GHCR release, re-audit
      signature/SBOM/provenance the same way PR #10 did for
      `ghostscript-printer-app` before marking that row verified.
- [ ] Do not mark physical print output as verified — no hardware is
      available to any of the four apps.
