---
name: governance
version: "2.1"
last_updated: "2026-10-08"
id: governance
one_line_purpose: Check OWNERS approvers, triager roles, and live branch rules.
entry_point: docs/skills/governance.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [governance, issues, owners]
description: >-
  Prow triage-command roles, OWNERS approvers synced from projectbluefin/.project,
  and live branch protection. Use when changing who approves, configuring
  Prow triage, or verifying repository review rules.
metadata:
  type: reference
---

# Contributor Governance — Triagers & OWNERS

## Contents
- [Roles](#roles)
- [OWNERS](#owners)
- [Branch protection](#branch-protection)
- [Issue and PR automation](#issue-and-pr-automation)

---

## Roles

| Role | Roster or GitHub team | What they can do |
|---|---|---|
| **Maintainers** | `@projectbluefin/maintainers` | Merge PRs, push to main, full admin |
| **Prow triagers** | `triage` in `projectbluefin/.project/maintainers.yaml` | Add/remove triage and priority labels through Prow; use generic label commands |

To add or remove a Prow triager, edit the canonical YAML roster through a PR.
The read-only authorization workflow reads that roster for each comment.
This grants no GitHub organization membership, collaborator access, issue-closing
authority, or PR approval rights. Area labels remain public. See
[`label-workflow.md`](label-workflow.md) for the command boundary.

## OWNERS

Each Prow repository has a root `OWNERS` file whose `approvers:` may `/lgtm`
and `/approve` pull requests and receive review requests. It is generated from
the `project-maintainers` team in `maintainers.yaml` in `projectbluefin/.project`;
a sync job opens a PR in each repository when that list changes. The `triage`
team is not copied into `OWNERS`.

**To add/remove an approver:** change `maintainers.yaml` in
`projectbluefin/.project` through its normal review. Never edit `OWNERS` by hand.

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

## Issue and PR automation

Prow drives issues and PRs; see [`label-workflow.md`](label-workflow.md) for
the flow, labels, and commands.

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
