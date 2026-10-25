---
name: label-workflow
version: "3.0"
last_updated: "2026-09-13"
id: label-workflow
one_line_purpose: Route factory work using the canonical label workflow.
entry_point: docs/skills/label-workflow.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [labels, issues, workflow]
description: >-
  The single label authority for the projectbluefin org: the seven canonical
  workflow-state labels, their measured adoption, and the other label families
  that coexist with them. Use when triaging, routing, or reviewing work.
metadata:
  type: procedure
---

# Label Workflow — projectbluefin

This file is the only place the label vocabulary is defined. Every other doc
links here instead of restating a table.

## The seven canonical workflow-state labels

| Label | Meaning | Who sets it |
|---|---|---|
| `1-triage` | Filed, awaiting a human read | Issue form (`labels: ["1-triage"]`), or a human |
| `2-discussing` | Needs a decision or a clearer spec | Human |
| `3-human-queue` | Accepted, queued for a person | Human |
| `3-clanker-queue` | Accepted, queued for an agent | Human, or Hive |
| `4-review` | A pull request is open and awaiting review | Human, or Hive |
| `blocked` | Waiting on human input or an external dependency | Human |
| `hold` | Intentionally paused | Human |

At most one numbered label at a time. `blocked` and `hold` are overlays that
may sit on top of a numbered label. `3-human-queue` and `3-clanker-queue` are
mutually exclusive — swap them, never add.

These seven are *workflow state*. They are not the only labels in the org, and
claiming otherwise has been false in every repo for as long as the org has had
more than one repo.

## The vocabulary Hive expects

Hive (`kubestellar-hive[bot]`) stamps four **orthogonal** namespaces. They are
not alternatives to each other and never conflict: an item normally carries one
label from each.

| Namespace | Labels | Answers |
|---|---|---|
| Workflow state | the seven above | where in the lifecycle |
| Hive routing | `hive/hosted-projectbluefin-knuckle-gjvq` | which Hive deployment owns it |
| Agent role | `agent/architect`, `agent/quality`, `agent/security`, `agent/ci-maintainer`, `agent/scanner`, `agent/strategist`, `agent/contributor` | which agent persona filed or owns it |
| Classification | `bug`, `security`, `quality`, `testing`, `tech-debt`, `architecture`, `ci`, `roadmap` | what kind of work |

Measured from 200 Hive-routed issues: Hive routes work to 18 live repos
(`actions`, `bluefin`, `bluefin-bling`, `bluefin-lts`, `chairlift`, `common`,
`dakota`, `dakota-iso`, `documentation`, `fsdk-containers`, `knuckle`, `lab`,
`review`, `server`, `testsuite`, `utah`, `utah-packages`, `website`) and to the
archived `bootc-installer`.

All 18 carry the full vocabulary as of 2026-09-13. Keep it that way with:

```bash
python3 scripts/hive-label-sync.py            # dry run
python3 scripts/hive-label-sync.py --apply    # create missing, repair metadata
```

It is additive and corrective only — it never deletes a label and never changes
which issues carry which label. Re-running it is the check; "aligned" on every
row means there is no drift.

### Do not strip other namespaces

`PUT /repos/{owner}/{repo}/issues/{n}/labels` **replaces the whole label set**.
Any automation that normalises workflow state must carry the other three
namespaces through unchanged, or it deletes Hive's routing on contact.

This was a live defect: `actions`'
`.github/actions/design-enforcement/index.js` returned only `[state, overlay]`,
so on `projectbluefin/finpilot` — the one repo calling it — every Hive-filed
issue lost `hive/*`, `agent/*`, and its classification within seconds of being
filed. Do not wire `reusable-design-enforcement.yml` into a repo until the
version you pin preserves them.

### Adoption of the seven, org-wide

Across all 39 non-archived repos on 2026-09-13, each of the seven now sits at
**22/39**, and adoption is uniform — every repo that carries one carries all
seven. 17 repos carry none. That uniformity is the sync's doing; before it,
adoption was ragged at 17–23 of 41.

Eleven repos carry all seven *and* an `AGENTS.md` *and* a `CODEOWNERS`:
`actions`, `bluefin`, `bluefin-lts`, `bluespeed`, `bonedigger`, `chairlift`,
`common`, `dakota`, `documentation`, `iso`, `knuckle`.

Read a repo's actual label list before routing anything:
`python3 scripts/factory-conformance.py --gaps`.

There is still no cross-repo label sync *workflow* — `hive-label-sync.py` is
run by hand — and `projectbluefin/.github` ships no org-wide defaults, so every
remaining gap is a real gap rather than an inheritance artifact.

## The remaining label families

Beyond the four namespaces above, these coexist and are legitimate. Do not
remove them and do not treat them as workflow state.

| Family | Examples | What it means |
|---|---|---|
| Operational | `lgtm`, `automerge`, `chore/deps`, `needs-human` | Merge and dependency automation. `lgtm` is read by the Hive auto-merge sweep — see [hive-automerge.md](hive-automerge.md) |
| Stale routing | `hive/hive-pale-eel` on `website` | A dead Hive deployment. Nothing reaps these; ignore it |

## Repos running a different dialect

Three repos do not use the numbered labels as their primary state machine.
Routing work into them with `3-clanker-queue` alone will not be picked up.

| Repo | Labels | Dialect |
|---|---|---|
| `documentation` | 70 | `queue/agent-ready`, `queue/claimed`, `queue/hold`, `needs-human/agent-ready`, `size:XS`–`size:XXL`, `priority/p0`–`p3`, `kind/*`, `source:*`. Of the seven it has only `3-clanker-queue` and `hold` |
| `website` | 41 | Same `queue/*` + `needs-human/*` + `size:*` dialect. Of the seven it has only `3-clanker-queue` and `hold` |
| `lab` | 79 | Runs **both** systems simultaneously — all seven canonical labels plus the `queue/*` dialect |

`server`, `utah`, and `utah-packages` are partial: they carry `3-clanker-queue`
and `hold` (plus `blocked` in `utah`) alongside a `status/*` or `kind/*` set.

## Ownership

`common` documents this contract. It does not implement it: there is no
lifecycle workflow in `.github/workflows/` here, and nothing in this repo
validates or repairs a label combination. Labels in `common` are applied by
humans and by Hive.

Reusable lifecycle automation belongs to `projectbluefin/actions`. Report
intake belongs to `projectbluefin/bonedigger`.

## Workflow

1. A contributor files with enough context to act. The issue form applies
   `1-triage`.
2. A human reads it and moves it to `2-discussing`, `3-human-queue`, or
   `3-clanker-queue`.
3. The assignee opens a pull request linking the issue with `Closes #NNN`, and
   the item moves to `4-review`.
4. Merge closes the linked issue. Merging requires two approvals and three
   green checks — see [governance.md](governance.md#how-main-is-protected).

Do not infer state from an old label, an issue comment, or an unlinked branch.
Read the current labels, GitHub assignment, branch, and PR association.

## Agent rules

- Work only on an item routed to you by assignment or `3-clanker-queue`.
- Do not change a numbered label to manufacture progress.
- Do not invent a new workflow-state label or a slash command.
- You may apply `blocked` when you stop at a decision you cannot make, and you
  must say in the same comment exactly which decision or dependency you are
  waiting on. An unexplained `blocked` is worse than an open issue.
- Descriptive facts belong in the issue body or project fields, not in new
  labels.

## Red Flags

- A doc restating this table instead of linking here.
- Two numbered labels on one item, or both queue labels at once.
- A slash command treated as a state transition.
- A claim that `common` runs lifecycle automation.
- Work routed into `documentation`, `website`, or `lab` on the assumption that
  the numbered labels drive them.

## Verification

- [ ] The repo you are about to route work in actually has the label:
      `gh label list --repo projectbluefin/<repo> --search 3-clanker-queue`
- [ ] The item carries at most one numbered label:
      `gh issue view <N> --repo projectbluefin/<repo> --json labels --jq '[.labels[].name | select(startswith("1-") or startswith("2-") or startswith("3-") or startswith("4-"))] | length'`
      returns `0` or `1`.
- [ ] Pull requests link issues with `Closes #NNN`.
- [ ] No file other than this one contains the seven-row label table:
      `grep -rl '3-clanker-queue' docs/ *.md .github/ | grep -v label-workflow.md`
      returns only files that *link* here.
