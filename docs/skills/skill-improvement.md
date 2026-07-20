---
name: skill-improvement
version: "1.1"
last_updated: 2026-07-20
tags: [skills, improvement, documentation]
description: "The skill-improvement mandate — every agent session must produce a skill file update alongside the work. Use when completing a task and deciding whether to write a skill update, or when creating or updating a skill file."
metadata:
  type: procedure
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

## Contents
- [Before You Mark Work Complete](#before-you-mark-work-complete)
- [What Counts as a Learning Worth Writing Back](#what-counts-as-a-learning-worth-writing-back)
- [Where to Write It](#where-to-write-it)
- [Which Skill File to Update](#which-skill-file-to-update)
- [How to Commit It](#how-to-commit-it)
- [See Also](#see-also)

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

```
Changed a workflow?          → ci-tooling.md or workflow-map.md
Changed a GNOME setting?     → dconf-consistency.md
Changed a release step?      → release-promotion.md
Changed the lifecycle bot?   → label-workflow.md or bonedigger.md
Changed CI gates?            → e2e-ci.md
New domain entirely?         → create docs/skills/<area>.md
```

When in doubt, file a GitHub issue in `projectbluefin/common` with `kind/improvement` + `area/agent` labels. Add `ai-context` if it's a context gap affecting agent reliability. Do **not** add it to `factory-improvement.md` as a running list.

---

## How to Commit It

The skill update goes in the **same commit or same PR** as the implementation. Not a follow-up PR. Not "I'll do it later."

```bash
# stage both the implementation and the skill update together
git add .github/workflows/something.yml docs/skills/ci-tooling.md
git commit -m "feat(ci): add SHA pinning for new action

Update ci-tooling.md with pinning pattern for this action type.

Assisted-by: Claude Sonnet 4.6 via GitHub Copilot
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

The skill-drift CI gate will warn if you forget. Treat the warning as a hard requirement.

---

## Self-audit against canonical skill standards

Before finalizing a skill update, verify it matches the canonical patterns surfaced by Context7 (highest-rated conventions as of 2026-07-20):

| Source | Relevance |
|---|---|
| `/anthropics/skills` (benchmark 80.59) | SKILL.md schema, YAML frontmatter rules, bundled resources layout, progressive disclosure model. |
| `/addyosmani/agent-skills` (benchmark 85.67) | Highest-rated skill-improvement source; target structure for Red Flags and Verification sections. |
| `/vercel-labs/agent-skills` (benchmark 84.36) | `skills/{name}/SKILL.md` + `scripts/` + `references/` directory convention. |

Checklist:
- [ ] Frontmatter includes `name`, `description` with "Use when" triggers, `version`, `last_updated`, `tags`, and `metadata.type`.
- [ ] Description is specific enough that an agent can decide to load the skill from the description alone.
- [ ] Skill body has `## When to Use`, `## Core Process`, `## Red Flags`, and `## Verification` sections (or equivalent).
- [ ] Any library/framework API examples were verified via Context7 first and the `libraryId` is recorded in `metadata.context7-sources`.
- [ ] Files over 500 lines are split into a per-skill directory with `references/` or `scripts/` per the Anthropic/Vercel convention.

## See Also

- [`docs/skills/skill-drift.md`](./skill-drift.md) — how the CI enforcement works
- Canonical skill conventions (verified via Context7):
  - `/anthropics/skills` — YAML frontmatter, bundled resources, progressive disclosure.
  - `/addyosmani/agent-skills` — skill-improvement and audit structure.
  - `/vercel-labs/agent-skills` — per-skill directory layout with `scripts/` and `references/`.
