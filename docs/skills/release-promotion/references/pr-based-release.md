# PR-Based Release Model

Part of [release-promotion](../SKILL.md) — The squash-promotion pipeline used by bluefin, bluefin-lts, and dakota; schedule, commit title rules, repo variants, E2E gate model, merge model, and reusable workflow patterns.

---

## PR-based release model (current)

As of 2026-06-09, all three image repos (bluefin, bluefin-lts, dakota) use a **PR-based squash promotion** model. There are no more scheduled release workflows.

### How it works

```
testing branch builds (Renovate, feature PRs)
       │
       ▼ push to testing
promote-testing-to-main.yml (daily + on push)
       │
       ├── creates/updates auto/promote-testing-to-main branch (squash of testing)
       ├── opens or updates the promotion PR (testing → main)
       ├── runs release gate checks (cosign verify, E2E)
       └── attempts to enqueue PR in merge queue
                │
                ▼ maintainer approves → PR merges
       execute-release.yml (on PR close)
               │
               ├── re-verifies cosign signatures
               ├── promotes :testing digest to :stable (via skopeo copy)
               └── calls reusable-release.yml for release notes + GitHub Release
```

### Schedule

`promote-testing-to-main.yml` runs on three triggers:
- Push to `testing` branch
- Daily `cron: '0 23 * * *'` (refreshes promotion PR even with no testing activity)
- `workflow_dispatch` (manual override)

The daily heartbeat ensures the promotion PR stays fresh and gate checks are re-run.

### Commit title surfaces — PR title vs merged release trigger

`reusable-promote-squash.yml` emits **two different titles** during promotion:

- Promotion branch commit: `chore: promote <source_branch> to <target_branch>`
- Promotion PR title: `ci(promote): <primary_image> <source_branch> → <target_branch> <date>`

This distinction matters for `execute-release.yml`.

All three image repos currently use GitHub squash settings:

- `squash_merge_commit_title: COMMIT_OR_PR_TITLE`
- `use_squash_pr_title_as_default: false`

Because the auto-promotion branch contains a **single commit**, the squash merge on the target branch keeps the commit subject (`chore: promote ...`) rather than the PR title (`ci(promote): ...`).

**Canonical rule:** `execute-release.yml` must match the commit message that lands on the target branch, not just the PR title.

Current correct trigger subjects:

| Repo / branch | Target-branch commit subject to match |
|---|---|
| bluefin `main` | `^chore: promote testing to main` |
| bluefin-lts `main` | `^chore: promote testing to main` |
| dakota `main` | `^chore: promote testing to main` |

`ci(promote): ...` is still the correct PR title format for the open promotion PR, but **`ci(promote)` alone is not a reliable `execute-release` trigger** under the current squash-merge settings.

### Repo variants

| Repo | source | target tag |
|---|---|---|
| bluefin | `testing` branch | `stable` |
| bluefin-lts | `testing` branch | `stable` |
| dakota | `testing` OCI tag | `stable` |

### E2E gate model

All three repos run with `run_e2e: false` in `promote-testing-to-main.yml`. The e2e quality gate runs separately via `post-testing-e2e.yml` (bluefin) rather than at the PR gate level.

**Why `run_e2e: false`:** The gate queries GitHub's runs API by `head_sha = <testing-branch-SHA>`. Workflows triggered via `workflow_run` are stored in the API under the **default branch (main) SHA**, so the gate never finds a match regardless of whether E2E passed. This is the structural mismatch documented in [e2e-ci references/never-stall-design.md](../../e2e-ci/references/never-stall-design.md).

### Merge model

Promotion PRs auto-merge via the merge queue with **0 approvals required**. `Lint & syntax` is the only required check. `workflow_dispatch` is available on all three `promote-testing-to-main.yml` workflows for out-of-band promotion.

---

## Related docs

| Topic | Doc |
|---|---|
| CI workflow purposes | [workflow-map.md](../../workflow-map.md) |
| E2E gates | [e2e-ci.md](../../e2e-ci/SKILL.md) |
| Supply chain tooling (shared) | Keyless cosign, SBOM, SLSA L2, Trivy via `projectbluefin/actions` composites |

---

## Reusable workflow patterns (actions v1)

All image repos now delegate to shared reusables in `projectbluefin/actions`. Pin to the v1 SHA.

### Release generation — `reusable-release.yml`

Supports two SBOM modes:

| Mode | When to use | Key inputs |
|---|---|---|
| **Artifact mode** (default) | Build pipeline uploads a SBOM artifact (e.g. `reusable-build.yml` runs with `stream_name: stable`) | `build_workflow`, `build_branch`, `sbom_artifact` |
| **Inline mode** | No SBOM artifact (promote-from-testing weekly path, LTS weekly path) | `generate_sbom_inline: true`, `syft_version` (default v1.44.0) |

Use `checkout_ref` when the caller runs on `main` but the release should reflect a different branch (e.g. `checkout_ref: lts` for bluefin-lts).

**Critical**: `reusable-release.yml` always has `environment: production` on the `image-release` job — this is the R3 human gate. Do NOT remove it.

### Renovate runner — `reusable-renovate.yml`

Image repos keep their own `schedule`/`workflow_dispatch` wrapper and delegate the job:

```yaml
jobs:
  renovate:
    uses: projectbluefin/actions/.github/workflows/reusable-renovate.yml@<sha> # v1
    with:
      dry_run: ${{ inputs.dry_run == true }}
    secrets:
      renovate_token: ${{ secrets.RENOVATE_TOKEN }}
```

`persist-credentials: false` is enforced in the reusable — callers do not need to set it.

### Renovate auto-merge — `reusable-renovate-automerge.yml`

Image repos keep their `workflow_run` trigger (must reference the repo-specific CI workflow name) and delegate the PR lookup + squash-merge:

```yaml
on:
  workflow_run:
    workflows: ["<repo-specific CI workflow name>"]
    types: [completed]
permissions:
  contents: write
  pull-requests: write
jobs:
  automerge:
    if: github.event.workflow_run.conclusion == 'success'
    uses: projectbluefin/actions/.github/workflows/reusable-renovate-automerge.yml@<sha> # v1
    with:
      head_sha: ${{ github.event.workflow_run.head_sha }}
      # base_branch defaults to 'testing' — override only if needed
```

The `workflow_run` trigger CANNOT be in a reusable workflow — it must stay in the caller. Only the job logic is centralised.
