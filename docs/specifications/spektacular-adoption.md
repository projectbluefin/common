---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: spektacular-adoption

## Overview

Project Bluefin will use reviewed specifications as the planning source for substantive product work, with an approved plan and verified pull request as separate downstream stages. GitHub remains the intake, routing and traceability surface; Hive may orchestrate a stage only after a real Spektacular project and a safely scoped end-to-end pilot exist. This draft does not authorize enabling automation.

## Requirements

- [ ] **Keep issue intake human-first**
  Contributors can report bugs or propose product work through the existing issue form without automatically sending an incomplete request to a coding agent.
- [ ] **Review requirements before planning**
  A product feature or epic has one traceable specification with atomic outcomes, constraints, pass/fail acceptance and non-goals; a maintainer resolves open choices before marking it final.
- [ ] **Make identity unambiguous**
  GitHub issue, Project #2 `Specification ID`, CLI artifact and Hive run refer to the same work without guessing a filename or reinterpreting an issue number.
- [ ] **Plan and approve before execution**
  An implementation plan attributes work to the owning repositories, covers every accepted requirement and is reviewed by a human before code changes begin.
- [ ] **Preserve the direct-fix path**
  A bounded, reproducible bug can reach the ordinary issue/PR workflow without a specification; complex product work may take the staged path only when configured and reviewed.
- [ ] **Ship with verifiable evidence**
  The owning repository's checks, real changed-path smoke evidence and PR review decide delivery; document status alone never closes an issue.

## Constraints

- Project #2's `Workflow Stage` (`Specification`, `Planning`, `Implementation`) describes a stage, not issue state or Spektacular's `document_status`. Work labels and human approval continue to belong to their existing owners.
- Hive's `runs.triage.enabled` and `runs.spektacular.enabled` default off. The reviewed upstream configuration has no per-repository triage allowlist, so an initial test must use an isolated deployment scoped to one product repository.
- Hive's current issue-run key (`owner/repo#number`) and Spektacular's default timestamp artifact name do not match in the observed code path. No live factory run may depend on Project #2 text fields as an untested binding.
- The default human checkpoints for specification, plan and implementation stay in force. Design, Security, Breakage and Merge gates are expressed through this specification and repository review, not a second approval document.
- Do not add credentials or package sources, write to `ublue-os/*`, stage unrelated working files, or change a downstream product's labels/branch policy without its owner.

## Acceptance Criteria

- [ ] **Feature intake stays gated**
  The one issue form accepts a bounded bug and a feature with an observable finish line, keeps `1-triage` on filing, and creates no Hive run merely from form submission.
- [ ] **Requirements are reviewable**
  A maintainer can trace each accepted requirement to a binary acceptance criterion and the source issue; undecided security or product choices keep the specification in draft.
- [ ] **The pilot addresses one artifact**
  In a clean checkout, a source issue, `Specification ID`, `spektacular spec status <name>` response and Hive run/receipt all identify the same feature; a missing or mismatched artifact parks the run.
- [ ] **The plan gates implementation**
  The approved plan maps every requirement to owning code, dependencies and verification, and changing the specification invalidates stale execution until a new human review.
- [ ] **Small bugs remain direct fixes**
  In the pilot configuration, a `kind/bug` issue with a clear reproduction follows the existing direct path while an approved feature follows exactly one staged run.
- [ ] **Delivery is real**
  A product change reaches a reviewed PR with repository CI and a smoke check; the issue closes only by the owning merge policy, not by advancing an artifact or board field.

## Technical Approach

The [implementation plan](spektacular-adoption/plan.md) is downstream of this specification: it records rollout tasks, source-backed risks, the issue-to-artifact binding gate, and pilot/rollback checks. It is not a separate place to decide product requirements. Today, existing issue bodies are specification-shaped Markdown, not CLI-managed artifacts. The Spektacular file store and Hive's optional [run stages](https://github.com/hivecommons/hive/blob/v5/src/docs/runs.md) must be exercised together before rollout. [How Spektacular works](https://spektacular.dev/how-it-works/) and [Hive's integration](https://github.com/hivecommons/hive/blob/v5/src/docs/spektacular.md) define the two sides of that boundary.

## Success Metrics

- One approved feature completes an observed specification → plan → implementation run with a matching artifact ID, human approvals and passing product checks.
- No incomplete draft or direct-fix bug is accidentally promoted into a staged implementation.
- Reviewers can find the decision, tests and rollback evidence from the specification and its source issue without consulting a parallel planning record.

## Non-Goals

- Enabling Hive's runner or triage on the multi-repository hosted factory before an isolated pilot proves its contracts.
- Migrating LTS, Knuckle, archived repositories or unrelated user-authored working files as part of this specification.
- Replacing the existing issue lifecycle, product CI, human decisions or PR merge gate with artifact status.
