# docs/skills — Index

Agent skill docs for the `projectbluefin/common` repo.

| File | What it covers |
|---|---|
| [governance.md](governance.md) | Triagers role, CODEOWNERS sentinel pattern, sync workflow, branch protection matrix |
| [hive-review.md](hive-review.md) | `~/src/hive-status` — session start, P0/P1 triage, hive label taxonomy |
| [queue-dashboard.md](queue-dashboard.md) | queue.projectbluefin.io — PR tiers, merge ruleset (2 approvals), refresh cadence |
| [e2e-ci.md](e2e-ci.md) | Post-merge E2E CI architecture — common suite, brew tools masked in CI, MOTD fix, known quarantined scenarios |

## Quality standard

All files in this directory are Claude Code skills. Use the Trail of Bits skill-improver to maintain them:

```bash
npx skills add https://github.com/trailofbits/skills --skill skill-improver
# Then in your editor: /skill-improver docs/skills/<file>
```

Each file must have YAML frontmatter with `name` and `description`. CI enforces this.
