# bluefin-common PR

## What does this change?

<!-- Required: one sentence -->

## Why?

<!-- Link related issues with "Refs #NNN" or "Fixes #NNN". -->
Refs #

## How this PR merges

Prow requests two reviews from `OWNERS`. A reviewer who is not the author
comments `/lgtm` (removed on every push), an `OWNERS` approver comments
`/approve` or approves in GitHub, and Common also needs 2 approving GitHub
reviews. With green checks, Prow puts the PR in the merge queue. `/hold`
pauses it. See [how issues and PRs work here](https://github.com/projectbluefin/common/blob/main/docs/skills/label-workflow.md).

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
