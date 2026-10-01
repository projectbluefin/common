---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: reviewer-ladder

## Overview

Project Bluefin needs a safe route from contributor to trusted, domain-scoped reviewer so human triage and review do not stall behind a small maintainer pool. The proposed roles would grow review capacity without granting merge or release authority to a reviewer. This draft is sourced from [common#1029](https://github.com/projectbluefin/common/issues/1029); it changes no permissions until maintainers approve it.

## Requirements

- [ ] **Recognize useful triage work**
  A contributor can qualify for a per-repository Triager role through reviewable contributions rather than an informal nomination alone.
- [ ] **Count review authority only within a domain**
  An experienced Triager's review may satisfy the human review requirement only for a named repository and domain in which they have demonstrated competence.
- [ ] **Preserve the merge gate**
  Domain Reviewers may provide human review evidence but cannot merge, release or bypass branch protection; maintainers retain those decisions.
- [ ] **Make promotion and revocation auditable**
  The sponsoring maintainer records evidence, scope, grant and removal of reviewer rights so a departing reviewer does not retain access indefinitely.
- [ ] **Measure whether review improves**
  The owning repo can compare triage age, review latency and hold-gated queue depth before and after a pilot without counting approval volume as proof of quality.

## Constraints

- This draft does not grant GitHub roles, change CODEOWNERS or branch rules, or authorize a new approval path. Maintainers and repository owners approve each scope and any rights change at the Security/Breakage/Design gates.
- A Domain Reviewer cannot approve their own PR; reviews outside the recorded repo/domain do not count as domain approval. The repo's existing required human merge and CI gates stay in force.
- Proposed evidence thresholds from the source are **options pending approval**: Contributor→Triager at five merged PRs or ten substantive triage actions; Triager→Domain Reviewer after 30 days and ten reviewed PRs with maintainer quality sign-off. No automation should treat those numbers as policy before review.

## Acceptance Criteria

- [ ] **Triage qualification is evidenced**
  A pilot repo can cite the selected promotion rule, a real contributor's qualifying actions and a maintainer approval before granting triage permissions; workflow-owned queue labels remain workflow-owned.
- [ ] **Domain boundary holds**
  A reviewer can provide counted review on a PR in their approved domain; their review does not satisfy the same gate outside it or on their own PR.
- [ ] **Maintainers still control delivery**
  A reviewed PR still requires the repo's ordinary checks and maintainer merge or explicit policy-controlled merge path.
- [ ] **Grant lifecycle is recorded**
  The contributor docs name the reviewer, owned domain, approving maintainer and removal procedure; revocation removes their elevated rights.
- [ ] **The pilot has measured benefit**
  The owning repo records before/after first-response age and review latency with no increase in unreviewed or self-approved merges.

## Technical Approach

The source proposal identified four roles: Contributor (fork PR), Triager (reproduce, deduplicate and route within one repo), Domain Reviewer (human review within a named domain, no merge), and Maintainer (merge/release). The scope and promotion thresholds above are proposed, not accepted. Use one existing product repo as a reversible pilot before proposing a factory-wide grant. See [common#1058](https://github.com/projectbluefin/common/issues/1058) for historical concentration evidence; refresh live queue numbers before deciding.

## Success Metrics

- Human issue first-response and domain review latency improve against a fresh pre-pilot baseline, with actual review quality approved by maintainers.
- Every elevated reviewer can be named, scoped and revoked; no new reviewer merges without an existing maintainer gate.

## Non-Goals

- A new org-wide maintainer role, automated reviewer promotion or merge right.
- Imposing historical queue-size targets as current measurements.
- Changing agent output volumes or implementing an independent PR priority rubric through this specification.
