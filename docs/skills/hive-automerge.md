---
name: hive-automerge
version: "1.0"
last_updated: 2026-08-08
id: hive-automerge
one_line_purpose: Queue reviewed PRs for Hive's auto-merge-on-green sweep.
entry_point: docs/skills/hive-automerge.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [hive, automerge, lgtm, merge-queue]
description: >-
  The Hive "Queue auto merge" feature: merger-tier queue action applying the
  `lgtm` label plus an audit approval; a per-minute sweep squash-merges
  labelled PRs once CI is green. Use when queuing a reviewed PR or listing
  what the sweep will merge.
metadata:
  type: reference
---

# Hive Auto-Merge ("Queue auto merge")

Verified against `kubestellar/hive` branch `v2` (`pkg/dashboard/api.go`,
`pkg/github/client.go`, `pkg/github/automerge_sweep.go`). The deployed spoke
revision is unknown — feature presence may bound the version but does not
identify it.

## How it works

1. **Queue action** — dashboard button or API call
   `POST /api/prs/{owner}/{repo}/{number}/queue-automerge` on the hosted Hive
   (`hosted-projectbluefin-knuckle-gjvq.hive.hivecommons.dev`). Requires
   merger/owner role; the repo must be managed by the hive; the queuer must
   not be the PR author.
2. **What queuing does** — the Hive GitHub App posts an `APPROVE` review with
   the exact body `Approved by @<user> for Hive auto-merge on green CI.` and
   adds the `lgtm` label (configurable via `governor.labels.automerge`;
   default `lgtm`, the Prow convention).
3. **The sweep** — runs every minute. Scans managed repos for open, non-draft
   PRs with the label, re-verifies the queue approval, re-checks the
   self-merge ban, requires mergeable plus **every** non-meta commit status
   and check run green (tide/netlify-style meta checks excluded; pending is
   NOT green), then squash-merges. Cap: 3 merges per sweep.

## CLI equivalent

After a human review verdict on someone else's PR:

```bash
gh pr review <N> --repo projectbluefin/<repo> --approve \
  --body "Approved by @<user> for Hive auto-merge on green CI."
gh pr edit <N> --repo projectbluefin/<repo> --add-label lgtm
```

The sweep also re-parses review bodies, so hand-applied `lgtm` without the
exact approval body is skipped with reason `no-hive-queue-approval`.

## Listing what is queued

```bash
# PRs carrying the sweep label across a repo
gh pr list --repo projectbluefin/<repo> --label lgtm \
  --json number,title,mergeStateStatus

# PRs with GitHub-native auto-merge armed (a different mechanism)
gh pr list --repo projectbluefin/<repo> \
  --json number,title,autoMergeRequest \
  --jq '.[] | select(.autoMergeRequest != null) | "\(.number)\t\(.title)"'
```

GitHub-native auto-merge (`gh pr merge --auto`) and the Hive sweep are
independent. Once a PR actually enters a GitHub merge queue,
`autoMergeRequest` reads `null` — probe with `gh pr merge <N> --auto`
("already queued") rather than re-arming blindly.

## Rules

- **Human gate first.** Queueing is an approval — it follows an explicit human
  review verdict, never precedes it.
- **Self-merge ban is enforced twice** — at queue time and again by the sweep.
  Your own PRs need a second human.
- **The sweep squash-merges directly**, bypassing any GitHub merge queue.
  Watch the first sweep merge in a merge-queue repo before relying on both
  mechanisms in the same repo.
- **`lgtm` is not one of the seven canonical workflow labels.** It is a
  merge-queue marker owned by the sweep; do not use it to express triage
  intent.
- Treat "sweep merged" as merged only after confirming on GitHub — the sweep
  logs, it does not report back into issue state.

## Red Flags

- Queueing your own PR (rejected at queue time; skipped at sweep time).
- Adding `lgtm` without the audit approval body — the sweep silently skips it.
- Assuming a `lgtm` PR will wait for a merge queue — the sweep merges
  directly once checks are green.
- Treating the label as a triage signal instead of a merge decision.

## Verification

- [ ] Human review verdict preceded the queue action.
- [ ] Queuer is not the PR author.
- [ ] Approval body matches the exact audit format.
- [ ] `lgtm` label present; PR open, non-draft, mergeable.
- [ ] Merge confirmed on GitHub after the sweep window (~1 min after green).

## See Also

- [hive.md](hive.md) — Hive coordination and the seven canonical labels
- [pr-review/references/merge-queue.md](pr-review/references/merge-queue.md) —
  GitHub merge queue defaults and `gh` traps
- [hosted-hive.md](hosted-hive.md) — hosted Hive API operations
