# Consistency Audit — Removing Per-Image Code

> **Purpose:** Inventory code that is duplicated across `bluefin`, `bluefin-lts`, and `dakota`, and propose a consolidation path so all images share as much as possible from `projectbluefin/actions`.
>
> **Mantra:** *Per-image code is a reliability tax. Every line that lives in only one image repo is a line that drifts.*

This document supplements [`pipeline-map.md`](pipeline-map.md) and [`manual-touchpoints.md`](manual-touchpoints.md) by addressing the brief's explicit ask: **"actively try to remove per-image code"**.

## Current consolidation state (what's already shared)

`projectbluefin/actions` already exposes a strong reusable surface. Both `bluefin` and `bluefin-lts` consume:

| Shared asset | Type | Adopters |
|---|---|---|
| `reusable-build.yml` | reusable workflow | bluefin, bluefin-lts |
| `reusable-execute-release.yml` | reusable workflow | bluefin, bluefin-lts |
| `reusable-release-gate.yml` | reusable workflow | bluefin, bluefin-lts |
| `reusable-release.yml` | reusable workflow | bluefin, bluefin-lts |
| `reusable-release-reminder.yml` | reusable workflow | bluefin, bluefin-lts |
| `reusable-renovate-automerge.yml` | reusable workflow | bluefin, bluefin-lts, dakota |
| `reusable-sync-branches.yml` | reusable workflow | bluefin, bluefin-lts |
| `skill-drift-check.yml` | reusable workflow | bluefin, bluefin-lts, dakota |
| `bootc-build/detect-changes` | composite action | bluefin, bluefin-lts |
| `bootc-build/validate-pr` | composite action | bluefin, bluefin-lts, dakota |
| `bootc-build/setup-runner` | composite action | bluefin |
| `bootc-build/generate-release-notes` | composite action | bluefin |
| `bootc-build/chunka` | composite action | dakota |
| `bootc-build/ghcr-cleanup` | composite action | dakota |

**Estimate:** ~70% of CI logic is already in `projectbluefin/actions`. The remaining ~30% is the long tail addressed below.

## Per-image code that MUST consolidate

### C1 — `promote-testing-to-main.yml` (HIGH IMPACT)

| Field | Value |
|---|---|
| Lives in | `bluefin/.github/workflows/promote-testing-to-main.yml` (~14 KB), `bluefin-lts/.github/workflows/promote-testing-to-main.yml` (~14 KB), `dakota/.github/workflows/promote-testing-to-main.yml` (~6 KB) |
| What it does | Resolves `:testing` digests, writes `.github/release-state.yaml`, opens/updates the always-open squash PR against `main` |
| Per-image variation | List of variants (image streams) and the e2e suite name |
| Total LoC duplicated | **725 lines** remaining (verified 2026-06-10-drift: bluefin 343 + bluefin-lts 353 + dakota **29** — dakota migrated via [actions#157](https://github.com/projectbluefin/actions/pull/157) + [dakota#788](https://github.com/projectbluefin/dakota/pull/788)) |
| Consolidation target | `projectbluefin/actions/.github/workflows/reusable-promote.yml` taking `variants` (array) + `e2e_suite` (string) + `lts_floor_days` (int, default 0) as inputs |
| Effort | 1 day |
| Risk | LOW — this workflow runs daily; regression is caught within 24h |
| Artifact | [`reusable-promote.yml`](reusable-promote.yml) (template) |

**Adoption order (canary-first, lowest blast radius first):**

1. `dakota` ✅ **Done** — migrated to caller pattern, 183 → 29 LoC ([actions#157](https://github.com/projectbluefin/actions/pull/157) + [dakota#788](https://github.com/projectbluefin/dakota/pull/788))
2. `bluefin-lts` — **pending** one observed dakota promotion cycle
3. `bluefin` (highest user impact) — land last

**Rollback strategy:** keep the original `promote-testing-to-main.yml` content commented (or in a `.bak` sibling file) for one full promotion cycle after migration. Revert is one commit.

**Deploy-time substitution:** the `reusable-promote.yml` template uses `<sha>` placeholders for third-party action references (e.g. `actions/checkout@<sha> # v6`). Substitute the actual SHAs at deploy time using the Renovate convention; the SHA-pin pre-commit gate will fail the PR if any literal `<sha>` remains.

### C1 — Caller example after migration

What `bluefin/.github/workflows/promote-testing-to-main.yml` becomes after migration (~30 lines):

```yaml
name: Promote testing to main
on:
  push:
    branches: [testing]
  schedule:
    - cron: '0 8 * * *'
  workflow_dispatch:

jobs:
  promote:
    uses: projectbluefin/actions/.github/workflows/reusable-promote.yml@<sha> # v1
    with:
      variants: '["bluefin","bluefin-dx","bluefin-nvidia","bluefin-nvidia-open","bluefin-asus","bluefin-asus-nvidia","bluefin-asus-nvidia-open","bluefin-surface","bluefin-surface-nvidia","bluefin-surface-nvidia-open","bluefin-framework","bluefin-framework-nvidia","bluefin-framework-nvidia-open"]'
      e2e_suite: 'smoke'
    secrets:
      APP_ID: ${{ secrets.MERGERAPTOR_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.MERGERAPTOR_PRIVATE_KEY }}
```

`bluefin-lts` differs only in the `variants` list and `lts_floor_days: 7`.
`dakota` differs only in `variants: '["dakota"]'` and `e2e_suite: 'dakota'`.

### C2 — Pinning `@main` references to SHAs (HIGH IMPACT, LOW EFFORT)

`bluefin` and `bluefin-lts` reference 4 reusable workflows with `@main`:

```yaml
uses: projectbluefin/actions/.github/workflows/reusable-execute-release.yml@main
uses: projectbluefin/actions/.github/workflows/reusable-release-gate.yml@main
uses: projectbluefin/actions/.github/workflows/reusable-release-reminder.yml@main
uses: projectbluefin/actions/.github/workflows/reusable-release.yml@main
```

This violates the **SHA-pinning gate** enforced by `pre-commit` in `common` and the rule in [`docs/skills/ci-tooling.md`](../../skills/ci-tooling.md). It also creates a non-deterministic step: a merge to `actions/main` silently changes behavior for every downstream image without a PR.

| Field | Value |
|---|---|
| Action | One PR per repo: pin all `@main` to the current `actions/main` HEAD SHA + `# v1` comment |
| Sustainability | Renovate already updates pinned SHAs; the `actions-v1-tag-update.yml` artifact accelerates the v1 tag update so Renovate sees motion |
| Effort | 30 min × 2 repos |
| Risk | NONE — pinning to current HEAD is a no-op semantically |

### C3 — SHA drift across repos for "same" version (MEDIUM IMPACT)

Within `bluefin` alone, 7 different SHAs are pinned for `projectbluefin/actions`:

```
6274199cfb6666180ac2fd0ad5a41bc8440e0929 (v1)
2497c3a7e0a7bbeeb36ac10bc2b487e7812ab562 (consumer-validation branch)
352163f170c15bf65f936b150e6a13f2a5f7037b (fix/precommit-sha-pin branch)
bd1d83a3eb3a55d63f71069cd9234d6a8d93f4b5 (v1)
fcd2a6bac15f2037df2e62572eef7a70fd25759f (v1)
1b6ae6a57f589db7175c3748ff93337ba63457ce (v1)
0527fe28c462e3f53cb1f6674c429562861e316c (main, commented out)
```

Two of these are non-`v1` branch SHAs that escaped review. `bluefin-lts` uses 2 different SHAs; `dakota` uses 4. The actions repo is the single source of truth — every consumer should converge on the same SHA per release.

| Field | Value |
|---|---|
| Action | Add a Renovate rule that groups all `projectbluefin/actions/*` references into one PR per repo, ensuring atomic SHA bumps |
| Detection | Add a `consistency-check.yml` to `actions` that lists all SHAs each consumer uses and warns on drift > N days |
| Effort | 1 hour Renovate rule + 2 hours consistency action |
| Risk | NONE — purely observability/grouping |

### C4 — Cosign key-based signing (MEDIUM IMPACT)

| Field | Value |
|---|---|
| Lives in | bluefin, bluefin-lts, dakota each have a key-based cosign step in their build workflows; common also still has the legacy path |
| Consolidation | The `build-upgraded.yml` artifact already exists for `common` (keyless via OIDC). Once merged, the same composite (`projectbluefin/actions/sign-and-publish`) MUST be the only signing path for all four repos |
| Effort | 4 hours (covered in roadmap Phase 6 — supply chain upgrade, [actions#86](https://github.com/projectbluefin/actions/issues/86)) |
| Status | Already tracked — this audit confirms it as a consistency item |

### C5 — Per-image release-state.yaml schema drift (LOW IMPACT)

`dakota` writes `.github/release-state.yaml` with a different schema than `bluefin` and `bluefin-lts`. This will bite when `reusable-execute-release.yml` is asked to handle dakota.

| Field | Value |
|---|---|
| Action | Define `release-state.yaml` schema in `projectbluefin/actions/docs/schemas/release-state.schema.json` and validate it with `ajv` in a pre-commit hook in each consumer |
| Effort | 2 hours schema + 30 min wiring |
| Risk | NONE — schema-only addition |

## Per-image code that MAY stay per-image

These vary intentionally and are NOT consolidation candidates:

| File | Why it stays per-image |
|---|---|
| `Containerfile` | Image content IS the per-image differentiation. Shared logic belongs in `common` as image layers, not as YAML. |
| `recipes/*.yml` (bluefin) / `bluefin-lts.yaml` / dakota BST elements | Image composition spec — domain-specific by design |
| `iso/build-iso-*.yml` | Per-variant artifacts; consolidation already done in `iso/.github/workflows/reusable-build-iso-anaconda.yml` |
| Repo-specific `validate.yml` policy guards | Per-repo policy is a feature: bluefin enforces no-NVIDIA-in-base, dakota enforces no-floating-action-tags. Standardize the *framework* (composite action `policy-check`), not the policies. |

## Consolidation roadmap

Order by automation gain × inverse effort:

| Order | Item | Gain | Effort | Status | Tracks |
|---|---|---|---|---|---|
| 1 | C2 — pin `@main` to SHA | HIGH | 30 min × 2 | ✅ **Done** — dakota ([#786](https://github.com/projectbluefin/dakota/pull/786)), bluefin-lts ([#159](https://github.com/projectbluefin/bluefin-lts/pull/159)); bluefin ([#484](https://github.com/projectbluefin/bluefin/pull/484)) merged to `testing`, lands on `main` at next promotion | Pre-existing pre-commit hook |
| 2 | C3 — Renovate grouping rule | MEDIUM | 1 hour | ✅ **Done** — [common#593](https://github.com/projectbluefin/common/pull/593) | [#587](https://github.com/projectbluefin/common/issues/587) |
| 3 | C1 — reusable-promote workflow | HIGH | 1 day | 🔶 **Partial** — reusable workflow live ([actions#157](https://github.com/projectbluefin/actions/pull/157)), dakota adopted ([dakota#788](https://github.com/projectbluefin/dakota/pull/788)); bluefin-lts + bluefin pending one promotion cycle | [#584](https://github.com/projectbluefin/common/issues/584) |
| 4 | C4 — sign-and-publish migration | HIGH | 4 hours | ⏳ Pending | [actions#86](https://github.com/projectbluefin/actions/issues/86), [common#513](https://github.com/projectbluefin/common/issues/513) |
| 5 | C5 — release-state schema | LOW | 2.5 hours | ⏳ Pending | New |
| 6 | C3.5 — drift detector workflow | MEDIUM | 2 hours | ⏳ Pending | New in `actions/` |

## Net automation impact

After C1–C5:

- **725 lines** of triplicated YAML reduced to one reusable workflow + 3 thin callers (≈30 LoC each) — **in progress**: dakota 29 LoC ✅, bluefin-lts + bluefin pending adoption
- Zero `@main` refs — full SHA pinning across all consumers (5 remain in bluefin `testing` branch; land on `main` at next promotion)
- Single source of truth for: build, sign, release, promote, ISO rebuild, renovate-automerge, sync-branches, skill-drift, release-state schema
- Shared composite library for: token health, retry, sign-and-publish, scan-image, detect-changes, validate-pr, setup-runner, chunka, ghcr-cleanup, generate-release-notes

**Coverage shift:** consolidation moves the factory from "70% shared / 30% per-image" to "≥90% shared / ≤10% per-image" (the per-image residual is intentional image-content specification, not CI logic).

## Validation

Run after each consolidation:

```bash
# 1. No @main references in image repo workflows
for repo in bluefin bluefin-lts dakota; do
  echo "=== $repo ==="
  grep -rn '@main' ~/src/$repo/.github/workflows/ || echo "OK"
done

# 2. SHA convergence check
for repo in bluefin bluefin-lts dakota; do
  echo "=== $repo ==="
  grep -h 'projectbluefin/actions' ~/src/$repo/.github/workflows/*.yml \
    | grep -oE '@[a-f0-9]{40}' | sort -u
done
# Expect: ≤2 unique SHAs per repo (one for active v1, one for any in-flight branch)

# 3. promote-testing-to-main.yml deduped
for repo in bluefin bluefin-lts dakota; do
  wc -l ~/src/$repo/.github/workflows/promote-testing-to-main.yml
done
# Expect: <50 lines each (just calls reusable-promote.yml with inputs)
```

## Tracking

When this audit lands, file:

- `[consistency] C2: pin @main refs to SHA in bluefin` — `kind/improvement`, `area/ci`, `priority/p1`
- `[consistency] C2: pin @main refs to SHA in bluefin-lts` — same labels
- `[consistency] C3: group projectbluefin/actions Renovate updates` — `kind/improvement`, `area/renovate`
- `[consistency] C1: reusable-promote workflow in projectbluefin/actions` — `kind/improvement`, `area/ci`, epic-link to factory pipeline consistency epic
- `[consistency] C5: release-state.yaml JSON schema` — `kind/improvement`, `area/ci`

Each issue links back to this document.
