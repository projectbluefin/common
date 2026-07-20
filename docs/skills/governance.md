---
name: governance
version: "1.0"
last_updated: "2026-07-20"
tags: [governance, issues, lifecycle]
description: >-
  Triagers role, CODEOWNERS sentinel pattern, cross-repo sync workflow, and
  branch protection matrix for projectbluefin repos. Use when managing
  CODEOWNERS, adding/removing triager permissions, or syncing governance
  policy across repos." type: reference
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

> ⚠️ **Secret required:** Both `sync-codeowners.yml` and `sync-labels.yml` need `MERGERAPTOR_APP_ID` and `MERGERAPTOR_PRIVATE_KEY` set as org or repo secrets. Without them the workflows will fail. See issue #511 for tracking.

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

The sync jobs count slash-separated labels (`hive/p0`, `hive/p1`) across the full repo set.
Older references to dotted labels are stale.

## Template sync namespace

bonedigger's `sync-templates.yml` now targets the `projectbluefin/*` namespace,
not the old `ublue-os/*` pre-migration namespace. `projectbluefin/knuckle` is
included in that sync set.

## Branch protection

The factory repositories use protected branches or rulesets; their approval
policies are not identical. A CODEOWNERS match is required where the table says
code-owner review is active.

| Repo | Mechanism | Required approvals |
|---|---|---|
| `common` | Ruleset `main-review-required-with-renovate-bypass` | 1 |
| `bluefin` | Branch protection on `main` | 1 |
| `bluefin-lts` | Branch protection on `main` | 1 |
| `dakota` | Branch protection on `main` | 1 |
| `knuckle` | Ruleset `main — merge queue` | 1 (merge queue) |
| `lab` | Ruleset `main — merge queue` | 0; `lint` is required |

For any repository using a GitHub merge queue, every required check workflow must
also subscribe to the `merge_group` event with `types: [checks_requested]`.
Without that trigger, queued PRs remain in `AWAITING_CHECKS` because ordinary
`pull_request` workflows do not run on merge-group refs. See the lab runbook at
[`projectbluefin/lab/docs/ops/merge-queue.md`](https://github.com/projectbluefin/lab/blob/main/docs/ops/merge-queue.md).

## Documentation changes — push directly to main

Changes to `docs/` and `docs/skills/` in this repo do **not** need a PR. Push directly to `main`:

```bash
git add docs/...
git commit -m "docs: ..."
git push origin main
```

This includes skill updates, `docs/SKILL.md` changes, and any other `docs/` content. Do not open a PR for docs-only work in `projectbluefin/common`.

## Lifecycle automation

| Repo | Workflow | State |
|---|---|---|
| `bluefin` | `lifecycle-caller.yml` | ✅ live |
| `common` | `lifecycle-caller.yml` | ✅ live |
| `bluefin-lts` | `lifecycle-caller.yml` | ✅ live |
| `dakota` | `lifecycle-caller.yml` | ✅ live |
| `knuckle` | `lifecycle-caller.yml` | ✅ live |

`common` owns the reusable `.github/workflows/lifecycle.yml`. Each repo's `lifecycle-caller.yml` calls that workflow at a pinned `common` commit SHA.

Lifecycle labels now come from `labels.json` and are synced by `sync-labels.yml` across the factory.

Full unification (claim TTL, heartbeat, linked-PR requirement, stale-claim recovery across all engines) was tracked in projectbluefin/common#409 — **closed/resolved**.
