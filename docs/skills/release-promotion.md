---
name: release-promotion
description: "Promotion criteria, monthly release cadence, hotfix procedure, and artifact verification for projectbluefin/common."
---

# Release and promotion — common

Load this when cutting a release, evaluating whether a monthly tag is safe to create, doing a hotfix, or verifying signed artifacts.

## Promotion criteria

A `common` release is safe when **all** of the following are true:

| Criterion | How to verify |
|---|---|
| Post-merge E2E is green | Check `.github/workflows/e2e.yml` run on latest `main` commit |
| No open `do-not-merge` PRs targeting `main` | `gh pr list --repo projectbluefin/common --label do-not-merge` |
| No open P0 issues | `~/src/hive-status` — zero 🔴 blockers |
| Promotion-candidate E2E passed this week | Check `.github/workflows/promotion-candidate-e2e.yml` (runs Tuesdays) — no open blocker issue from it |

If any criterion fails, **do not tag a release**. File or escalate the blocker issue and wait.

> **Planned gate (common#513):** The monthly `release.yml` will be updated to run the promotion-candidate E2E as a required prerequisite job before creating the GitHub Release. Until that ships, the check above is manual.

## Monthly release cadence

- **Schedule:** 1st of every month at 00:00 UTC (`release.yml` cron)
- **Tag format:** `v<YEAR>.<MONTH>` — e.g., `v2026.06`
- **What it creates:** A GitHub Release with a changelog since the previous tag, pointing at the current `main` HEAD
- **What it does NOT do:** Promote or retag the OCI image — `:latest` is always the most recent merge to `main`

## Emergency hotfix release

When a critical fix needs a versioned tag outside the monthly window:

1. Merge the fix to `main` via normal PR process
2. Verify all promotion criteria above are met
3. Run `release.yml` manually via `workflow_dispatch` — it will tag the current `main` with the current month's tag (or create a patch tag manually with `gh release create`)
4. Notify downstream image repos if the fix affects their builds

## Supply chain — current state and planned improvements

> **Note:** Supply chain tooling for this repo is being centralized. Do not add inline signing, SBOM, or scanning logic to `build.yml`. All of that belongs in `projectbluefin/actions`.

| Practice | Current state | Tracking |
|---|---|---|
| OCI image signing | Key-based (`SIGNING_SECRET`) | Migrate to keyless via `sign-and-publish` — [common#513](https://github.com/projectbluefin/common/issues/513) |
| SBOM | None | Adopt `sign-and-publish` (includes syft) — [actions#86](https://github.com/projectbluefin/actions/issues/86) |
| SLSA L2 provenance | None | Adopt upgraded `sign-and-publish` — [actions#86](https://github.com/projectbluefin/actions/issues/86) |
| CVE scanning | None | Adopt `scan-image` composite action — [actions#86](https://github.com/projectbluefin/actions/issues/86) |
| Changelog quality | `git log` heredoc | Migrate to `git-cliff` — [common#513](https://github.com/projectbluefin/common/issues/513) |

## Verifying a published artifact

### Verify cosign signature (current — key-based)

```bash
cosign verify \
  --key https://raw.githubusercontent.com/projectbluefin/common/main/cosign.pub \
  ghcr.io/projectbluefin/common:latest
```

### Verify GitHub attestation (after common#513 ships)

```bash
gh attestation verify \
  oci://ghcr.io/projectbluefin/common:latest \
  --repo projectbluefin/common
```

### Verify SBOM attachment (after actions#86 ships)

```bash
# List attached referrers (SBOM, signatures, attestations)
oras discover ghcr.io/projectbluefin/common:latest

# Pull the SBOM
cosign verify-attestation \
  --type cyclonedx \
  ghcr.io/projectbluefin/common:latest | jq .payload | base64 -d | jq .
```

## Weekly gated release model

As of 2026-06-06, all three image repos fire releases on **Tuesday at 06:00 UTC** and require maintainer approval before the release is created.

| Repo | Workflow | Gate |
|---|---|---|
| **bluefin** | `scheduled-stable-release.yml` (new) | `production` environment — `@projectbluefin/maintainers` |
| **bluefin-lts** | `scheduled-lts-release.yml` | `production` environment — `@projectbluefin/maintainers` |
| **dakota** | `release.yml` | `production` environment — `@projectbluefin/maintainers` |

### How the gate works

1. Schedule fires Tuesday 06:00 UTC → GitHub notifies `@projectbluefin/maintainers`
2. Any maintainer clicks **Review deployments** in the Actions UI and approves
3. The release job proceeds once approved (GitHub enforces this natively — no bot logic needed)
4. `workflow_dispatch` is available on all three for out-of-band cuts

### Approval requirement

GitHub Environment protection requires **any 1** reviewer from the listed team to approve (GitHub does not support a "require N" count natively for environments). In practice, social convention is 2 acks. If a stricter gate is needed, a two-stage environment chain (`gate-1` → `gate-2`) can be added.

### Blocking an individual release

Add a `do-not-release` label convention: before the Tuesday run, a maintainer can cancel the in-progress workflow run for that repo specifically. The other two repos are not affected.

### Context sourcing (dakota and bluefin)

Unlike `bluefin-lts` which dispatches fresh builds, the bluefin and dakota scheduled release workflows find the **latest successful build/publish run** at approval time and pull its SHA, SBOM, and digest from there. This means the release tags the most recently built image, not necessarily the one built that Tuesday.

## Promotion pipeline consistency epic (#516)

The three image repos (bluefin, bluefin-lts, dakota) currently use inconsistent pipeline models. Epic [#516](https://github.com/projectbluefin/common/issues/516) tracks bringing them into alignment on a shared "build once, promote the artifact" model.

**Known gaps being tracked:**

| Issue | Repo | Gap | Blocked on |
|---|---|---|---|
| [#518](https://github.com/projectbluefin/common/issues/518) | bluefin | `:testing` tag pushed before e2e — broken images visible to users | Investigate shared build action first |
| [#517](https://github.com/projectbluefin/common/issues/517) | bluefin-lts | Rebuilds from source for production — `:lts` never tested as shipped | **bluefin-lts PR #73** must merge first |
| [#519](https://github.com/projectbluefin/common/issues/519) | bluefin-lts | No 7-day promotion floor | **bluefin-lts PR #73** must merge first (same file as #517) |
| [#520](https://github.com/projectbluefin/common/issues/520) | dakota | Weekly promotion runs Sunday, not Tuesday | ✅ Fixed — dakota and bluefin now Tuesday 06:00 UTC, gated behind `production` env |
| [#521](https://github.com/projectbluefin/common/issues/521) | dakota | No cosign verify before final promotion | Ready (after #520) |
| [#522](https://github.com/projectbluefin/common/issues/522) | dakota | No full e2e at weekly promotion time | Ready (after #520) |
| [#523](https://github.com/projectbluefin/common/issues/523) | common | No shared release-pipeline.md spec | **Start here — approve before any workflow PRs** |
| [#524](https://github.com/projectbluefin/common/issues/524) | all repos | No TOCTOU SHA guard before final skopeo copy | bluefin and dakota ready; LTS after #517 |

**⚠️ bluefin-lts PR #73 (`feat/shared-workflow-migration`)** is pending review and rewrites the LTS build workflows + renames all LTS images. Do not implement #517 or #519 until #73 merges. After #73 merges, the LTS testing tag scheme changes from `bluefin:lts-testing` → `bluefin-lts:testing` / `bluefin-lts-hwe:testing` / `bluefin-gdx:testing`.

Suggested implementation order: `#523 → #520 → #521 #522 #524-bluefin #524-dakota → #518 → (wait for #73) → #517+#519+#524-lts`

## Related docs

| Topic | Doc |
|---|---|
| CI workflow purposes | [workflow-map.md](workflow-map.md) |
| E2E gates | [e2e-ci.md](e2e-ci.md) |
| Promotion gates (QA model) | [../qa/PROMOTION_GATES.md](../qa/PROMOTION_GATES.md) |
| Supply chain tooling (shared) | [projectbluefin/actions#86](https://github.com/projectbluefin/actions/issues/86) |
