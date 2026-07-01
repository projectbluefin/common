---
name: label-workflow
version: "1.0"
last_updated: 2026-06-23
tags: [labels, issues, workflow]
description: "Label taxonomy, issue lifecycle (filed→triage→queued→claimed→done), slash commands, and the agent/human handoff model for projectbluefin factory repos. Use when understanding the issue lifecycle, triaging work, or using slash commands."
metadata:
  type: procedure
---

# Label Workflow — projectbluefin Factory

## Contents
- [The one-line model](#the-one-line-model)
- [Automation ownership](#automation-ownership)
- [Issue lifecycle](#issue-lifecycle)
- [Human workflow](#human-workflow)
- [Agent workflow](#agent-workflow)
- [Label reference](#label-reference)
- [Epics](#epics)

---

## The one-line model

**Git branches are the state machine. Standard GitHub Flow is the engine.**

We use a simple, lightweight, GitOps-first DevOps pipeline. Issues have static labels for categorization (type, area, priority) while the active work state is tracked purely through branches, PR associations, standard assignees, and projects. Mutable label-based FSMs and slash commands (like `/claim` or `/approve`) are retired.

---

## Automation ownership

The legacy comment-based active FSM previously driven by `.github/workflows/lifecycle.yml` is retired.

Our current automation is focused exclusively on static validation, OCI builds, and release promotion:
- **Repository Sync**: Label definitions are managed via `labels.json` and cross-repo sync workflows to ensure consistent tags (`kind/`, `area/`, `priority/`).
- **PR Association**: Standard GitHub PR closing keyword syntax (`Closes #NNN` in PR descriptions) natively handles closing resolved issues upon merge, requiring no background state-machine code.
- **Auto-Promotion and Gates**: Automated squash promotion is run via `projectbluefin/actions/.github/workflows/reusable-promote-squash.yml` to advance `testing` branch changes to `main` (stable).
- **bonedigger**: Handles automated client reporting, `ujust report` issue generation, and automated cycle prioritization based on client confirmation counts.

---

## Next-step reference

Under our branch-as-state model, we focus primarily on standard GitHub issue assignments and standard pull requests (PRs).

### Issues

| Component | 🟠 Actor | Next action |
|---|---|---|
| Issue Opened | **Human** triager | Set `kind/` + `area/` + `priority/`, then assign to a contributor or mark as open. |
| In Discussion | **Human** maintainer / team | Drive spec/design to consensus in the issue comments. |
| Assigned / In Progress | **Assignee** | Work on feature/bugfix branch. |
| block/hold | **Human** / *nobody* | Add comment describing any blockers or reason for hold. |

### PRs

| Label | 🟠 Actor | Next action |
|---|---|---|
| `pr/needs-review` | **Human** reviewer | Review ➔ add `lgtm` or request changes |
| `lgtm` + CI green | *automation* | Enqueue to merge queue or merge automatically |
| Changes requested | **Agent** / contributor | Address feedback ➔ push updates |
| `do-not-merge` | **Human** | Investigate ➔ remove when blocker resolved |

---

## Issue lifecycle

Our lifecycle is direct, visual, and zero-maintenance:

```
Issue Filed ➔ Triaged & Assigned ➔ Branch Work ➔ Pull Request Open ➔ Merge (Done)
```

We link code directly to design goals:
1. **Assignment**: Contributors or agents claim an issue by being assigned to it in GitHub (using the native UI/projects).
2. **Implementation**: Developers create scoped feature/fix branches (`fix/NNN-short-description`).
3. **Association**: The pull request includes standard keyword linkage (`Closes #NNN`) in its description.
4. **Merge**: Once E2E tests pass and the PR is approved (`lgtm`), it is merged into the branch, and the issue closes automatically.

---

## Human workflow

### Filing an issue

Use the issue templates — they set the right initial labels automatically.

If filing without a template, include enough context that someone else can act on it without asking follow-up questions. Issues that require clarification stay in discussion or triage indefinitely.

- **Bug reports** get tagged with `kind/bug` and `status/triage` automatically.
- **Feature requests** get tagged with `kind/enhancement` automatically.

### Triaging a bug (maintainers and triagers)

When a new bug is filed:

1. **Validity Check**: Is this a valid report? If it is invalid or a duplicate, close it with an explanation and tag with `kind/wontfix`.
2. **Details**: If you need more data, ask for `ujust report` output in a comment.
3. **Categorization**: Set **one or more** `area/` labels.
4. **Prioritization**: Optionally set a `priority/` label or `hive/p0`/`hive/p1` cycle labels.
5. **Assignment**: Assign the issue to yourself, a contributor, or an agent.

### Advancing a feature discussion

When a feature request reaches consensus:

1. Update the issue description with the agreed spec. The description should be concrete and self-contained so that any contributor or agent can implement it immediately without context gaps.
2. Mark the issue as ready by assigning it or adding a cycle priority label (`hive/*`).

### Reviewing PRs

PRs opened by contributors or agents carry `pr/needs-review` automatically. When you see it:

1. **Correctness**: Verify the diff solves the stated issue safely.
2. **Attribution**: Check for appropriate co-author and assistant-by trailers.
3. **Approval**: If it looks good, add the `lgtm` label. The PR will automatically merge once CI completes successfully.
4. **Block**: To block merge entirely, add `do-not-merge`.

### Unblocking a stuck agent

When an issue has `agent/blocked` or an agent leaves a comment asking for decisions:

1. Read the agent's comment to understand the options/blocker.
2. Provide the answer or decision as a comment on the issue.
3. Remove any blocker labels or ping the agent.

### Pausing work

- **Hold**: Set the `status/hold` label to signal a paused feature or dependency. Always comment on the issue explaining the reason and duration of the hold.
- **Oops**: Use `needs-human/agent-oops` if an agent made a significant error. Fix the underlying problem by hand before resuming agent runs.

---

## Agent / Contributor workflow

### Finding work

```bash
# Find open, unassigned, triaged issues across the org
gh search issues --assignee "" --owner projectbluefin --state open

# Find open, unassigned issues in a single repository
gh issue list --repo projectbluefin/common --assignee "" --state open
```

**Pick order**: Triaged issues with cycle priority labels (`hive/p0` first ➔ `hive/p1`) ➔ backlog priority labels (`priority/p0` ➔ `priority/p1` ➔ `priority/p2`) ➔ unassigned/unlabeled issues.

Avoid any issue with the `status/hold` label — those are off-limits.

### Claiming an issue

We use native GitHub features for claiming work:
1. Assign yourself to the issue in GitHub (using `gh issue edit <number> --add-assignee "@me"` or via the web UI).
2. The assignment acts as the claim. No comment-based commands are needed.

### Working

- Read the target repo's `AGENTS.md` — it specifies the required validation commands for that repo.
- Create a branch: `fix/NNN-short-description` or `feat/NNN-short-description`.
- Run the repo's validation gate before every commit (e.g. `just check && pre-commit run --all-files`).
- Follow Conventional Commits for PR titles: `fix:`, `feat:`, `chore:`, etc.

### Signaling a blocker

When you cannot proceed without a human decision:

1. Add the `agent/blocked` label to the **issue** (not the PR).
2. Leave a detailed comment on the issue describing:
   - What you need (be specific and clear).
   - The exact ambiguity or missing information.
   - Proposed options to resolve it.
3. Stop. Do not open a partial PR, and do not guess.

### Opening a PR

- **Title**: Conventional Commits format (`fix: ...`, `feat: ...`, `chore(deps): ...`).
- **Body**: Include `Closes #NNN` to link and automatically close the issue upon PR merge.
- **Attribution**: Include the required attribution trailers on any automated commits.
- **Labels**: PR labels such as `source:agent`, `size/*`, and `agent-tested` will be applied automatically by workflows.

### Unclaiming

If you are unable to complete the work, unassign yourself from the issue using the standard GitHub CLI or web UI:
```bash
gh issue edit <number> --remove-assignee "@me"
```

---

## Label reference

### Lifecycle — active categorization labels

> **Note**: Active label-based FSM states (`status/queued`, `status/claimed`, `status/discussing`) have been retired in favor of native GitHub features. We retain a minimal set of status labels for passive triage and overlay signals.

| Label | Color | Who sets it | Meaning |
|---|---|---|---|
| `status/triage` | 🟣 lavender | Auto on issue open | New issue awaiting categorization and triage. |
| `status/hold` | ⬜ gray | Human | Intentionally paused/held — do not work on. Read comments for reason. |
| `agent/blocked` | 🔴 red | Agent | Agent is stuck and needs human input. Read the issue comment. |

### Kind — what type of work?

> **Invariant:** exactly one `kind/*` per issue

| Label | Meaning |
|---|---|
| `kind/bug` | Broken behavior. Requires a fix PR. Verify with `ujust verify` after fix. |
| `kind/enhancement` | New capability. Must have a written spec in the issue body before claiming. |
| `kind/improvement` | Incremental improvement to existing behavior. No new spec required. |
| `kind/tech-debt` | Cleanup or refactor with no user-visible change. No spec required. |
| `kind/documentation` | Docs only. In `common`, commit directly to main — no PR needed. |
| `kind/translation` | i18n/l10n change. Coordinate with translation team before claiming. |
| `kind/epic` | Multi-issue tracker. Do not implement here; file child issues instead. |
| `kind/wontfix` | Will not be implemented. Do not claim or open PRs for this issue. |

---

## Epics

An epic is a `kind/epic` issue that tracks a multi-issue feature. It is never implemented directly — implementation happens in child issues that link back to it.

### When to use an epic

The lifecycle automation posts an epic-check comment when an issue has **both** `kind/enhancement` and `size/L` or `size/XL`. This is advisory, not blocking — you must act on it before commenting `/approve`.

**Use an epic when:**
- The feature has 3+ distinct pieces of work
- Progress needs to be visible on the project board across a release cycle
- Multiple contributors or agents may work on different pieces simultaneously

**Skip the epic when:**
- The enhancement is self-contained and can land in a single PR
- Size was auto-labeled conservatively but the actual scope is small

### Filing an epic

1. Open a new issue with `kind/epic` and the full feature title
2. Write a description that states the goal and acceptance criteria for the whole feature
3. List child issues as checkboxes in the body: `- [ ] Part of #NNN — short description`
4. On each child issue body, add `Part of #EPIC_NUMBER` so the board links them

### Linking a child issue to an epic

Add to the issue body:
```
Part of #EPIC_NUMBER
```

The project board groups issues by parent, so this is what makes the progress roll up correctly.

### Automation trigger

| Trigger | What happens |
|---|---|
| `kind/enhancement` + `size/L` or `size/XL` labeled on an open issue | Lifecycle posts a one-time comment (`<!-- epic-reminder -->`) asking to link or create an epic |
| `kind/epic` already present | No comment posted — the issue IS the epic |

### Priority — two families, different purposes

> **Invariants:** at most one `hive/*`; at most one `priority/*`

**Hive** — current release cycle priority. Reset each cycle by maintainers.

| Label | Meaning |
|---|---|
| `hive/p0` | Cycle release blocker. Fix before next promotion. |
| `hive/p1` | Must land this cycle. |

**Priority** — static backlog ordering. Set during triage, not reset each cycle.

| Label | Meaning |
|---|---|
| `priority/p0` | Repo-level blocker |
| `priority/p1` | High priority |
| `priority/p2` | Normal backlog |

An issue can carry **both** a `hive/*` and a `priority/*` — they track different things.

### Area — what part of the system?

> Set one or more `area/` labels. These scope the work and route CODEOWNERS reviews.

`area/agent` · `area/aurora` · `area/bling` · `area/bluespeed` · `area/bootc` · `area/brew` · `area/buildstream` · `area/ci` · `area/dx` · `area/finpilot` · `area/flatpak` · `area/gnome` · `area/hardware` · `area/iso` · `area/just` · `area/nvidia` · `area/policy` · `area/security` · `area/services` · `area/testing` · `area/ujust` · `area/upstream`

### Source — who filed it?

> Set automatically by templates and automation. Do not set or change manually.

| Label | Meaning |
|---|---|
| `source:agent` | Filed by an AI agent |
| `source:gha` | Filed by GitHub Actions |
| `source:manual` | Filed by a human contributor |
| `source:ujust-report` | Filed via `ujust report` by a user |

Note: `source:` uses a colon separator — retained for automation compatibility with bonedigger's ujust report routing.

### PR labels

> `pr/needs-review` is auto-set when a PR is opened. Size labels are auto-set where wired.

| Label | Color | Who sets it | Meaning |
|---|---|---|---|
| `pr/needs-review` | 🟠 orange | Auto on PR open | Awaiting human review. Add `lgtm` or request changes. |
| `lgtm` | 🟢 green | Human | Maintainer approved. Merges automatically when CI is green. |
| `do-not-merge` | 🔴 red | Human | Blocks all merges. Remove only when the blocking issue resolves. |
| `agent-tested` | 🟢 green | CI automation | e2e test suite passed. Set automatically after a clean run. |
| `tests:pass` | 🔵 blue | CI automation | Required CI gate passed. Enables auto-merge where wired. |
| `size/XS` | gray | Auto | ~1 hour: 0–9 lines changed |
| `size/S` | gray | Auto | ~half day: 10–29 lines changed |
| `size/M` | gray | Auto | ~1 day: 30–99 lines changed |
| `size/L` | gray | Auto | ~3 days: 100–499 lines changed |
| `size/XL` | gray | Auto | ~1 week: 500–999 lines changed |

PRs over ~1000 lines should be split. If you see one that size, split the PR or the issue.

Note: `tests:pass` uses a colon separator — retained for CI automation compatibility.

### Agent flow triggers

Applied to issues or PRs to request a specific agent workflow. The agent removes the label after completing the task.

| Label | Who applies | Meaning |
|---|---|---|
| `flow/issue-review` | Human or maintainer | Agent: review this issue, post findings as a comment, remove this label. |
| `flow/pr-review` | Human or maintainer | Agent: review this PR, post findings as a comment, remove this label. |
| `flow/agent-donation` | Human | Agent: donate time to this repo, issue, or PR as described in the linked item. |
| `flow/project-report` | Human or maintainer | Agent: produce a sourced project status report, remove this label. |

### Special and automation labels

| Label | Meaning |
|---|---|
| `ai-context` | ACMM audit finding — AI/LLM context gap that improves agent reliability org-wide |
| `stale` | No recent activity; will auto-close unless updated |
| `stale-digest` | Filed against an outdated image digest — may not reproduce on current build |
| `needs-human/agent-oops` | Agent error — do not re-run automation; fix manually then re-queue |
| `dependencies` | Renovate dependency update PR. Automerges on CI pass; only major bumps need review. |

### Hardware test labels

Used on issues in `projectbluefin/common` filed via the **Hardware test report** template.
See [`docs/hardware-testing.md`](../hardware-testing.md) for the full process.

| Label | Who sets it | Meaning |
|---|---|---|
| `hardware/test-report` | Issue template (auto) | Community hardware test report — needs triage |
| `hardware/all-clear` | Maintainer after triage | Real-device evidence of a clean run — supports promotion |
| `hardware/blocker` | Maintainer after triage | Hardware regression — **blocks image promotion** until resolved |

```bash
# Find open hardware blockers before promoting
gh search issues --label "hardware/blocker" --owner projectbluefin --state open
```

---

## What automation does

The mutable lifecycle active FSM automation is retired. Standard GitHub project automation and keywords handle status transitions natively.

We retain lightweight automation for metadata, sync, and release promotion:
- **PR Opened**: Automatically adds `pr/needs-review` to incoming pull requests.
- **Repository Label Sync**: Synchronizes definitions from `labels.json` across all core repos.
- **Auto-Promotion (Squash PRs)**: Compares trees and automatically generates release candidate promotion PRs.

**bonedigger** handles only: ujust report issue detection/parsing and priority auto-escalation from `ujust confirm` counts (3+ → `priority/p1`, 5+ → `priority/p0`).

---

## Quick reference for new contributors

**I want to report a bug:**
→ Open an issue → use the Bug Report template → fill it out → done. Maintainers triage it.

**I want to propose a feature:**
→ Open an issue → use the Feature Request template → be specific → done. Vague proposals wait indefinitely in `status/discussing`.

**I want to implement something:**
1. Find an issue with `status/queued` in the target repo
2. Comment `/claim`
3. Read the issue + the repo's `AGENTS.md`
4. Branch, build, test, PR with "Closes #NNN"

**I'm a maintainer and want to queue work for agents:**
1. Find a triaged issue (has `kind/` and `area/` set)
2. Comment `/approve`
3. Done — automation queues it immediately

**I need to stop automation from touching something:**
→ Comment `/hold` with a reason, or add `status/hold` manually
