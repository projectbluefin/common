---
name: label-workflow
description: "Label taxonomy, issue lifecycle, and workflow guidelines for contributors and agents in projectbluefin factory repos."
---

# Label Workflow — projectbluefin Factory

## The one-line model

**Humans decide what gets built. Agents build it.**

Humans file, triage, and approve work. Agents claim, implement, and ship it.
Labels are the handoff signal between the two.

---

## Automation ownership

The lifecycle automation lives in **`projectbluefin/common/.github/workflows/lifecycle.yml`**
and is called by every factory repo. Common owns:

- Label definitions (`labels.json`, 67 labels) and cross-repo sync (`sync-labels.yml`)
  > ⚠️ `sync-labels.yml` requires `MERGERAPTOR_APP_ID` + `MERGERAPTOR_PRIVATE_KEY` org secrets to push to downstream repos. See issue #511.
- Slash commands (`/approve`, `/claim`, `/unclaim`, `/wontfix`, `/hold`, `/unhold`)
- Issue widget (the pipeline status block embedded in each issue body)
- Label guard (blocks `/approve` if `kind/` or `area/` is missing)
- Stale-claim sweep (daily — returns inactive claims after 7 days)

**bonedigger** handles only: `ujust report` issue filing and priority auto-escalation from `ujust confirm` counts.

---

## Next-step reference

Every issue and PR always has exactly one actor who owns it. The issue body widget shows your current stage and the exact next action. Find the active label below if you need the quick lookup.

### Issues

| Label | 🟠 Actor | Next action |
|---|---|---|
| `status/triage` | **Human** triager | Set `kind/` + `area/`, then comment `/approve` or add `status/discussing` |
| `status/discussing` | **Human** maintainer | Drive to consensus, update spec in issue body, then comment `/approve` |
| `status/queued` | **Agent** / contributor | Comment `/claim` |
| `status/claimed` | **Agent** | Implement → open PR with `Closes #NNN` |
| `agent/blocked` | **Human** | Read the issue comment → unblock → remove label |
| `status/hold` | *nobody* | Intentionally paused — read comments for reason |

### PRs

| Label | 🟠 Actor | Next action |
|---|---|---|
| `pr/needs-review` | **Human** reviewer | Review → add `lgtm` or request changes |
| `lgtm` + CI green | *automation* | Merges automatically |
| Changes requested | **Agent** | Address feedback → re-request review |
| `do-not-merge` | **Human** | Investigate → remove when resolved |

---

## Issue lifecycle

Issues follow one of two entry paths depending on type, then converge into a shared pipeline:

```
BUG:     filed → status/triage    → status/queued → status/claimed → done
FEATURE: filed → status/discussing → status/queued → status/claimed → done
```

`/approve` moves an issue directly to `status/queued`. There is no intermediate `status/approved` label.

Blocking overlays (can be applied at any stage):
- `status/hold` — paused intentionally, do not touch
- `agent/blocked` — agent stuck, needs human input

---

## Human workflow

### Filing an issue

Use the issue templates — they set the right initial labels automatically.

If filing without a template, include enough context that someone else can act on it without asking you follow-up questions. Issues that require clarification stay in triage indefinitely.

**Bug reports** get `status/triage` automatically.
**Feature requests** get `status/discussing` automatically.

### Triaging a bug (maintainers and triagers)

When you see `status/triage`:

1. Is this valid? Is it a duplicate?
   - Invalid or duplicate → close with explanation; add `kind/wontfix` if you want to track the decision
   - Needs more data → ask for `ujust report` output in a comment, leave `status/triage` in place
2. Set **exactly one** `kind/` label
3. Set **one or more** `area/` labels
4. Optionally set one `priority/` label (backlog ordering) or `hive/p0`/`hive/p1` (current-cycle urgency)
5. Remove `status/triage`

If the bug needs design discussion before anyone implements a fix, add `status/discussing` after removing `status/triage`.

### Advancing a feature discussion

When an issue in `status/discussing` reaches consensus on approach:

1. Update the issue description with the agreed spec — it needs to be clear enough for a contributor who wasn't part of the discussion to act on it
2. Comment `/approve`

### Approving work

When an issue is fully scoped and ready for implementation:

- Comment `/approve`

The lifecycle automation checks that the issue has exactly one `kind/` label and at least one
`area/` label. If either is missing, the command is rejected with an explanation.
On success, `status/triage` / `status/discussing` is removed and `status/queued` is added.
The issue widget updates to show the new stage and next action.

**Manual fallback (if automation is down):**
```
Add: status/queued
Remove: status/triage (or status/discussing)
```

### Reviewing agent PRs

PRs opened by agents carry `pr/needs-review` automatically. When you see it:

1. Verify the diff solves the stated issue (not just technically correct — actually the right fix)
2. Check `agent-tested` is present (e2e passed)
3. If it looks good: add `lgtm` — the PR will merge when CI is green
4. If something is wrong: leave a review comment — the agent will address it on next run
5. To block merge entirely: add `do-not-merge`

### Unblocking a stuck agent

When an issue has `agent/blocked`:

1. Read the comment the agent left — it will state exactly what it needs
2. Provide the answer or decision as a comment on the issue
3. Remove `agent/blocked`

The agent resumes on its next run.

### Pausing work

- `status/hold` — add to prevent any agent from claiming. Always add a comment explaining why and when it can be unpaused.
- `needs-human/agent-oops` — agent made an error that requires manual correction. Do not re-trigger agents on this issue; fix the underlying problem by hand first.

---

## Agent workflow

### Finding work

```bash
# All factory repos — start here
gh search issues --label "status/queued" --owner projectbluefin --state open

# Single repo
gh issue list --repo projectbluefin/common --label "status/queued" --state open

# Live hive snapshot (if available)
just hive   # from ~/src
```

**Pick order:** `hive/p0` first → `hive/p1` → `priority/p0` → `priority/p1` → `priority/p2` → unlabeled.

Check each candidate issue for `status/hold` before claiming — those are off-limits.

### Claiming an issue

Comment `/claim` on the issue. The lifecycle automation will:
1. Replace `status/queued` with `status/claimed`
2. Assign the issue to you
3. Update the issue widget

**Manual fallback (if automation is down):**
```
Add: status/claimed
Remove: status/queued
Assign: yourself
```

### Working

- Read the target repo's `AGENTS.md` — it specifies the required validation commands for that repo
- Create a branch: `fix/NNN-short-description` or `feat/NNN-short-description`
- Run the repo's validation gate before every commit (see `AGENTS.md`)
- Follow Conventional Commits for PR titles: `fix:`, `feat:`, `chore:`, etc.

### Signaling a blocker

When you cannot proceed without a human decision:

1. Add `agent/blocked` to the **issue** (not the PR)
2. Comment on the issue with:
   - What you need (specific, not vague)
   - Why you're blocked (the exact ambiguity or missing information)
   - What the options are, if you can enumerate them
3. Stop. Do not open a partial PR. Do not guess.

### Opening a PR

- Title: Conventional Commits format (`fix: ...`, `feat: ...`, `chore(deps): ...`)
- Body: `Closes #NNN` + what changed + why
- Follow the target repo's `AGENTS.md` for attribution trailers
- Labels are set automatically where wired: `source:agent`, `size/*`, `agent-tested` after e2e

### Unclaiming

If you cannot finish the work:
```
Comment: /unclaim
```

**Manual fallback:**
```
Remove: status/claimed
Add: status/queued
Unassign yourself
```

---

## Label reference

### Lifecycle — defines where an issue is

> **Invariants:** at most one lifecycle label active at a time (except overlays `status/hold` and `agent/blocked`, which can coexist with any stage)

| Label | Color | Who sets it | Meaning |
|---|---|---|---|
| `status/triage` | 🟣 lavender | Auto on issue open | New issue. Human: set `kind/` + `area/`, then comment `/approve` or add `status/discussing`. |
| `status/discussing` | 🔵 blue | Auto on features; human for bugs needing design | Under discussion. Human: reach consensus, update spec, then comment `/approve`. |
| `status/queued` | 🟣 purple | Lifecycle automation (`/approve`) | In the work pool. Contributor: comment `/claim` to take it. |
| `status/claimed` | 🟡 amber | Lifecycle automation (`/claim`) | Actively being worked. Owner: open PR with `Closes #NNN`. |
| `status/hold` | ⬜ gray | Human | Off-limits — do not claim or touch. Read comments for reason. |
| `agent/blocked` | 🔴 red | Agent | Agent stuck; needs human decision. Read the issue comment. |

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

All lifecycle automation runs from `projectbluefin/common/.github/workflows/lifecycle.yml`.
Do not set these labels manually unless the workflow is down.

| Trigger | What the lifecycle workflow does |
|---|---|
| Issue opened | Adds `status/triage`, inserts pipeline widget in issue body |
| Issue labeled (`kind/enhancement` + `size/L` or `size/XL`) | Posts one-time epic-check comment if `kind/epic` not present and reminder not yet sent |
| `/approve` comment (write+) | **Guard:** checks for `kind/` + `area/`. Rejects with comment if missing. On pass: removes `status/triage`/`status/discussing`, adds `status/queued`, updates widget. |
| `/claim` comment | Removes `status/queued`, adds `status/claimed`, assigns commenter, updates widget |
| `/unclaim` comment | Removes `status/claimed`, re-adds `status/queued`, unassigns, updates widget |
| `/wontfix [reason]` (write+) | Adds `kind/wontfix`, closes issue as not-planned, posts reason |
| `/hold [reason]` (write+) | Adds `status/hold`, posts comment with reason |
| `/unhold` (write+) | Removes `status/hold`, posts comment |
| PR opened | Adds `pr/needs-review` |
| Daily schedule | Stale sweep: any `status/claimed` issue with no activity for 7 days is returned to `status/queued` |

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
