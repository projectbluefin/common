---
name: skill-improvement
description: "The skill-improvement mandate — every agent session must produce a skill file update alongside the work. Checklist, what counts as a learning, and where to write it."
---

# Skill Improvement Mandate

Every agent session produces two outputs:

1. **The work** — the PR, fix, or improvement
2. **The learning** — what a future agent should know

Output 1 without Output 2 leaves the factory no smarter. The loop only compounds if agents write back.

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
Changed a package?           → bluefin-packages.md
Changed a release step?      → release-promotion.md or bluefin-release.md
Changed a dakota element?    → the matching dakota-*.md skill
Changed the lifecycle bot?   → label-workflow.md or bonedigger.md
Changed CI gates?            → e2e-ci.md
New domain entirely?         → create docs/skills/<area>.md
```

When in doubt, update `factory-improvement.md` with the gap you found — that file tracks factory-level discoveries.

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

## See Also

- [`docs/skills/skill-drift.md`](./skill-drift.md) — how the CI enforcement works
- [`docs/factory/IMPROVEMENTS.md`](../factory/IMPROVEMENTS.md) — the running record of factory improvements (append here too when shipping something significant)
