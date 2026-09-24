---
name: label-workflow
version: "2.1"
last_updated: "2026-09-23"
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
  The canonical Trust the Machines workflow and seven-label contract for
  projectbluefin factory repositories. Use when triaging, routing, or reviewing
  work.
metadata:
  type: procedure
---

# Label Workflow — projectbluefin Factory

## The contract

**Trust the Machines: workflows own state; humans provide intent.**

The factory has exactly seven labels:

| Label | Meaning | Owner |
|---|---|---|
| `1-triage` | New work awaiting triage | Workflow |
| `2-discussing` | Discussion or design clarification | Workflow |
| `3-human-queue` | Admitted to the human-maintained queue | Workflow |
| `3-clanker-queue` | Admitted to the agent-maintained queue | Workflow |
| `4-review` | Pull request awaiting review | Workflow |
| `blocked` | Waiting on human input or an external dependency | Workflow |
| `hold` | Intentionally paused | Workflow |

These are the only labels. A contributor or maintainer may select one numbered
label to express the intended next step, with `blocked` or `hold` as an
optional overlay. Automation validates the selection, repairs illegal
combinations, and performs the resulting triage. Do not create a second state
machine with comments, custom labels, or local scripts. Issue forms, issue
bodies, and Hive metadata may contain descriptive facts, but those facts are
not additional labels or state.

## Ownership

`common` documents this contract and consumes configured automation; it does not
own a lifecycle implementation. Reusable lifecycle automation belongs to
`projectbluefin/actions`. Report intake and report-specific automation belong
to `projectbluefin/bonedigger`.

## Downstream consumer subsets

The seven canonical labels are the factory-wide contract for the core pipeline
repos (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`, `testsuite`).
A downstream **consumer** product — for example Bluefin Server — may maintain a
smaller label subset for its own issue forms and lifecycle. That subset is
product-local: it is **not** an extension of the factory catalog, is not
synchronized to the core pipeline repos, and is never the organization-wide
source of truth.

| Product | Local subset |
|---|---|
| Bluefin Server | `kind/bug`, `status/triage`, `kind/enhancement`, `status/discussing`, `flow/agent-donation` |

Treat a consumer subset as local configuration only. Do not read it as standing
in for, or adding to, the seven canonical factory labels above, and do not copy
it into a core pipeline repo.

## Workflow

1. A form or contributor files work with enough context to act.
2. Workflow automation applies `1-triage`.
3. A human clarifies the request; automation advances it to `2-discussing` when
   discussion is required.
4. The owning workflow routes work to `3-human-queue` or `3-clanker-queue`.
5. A contributor or agent works on the assigned branch and opens a pull
   request linking the issue with `Closes #NNN`.
6. Workflow automation applies `4-review`; a human reviews the pull request.
7. Merge closes the linked issue. `blocked` and `hold` are workflow-controlled
   overlays and may pause work at any stage.

Do not infer state from an old label, an issue comment, or an unlinked branch.
Use the current workflow output, GitHub assignment, project state, branch, and
pull request association.

## Human actions

### Filing and triage

Use the repository's issue forms. If filing without a form, include the
problem, expected outcome, reproduction or evidence, affected scope, and
acceptance criteria. Keep descriptive classification in the issue body.

Humans decide whether the work is valid, needs discussion, belongs in the
human queue, or should be routed to an agent queue by selecting the matching
canonical label. Automation rejects extra labels and handles the resulting
triage.

### Review

When `4-review` is present:

1. Verify the pull request solves the linked issue.
2. Check required tests and evidence.
3. Approve or request changes using the repository's normal review flow.
4. Apply a hold through the owning workflow if a merge must pause.

### Blocking and holding

Explain the decision or missing input in the issue or pull request. Select
`blocked` or `hold` when the work is blocked or intentionally paused;
automation preserves the overlay and reports the next action.

## Agent and contributor actions

1. Read the issue and target repository `AGENTS.md`.
2. Work only on an issue routed to you by assignment, project state, or
   `3-clanker-queue`.
3. Create a scoped branch and keep the change small.
4. Run the target repository's validation commands.
5. Open a pull request containing `Closes #NNN`.
6. Respond to review feedback; do not self-approve or self-merge.

If blocked, describe the exact decision or dependency in the issue and stop.
Do not change labels to manufacture progress.

## Epics and project metadata

Use issue descriptions and project fields to explain multi-part work, priority,
scope, size, source, and relationships. These are metadata, not labels. Link
child issues to a parent with plain text such as `Part of #NNN`.

## Red Flags

- Any label outside the seven names in the table above.
- A human selecting more than one numbered workflow label.
- A slash command being treated as a state transition.
- A document claiming that `common` owns lifecycle automation.
- Queue state inferred from an issue body, comment, or stale local checkout.
- Treating a downstream consumer label subset as part of the factory contract.

## Verification

- [ ] `gh label list` on the repository returns only the seven canonical labels
      plus repository-local automation labels.
- [ ] Downstream consumer subsets are documented as local, never as factory contract.
- [ ] No workflow guidance invents another label or slash-command transition.
- [ ] Work is routed by the owning workflow, assignment, project, branch, and PR.
- [ ] Pull requests link issues with `Closes #NNN`.
- [ ] `pre-commit run check-skill-frontmatter --all-files` passes.
- [ ] `pre-commit run check-skill-index --all-files` passes.
- [ ] `pre-commit run check-doc-links --all-files` passes.
