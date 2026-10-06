---
name: pr-review
version: "3.7"
last_updated: "2026-09-25"
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

## When to Use

- Reviewing the open PR queue.
- Triaging the open issue backlog.
- A maintainer asks to "work through the backlog."

## When NOT to Use

- Reviewing a single PR you were directly asked about — just review it.
- Any repository outside `projectbluefin/*`. Never for `ublue-os/*`.
- Automated/unattended review. This skill requires a human in the loop by
  design; if no human is present, stop rather than substituting your judgment.
- A maintainer-run `/bluefin-review` sweep, where the agent lands PRs within
  repo policy while the maintainer watches — use
  [`bluefin-review/SKILL.md`](../bluefin-review/SKILL.md).

## Core Process

The loop: **dossier → verdict → land.**

### 0 — Sources (queue sweep)

For "let's review <repo> PRs" the agent assembles the list from three sources, in order:

1. **Queue feed** (cheap first pass, non-authoritative):
   ```bash
   curl --fail --silent --show-error --location --max-time 20 \
     https://projectbluefin.github.io/review/queue.json |
     jq -r '.items[] | select(.repository == "projectbluefin/<repo>") | [.recommended_action, .number, .title] | @tsv'
   ```
   `ready-for-human-merge` items go first. Verify every fact live — the feed is a snapshot, not authority. See [queue-feed.md](../queue-feed.md).
2. **Auto-merge-armed scan** — PRs a human already queued with `gh pr merge --auto` (or the Hive sweep label):
   ```bash
   gh pr list --repo projectbluefin/<repo> --json number,title,autoMergeRequest \
     --jq '.[] | select(.autoMergeRequest != null) | "\(.number)\t\(.title)"'
   gh pr list --repo projectbluefin/<repo> --label lgtm --json number,title,mergeStateStatus
   ```
   Armed/labelled PRs still show up in the review queue: the human verdict is the only real gate (required approvals are 0 — see [references/merge-queue.md](references/merge-queue.md)). For the Hive sweep contract, see [hive-automerge.md](../hive-automerge.md).
3. **Live GitHub state** — the dossier fetch below is the authority.

### Cadence: stream, don't batch

Use **streaming**: present one card, take that item's human verdict, execute it immediately, then advance. A non-interactive run stops before any mutation; it cannot substitute one confirmation for multiple verdicts.

**Easy-wins mode.** Check current security, release and cross-repo blockers
before sorting ordinary work ascending by `additions + deletions`; present
small ones first. In common, park complex work with a human-directed `hold`
and findings; PRs retain native assignment and review state. Other repositories
follow their local queue contract. An unapproved draft never supplies queue policy.

### 1 — Dossier (one-call fetch)

```bash
gh pr list --limit 60 \
  --json number,title,author,createdAt,headRefOid,additions,deletions,files,labels,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,closingIssuesReferences \
| jq '[.[] | select(.author.is_bot | not)][:5]'
```

Filter on `author.is_bot` (real boolean). Fetch a WIDE window then slice to 5 *after* filtering. For a bot sweep, invert to `select(.author.is_bot)`. Capture `headRefOid` with the card and diff before the human verdict; retain it for any merge. Field definitions and the `mergeStateStatus` table: [references/card-fields.md](references/card-fields.md).

- **Competing-pair detection (mandatory):** pairwise-intersect file paths and `closingIssuesReferences` across the batch. Print `⚠️ COMPETING PAIR` on any overlap — human must resolve before both can be voted `merge`.
- **Duplicate-cluster resolution:** a pair sharing a *closing issue*, or two Renovate PRs normalizing to the *same dependency*, is one piece of work twice — resolve as a unit, arming the survivor before closing the rest. Full procedure: [references/duplicate-cluster.md](references/duplicate-cluster.md).
- **CI card classification:** classify every red before it costs a human slot. Full procedure: [references/red-check-triage.md](references/red-check-triage.md).
- **Dismissed-approval check (mandatory):** diff current head against the approved commit SHA. Full procedure: [references/dismissed-approval.md](references/dismissed-approval.md).

### 2 — Verdict

Prompt the human **per PR, one at a time**:

```bash
gum choose "merge" "queue" "close" "defer" "rebase" "changes" "open" "skip" \
  --header "PR #${N} — ${TITLE}"
```

| Verdict | Effect |
|---|---|
| `merge` | Squash-merge via merge queue |
| `queue` | Hive auto-merge: audit approval + `lgtm` label (others' PRs only — see [hive-automerge.md](../hive-automerge.md)) |
| `close` | Close with the human's stated reason |
| `defer` | Leave open, move to next |
| `rebase` | Update branch, re-present later |
| `changes` | Request changes with the human's exact words |
| `open` | Show the full diff before deciding |
| `skip` | Move to next, no action |

### 3 — Land

Execute each verdict immediately after its own human keypress. Never stage a
multi-item command plan behind one `gum confirm`.
For `merge`, pass the captured head SHA to `--match-head-commit`; a changed
head requires a new diff and a new per-item verdict, never a fresh SHA at land.

**Three landing invariants** — check after every verdict that closes or parks:

1. **Respect the target lifecycle.** Common PRs use native assignment and review
   status, not numbered queue labels; preserve the linked issue's stage and gates.
   Elsewhere, legacy queue labels (`3-human-queue` / `3-clanker-queue`) swap
   in the same command only under that repository's local unmigrated contract.

2. **Retitling requires close/reopen.** `edited` is not a trigger for
   `validate.yml`. A rerun replays the stale payload. Close, reopen, re-verify.

3. **Closing a PR does not close its issue.** Only a merge does. Re-check the
   link after any close and decide explicitly.

See [references/merge-queue.md](references/merge-queue.md) for landing commands,
queue state reading, branch update, and fork PR rebase.

---

## Red Flags

- Agent states an opinion on whether a PR should be merged.
- Agent approves, merges, closes, or labels without an explicit human verdict.
- `queue` verdict applied to the human's own PR (Hive self-merge ban).
- `lgtm` added without the exact audit approval body — the sweep skips it.
- Any `--admin` override; the human gate does not permit a tool to bypass rulesets.
- `--delete-branch` used (hard-fails with merge queue).
- `system_files/shared/` change treated as trivial or fast-laned.
- Multiple PRs mutated behind one batch confirmation instead of per-item verdicts.
- Competing PRs both staged for merge without human acknowledgment.
- A PR closed without checking whether its `Closes #NNN` issue is now orphaned.
- Numbered queue labels on a common PR, or conflicting queues elsewhere.
- Re-arming auto-merge because `autoMergeRequest` was `null`, without a read-only queue check.
- A title fix declared done without a close/reopen and re-read of the check.
- A flake re-run with no issue filed against the check that flaked.
- A PR with a `DISMISSED` approval re-reviewed without diffing the current head.

---

## Verification

- [ ] Every `gh pr merge` / `gh pr close` was preceded by an explicit human verdict.
- [ ] No approval judgment or recommendation appears in dossier cards.
- [ ] No `--admin` override was used; every merge was pinned to the head reviewed by the human.
- [ ] `system_files/shared/` PRs were flagged as ALL-variant blast radius.
- [ ] The four [human decision gates](../human-gates.md) were respected.
- [ ] Competing pairs detected and resolved before staging merges.
- [ ] The orphaned-issue sweep was run before ending the session.
- [ ] No item carries both queue labels.
- [ ] Every red check was classified, not just reported.
- [ ] Every infra-flake re-run has a corresponding issue filed.
- [ ] Every retitled PR was closed/reopened and its check re-read as green.
- [ ] Every `DISMISSED` review was diffed from the approved SHA to current head.

---

## References

| File | Contents |
|---|---|
| [references/card-fields.md](references/card-fields.md) | Full card field reference and `mergeStateStatus` table |
| [references/duplicate-cluster.md](references/duplicate-cluster.md) | Duplicate-cluster resolution: arm the survivor, then close the rest |
| [references/red-check-triage.md](references/red-check-triage.md) | Classifying red checks, infra-flake correlation, `gh` CLI traps |
| [references/dismissed-approval.md](references/dismissed-approval.md) | Dismissed-approval regression check procedure |
| [references/stale-snapshots.md](references/stale-snapshots.md) | Re-verifying strategist/roadmap metrics before acting on a finding |
| [references/merge-queue.md](references/merge-queue.md) | Merge queue defaults, landing commands, fork PR rebase |
| [references/triage-operations.md](references/triage-operations.md) | Issue triage verdicts and blast radius map |
| [references/common-rationalizations.md](references/common-rationalizations.md) | Common rationalizations and why they are wrong |

## See Also

- [queue-feed.md](../queue-feed.md) — optional cheap first-pass source list (non-authoritative; verify every fact live)
- [hive-automerge.md](../hive-automerge.md) — Hive "Queue auto merge" sweep contract (`lgtm` label + audit approval)
- [human-gates.md](../human-gates.md) — the four human decision gates
- [label-workflow.md](../label-workflow.md) — canonical label lifecycle
- [governance.md](../governance.md) — branch protection and ownership
- [shell-scripts/SKILL.md](../shell-scripts/SKILL.md) — shell review patterns and bats testing
- [ci-tooling/SKILL.md](../ci-tooling/SKILL.md) — CI workflow review and SHA pinning
- [lab-testing/SKILL.md](../lab-testing/SKILL.md) — lab verification
