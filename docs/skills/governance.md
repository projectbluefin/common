---
name: governance
version: "2.0"
last_updated: "2026-09-13"
id: governance
one_line_purpose: Manage CODEOWNERS, triager roles, and governance policies.
entry_point: docs/skills/governance.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [governance, issues, lifecycle]
description: >-
  Org team membership, CODEOWNERS structure, and the live ruleset that gates
  `main` in projectbluefin/common. Use when managing CODEOWNERS, granting
  triage permission, or reasoning about what actually blocks a merge.
metadata:
  type: reference
---

# Governance — Teams, CODEOWNERS, and the `main` Ruleset

## Contents
- [Teams](#teams)
- [CODEOWNERS](#codeowners)
- [How `main` is protected](#how-main-is-protected)
- [Protection across the org](#protection-across-the-org)
- [Lifecycle automation](#lifecycle-automation)
- [Verification](#verification)

---

## Teams

The `projectbluefin` org has exactly two teams.

| Team | Members | Count |
|---|---|---|
| `@projectbluefin/maintainers` | daegalus, castrojo, ahmedadan, hanthor, inffy, alatiera, tulilirockz | 7 |
| `@projectbluefin/triagers` | castrojo | 1 |

`triagers` is a real team, not a placeholder — but it has one member, who is
also a maintainer. **Triage has a bus factor of one.** Adding a second triager
is the single highest-value governance change available.

`.project/maintainers.yaml` names a `project-maintainers` team. No such team
exists.

Grant triage on a repo:

```bash
gh api repos/projectbluefin/<repo>/collaborators/<user> \
  --method PUT --field permission=triage
```

## CODEOWNERS

`.github/CODEOWNERS` in this repo is the file; read it there rather than a copy
in a doc. Every handle in it resolves to a real account.

The `BEGIN TRIAGERS` / `END TRIAGERS` sentinel block marks the section that
downstream repos copy. To add or remove a triager, edit the `**/*.md` line
inside that block and grant the `triage` collaborator permission above.

Each repository owns its own `.github/CODEOWNERS`; there is no cross-repo push
automation. Open a PR in the affected repo.

> **CODEOWNERS does not gate merges here.** The `main` ruleset sets
> `require_code_owner_review: false`. CODEOWNERS assigns reviewers and nothing
> more. A code-owner approval is not required and a code owner's absence does
> not block anything.

## How `main` is protected

`projectbluefin/common` has **no classic branch protection** —
`gh api repos/projectbluefin/common/branches/main/protection` returns
`404 Branch not protected`. Protection lives entirely in a ruleset, so that
404 is not evidence of an unprotected branch. Always read `/rulesets`.

There is exactly **one** active ruleset: id `17513003`, name
`main — merge queue`, targeting `refs/heads/main`, with **`bypass_actors: []`**
— nobody, including org admins and Renovate, can bypass it.

| Rule | Live parameters |
|---|---|
| `pull_request` | `required_approving_review_count: 2`, `require_code_owner_review: false`, `require_extra_approval_for_unattributed_changes: true`, `dismiss_stale_reviews_on_push: false`, `require_last_push_approval: false`, `allowed_merge_methods: ["squash"]` |
| `required_status_checks` | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)`; `strict_required_status_checks_policy: false` |
| `merge_queue` | `merge_method: SQUASH`, `grouping_strategy: ALLGREEN`, `max_entries_to_build: 5`, `check_response_timeout_minutes: 90` |
| `deletion` | `main` cannot be deleted |
| `non_fast_forward` | force-push to `main` is rejected |

**What this means in practice:**

- Landing anything on `main` requires a pull request, **two** human approvals,
  and three green required checks, then the merge queue.
- **Direct pushes to `main` are impossible for everyone.** There is no
  path-scoped exemption in GitHub rulesets, so there is no doc-only exception.
  Documentation changes go through a PR like everything else.
- Docs-only PRs still merge. `build.yml` path-ignores `docs/**`, `*.md`, and
  `AGENTS.md` on `pull_request`, so the two Build checks are *skipped*, not
  pending, and `validate` alone carries the PR.
- `require_extra_approval_for_unattributed_changes: true` means commits whose
  author is not a linked GitHub account need an extra approval. The
  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  trailer is a linked account, so the standard AI-attribution form satisfies
  it.
- Reviews are **not** dismissed on push (`dismiss_stale_reviews_on_push:
  false`) and the last pusher does not need a fresh approval.
- Only `validate`, `Build and push image (x86_64)`, and
  `Build and push image (aarch64)` are required. Unit Tests, PR E2E, Validate
  Brewfiles, Validate ChairLift Config, and Scorecard all report but gate
  nothing.

Any repo using a merge queue needs every required-check workflow to also
subscribe to `merge_group` with `types: [checks_requested]`; without it queued
PRs sit in `AWAITING_CHECKS`. `build.yml` and `validate.yml` both do.

## Protection across the org

The org runs **both** mechanisms side by side, and several repos run neither.
Read both endpoints before asserting anything about another repo.

| Repo | Active ruleset | Classic branch protection |
|---|---|---|
| `common` | `main — merge queue` | none |
| `bluefin` | `bluefin — release (main, stable)` | none |
| `bluefin-lts` | `bluefin-lts — release (main)` | none |
| `dakota` | `dakota — release (main)`, `— integration (testing)`, `— next (stream)` | none |
| `knuckle` | `main — merge queue` | none |
| `testsuite` | `main — merge queue` | none |
| `review` | `main: squash-only, conventional title, current CI` | none |
| `documentation` | `main` | present, no review requirement |
| `actions` | `actions — main`, `actions — v1 tag` | present, 1 approval |
| `finpilot` | `main — review policy` | present, no review requirement |
| `fsdk-containers` | `main — review policy` | present, 2 approvals |
| `lab` | **none** | none |
| `iso` | **none** | none |

`lab` and `iso` have no enforced protection on their default branch at all.

## Lifecycle automation

Issue intake automation lives in
[`projectbluefin/bonedigger`](https://github.com/projectbluefin/bonedigger) and
is consumed through a `bonedigger.yml` caller in `bluefin`, `bluefin-lts`,
`dakota`, and `knuckle`.

`common` has no lifecycle caller, by choice. It owns no lifecycle automation
and runs no label sync. The label vocabulary and its measured adoption live in
[`label-workflow.md`](label-workflow.md).

Hive operates across the org through the
`hive/hosted-projectbluefin-knuckle-gjvq` label; the live work queue spans
`bluefin`, `documentation`, and `review`. Hive's schedule belongs to Hive and
is not mirrored here.

## Verification

- [ ] The ruleset still reads as documented above:

  ```bash
  gh api repos/projectbluefin/common/rulesets --jq '.[] | {id, name, enforcement}'
  gh api repos/projectbluefin/common/rulesets/17513003 \
    --jq '{bypass: .bypass_actors, rules: [.rules[] | {type, parameters}]}'
  ```

- [ ] Team membership matches:

  ```bash
  gh api orgs/projectbluefin/teams --jq '.[].slug'
  gh api orgs/projectbluefin/teams/maintainers/members --jq 'length'
  gh api orgs/projectbluefin/teams/triagers/members --jq '[.[].login]'
  ```

- [ ] A direct push to `main` is still refused, which is the only proof that
      matters: `git push --dry-run origin HEAD:main` fails on the ruleset.
