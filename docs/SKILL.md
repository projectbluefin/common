# Common Skill Router

Agent entry point for `projectbluefin/common`. Load only the skill that matches your task.

## Task → Skill

| I need to... | Load |
|---|---|
| Understand CODEOWNERS, triagers, or branch protection | `docs/skills/governance.md` |
| Run hive priority review at session start | `docs/skills/hive-review.md` |
| Check the PR queue or merge ruleset | `docs/skills/queue-dashboard.md` |
| Debug post-merge E2E CI, MOTD, or brew-setup masking | `docs/skills/e2e-ci.md` |

## Improving skill docs

All files in `docs/skills/` are Claude Code skills maintained with the Trail of Bits skill-improver:

```bash
npx skills add https://github.com/trailofbits/skills --skill skill-improver
# Then in your editor: /skill-improver docs/skills/<file>
```

## Scope rules

- **Doc tasks**: modify only `docs/` and `AGENTS.md`. Do not create `.github/` workflow files unless the task is explicitly CI work.
- **CI tasks**: touch only `.github/` and update `docs/skills/` if learnings arise.
- **Changes here propagate to all downstream Bluefin variants.** Keep changes surgical.
