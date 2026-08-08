---
name: pr-review
version: "3.5"
last_updated: "2026-08-08"
id: pr-review
one_line_purpose: Run human-decides, agent-lands backlog review one card at a time.
entry_point: docs/skills/pr-review/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [review, merge, triage, backlog]
description: >-
  Human-decides, agent-lands PR and issue backlog review. Present one card at a
  time, take the human verdict, execute it immediately, then advance. Use when
  reviewing the PR queue or triaging the issue backlog.
metadata:
  type: procedure
  context7-sources:
    - /websites/github_en_actions
---

# Backlog Review — Human Decides, Agent Lands

The agent assembles facts and executes commands. The human makes every
approval, merge, close, and label decision. No exceptions.

## Contents

- [When to Use](#when-to-use)
- [When NOT to Use](#when-not-to-use)
- [Core Process](#core-process)
- [Issue Triage Sweep](#issue-triage-sweep)
- [Blast Radius Map](#blast-radius-map)
- [Merge Queue Defaults](#merge-queue-defaults)
- [gh CLI Traps](#gh-cli-traps)
- [Common Rationalizations](#common-rationalizations)
- [Red Flags](#red-flags)
- [Verification](#verification)
- [See Also](#see-also)

---

## When to Use

- Reviewing the open PR queue.
- Triaging the open issue backlog.
- A maintainer asks to "work through the backlog."

## When NOT to Use

- Reviewing a single PR you were directly asked about — just review it.
- Any repository outside `projectbluefin/*`. Never for `ublue-os/*`.
- Automated/unattended review. This skill requires a human in the loop by
  design; if no human is present, stop rather than substituting your judgment.

## Core Process

The loop: **dossier → verdict → land.**

### Cadence: stream, don't batch

Default to **streaming**: present one card, take the verdict, execute it
immediately, then present the next. The human stays engaged because every
answer produces a visible result before the next question arrives.

Batching verdicts and staging them for one bulk confirm at the end is the
fallback for non-interactive runs only. It front-loads a wall of cards, and by
the time the plan is printed the human has forgotten card 1.

Ask the maintainer which mode they want if it is not obvious. Two signals that
streaming is wanted: *"I want to be constantly engaged"* and *"one at a time."*

**Easy-wins mode.** When the maintainer says to skip complexity and exercise
the loop, sort the remaining queue ascending by `additions + deletions` and
present the small ones first. Park anything that needs deep investigation in
`3-human-queue` with a findings comment rather than burning the session on it —
the goal in this mode is throughput and rhythm, not exhaustive coverage.

### 1 — Dossier (one-call fetch)

Fetch all card data in a single API call (~2 s for 5 PRs):

```bash
gh pr list --limit 5 --json number,title,author,createdAt,additions,deletions,files,labels,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,closingIssuesReferences
```

**Bot-PR filtering** — Renovate, `mergeraptor`, and `kubestellar-hive` PRs
covered by platform auto-merge waste human slots. Filter them out by default.

> ⚠️ Fetch a WIDE window and slice to 5 *after* filtering. `--limit 5` applies
> before the filter, so a bot-heavy window yields fewer than 5 cards.

Filter on `author.is_bot` (a real boolean) rather than matching login strings —
app authors appear as `app/kubestellar-hive`, so name regexes are brittle:

```bash
# Fetch wide, drop bots, then take 5
gh pr list --limit 60 \
  --json number,title,author,createdAt,additions,deletions,files,labels,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,closingIssuesReferences \
| jq '[.[] | select(.author.is_bot | not)][:5]'
```

For a dedicated **bot sweep**, invert the selector to `select(.author.is_bot)`.

Present each PR as a one-screen card. See [references/card-fields.md](references/card-fields.md)
for field definitions and the `mergeStateStatus` table.

#### Competing-pair detection (mandatory)

Before showing verdict prompts, pairwise-intersect file paths and
`closingIssuesReferences` across the batch:

```python
import json, sys
prs = json.loads(sys.stdin.read())
for i, a in enumerate(prs):
    for b in prs[i+1:]:
        shared_files = set(f["path"] for f in a["files"]) & set(f["path"] for f in b["files"])
        shared_issues = set(r["number"] for r in a.get("closingIssuesReferences", [])) & \
                        set(r["number"] for r in b.get("closingIssuesReferences", []))
        if shared_files or shared_issues:
            print(f"⚠️  COMPETING PAIR: #{a['number']} ↔ #{b['number']}")
            if shared_files: print(f"   Files: {shared_files}")
            if shared_issues: print(f"   Issues: {shared_issues}")
```

On any overlap, print `⚠️ COMPETING PAIR` between both cards. The human must
resolve the pair (defer one, or explicitly acknowledge) before both can be
voted `merge`.

#### Duplicate-cluster resolution

A competing pair sharing a *closing issue* — or two Renovate PRs normalizing to the *same dependency* — is one piece of work twice, not an ordering hazard. Resolve the cluster as a unit, halting on the first failure:
**(1)** the human names the survivor from presented diff evidence (`gh pr diff` works for fork heads); **(2)** arm the survivor first: `gh pr merge <S> --squash --auto --match-head-commit <sha>` with the SHA read live, so a push before landing is a server-side refusal;
**(3)** comment on each superseded PR naming survivor and evidence (`--body-file`, never `--body` with prose through a shell); **(4)** close it — never `--reason "not planned"`, never a label swap;
**(5)** re-check linked issues per rule 3 below — a still-open issue with no remaining open PR is a finding to report, not something to silently fix.

#### CI card classification

Classify every red before it costs the human a slot. Full triage procedure,
including the failing-step lookup and the infra-flake correlation check:
[references/red-check-triage.md](references/red-check-triage.md).

| Kind | Action |
|---|---|
| **stale-red** | Fix already on `main` — `gh pr update-branch <N>` |
| **infra-flake** | HTTP 403/429/5xx or timeout — re-run, then file the fragility |
| **fork-expected** | `Compose PR test image` on a fork — expected, not blocking |
| **bad-title** | Retitle, then see the retitle invariant below |
| **real failure** | Report to human as blocking |

#### Dismissed-approval regression check (mandatory)

A `DISMISSED` review is not merely a stale approval to be re-collected. The
dismissal exists **because the head moved**, and the commits that moved it can
undo the very thing the reviewer approved — while every check stays green.

Never re-approve on the strength of a prior approval. Diff the current head
against the approved commit, then read the dismissed reviewer's concerns as a
checklist against that head:

```bash
gh api repos/{owner}/{repo}/pulls/<N>/reviews \
  --jq '.[] | select(.state == "APPROVED" or .state == "DISMISSED")
        | {user: .user.login, state: .state, sha: .commit_id}'
git diff <approved_sha>...<current_head>
```

Full procedure and the table of regressions CI cannot see:
[references/dismissed-approval.md](references/dismissed-approval.md).

### 2 — Verdict

Prompt the human **per PR, one at a time**. Use `gum choose` when available:

```bash
gum choose "merge" "close" "defer" "rebase" "changes" "open" "skip" \
  --header "PR #${N} — ${TITLE}"
```

For `open`, show the diff: `gh pr diff ${N} --color=always | glow -`

Plain-text fallback for non-interactive runs: print verdict vocabulary and read
from stdin.

PR verdict vocabulary:

| Verdict | Effect |
|---|---|
| `merge` | Squash-merge via merge queue |
| `close` | Close with the human's stated reason |
| `defer` | Leave open, move to next |
| `rebase` | Update branch, re-present later |
| `changes` | Request changes with the human's exact words |
| `open` | Show the full diff before deciding |
| `skip` | Move to next, no action |

### 3 — Land

In streaming mode, execute the verdict as soon as it is given, then report the
outcome in one line and move to the next card.

In batch fallback mode, print the **complete action plan** as exact `gh`
commands after all verdicts and gate it on `gum confirm "Execute action plan?"`.
Nothing is written before the human confirms.

**Halt-on-overlap rule:** if a merge command fails, halt any remaining staged
action whose file list or closing-issue set intersects the failed PR's. Report
the conflict and ask the human whether to proceed with the unaffected remainder.

**Batch safety:** GitHub's merge queue (`ALLGREEN` grouping) automatically
evicts a failing PR and re-tests the remaining group. A single bad PR does NOT
delay the rest — so it is safe to arm several PRs across a session.

### Landing invariants

Three things are easy to forget and leave the backlog inconsistent. Check all
of them after every verdict that closes or parks something.

**1. Queue labels are a swap, never an add.** `3-human-queue` and
`3-clanker-queue` are mutually exclusive. Deferring to a human means removing
the clanker label in the same command, on the PR *and* its linked issue:

```bash
gh issue edit <N> --add-label 3-human-queue --remove-label 3-clanker-queue
```

An item carrying both labels gives routing automation ambiguous input.

**2. Retitling requires a fresh `pull_request` event.** `validate.yml` triggers
on `pull_request` with **no `types:` filter**. Per GitHub's
[events reference](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows),
the default activity types are `opened`, `synchronize`, and `reopened` — and
`edited` is *not* among them.

Two consequences, both counter-intuitive:

- Editing the title does **not** re-run the Conventional Commits check.
- `gh run rerun --failed` does not help either. A rerun replays the **original
  event payload**, so the job re-reads the *old* title and fails identically.

Without a new commit to push, the only way to fire a qualifying event is to
close and reopen:

```bash
gh pr edit <N> --title "test: <conventional title>"
gh pr close <N> && sleep 3 && gh pr reopen <N>   # fires `reopened`
```

Verify the check actually re-ran against the new title rather than assuming:

```bash
gh pr view <N> --json title,statusCheckRollup \
  --jq '{title, validate: [.statusCheckRollup[]|select(.name=="validate")|"\(.conclusion)|\(.status)"]}'
```

> A `bad-title` card is therefore never a one-command fix. Budget the reopen,
> and expect the full check suite to re-run from scratch afterwards.

**3. Closing a PR does not close its issue.** GitHub only auto-closes a linked
issue when the PR **merges**. Closing a PR as redundant or superseded leaves
its `Closes #NNN` issue open forever. After any close, re-check the link:

```bash
gh pr view <N> --json closingIssuesReferences --jq '[.closingIssuesReferences[].number]'
gh issue view <ISSUE> --json state --jq .state
```

Then decide explicitly:

| Situation | Action |
|---|---|
| A sibling PR still fixes it | Leave open — it closes on that merge |
| Fix already landed elsewhere | Close as duplicate, link the merged PR |
| The premise was wrong | Close as `not planned` with the evidence |

Sweep the whole session before finishing:

```bash
# Any issue still open whose only PR was closed unmerged?
gh pr list --state closed --limit 30 --json number,state,closingIssuesReferences \
  --jq '.[]|select(.state=="CLOSED")|select(.closingIssuesReferences|length>0)
        |"PR#\(.number) -> \([.closingIssuesReferences[].number])"'
```

---

## Issue Triage Sweep

Same dossier → verdict → stage → land loop, with issue verdicts:

| Verdict | Effect |
|---|---|
| `close` | Close with the human's stated reason |
| `label <name>` | Apply a label — only the 7 canonical labels per [label-workflow](../label-workflow.md). Queue labels swap, never stack |
| `assign` | Assign to a user or bot |
| `dup <#>` | Close as duplicate, link to the original |
| `wrongrepo <repo>` | Transfer or close with redirect |
| `needsinfo` | Comment requesting more information |
| `defer` | Leave open |

---

## Blast Radius Map

| Path pattern | Affects | Fast-lane eligible? |
|---|---|---|
| `system_files/shared/` | bluefin + bluefin-lts + dakota | **Never** |
| `system_files/bluefin/` | GNOME / Bluefin only | No |
| `system_files/nvidia/` | NVIDIA overlay | No |
| `.github/workflows/` | CI pipeline | No |
| `Containerfile` | ALL variants | No |
| `docs/**`, `AGENTS.md` | Documentation only | N/A (doc-only push) |
| `tests/**` | Test suite only | N/A |

---

## Merge Queue Defaults

| Setting | Value |
|---|---|
| Merge method | Squash only (`allow_rebase_merge: false`) |
| Grouping strategy | `ALLGREEN` ("only merge non-failing pull requests") |
| Max entries to build | 5 |
| Required checks | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |
| Required approvals | **0** — and no code-owner review |

> ⚠️ The ruleset is named `main-review-required-with-renovate-bypass`, but the
> live rule requires **no** approval and **no** code-owner review. Never infer
> approval behavior from the ruleset name — read the live parameters.

Because approvals are not enforced, the human verdict in this loop is the only
real review gate on `main`. Treat it accordingly.

E2E checks are **informational** — they do not block merging. Only the required
checks listed above gate a merge.

Default landing command:

```bash
# Squash-merge via the merge queue
gh pr merge <N> --squash --auto
```

> ⚠️ Do NOT use `--delete-branch` — the repo has `deleteBranchOnMerge: true`
> and the flag **hard-fails** when a merge queue is enabled.

`--admin` bypasses the queue and merges immediately. It requires **explicit
human instruction** per PR — never default to it.

```bash
# Admin merge — ONLY when the human explicitly says so
gh pr merge <N> --squash --admin
```

### Reading queue state

`autoMergeRequest` reads `null` once a PR has actually **entered** the merge
queue — the queue entry supersedes the auto-merge request. Do not treat that as
"auto-merge fell off" and re-arm blindly. Probe instead:

```bash
gh pr merge <N> --auto   # → "is already queued to merge" means it IS queued
```

`mergeStateStatus` also goes `UNKNOWN` for a minute or two while GitHub
recomputes mergeability after anything lands on `main`. That is not an error;
poll again rather than acting on it.

> ⚠️ Pushing directly to `main` — including the doc-only exception — bumps every
> queued PR behind the new head. Re-check the armed set after any direct push.

### Updating branches

`gh pr update-branch <N>` (default merge mode) works for both main-repo and
fork PRs — it is a server-side GitHub operation.

> The `--rebase` flag does NOT work on fork PRs (requires force-push across
> permission boundaries). Use the default merge mode.

### Fork PR rebase (when update-branch is insufficient)

When a fork PR has real conflicts that require manual resolution:

```bash
gh pr view <N> --json headRefName,headRepository \
  --jq '{branch: .headRefName, repo: .headRepository.nameWithOwner}'

git fetch https://github.com/<fork-owner>/common.git <branch>
git checkout -b <branch>-rebase FETCH_HEAD
git rebase origin/main
# resolve conflicts…
git push origin <branch>-rebase
gh pr create --base main --head <branch>-rebase \
  --title "<original title>" \
  --body "Rebased from #N. Co-authored-by: <original-author>"
```

---

## gh CLI Traps

Two shell-level traps that cost real session time:
`--body` runs prose through the shell (use `--body-file` with a quoted
heredoc), and non-trivial `--jq` expressions error rather than filter.
Details: [references/red-check-triage.md](references/red-check-triage.md#gh-cli-traps).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This one is obviously fine, I'll just merge it." | The human verdict is the only review gate on `main` — approvals are not enforced. Merging without one means the change had zero review. |
| "The PR says it fixes issue N, so closing the PR closes N." | Only a **merge** closes the linked issue. Closing leaves it open forever. |
| "I'll add `3-human-queue` and sort the labels out later." | Later never comes, and routing automation sees ambiguous state in the meantime. Swap in the same command. |
| "Both PRs touch the same file, so one must be a duplicate." | Same file, different bug, is common. Compare the actual hunks and the closing-issue sets before calling it. |
| "The doc change is small, I'll push to main and keep going." | Direct pushes bump every queued PR. Cheap to re-check, expensive to discover a week later. |
| "The maintainer will not want to be asked about this one." | Ask. Deferring to `3-human-queue` with findings is always available; guessing their verdict is not. |
| "The check is red, so the PR is broken." | Most reds here are environmental. A one-line digest bump cannot cause an HTTP 403. Classify the red before it costs the human a slot. |
| "I retitled it, so the title check will pass now." | It will not. `edited` is not a trigger, and a rerun replays the stale payload. Close and reopen, then verify. |
| "A flake re-run with no issue filed" is fine. | Re-running unblocks the PR; it leaves the flake in place for the next agent. File the fragility as an issue in the same breath. |
| "It was approved before, so I just need a fresh rubber-stamp." | The approval was dismissed because the head moved. Those commits can revert what the reviewer approved — and still pass CI. Diff against the approved SHA. |
| "The reviewer already confirmed that concern was fixed." | They confirmed it against a head that no longer exists. Re-verify every resolved concern against the current head. |
| "The value is correct, so the pin is fine." | A mutable tag that resolves to the right commit today is still mutable. Correct-now is not the same as pinned. |

## Red Flags

- Agent states an opinion on whether a PR should be merged.
- Agent approves, merges, closes, or labels without an explicit human verdict.
- `--admin` merge used without explicit human instruction.
- `--delete-branch` used (hard-fails with merge queue).
- `system_files/shared/` change treated as trivial or fast-laned.
- Batch executed before the human confirms the staged plan.
- Competing PRs both staged for merge without human acknowledgment.
- A PR closed without checking whether its `Closes #NNN` issue is now orphaned.
- `3-human-queue` and `3-clanker-queue` present on the same item.
- Re-arming auto-merge because `autoMergeRequest` was `null`, without first
  probing whether the PR is already queued.
- A PR parked or reported as blocked on a red check that was never classified.
- A network/API traceback (`HTTPError`, timeout, 5xx) treated as a verdict on
  the diff.
- A title fix declared done without a close/reopen and a re-read of the check.
- A flake re-run with no issue filed against the check that flaked.
- A PR with a `DISMISSED` approval re-reviewed without diffing the current head
  against the commit that was approved.
- A previously-fixed concern assumed still fixed because a reviewer once said so.
- A dependency, action, or source checkout pinned to a tag or branch rather than
  a digest or commit SHA.

## Verification

### Behavioral checklist

- [ ] Every `gh pr merge` / `gh pr close` was preceded by an explicit human verdict.
- [ ] No approval judgment or recommendation appears in dossier cards.
- [ ] `--admin` was used only when the human explicitly said so.
- [ ] `system_files/shared/` PRs were flagged as ALL-variant blast radius.
- [ ] The four [human decision gates](../human-gates.md) were respected.
- [ ] Competing pairs were detected and resolved before staging merges.
- [ ] The orphaned-issue sweep was run before ending the session.
- [ ] No item carries both queue labels.
- [ ] Every red check presented to the human was classified, not just reported.
- [ ] Every infra-flake re-run has a corresponding issue filed against the check.
- [ ] Every retitled PR was closed/reopened and its check re-read as green.
- [ ] Every PR carrying a `DISMISSED` review was diffed from the approved SHA to
      the current head, and each concern the reviewer marked resolved was
      re-verified against that head.
- [ ] Any third-party config keys, enum values, or state paths the diff ships
      were checked against the upstream project's own docs or source — a
      plausible-looking key passes lint and CI and still renders as the raw
      identifier to users.

### Re-derivation commands

Verify the repo merge settings and rulesets with:

```bash
# Merge settings (deleteBranchOnMerge, squashMergeAllowed)
gh repo view --json deleteBranchOnMerge,squashMergeAllowed

# Rulesets and required checks
gh api repos/projectbluefin/common/rulesets

# Confirm merge queue behavior
gh api repos/projectbluefin/common/rulesets | jq '.[].rules[] | select(.type == "merge_queue")'
```

## See Also

- [references/card-fields.md](references/card-fields.md) — full card field reference and `mergeStateStatus` table
- [references/red-check-triage.md](references/red-check-triage.md) — classifying red checks, infra-flake correlation, `gh` CLI traps
- [references/worked-example.md](references/worked-example.md) — worked example session
- [queue-feed.md](../queue-feed.md) — optional cheap first-pass source list (read-only, non-authoritative; every card fact must be verified live)
- [human-gates.md](../human-gates.md) — the four human decision gates
- [label-workflow.md](../label-workflow.md) — canonical label lifecycle
- [governance.md](../governance.md) — branch protection and ownership
- [shell-scripts.md](../shell-scripts.md) — shell review patterns and bats testing
- [ci-tooling.md](../ci-tooling.md) — CI workflow review and SHA pinning
- [lab-testing/SKILL.md](../lab-testing/SKILL.md) — lab verification
