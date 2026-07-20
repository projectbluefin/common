---
name: factory-onboarding
version: "1.0"
last_updated: 2026-06-23
tags: [factory, onboarding, setup]
description: "How to onboard a repo into the Project Bluefin factory model. The self-improvement mandate, what agents must do, and what is banned. Load when setting up a new repo or auditing factory compliance."
metadata:
  type: procedure
---

# Factory Onboarding

Project Bluefin is an agentic OS factory. Agents implement. Humans set direction and approve merges.

The factory gets smarter only if agents write back what they learn. Without that, every session starts from zero.

---

## The Two-Output Rule

Every agent session produces two outputs:

1. **The work** — the PR, fix, or feature
2. **The learning** — what a future agent needs to know

Output 1 without Output 2 = factory does not improve.

The learning goes in `docs/skills/` — the same PR, not a follow-up.

---

## What Is Banned

These patterns actively harm the factory. Delete them when found.

**Changelog files** (`IMPROVEMENTS.md`, `CHANGELOG.md`, `CHANGES.md`, `SESSION.md`, etc.)
Agents append to them instead of updating skill files. The result: a stale changelog, skill files that never get updated. **Delete on sight.**

**"Append here" instructions**
Any doc saying "append when you ship something" is a hallucination magnet. Route to `docs/skills/<file>.md` instead.

**Session logs committed to the repo** (`NOTES.md`, `PLAN.md`, `TODO.md`, progress files)
These become stale context that misleads every future agent. Session state lives in the agent's session folder only, never committed.

---

## What a Factory Repo Needs

### `docs/skills/`

Every repo needs a `docs/skills/` directory. This is the knowledge base. Agents read it; agents update it.

Minimum files:
- `skill-improvement.md` — the two-output rule adapted for this repo
- `docs/SKILL.md` — task→skill router and index

Reference: [`projectbluefin/common/docs/skills/`](https://github.com/projectbluefin/common/blob/main/docs/skills/)

### `skill-drift.yml` CI check

Wire the skill-drift check. It warns when a PR changes code without updating a skill file.

```yaml
name: Skill Drift

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: read

jobs:
  skill-drift:
    uses: projectbluefin/actions/.github/workflows/skill-drift-check.yml@v1
    with:
      code-paths: '[".github/workflows/**", "Justfile"]'  # adapt to your repo
      skill-paths: '["docs/skills/**", "docs/*.md", "AGENTS.md"]'
```

Adjust `code-paths` to match your repo's implementation files. Treat warnings as hard requirements.

### `AGENTS.md` — self-improvement section

Every factory repo's `AGENTS.md` must state the two-output rule and the banned anti-patterns explicitly. Agents read `AGENTS.md` first. If it is not there, agents will not do it.

Minimum block to include:

```markdown
## Self-Improvement

Every session: ship the work AND update the relevant skill file in `docs/skills/`.
Same PR. Not a follow-up.

Banned:
- No changelog files. Delete IMPROVEMENTS.md, CHANGELOG.md, SESSION.md if found.
- No session notes committed to the repo.
- No "append here" docs. Route to docs/skills/ instead.

Before marking work done:
- [ ] Discovered a workaround, pattern, or convention?
- [ ] Skill file updated (or created)?
- [ ] Committed in this same PR?
```

---

## Done When

- [ ] `docs/skills/` exists with `skill-improvement.md` and `docs/SKILL.md` task router
- [ ] `skill-drift.yml` wired and passing
- [ ] `AGENTS.md` includes self-improvement mandate and banned list
- [ ] No changelog files in the repo

---

## Cross-Repo Patterns

Factory-wide learning -> open issue in `projectbluefin/common` (`kind/improvement` + `area/agent`).
Never touch `ublue-os/*`. Tell the human to report upstream manually.
