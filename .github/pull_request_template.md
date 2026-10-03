# bluefin-common PR

## What does this change?

<!-- Required: one sentence -->

## Why?

<!-- Link related issues with "Refs #NNN". Use "Closes #NNN" only for code-only
     work whose acceptance criteria are satisfied at merge, or a report whose
     delivery and verification are already complete. Image reports stay open
     until delivery evidence and reporter verification are recorded. -->
Refs #

## PR pipeline

```
opened ──▶ native review status ──▶ approved ──▶ merge queue ──▶ merged
```

> A maintainer reviews and approves; merge goes through the merge queue.
> Select `blocked` or `hold` to pause the work.

PRs use GitHub assignments, review requests, and review status, not issue-stage
labels. Keep related image reports open after merge: record what must ship and
which image or channel the reporter will need before requesting verification.
Project-owned lifecycle posts state the status, next actor, specific next steps,
and reporter action (or explicitly say none is needed).

## Checklist

- [ ] PR title follows Conventional Commits (`fix:`, `feat:`, `docs:`, `ci:`, `refactor:`, etc.)
- [ ] `just check` passes
- [ ] `pre-commit run --all-files` passes
- [ ] Skill doc updated if the change affects agent-facing conventions or behavior (see `docs/skills/skill-improvement.md`)
- [ ] `AGENTS.md` / `docs/SKILL.md` / `docs/skills/` links remain valid
- [ ] CI is green after push: `gh run list --repo projectbluefin/common --limit 5`

## AI attribution

If this PR includes AI-authored commits, include both trailers:
```
Assisted-by: <Model> via GitHub Copilot
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```
