---
name: skill-drift
version: "2.0"
last_updated: "2026-08-01"
id: skill-drift
one_line_purpose: Record why the skill-drift CI check was retired and what replaced it.
entry_point: docs/skills/skill-drift.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: deprecated
dependencies: []
tags: [skills, drift, ci]
description: >-
  Retirement record for the skill-drift CI check. Use when you find a stale
  reference to skill-drift.yml, or are tempted to add a per-convention CI
  gate for skill documentation.
metadata:
  type: reference
---

# Skill Drift (retired)

`skill-drift.yml` has been removed from every factory repo. Do not re-add it.

This page exists so anyone who finds a stale reference understands what the
check was, why it was retired, and what enforces skill discipline now.

## What it was

The check was meant to warn when a pull request changed implementation files
without updating the matching skill documentation. Each repo carried a
`.github/workflows/skill-drift.yml` that called the reusable workflow
`projectbluefin/actions/.github/workflows/skill-drift-check.yml`, passing
`code-paths` and `skill-paths` inputs.

The design was always advisory — warn, never block.

## Why it was retired

**It stopped working long before it was removed, and nobody noticed.**

The reusable workflow's real logic was deleted in
`actions@001ae97 chore: remove skill-drift and skill-audit workflows`, then
replaced with a compatibility stub in `actions@a7c230c fix: restore
skill-drift-check.yml as a no-op stub for consumer compat`. The stub's only
step echoed:

```
Skill drift check removed. Delete skill-drift.yml from consumer repo.
```

It exited successfully without inspecting any changed path.

At the point of retirement, five repos — bluefin, bluefin-lts, dakota,
knuckle, and testsuite — still called that stub on every pull request and
received a silent green result regardless of what they changed. `common` never
wired it up at all. The org had five repos running a check that could not
fail, and zero repos enforcing anything.

A green check that proves nothing is worse than no check: it invites people to
read the green tick as evidence that a skill update was not needed.

The deeper reason is policy. [`agentic-model.md`](../factory/agentic-model.md)
states that CI gates protect the OCI image artifact, and that a check earns
`exit 1` only if failure means a broken or wrong image ships. Skill
documentation drift does not ship a broken image. It is a process convention,
and process conventions do not belong in bespoke CI jobs.

## What enforces skill discipline now

| Mechanism | Where | When it runs |
|---|---|---|
| `pre-commit` hooks | `.pre-commit-config.yaml` | developer time, before every commit |
| Skill front-matter validation | `scripts/check-skill-frontmatter.sh` | via pre-commit |
| Router and catalog coverage | `scripts/check-skill-index.sh` | via pre-commit |
| Internal link validation | `scripts/check-doc-links.sh` | via pre-commit |
| Generated catalog freshness | `scripts/generate_skill_index.py` | post-merge automation |
| Self-repair loop | [`skill-improvement.md`](./skill-improvement.md) | every agent task loop |

Per `agentic-model.md`, CI may re-run the whole `pre-commit` suite as a single
aggregate step, and that aggregate step is the only place a process convention
may fail a build. Adding a separate per-convention CI job is banned.

## The obligation did not go away

Retiring the check did not retire the rule. Every implementation change should
still carry the matching skill update in the same pull request. That obligation
is enforced by review and by the self-repair loop, not by a workflow.

The mandate for *why* is in [`skill-improvement.md`](./skill-improvement.md).
Authoring rules are in [`write-a-skill.md`](./write-a-skill.md).

## Code path to skill mapping

Still useful when deciding which skill a change belongs to:

| Changed path | Update this skill |
|---|---|
| `.github/workflows/build.yml` | [`ci-tooling/SKILL.md`](./ci-tooling/SKILL.md) |
| `.github/workflows/e2e*.yml`, test configs | [`e2e-ci/SKILL.md`](./e2e-ci/SKILL.md) |
| `.github/workflows/release.yml` | [`release-promotion/SKILL.md`](./release-promotion/SKILL.md) |
| `system_files/**` | [`submodule-boundary.md`](./submodule-boundary.md) or [`dconf-consistency.md`](./dconf-consistency.md) |
| `Justfile` | whichever skill owns the changed recipe |
| `Containerfile` | [`containerfile/SKILL.md`](./containerfile/SKILL.md) |
| `.github/CODEOWNERS` | [`governance.md`](./governance.md) |

Not sure? Use [`docs/SKILL.md`](../SKILL.md) as the task-to-skill router.

## Red Flags

- Re-adding `skill-drift.yml` to any repo.
- Adding a new CI job whose only purpose is enforcing a documentation or
  process convention.
- Treating a green CI run as evidence that a skill update was unnecessary.
- Citing this page as if the check were still live.

## Verification

```bash
# No factory repo should carry the workflow
gh search code "skill-drift" --owner projectbluefin

# The reusable stub should no longer exist
gh api repos/projectbluefin/actions/contents/.github/workflows/skill-drift-check.yml
```

Expected: the search returns only this retirement record, and the API call
returns `404`.
