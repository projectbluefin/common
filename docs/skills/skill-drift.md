---
name: skill-drift
description: "How the skill-drift CI check works — when it fires, what it validates, how to write a passing update, and how to suppress it when warranted."
---

# Skill Drift

`skill-drift.yml` warns when a PR changes implementation files without updating the matching skill documentation. The goal: keep agent-facing docs in sync with real repo behavior while the implementation context is still fresh.

The mandate for *why* you must write skill updates is in [`skill-improvement.md`](./skill-improvement.md).

---

## How it works

```
PR opened
  └─ extract changed files
       ├─ match against code-paths
       └─ if code-paths hit and no skill-paths hit → WARN
```

Currently advisory (warns but does not block merge). Treat warnings as hard requirements — the check is expected to harden into a block.

---

## Path mapping by repo

| Repo | code-paths | skill-paths |
|---|---|---|
| common | `.github/workflows/**`, `system_files/**`, `Containerfile`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin | `.github/workflows/**`, `build_files/**`, `Justfile`, `recipes/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin-lts | `.github/workflows/**`, `build_files/**`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| dakota | `.github/workflows/**`, `build_files/**`, `Justfile`, `elements/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| knuckle | `.github/workflows/**`, `cmd/**`, `internal/**`, `Justfile`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| testsuite | `.github/workflows/**`, `.github/actions/**`, `tests/**`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |

The workflow calls the reusable `projectbluefin/actions/.github/workflows/skill-drift-check.yml` at a pinned SHA (so the floating-tag guard does not reject the caller).

---

## Code path → skill file mapping

Use this when the check fires and you need to know which skill to update:

| Changed path | Update this skill |
|---|---|
| `.github/workflows/build.yml`, `build.yml` | `bluefin-build.md` or `bluefin-ci.md` |
| `.github/workflows/e2e*.yml`, test configs | `e2e-ci.md` |
| `.github/workflows/lifecycle*.yml` | `label-workflow.md` |
| `.github/workflows/skill-drift.yml` | `skill-drift.md` (this file) |
| `.github/workflows/release.yml` | `release-promotion.md` |
| `system_files/**` | `submodule-boundary.md` or `dconf-consistency.md` |
| `Justfile` | whichever skill owns the changed recipe |
| `Containerfile` | `bluefin-build.md` |
| `elements/**` (dakota) | matching `dakota-*.md` skill |
| `.github/CODEOWNERS` | `governance.md` |

Not sure? Check `docs/skills/INDEX.md`.

---

## What counts as a satisfying update

A passing update must:
- Name the file, workflow, hook, command, or path that changed
- State the new rule, behavior, or expectation
- Explain what an agent should now do differently

**Passing:** "Added `elements/**` to code-paths in skill-drift.yml; dakota element changes now trigger skill-drift warnings. Update matching `dakota-*.md` when changing elements."

**Failing:** rewrapping text, adding unrelated notes, or touching any markdown file without explaining the implementation change.

---

## Waiver process

For refactoring changes with no functional impact:

1. Add to your PR description:
   ```markdown
   ## Skill drift waiver
   Changed: `.github/workflows/build.yml`
   Reason: Internal variable rename only — no behavior change, no operator impact.
   ```
2. A maintainer can override the check. Do not self-waive.

---

## Common failure modes

- Changing a workflow and forgetting to update docs
- Updating the wrong skill file for the behavior that changed
- Adding a placeholder doc that does not explain the change
- Assuming advisory = optional
