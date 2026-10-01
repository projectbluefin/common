---
name: bluefin-review
version: "1.0"
last_updated: "2026-09-25"
id: bluefin-review
one_line_purpose: Land the projectbluefin PR backlog under each repo's policy while a maintainer watches.
entry_point: docs/skills/bluefin-review/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [review, merge, backlog, prewalk, agents]
description: >-
  Monitored, semi-automatic PR backlog review for projectbluefin repos: the
  agent lands PRs within each repo's policy while a maintainer watches,
  planning on a strong model and executing on a fast one. Use when running
  /bluefin-review.
metadata:
  type: procedure
---

# Bluefin Review — Monitored Fix-and-Land

Unclog the open PR backlog in the `projectbluefin` repos in scope. Land each PR
or leave it where the only blocker is someone else's action. Nothing merges
without satisfying the target repo's actual branch protection and contribution
policy; never assume a fixed approval count.

## When to Use

- A maintainer runs `/bluefin-review [owner/repo]` and stays at the terminal to
  watch the run, answer gates, and stop it.
- Clearing a batch of routine PRs: green bot bumps, mechanical rebases, lint
  fixes, stale rollouts.

## When NOT to Use

- Nobody is watching: stop. Both review skills require a human at the
  terminal.
- The maintainer wants to decide every card themselves: use
  [`pr-review/SKILL.md`](../pr-review/SKILL.md).
- A PR carrying a [`human-gates.md`](../human-gates.md) decision (design,
  security, cross-repo breakage): surface it at the top of the ledger instead
  of approving.
- Any `ublue-os/*` repository. Read-only; no writes of any kind.

## Run shape and model routing

Cost comes from which model runs the loop. Harness configuration lives in
[`references/harness-setup.md`](references/harness-setup.md).

1. **Plan (planning model, omp `@default`).** Identity, scope and exclusions,
   enumeration (§2), policy tables (§3), overlap clusters, landing orders. Read
   the API only: no diff review, no worktrees, no lanes.
2. **Hand off.** `todo init` with one item per lane, then `write` the ledger's
   initial state (§8) with the harness's native `write` tool. With omp prewalk
   armed, that first write switches the session to `@smol`. A shell heredoc
   or `echo >` is a `bash` call and does not trigger the handoff. Nothing
   expensive happens before it. On 2026-09-25 the planner fanned out lanes and
   verified their claims before its first write, so the planning model ran
   the whole orchestration loop.
3. **Execute (fast model).** Fan out one lane per repo or PR cluster with
   `agent: "bluefin-review"`. The lane agent is pinned to `@smol`. Verify every
   lane claim before it enters the ledger.
4. **Next batch.** `/prewalk restart` returns the session to `@default` and
   re-arms the handoff. Re-plan, write, and execute again.

The advisor (omp `advisor` role) watches the main session only. Lanes run
without one and escalate judgment calls to the main session.

## 1. Operating mode

- Default is fix-and-land. Every review action produces an outcome: approve+merge/enqueue if sound, or fix+push+merge/enqueue once policy is met, in an isolated worktree. Never post COMMENT-state reviews, advisory summaries, or status comments. Use `--request-changes` only when an unresolvable design or product decision blocks progress.
- Comment only after pushing a fix (one comment: what conflicted, how it was resolved, which test command ran) or when closing or blocking on a design decision you cannot make for the author.
- Scope once: if the repo set is not given, ask one up-front question (e.g. Hive-tracked repos minus exclusions). Never loop on repo discovery or search the local filesystem for targets.
- Standing exclusions unless the user overrides them: `projectbluefin/bluefin`, `projectbluefin/bluefin-lts`. `gh search prs` still returns PRs on archived repos; drop them up front with one `gh repo list projectbluefin --limit 200 --json nameWithOwner,isArchived,defaultBranchRef`.
- Identity first: `gh api user -q .login`. Your approval never counts on PRs you authored or on heads you pushed (rebases, conflict fixes).
- Orchestrator: parallelize with `task`, one lane per repo or PR cluster. Give each lane the full rule set, that repo's policy table, the exact PR list, and the outcome categories. Lanes execute (rebase, test, push, merge, close); they do not return status snapshots.
- Never poll. Long CI waits go async (`gh run view <id> --json status,conclusion`), never foreground `gh run watch`; work other lanes meanwhile.
- Consult the advisor on every non-obvious call: anything merged on judgment rather than green required checks plus satisfied review requirements.
- Human-decision gates: a hive review whose body starts `HUMAN DECISION NEEDED`, or a PR that clears a supply-chain or security flag (SBOM `pendingSbom` mapping, signing, secrets inventory), is not yours to approve when your approval alone meets the threshold. Put it at the top of the ledger for the human the marker names, with the evidence you checked. website#827 merged on an agent approval this way on 2026-09-23.

## 2. Enumerate cheaply

- Per repo, one line per PR: `gh pr list -R <o>/<r> --state open --limit 500 --json number,title,author,isDraft,mergeable,reviewDecision,headRefOid,labels -q '.[]|"\(.number) \(.author.login) \(.mergeable) \(.reviewDecision) [\([.labels[].name]|join(","))] \(.title)"'`. Never bare `gh pr list` without `-R`. `hold`/`do-not-merge` rows go straight to the ledger as blocked.
- Org-wide: `gh search prs --owner projectbluefin --state open --limit 500` with `--author @me` / `--review-requested @me` / `--assignee @me`. It defaults to 30 results; always pass `--limit 500`.
- Never dump full `reviews`/`statusCheckRollup` arrays; truncation hides the fact you need. Filter:
  `--json headRefOid,reviews,statusCheckRollup -q '{head:.headRefOid[0:7],approvals:[.reviews[]|select(.state=="APPROVED")|{a:.author.login,c:.commit.oid[0:7]}],pending:[.statusCheckRollup[]|select(.status!="COMPLETED")|.name],failed:[.statusCheckRollup[]|select(.conclusion=="FAILURE")|.name]}'`
- `gh pr view -q` requires `--json`. Capture `headRefName,headRefOid,headRepositoryOwner,isCrossRepository,maintainerCanModify` and abort if any is empty.
- Never request `commits` from `gh pr list`: across a repo it exceeds GraphQL's 500,000-node limit and the call fails. Get pushers per PR only when needed: `gh pr view N -R <o>/<r> --json commits -q '[.commits[].authors[].login]|unique'`.
- Never type or reconstruct a SHA. Copy `headRefOid` from `--json` and re-read it after every push; `actions/runs?head_sha=` needs the full 40-character OID and silently returns nothing for a wrong one.
- Same-repo overlap: before approving, run `gh pr diff N -R <o>/<r> --name-only` for each open PR in the repo. PRs creating or registering the same file are a cluster (common#1146 and #1183 both added `tests/test_renovate_config.py`: land #1146, then rebase #1183).
- Diffs: `gh pr diff N > /tmp/<repo>-N.diff`, then read the file in ranges, one diff per command. Never claim a full-diff review you did not read.
- CI failures: `gh run view <id> --log-failed`; read only the error lines. Triage via API first; do not pre-create worktrees.

## 3. Policy table (per repo, before any merge)

- `gh api repos/<o>/<r>/rules/branches/<default> | jq '[.[]|{type,ruleset_id,parameters}]'` plus `CODEOWNERS`. Take `<default>` from `defaultBranchRef`; dakota's is `testing`.
- Record: required approving review count, code-owner review (+ owners), stale-review dismissal, last-push approval, extra approval for unattributed/agent commits, thread resolution, required status checks, merge queue + method, allowed merge methods, auto-merge.
- Only required checks gate merge; never call a non-required check a blocker.
- Merge-queue repos: `gh pr merge N -R <o>/<r>` with no method flags (`--squash` fails: the queue sets the strategy). A CLEAN PR enters the queue directly; confirm with `gh api graphql -f query='query{repository(owner:"<o>",name:"<r>"){pullRequest(number:N){state isInMergeQueue mergeQueueEntry{state position}}}}'` or `state: MERGED`.
- A required check that never reports means its workflow cannot run for that event: no `merge_group:` trigger (finpilot#418) or `paths-ignore` skipping docs-only PRs (common#1181). Fix the trigger in one small PR.
- Never `--admin` or any bypass. "Base branch policy prohibits the merge" means a rule is unmet; name it.

## 4. Before rebasing anything

- Check whether the default branch already supersedes it (`git log origin/main --oneline -S '<key symbol>' -- <path>`). If so, close citing the superseding commit after confirming it contains the change.
- Duplicates: diff them, keep one, close the other with a link. Clusters editing the same block: pick a landing order, rebase only the next one to land, record the order in the ledger.
- Renovate/bot branches: tick the bot's rebase checkbox; hand pushes stop Renovate maintaining the branch. Push only a required in-scope fix, with the lease (knuckle#919: `go mod tidy` for a stale `go.sum`). A major bump the image deliberately holds gets closed with that reason.
- Gating labels (`hold` etc.): check provenance with `gh api repos/<o>/<r>/issues/<N>/events` before removing. Respect human holds.
- Stale rollouts and superseded drafts: close with a one-line reason. First search open PRs for both the branch name and the head SHA; downstream repos may pin either. Close pinned consumer PRs in the same sweep.
- Never close active bug fixes or community contributions just because they have review comments or are drafts.

## 5. Workspaces, rebase, push

- Never `checkout`, switch branches, `stash`, `reset`, `clean`, or `pull` in a primary clone or dirty host tree. Work in a scratch root outside every primary clone (examples use `~/src/tmp`). Never `git pull` in the shared scratch clone either; a PR branch may be checked out there.
- Fetch a PR by refspec: `git -C ~/src/tmp/repos/<repo> fetch origin pull/<N>/head:pr-<N>`. Add a worktree only to test, resolve conflicts, or push: `git -C ~/src/tmp/repos/<repo> worktree add ~/src/tmp/wt/<repo>-<N> pr-<N>`. Remove only your own worktree; other lanes keep unpushed fixes in theirs.
- `git fetch origin` before every rebase; rebase onto the fresh default branch.
- `git diff --cc` hides main's side; read the conflicted file. Additive lists (path filters, allowlists, append-only JSONL, doc sections) take both sides. Numbered doc entries appended on both sides: keep main's numbers, renumber the PR's entry, fix its cross-references.
- omp `conflict://N`: `read` the whole marker block first (the id registers on that read), then write the resolution to `conflict://N`.
- Generated files (`docs/skills/index.json`, `index.md`, lockfiles): regenerate with the repo's generator, never hand-resolve.
- A PR whose tests invert safety guards on main is a design conflict, not a rebase: stop and say so.
- Push to the head owner's URL, never a shared `fork` remote: `git push https://github.com/<headRepositoryOwner>/<repo>.git HEAD:<headRefName> --force-with-lease=<headRefName>:<headRefOid>`, both values from `--json`. An empty lease OID creates stray branches. A fork push can 403 despite `maintainerCanModify: true` (contribute#633): record blocked(author rebase). Do not force-push a rebase onto a branch the author or a Hive lane does not own: even a mechanical rewrite drops commits on the author's branch they did not make and resets their review, so a BEHIND or conflicted contributor branch waits for its author. Only rewrite branches the agent owns (author, or a Hive lane).
- Before pushing, run what CI runs (full `pytest tests/` + `bats`, `go test ./...`, `just validate`), not one test file. Never trim a contributor's changes and call it a rebase.
- After you push, your approval no longer counts. Reuse prior approvals only after proving the rebase mechanical with `git range-diff <oldbase>..<oldhead> <newbase>..<newhead>`.
- Fork heads get `action_required` runs. Do not approve them: releasing a fork's workflow run is the one step where a person should look at what the fork's code will run in our CI, so keep approval with the human. List the waiting run IDs in the ledger as blocked(human approve) and move on. Approval starts CI; it does not pass it. An empty rollup means no run was approved yet (common#1180).
- A required check that never reported on an old head: close and reopen the PR, then re-enable auto-merge.
- Scope: rebases and lint/changelog fixes are in; refactors, new abstractions, and workarounds are out.

## 6. Failing CI

- Decide from fresh workflow evidence or a reproduction whether the PR or the infrastructure is at fault. PR at fault and fix small and in scope: fix it. Upstream: say so with evidence.
- Local tools lag (e.g. runner-label lists); prove availability from green runs in the repo before rejecting an update.

## 7. Merge gates

- Merge only when required approvals are on the current `headRefOid` from someone other than the author or pusher (count distinct approvals per commit; `reviewDecision: APPROVED` can reflect a stale head when stale reviews are not dismissed), required checks are green on that head, and build-heavy repos' own build runs finished. `cancelled` is not a pass.
- Below threshold, not your PR or push: review the diff and approve if sound; merge if that satisfies policy.
- Never leave auto-merge armed on a head you pushed while your earlier approval is still attached. With `dismiss_stale_reviews_on_push: false` GitHub keeps counting it, so the next single approval merges a PR only one independent reviewer saw (common#1181, 2026-09-25). Disarm with `gh pr merge N -R <o>/<r> --disable-auto` and record fixed+awaiting-review.
- 0-approval repos: still review, test, and wait for CI; don't stack merges on an unverified main.
- After a batch, check the default branch's post-merge runs. If your merge broke it, fix it in one small PR and mark dependent PRs blocked.
- Never fabricate evidence. "CI passed" means you read the run; "merged" means `state: MERGED`; "fixed" means you confirmed the original issue is resolved.

## 8. Ledger

- Keep a running ledger per run at `~/src/tmp/bluefin-review-ledger-<YYYY-MM-DD>-<scope>.md`, updated after every action with the native `write`/`edit` tools, never shell heredocs; its first write is the prewalk handoff. One file per run, so concurrent sweeps cannot overwrite each other. Emit it at the end or per batch. Human decisions go at the top. Carry every non-landed row forward from the previous run's ledger.
- One plain line per PR: repo#number, one-line description, outcome, and for anything not landed the single blocker and who moves next. Include cluster landing orders.
- Outcome in {merged, queued, fixed+queued, fixed+awaiting-review, reviewed+awaiting-N-approvals, closed(reason), blocked(named blocker, who moves)}. Verified facts only; no emojis.

## Red Flags

- Lanes spawned, diffs reviewed, or worktrees created before the ledger's first write.
- An approval counted on a head you pushed, or on a stale head.
- A merge on judgment without an advisor consult, or past a human-decision marker.
- `--admin`, `--no-verify`, or any other bypass.

## Verification

```bash
# Harness wiring resolves to this skill
readlink .agents/skills/bluefin-review .pi/prompts/bluefin-review.md .omp/agents/bluefin-review.md
# Live policy for a repo before merging
gh api repos/projectbluefin/common/rules/branches/main | jq '[.[]|{type,parameters}]'
```
