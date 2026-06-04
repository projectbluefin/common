---
name: skill-drift
description: "How to satisfy the PR skill-drift check and what counts as a real skill update."
---

# Skill drift

## Scope

**Workflow:** `.github/workflows/skill-drift.yml`
**Repo:** `projectbluefin/common`

`skill-drift.yml` warns when a PR changes implementation files without updating the matching skill documentation. The goal is to keep agent-facing docs in sync with real repo behavior while the change context is still fresh.

## What triggers the check

For `common`, the check treats these as **implementation** paths:

- `.github/workflows/**`
- `system_files/**`
- `Containerfile`
- `Justfile`

It treats these as **skill/doc** paths:

- `docs/skills/**`
- `docs/*.md`
- `AGENTS.md`

If a PR touches an implementation path but none of the skill/doc paths, the workflow warns.

## What counts as a satisfying update

A passing doc update must describe the behavior, rule, workflow, path mapping, or operator guidance changed by the implementation. Merely touching a markdown file, rewrapping text, or adding unrelated notes is not a real skill update.

Use the skill file that matches the changed surface area. Update the closest existing skill when one already covers the behavior; add a new skill only when the change introduces a new reusable rule or workflow.

## Writing a passing update

- Name the file, workflow, hook, command, or path that changed
- State the new rule, behavior, or expectation
- Explain what an agent should now do differently
- Keep the update adjacent to the skill that owns that topic

Good updates answer: **what changed, where it lives, and how to operate it correctly now**.

## Warning now, blocking later

Today the check is advisory: it warns but does not block merge. Treat that as an early prompt, not optional cleanup. The audit explicitly calls for `common` to enforce the same hygiene as the other Bluefin repos, and advisory checks are likely to harden over time.

## Related CI hook

See [ci-tooling.md](./ci-tooling.md) for the floating-tag guard. It uses the same broader pre-commit/CI hygiene model: implementation changes should carry the operator guidance needed to keep future changes safe.

## Common failure modes

- Changing only a workflow or other `.yml` implementation file and forgetting to update docs
- Updating `docs/skills/**`, but touching the wrong skill file for the behavior that changed
- Adding a doc-only placeholder that does not explain the implementation change
- Assuming a warning can be ignored because the workflow is not yet blocking
