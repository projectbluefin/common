# Common Skill Router

Agent entry point for `projectbluefin/common`. Load only the skill(s) that match your task.

## Task → Skill

| I need to... | Load |
|---|---|
| Understand CODEOWNERS, triagers, or branch protection | `docs/skills/governance.md` |
| Run hive priority review at session start | `docs/skills/hive-review.md` |
| Understand the hive system / kubestellar-bot loop | `docs/skills/hive.md` |
| Need to know when to stop and ask a human | `docs/skills/human-gates.md` |
| Need to write a skill update / unsure what counts | `docs/skills/skill-improvement.md` |
| Understand why Bluefin was rewritten (The Pattern) | `docs/factory/IMPROVEMENTS.md` |
| Check the PR queue or merge ruleset | `docs/skills/queue-dashboard.md` |
| Debug post-merge E2E CI, MOTD, or brew-setup masking | `docs/skills/e2e-ci.md` |
| Add, remove, or modify packages (brew, flatpak, RPM) | `docs/skills/bluefin-packages.md` |
| Change a GNOME setting or dconf key | `docs/skills/dconf-consistency.md` |
| Touch any image reference or registry path | `docs/skills/image-registry.md` |
| Work on `ublue-rollback-helper` | `docs/skills/rollback-helper.md` |
| Change `.github/workflows/` | `docs/skills/ci-tooling.md` + `docs/skills/workflow-map.md` |
| Understand what each workflow does | `docs/skills/workflow-map.md` |
| Work on E2E test changes | `docs/skills/e2e-ci.md` |
| Understand the release process or stream tags | `docs/skills/bluefin-release.md` |
| Work on the LTS variant | `docs/skills/bluefin-lts.md` |
| Work on Renovate dependency updates | `docs/skills/bluefin-renovate.md` |
| Understand the build pipeline or PR workflow | `docs/skills/bluefin-build.md` |
| Understand the security model (COPR, cosign, secureboot) | `docs/skills/bluefin-security.md` |
| Understand the promotion pipeline (what gates exist today) | `docs/qa/PROMOTION_GATES.md` |
| Understand factory open gaps and parity matrix | `docs/factory/README.md` |
| Understand the skill-drift CI check | `docs/skills/skill-drift.md` |
| Understand the bonedigger lifecycle bot | `docs/skills/bonedigger.md` |
| Improve the factory (gap audit, automation coverage) | `docs/skills/factory-improvement.md` |
| Check on-call / hive state for the whole org | `docs/skills/hive.md` |
| Submit a hardware test report | `docs/hardware-testing.md` |
| Work on the ACMM / factory maturity model | `docs/skills/acmm-audit-level2.md` |

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
