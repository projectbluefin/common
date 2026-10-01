---
name: skill-improvement
version: "1.3"
last_updated: "2026-09-24"
id: skill-improvement
one_line_purpose: Capture durable agent learnings in maintained skill docs.
entry_point: docs/skills/skill-improvement.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [skills, improvement, documentation]
description: >-
  The skill-improvement mandate — every agent session must produce a skill
  file update alongside the work. Use when completing a task and deciding
  whether to write a skill update, or when creating or updating a skill
  file.
metadata:
  type: reference
  context7-sources:
    - /anthropics/skills
    - /addyosmani/agent-skills
    - /vercel-labs/agent-skills
---

# Skill Improvement Mandate

Every agent session produces two outputs:

1. **The work** — the PR, fix, or improvement
2. **The learning** — what a future agent should know

Output 1 without Output 2 leaves the factory no smarter. The loop only compounds if agents write back.

## Every-Loop Repair Contract

Run this contract at task start, after failures or discoveries, and before
handoff:

1. Verify the target repository, issue, branch, catalog ref, and loaded skill
   set against source.
2. Identify stale, contradictory, missing, or failed guidance instead of
   silently adapting around it.
3. Repair the nearest authoritative skill or contract when the fix is
   source-backed and within scope.
4. Validate the repair with the repository's existing checks and regenerate
   generated documentation outputs when required.
5. Record evidence, confidence, durable learning, and unresolved gaps for the
   successor agent.
6. Escalate named human gates rather than turning uncertainty into autonomous
   policy or approval.

This loop is the factory's self-repair mechanism. It applies even when the
implementation succeeds: a successful task still checks for reusable learning
and documentation drift before completion.

## Contents
- [Before You Mark Work Complete](#before-you-mark-work-complete)
- [What Counts as a Learning Worth Writing Back](#what-counts-as-a-learning-worth-writing-back)
- [Where to Write It](#where-to-write-it)
- [Which Skill File to Update](#which-skill-file-to-update)
- [How to Commit It](#how-to-commit-it)
- [Verification](#verification)

---

## Before You Mark Work Complete

Run this checklist before opening a PR for review or marking an issue done:

- [ ] Did I discover any workaround, non-obvious pattern, or convention?
- [ ] Is there a skill file for the area I worked in?
- [ ] If yes — did I update it?
- [ ] If no — did I create one?
- [ ] Is the skill file committed in **this same PR**? (Not a follow-up. Same PR.)

If all five are checked, you're done. If any are unchecked, finish them first.

---

## What Counts as a Learning Worth Writing Back

**Write it:**

| Category | Example |
|---|---|
| Upstream bug workaround | "GNOME 47 broke this dconf key — use `x-gnome-47/` prefix instead. See upstream issue #NNN." |
| Non-obvious correctness requirement | "Must edit both the override file AND the dconf lock file — editing only one silently has no effect." |
| Convention not obvious from code | "Renovate automerges digest/patch/minor PRs. Only major bumps need agent review." |
| Trial-and-error discovery | "SHA pinning for internal `projectbluefin/` refs uses a different policy than third-party — read the comment in the workflow file before converting." |
| **Project-internal fact correction** | "No `:latest` tag exists on `projectbluefin/bluefin`. The only stream tags are `:testing` and `:stable`. Source: `execute-release.yml`." |

**Project-internal fact drift is a first-class failure mode.** When an agent writes documentation about image names, tags, workflow outputs, registry paths, or any other project-internal fact — and gets it wrong because it used training data instead of reading the source — that is a skill failure. The fix is always the same: read the workflow file, update the skill, add verification commands so the next agent can self-check.

**The rule:** Any skill file containing project-internal facts (image names, tag schemas, published streams, workflow matrix values) **must** include a "Verification" section with the exact shell commands to re-derive those facts from source. See [`image-registry.md`](./image-registry.md) for the reference implementation.

**Do NOT write:**

| Category | Example |
|---|---|
| One-off task note | "Use commit message `fix(gnome): revert dconf key` for this PR" |
| Obvious developer knowledge | "Run git status to see changed files" |
| Ephemeral state | "Renovate is currently paused due to config issue #487" |
| Contradiction of another skill | If a skill says X and you want to say not-X, update the skill to say not-X — don't add a new doc |

---

## Where to Write It

| Working in... | Write to |
|---|---|
| `projectbluefin/common` | `docs/skills/` in this repo |
| `projectbluefin/bluefin` | `docs/skills/` in that repo |
| `projectbluefin/bluefin-lts` | `docs/skills/` in that repo |
| `projectbluefin/dakota` | `docs/skills/` in that repo |
| `projectbluefin/actions` | `docs/skills/` (Copilot CLI) **and** `.github/skills/` (Cloud Agent) — both |
| `projectbluefin/testsuite` | `docs/skills/` in that repo |
| Cross-cutting (affects 2+ repos) | Local first, then open a propagation issue in `projectbluefin/actions` |
| `ublue-os/*` | **NEVER.** Tell the human to report manually. |

If the target repo has no `docs/skills/` directory, create it.

---

## Which Skill File to Update

Use the closest matching existing skill. Only create a new skill when the change introduces a new reusable domain that has no existing home.

| Changed path | Owning skill |
|---|---|
| `.github/workflows/build.yml` | [ci-tooling](ci-tooling/SKILL.md) |
| `.github/workflows/e2e*.yml`, test configs | [e2e-ci](e2e-ci/SKILL.md) |
| `.github/workflows/release.yml` | [release-promotion](release-promotion/SKILL.md) |
| Lifecycle automation | [label-workflow](label-workflow.md) or [bonedigger](bonedigger/SKILL.md) |
| `system_files/**` | [submodule-boundary](submodule-boundary.md) or [dconf-consistency](dconf-consistency.md) |
| `Justfile` | The skill owning the changed recipe |
| `Containerfile` | [containerfile](containerfile/SKILL.md) |
| `.github/CODEOWNERS` | [governance](governance.md) |

When in doubt, file a GitHub issue in `projectbluefin/common` with the
component, evidence, and agent-context gap described in the body. Do **not**
add it to `factory-improvement/SKILL.md` as a running list.

---

## How to Commit It

The skill update goes in the **same commit or same PR** as the implementation. Not a follow-up PR. Not "I'll do it later."

Stage explicit paths, audit the staged diff, and use the current repository
contract for commit attribution. Do not copy a model or runtime from an old
example.

There is no bespoke CI gate for this. Review, `pre-commit`, and the self-repair
loop enforce the obligation; see [write-a-skill](write-a-skill.md#verification)
for the authoring checklist.

---

## Verification

- [ ] A reusable learning is captured in the closest owning skill in the same PR.
- [ ] Its frontmatter, links and generated catalog pass the checks in
      [write-a-skill](write-a-skill.md#verification).
- [ ] No standalone process-convention CI gate was added; the
      [factory contract](../factory/agentic-model.md) permits only the
      aggregate `pre-commit` step.
