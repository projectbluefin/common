---
name: governance
version: "1.2"
last_updated: "2026-09-24"
id: governance
one_line_purpose: Check repo-local CODEOWNERS, triager roles, and live branch rules.
entry_point: docs/skills/governance.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [governance, issues, lifecycle]
description: >-
  Repo-local triager roles, CODEOWNERS ownership, and live branch protection.
  Use when changing CODEOWNERS, granting triage permissions, or verifying
  repository review rules; no cross-repository sync is implied.
metadata:
  type: reference
---

# Contributor Governance — Triagers & CODEOWNERS

## Contents
- [Roles](#roles)
- [CODEOWNERS structure](#codeowners-structure)
- [Sync workflow](#sync-workflow)
- [Branch protection](#branch-protection)
- [Lifecycle automation](#lifecycle-automation)

---

## Roles

| Role | GitHub team | What they can do |
|---|---|---|
| **Maintainers** | `@projectbluefin/maintainers` | Merge PRs, push to main, full admin |
| **Triagers** | `@projectbluefin/triagers` (placeholder) + direct collaborator | Label/assign/close issues, approve `docs/**` and `*.md` PRs |

Triagers are granted **triage** permission directly on each repo (not via team).
Add a person: `gh api repos/projectbluefin/REPO/collaborators/USERNAME --method PUT --field permission=triage`

## CODEOWNERS structure

The triager sentinel in `common/.github/CODEOWNERS` is canonical. There is no
active `sync-codeowners.yml` here: downstream copies require reviewed manual
propagation and can drift from the source.

**To add/remove a triager:** update the canonical block in `common` with its
required review, then compare affected downstream blocks and propose their
repo-local updates. Do not assume an automatic push or bypass local review.

Repository owners and sensitive paths live in each repository's current
`.github/CODEOWNERS`; do not copy an owner table from this document.

## Branch protection

Approval counts and code-owner enforcement differ by repository and can
change. Read the live ruleset or branch-protection API before acting; a
ruleset name is not proof of its requirements.

For any repository using a GitHub merge queue, every required check workflow must
also subscribe to the `merge_group` event with `types: [checks_requested]`.
Without that trigger, queued PRs remain in `AWAITING_CHECKS` because ordinary
`pull_request` workflows do not run on merge-group refs. See the lab runbook at
[`projectbluefin/lab/docs/ops/merge-queue.md`](https://github.com/projectbluefin/lab/blob/main/docs/ops/merge-queue.md).

## Documentation and contract changes

The [factory contract](../factory/agentic-model.md) permits the `common`
doc-only direct-to-main exception only when **every** staged path is under
`docs/` or is `AGENTS.md`. Inspect `git diff --cached --name-only` first;
mixed changes need a PR and the appropriate human gates.

## Lifecycle automation

[`projectbluefin/bonedigger`](https://github.com/projectbluefin/bonedigger)
owns lifecycle automation; each consumer owns its `bonedigger.yml` caller.
Check a repository's current workflows instead of assuming a caller exists.
`common` has no caller. The seven workflow labels are documented in
[`label-workflow.md`](label-workflow.md), not synchronized by this repo.

## Verification

- [ ] Query the live ruleset rather than trusting a label or an old table:

  ```bash
  gh api repos/projectbluefin/common/rulesets --jq '.[] | {id, name}'
  RULESET_ID="$(gh api repos/projectbluefin/common/rulesets --jq '.[] | select(.name == "main-review-required-with-renovate-bypass") | .id')"
  test -n "$RULESET_ID" && gh api "repos/projectbluefin/common/rulesets/$RULESET_ID" \
    --jq '.rules[] | select(.type == "pull_request") | .parameters | {required_approving_review_count, require_code_owner_review}'
  ```
- [ ] `pre-commit run check-skill-catalog --all-files` passes.
- [ ] `pre-commit run check-skill-index --all-files` passes.
