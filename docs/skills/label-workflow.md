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

## Issue lifecycle

Issues follow one of two entry paths depending on type, then converge into a shared pipeline:

```
BUG:     filed → [status/triage] → status/approved → status/queued → status/claimed → done
FEATURE: filed → [status/discussing] → status/approved → status/queued → status/claimed → done
```

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

Bonedigger responds by adding `status/approved` and `status/queued`.
The issue is now in the work pool.

**Manual fallback (if bonedigger is down):**
```
Add: status/approved + status/queued
```

### Reviewing agent PRs

1. Verify the diff solves the stated issue (not just technically correct — actually the right fix)
2. Check `agent-tested` is present (e2e passed)
3. If it looks good: add `lgtm` — the PR will merge when CI is green
4. If something is wrong: leave a review comment — the agent will address it on next run
5. To stop automation entirely: add `do-not-merge`

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

Comment `/claim` on the issue. Bonedigger will:
1. Replace `status/queued` with `status/claimed`
2. Assign the issue to you
3. Remove you from the available pool for this issue

**Manual fallback (if bonedigger is down):**
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
| `status/triage` | lavender | Auto on bug reports | New bug. Human must set kind/area/priority. |
| `status/discussing` | blue | Auto on features; human for bugs needing design | Under discussion. Not ready for work. |
| `status/approved` | green | Human (`/approve`) | Approved by maintainer. Ready for contributors. |
| `status/queued` | purple | Bonedigger or human | In the work pool. Comment `/claim` to take it. |
| `status/claimed` | yellow | Bonedigger or agent | Someone is actively working this. |
| `status/hold` | white | Human | Intentionally paused. Do not touch. Requires a comment explaining why. |
| `agent/blocked` | red | Agent | Agent is stuck and needs human input. Read the issue comment. |

### Kind — what type of work?

> **Invariant:** exactly one `kind/*` per issue

| Label | Meaning |
|---|---|
| `kind/bug` | Something broken |
| `kind/enhancement` | New capability — needs spec before work begins |
| `kind/improvement` | Incremental improvement to existing behavior |
| `kind/tech-debt` | Cleanup with no user-visible change |
| `kind/documentation` | Docs only |
| `kind/parity` | Behavior that differs across image variants |
| `kind/renovate` | Automated dependency update |
| `kind/epic` | Multi-issue tracking issue — no implementation here |
| `kind/wontfix` | Terminal: will not be implemented |

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

Note: `source:` uses a colon separator — this is intentional for compatibility with bonedigger's label routing.

### PR labels

> Size labels are auto-set where the bot is wired; otherwise set manually.

| Label | Meaning |
|---|---|
| `size/XS` | ~1 hour: single file |
| `size/S` | ~half day: small, well-understood change |
| `size/M` | ~1 day: moderate change across a few files |
| `size/L` | ~3 days: larger change, some design needed |
| `size/XL` | ~1 week+: significant feature or refactor |
| `lgtm` | Maintainer approved, ready to merge |
| `do-not-merge` | Never auto-merge this |
| `agent-tested` | e2e ran and passed via agent (where wired) |
| `tests:pass` | CI gate passed, enables auto-merge (where wired) |

`size/XXL` is removed from the taxonomy. PRs that large should be split. If you see one, split the PR or split the issue.

Note: `tests:pass` uses a colon separator — retained for CI automation compatibility.

### Agent flow triggers

Applied to issues to request a specific agent workflow:

| Label | Meaning |
|---|---|
| `flow/issue-review` | Agent reviews a linked issue and produces a sourced report |
| `flow/project-report` | Agent produces a project-wide status report |
| `flow/pr-review` | Agent reviews a linked PR and produces a sourced report |
| `flow/agent-donation` | Donate agent time for a specific repo, issue, or review |

### Special and automation labels

| Label | Meaning |
|---|---|
| `ai-context` | ACMM audit finding — AI/LLM context gap that improves agent reliability |
| `stale` | No recent activity; candidate for auto-close |
| `stale-digest` | Filed against an outdated image digest — verify on current image first |
| `aarch64` | ARM64-specific issue or change |
| `needs-human/agent-oops` | Agent error — do not re-run automation; fix manually |
| `dependencies` | Automated dependency update PR (Renovate) |

---

## What automation does (do not set these manually unless bonedigger is down)

| Trigger | What bonedigger does |
|---|---|
| Bug report opened | Adds `status/triage` |
| Feature request opened | Adds `status/discussing` |
| `/approve` comment | Adds `status/approved` + `status/queued` |
| `/claim` comment | Removes `status/queued`, adds `status/claimed`, assigns |
| `/unclaim` comment | Removes `status/claimed`, re-adds `status/queued`, unassigns |
| No PR activity in 7 days | Returns claim: removes `status/claimed`, re-adds `status/queued` *(target state — not fully consistent across all repos yet)* |

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
3. Done — bonedigger queues it automatically

**I need to stop automation from touching something:**
→ Add `status/hold` and leave a comment explaining why

---

## Migration status

The following labels are in the process of being retired. They remain present in some repos
while templates and automation are updated. **Do not use them for new issues.**

| Retiring | Use instead | Blocker |
|---|---|---|
| `bug` (bare) | `kind/bug` | Template update needed in common |
| `type/bug` | `kind/bug` | Template update needed in bluefin, bluefin-lts |
| `type/feature` | `kind/enhancement` | Template update needed in bluefin, bluefin-lts |
| `flow/agent-donation` (colon) | `flow/agent-donation` | Template update needed in common, bluefin, bluefin-lts |
| `needs-human/agent-ready` | `status/queued` | Docs update needed |
| `agent/claimed` | `status/claimed` | Verify no automation dependency |
| `priority/p0`, `priority/p1` | `priority/p0`, `priority/p1` | Bonedigger sets these — cannot remove until bonedigger is updated |
| `size:*` (colon variants) | `size/*` (slash variants) | Check automation consumers per repo |
| `copilot-ready` | `status/queued` | Label cleanup only |
| `hold` (bare) | `status/hold` | Verify automation consumers |

Tracking issue: file one in `projectbluefin/common` with `kind/tech-debt` + `area/agent`.
