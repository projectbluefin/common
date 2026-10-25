---
name: skill-improvement
version: "1.4"
last_updated: "2026-09-13"
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

Use the closest matching existing skill. Run `just skill <query>` or `python3 scripts/select-skill.py <query>` to search and rank existing skill files by topic. Only create a new skill when the change introduces a new reusable domain that has no existing home.

```
Changed a workflow?          → ci-tooling/SKILL.md or workflow-map.md
Changed a GNOME setting?     → dconf-consistency.md
Changed a release step?      → release-promotion/SKILL.md
Changed the lifecycle bot?   → label-workflow.md or bonedigger/SKILL.md
Changed CI gates?            → e2e-ci/SKILL.md
New domain entirely?         → create docs/skills/<area>.md
```

When in doubt, file a GitHub issue in `projectbluefin/common` with the
component, evidence, and agent-context gap described in the body. Do **not**
add it to `factory-improvement/SKILL.md` as a running list.

---

## How to Commit It

The skill update goes in the **same commit or same PR** as the implementation. Not a follow-up PR. Not "I'll do it later."

```bash
# stage both the implementation and the skill update together
git add .github/workflows/something.yml docs/skills/ci-tooling/SKILL.md
git commit -m "feat(ci): add SHA pinning for new action

Update ci-tooling/SKILL.md with pinning pattern for this action type.

Assisted-by: Claude Sonnet 4.6 via GitHub Copilot
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

There is no CI gate for this. Skill-update discipline is enforced by
`pre-commit`, by review, and by this self-repair loop — see
[Why there is no CI gate](#why-there-is-no-ci-gate). Treat the obligation as a
hard requirement regardless.

---

## Self-audit against canonical skill standards

Conventions come from this file's `metadata.context7-sources`:
`/anthropics/skills` (frontmatter, progressive disclosure),
`/addyosmani/agent-skills` (Red Flags and Verification structure),
`/vercel-labs/agent-skills` (`SKILL.md` + `references/` layout).

- [ ] Front-matter and size budget match [`write-a-skill.md`](./write-a-skill.md).
- [ ] The description alone is enough for an agent to decide to load the skill.
- [ ] Body has `## When to Use`, process content, `## Red Flags`, and
      `## Verification`.
- [ ] External-tool behaviour came from upstream docs, not memory — see
      [`context7.md`](./context7.md).

---

## Why there is no CI gate

`skill-drift.yml` used to warn when a pull request changed implementation files
without touching the matching skill doc. It is gone from every factory repo,
`common` never ran it, and it must not come back.

It was retired because it never enforced anything. The reusable workflow it
called, `projectbluefin/actions/.github/workflows/skill-drift-check.yml`, lost
its logic in `actions@001ae97` and was replaced by a no-op stub in
`actions@a7c230c` that echoed a removal notice and exited zero without reading
a single changed path. Five repos — bluefin, bluefin-lts, dakota, knuckle,
testsuite — kept calling the stub and kept collecting a green tick. A check
that cannot fail is worse than no check: the green tick reads as evidence that
a skill update was not needed.

The policy outlasts the incident. Per
[`agentic-model.md`](../factory/agentic-model.md), a CI check earns `exit 1`
only when failure means a broken or wrong image ships. Skill drift ships
nothing, so it is enforced at developer time by `pre-commit` and by review,
never by a bespoke per-convention CI job.

## Red Flags

- Re-adding `skill-drift.yml`, or any CI job whose only purpose is enforcing a
  documentation or process convention.
- Treating a green CI run as evidence that a skill update was unnecessary.
- Promising the skill update as a follow-up pull request.
