---
name: label-workflow
version: "6.0"
last_updated: "2026-10-07"
id: label-workflow
one_line_purpose: How issues and PRs move in projectbluefin repos with Prow, its labels and commands.
entry_point: docs/skills/label-workflow.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [labels, issues, workflow, prow]
description: >-
  The Prow workflow page for projectbluefin: how an issue gets accepted, how a
  pull request gets reviewed and merged, which labels mean something, and which
  /commands exist. Use when triaging issues, reviewing PRs, or changing labels.
metadata:
  type: procedure
---

# How issues and PRs work here

projectbluefin repositories use [Prow](https://github.com/cncf/prow-github-actions)
(cncf/prow-github-actions v3.0.1). You drive it with `/commands` in comments.
Reporters never need labels or commands: just reply normally.

## How an issue flows

1. **Filed.** The issue form adds `needs-human` and a kind (`kind/bug` or
   `kind/feature`). An issue with no kind gets `needs-kind` until someone sets one.
2. **Read.** A maintainer reads it, asks questions if needed, and fixes the kind
   (`/kind regression`), priority (`/priority important-soon`) or closes it (`/close`).
3. **Accepted.** When the scope is clear, a maintainer comments `/triage accepted`.
4. **Open to agents.** If agents may take it, a maintainer removes `needs-human`
   by hand. Prow never removes it. Leave it on when the reporter chose
   "Human interaction only" or a person must do the work.
5. **Blocked?** `/label blocked` while it waits on something outside the repo;
   `/remove-label blocked` when it can move again.

Hive only hands out issues that have `triage/accepted` and neither
`needs-human` nor `blocked`.

## How a pull request flows

1. **Opened.** Prow requests reviews from 2 people in the repo's `OWNERS` file.
2. **Reviewed.** A reviewer who is not the author comments `/lgtm`. Every new
   push removes `lgtm`, so re-review and `/lgtm` again after changes.
3. **Approved.** An `OWNERS` approver comments `/approve` or clicks
   **Approve** in a GitHub review. The author's own approval counts if they are
   in `OWNERS`. The repository's GitHub rules still apply on top: Common needs
   2 approving GitHub reviews, ChairLift 1.
4. **Merged.** With `lgtm`, `approved` and green checks, Prow puts the PR in the
   merge queue, which squash-merges it.
5. **Paused?** `/hold` stops the merge; `/hold cancel` releases it.

Link issues with `Fixes #NNN` or `Refs #NNN` as usual.

## Labels

Only these labels mean something. Others are descriptive or belong to Hive
(`hive/*`, `agent/*`, `needs-decision`, `approved-direction`).

| Label | Set by | What acts on it |
|---|---|---|
| `needs-human` | issue forms on every new issue; Hive when an agent stalls | Hive's human queue. Prow never touches it; a maintainer removes it by hand |
| `triage/accepted` | `/triage accepted` | Hive: only accepted issues are agent work; accepted issues rank first |
| `needs-kind` | Prow, on issues with no kind | re-added until a kind is set |
| `kind/bug` | issue form or `/kind bug` | Hive priority boost |
| `kind/regression`, `kind/security` | `/kind` | Hive: complex tier |
| `kind/feature`, `kind/documentation`, `kind/cleanup` | issue form or `/kind` | satisfies `needs-kind` |
| `priority/critical-urgent`, `priority/important-soon` | `/priority` | Hive priority boost |
| `blocked` | `/label blocked` | Hive skips it |
| `help wanted`, `good first issue` | `/help`, `/good-first-issue` | Hive boost; GitHub contribute page |
| `lgtm`, `approved` | `/lgtm`, `/approve` (a GitHub Approve review also counts as approve) | Prow merge gate |
| `hold` | `/hold`; Hive on agent PRs | blocks the merge. Hive clears its own |
| `ok-to-test` | `/ok-to-test` | runs CI on a first-time contributor's fork PR |

## Commands

Put each command at the start of its own line in a new comment.

| Command | What it does |
|---|---|
| `/kind bug` (`regression`, `security`, `feature`, `documentation`, `cleanup`), `/remove-kind ...` | set or remove a kind |
| `/triage accepted`, `/remove-triage accepted` | accept or un-accept an issue |
| `/priority critical-urgent` or `important-soon`, `/remove-priority ...` | set or remove a priority |
| `/label blocked`, `/remove-label blocked` | mark or clear blocked |
| `/hold`, `/hold cancel` | pause or release a merge |
| `/lgtm`, `/lgtm cancel` | review a PR (not your own) |
| `/approve`, `/approve cancel` | approve a PR as an `OWNERS` approver |
| `/assign @user`, `/cc @user` | assign people or request reviews |
| `/close`, `/close not-planned`, `/reopen` | close or reopen |
| `/retest`, `/test <workflow>`, `/test all` | re-run failed or named CI runs on a PR |
| `/ok-to-test` | run CI on a first-time contributor's fork PR |
| `/help`, `/good-first-issue` | add `help wanted` / `good first issue` |
| `/check-required-labels` | re-check `needs-kind` |

Who may use each command: see the upstream
[command reference](https://github.com/cncf/prow-github-actions/blob/v3.0.1/docs/commands.md).
Label commands (`/kind`, `/triage`, `/priority`, `/label`, `/hold`) work for
anyone today; leave them to maintainers.

## Where the config lives

- **Labels, `needs-kind`, merge and reviewer settings:**
  [`prow.yaml`](https://github.com/projectbluefin/.project/blob/main/prow.yaml)
  in `projectbluefin/.project`, shared by every repository. After changing it,
  run **Actions → Prow → Run workflow** in each repository to sync labels.
- **Who reviews and approves:** `maintainers.yaml` in `projectbluefin/.project`.
  A sync job copies it into each repository's root `OWNERS` file through a PR;
  never edit `OWNERS` by hand.
- **Workflow:** `.github/workflows/prow.yml` in each repository.
