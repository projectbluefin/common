---
name: governance
version: "1.1"
last_updated: "2026-08-06"
id: governance
one_line_purpose: Manage CODEOWNERS, triager roles, and governance sync.
entry_point: docs/skills/governance.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [governance, issues, lifecycle]
description: >-
  Triagers role, CODEOWNERS sentinel pattern, cross-repo sync workflow, and
  branch protection matrix for projectbluefin repos. Use when managing
  CODEOWNERS, adding/removing triager permissions, or syncing governance
  policy across repos.
metadata:
  type: reference
---

# Contributor Governance — Triagers & CODEOWNERS

## Contents
- [Roles](#roles)
- [CODEOWNERS structure](#codeowners-structure)
- [Sync workflow](#sync-workflow)
- [Branch protection](#branch-protection)
- [Lifecycle automation](#lifecycle-automation)

---

## Roles

| Role | GitHub team | What they can do |
|---|---|---|
| **Maintainers** | `@projectbluefin/maintainers` | Merge PRs, push to main, full admin |
| **Triagers** | `@projectbluefin/triagers` (placeholder) + direct collaborator | Label/assign/close issues, approve `docs/**` and `*.md` PRs |

Triagers are granted **triage** permission directly on each repo (not via team).
Add a person: `gh api repos/projectbluefin/REPO/collaborators/USERNAME --method PUT --field permission=triage`

## CODEOWNERS structure

Each repo has its own `.github/CODEOWNERS`. The **triage section is the single source of truth in `projectbluefin/common`** and is synced automatically to downstream repos.

### Sentinel block (edit only in `common`)

```
# BEGIN TRIAGERS — managed by projectbluefin/common, do not edit manually in downstream repos
# To add a triager: append @handle to the line below, then commit to main.
**/*.md  @handle1 @handle2 @projectbluefin/maintainers
# END TRIAGERS
```

**To add/remove a triager:** edit the `**/*.md` line inside the sentinel block in
`common/.github/CODEOWNERS` → commit to `main` → the sync workflow pushes the change to
`bluefin`, `bluefin-lts`, `dakota`, and `knuckle` automatically, and reconciles GitHub
triage permissions.

### Per-repo ownership (maintained in each repo separately)

| Repo | Default owners | Sensitive extra paths |
|---|---|---|
| `common` | `@inffy @renner0e @ledif @castrojo @hanthor @ahmedadan` (shared); `@castrojo @hanthor @ahmedadan` (bluefin) | — |
| `bluefin` | `@castrojo @p5 @m2Giles @tulilirockz` | `.github/workflows/`, `Justfile`, `build_files/` |
| `bluefin-lts` | same as bluefin | same + `image-versions.yml` exempt (Renovate) |
| `dakota` | same as bluefin | same + `elements/` |
| `knuckle` | `@castrojo @p5 @m2Giles @tulilirockz` | `.github/workflows/`, `Justfile` |

## Sync workflow

**File:** `.github/workflows/sync-codeowners.yml` in `projectbluefin/common`

- Triggers on `push` to `main` when `.github/CODEOWNERS` changes, plus `workflow_dispatch`
- Extracts the `BEGIN/END TRIAGERS` block and replaces it in `bluefin`, `bluefin-lts`, `dakota`, `knuckle`
- Skips repos where the block is already identical (no noise commits)
- Uses **mergeraptor** (`MERGERAPTOR_APP_ID` / `MERGERAPTOR_PRIVATE_KEY` org secrets) for cross-repo writes

> **Secret required:** `sync-codeowners.yml` needs `MERGERAPTOR_APP_ID` and `MERGERAPTOR_PRIVATE_KEY` set as org or repo secrets. Without them the workflow will fail.

Force a resync anytime:
```bash
gh workflow run sync-codeowners.yml --repo projectbluefin/common
```

## Hive sync coverage

Hive progress sync now covers all five `projectbluefin` repos on staggered cron slots:

| Repo | Minute |
|---|---|
| `dakota` | `:00` |
| `bluefin` | `:15` |
| `common` | `:20` |
| `knuckle` | `:30` |
| `bluefin-lts` | `:45` |

The sync jobs read the seven canonical lifecycle labels across the full repo set.

## Branch protection

The factory repositories use protected branches or rulesets; their approval
policies are not identical. A CODEOWNERS match is required where the table says
code-owner review is active.

| Repo | Mechanism | Required approvals |
|---|---|---|
| `common` | Ruleset `main-review-required-with-renovate-bypass` | 0; no code-owner review required (verified live, see [Verification](#verification)) |
| `bluefin` | Branch protection on `main` | 1 |
| `bluefin-lts` | Branch protection on `main` | 1 |
| `dakota` | Branch protection on `main` | 1 |
| `knuckle` | Ruleset `main — merge queue` | 1 (merge queue) |
| `lab` | Ruleset `main — merge queue` | 0; `lint` is required |

`common`'s ruleset name says "review-required" but the live rule sets
`required_approving_review_count: 0` and `require_code_owner_review: false`.
The name is aspirational/historical — do not trust it over the live API
response. The ruleset still blocks non-fast-forward pushes and branch
deletion, and a separate `main — merge queue` ruleset enforces the
`validate` and `Build and push image (x86_64|aarch64)` status checks.

For any repository using a GitHub merge queue, every required check workflow must
also subscribe to the `merge_group` event with `types: [checks_requested]`.
Without that trigger, queued PRs remain in `AWAITING_CHECKS` because ordinary
`pull_request` workflows do not run on merge-group refs. See the lab runbook at
[`projectbluefin/lab/docs/ops/merge-queue.md`](https://github.com/projectbluefin/lab/blob/main/docs/ops/merge-queue.md).

## Documentation and contract changes — push directly to main

Changes to `docs/**` and `AGENTS.md` in this repo do **not** need a PR. Push directly to `main`:

```bash
git add docs/... AGENTS.md
git commit -m "docs: ..."
git push origin main
```

This includes skill updates, `docs/SKILL.md` changes, `AGENTS.md`, and any other `docs/` content. Do not open a PR for docs-only work in `projectbluefin/common`. Verify before pushing:
`git diff --cached --name-only` must show only `docs/*` or `AGENTS.md`.

## Lifecycle automation

Issue intake automation lives in
[`projectbluefin/bonedigger`](https://github.com/projectbluefin/bonedigger) and is
consumed through a `bonedigger.yml` caller:

| Repo | Caller | State |
|---|---|---|
| `bluefin` | `bonedigger.yml` | live |
| `bluefin-lts` | `bonedigger.yml` | live |
| `dakota` | `bonedigger.yml` | live |
| `knuckle` | `bonedigger.yml` | live |
| `common` | none | intentional — no lifecycle caller here |

`common` does not own or run lifecycle automation. The seven canonical labels are
documented in [`label-workflow.md`](label-workflow.md) and applied per repository;
there is no cross-repo label sync workflow.

Full unification (claim TTL, heartbeat, linked-PR requirement, stale-claim recovery across all engines) was tracked in projectbluefin/common#409 — **closed/resolved**.

## Verification

- [ ] `common`'s live approval requirement matches the ruleset API, not the ruleset name:

  ```bash
  gh api repos/projectbluefin/common/rulesets --jq '.[] | {id, name}'
  gh api repos/projectbluefin/common/rulesets/<id> \
    --jq '.rules[] | select(.type == "pull_request") | .parameters | {required_approving_review_count, require_code_owner_review}'
  ```

  Expected today: `required_approving_review_count: 0`, `require_code_owner_review: false`
  (verified 2026-08-06 against ruleset `main-review-required-with-renovate-bypass`,
  id `17070417`).
- [ ] `pre-commit run check-skill-frontmatter --all-files` passes.
- [ ] `pre-commit run check-skill-index --all-files` passes.
