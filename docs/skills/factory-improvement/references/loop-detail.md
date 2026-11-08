# Scoped factory audit reference

Optional detail for [factory-improvement](../SKILL.md).

## Finding evidence and work

For a requested factory assessment, inspect the affected workflows, recent runs,
and existing issues before deciding a gap exists. These discovery queries show
Prow issue state; they do not prove a task is ready to implement:

```bash
gh search issues --label "needs-human" --owner projectbluefin --state open \
  --json number,title,repository
gh search issues --label "triage/accepted" --owner projectbluefin --state open \
  --json number,title,repository
```

Verify the target repository's local acceptance rules and current issue before
acting. Prow work requires `triage/accepted`, no `needs-human`, and no `blocked`
or `hold`; other repositories may use different rules. Do not copy numbered
legacy queues or self-accept a discovered gap. Maintainers own prioritization.

## Choosing an improvement

Separate a human decision from a mechanical defect. For a cross-repository
change, identify consumers and blast radius first. Implement only accepted,
in-scope work, through the target repo's branch/PR path; documentation has no
direct-main exception. Do not turn a small fix into infrastructure uniformity,
mandatory retries, or a documentation migration.

An actionable out-of-scope gap can be filed with its impact and expected outcome
through normal issue triage. Check for an existing issue before duplicating it.
Do not maintain stale backlog lists or completed-audit statistics in skills.

## E2E coverage

Common's workflows to inspect are `pr-e2e.yml` (composed image and common suite),
`e2e.yml` (post-merge), and `promotion-candidate-e2e.yml` (promotion candidate).
For image repositories, also inspect post-merge E2E, promotion smoke checks,
and upgrade coverage, not just PR validators. Read current workflow triggers,
required checks, and promotion configuration: advisory E2E is not a blocking
gate, and schedules or gate requirements can differ between repositories.

Validate the actual improved behavior with the target repository's existing
checks and report results and remaining blockers. Correct task-relevant docs
when necessary; no compulsory capture/verify loop or session-close skill update.
