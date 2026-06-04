# docs/skills — Index

Agent skill docs for the `projectbluefin/common` repo.

## Factory docs

| File | What it covers |
|---|---|
| [../factory/README.md](../factory/README.md) | Org brain landing page — what common is, factory structure, data flow, org board |
| [../factory/agentic-model.md](../factory/agentic-model.md) | Agent operating guide — rules, issue lifecycle, label taxonomy, PR policy, branch targets |
| [../factory/migration-status.md](../factory/migration-status.md) | Live parity matrix — current state of factory infra migration across all 5 repos |

## Skill docs

| File | What it covers |
|---|---|
| [bluefin-ci.md](bluefin-ci.md) | Bluefin CI/CD troubleshooting — workflow failures, build status, common issues |
| [governance.md](governance.md) | Triagers role, CODEOWNERS sentinel pattern, sync workflow, branch protection matrix |
| [hive.md](hive.md) | Hive label taxonomy, sync workflow schedule, org board fields, finding work |
| [qa.md](qa.md) | QA model, test coverage matrix, promotion gates by repo, hardware gap, running tests |
| [bonedigger.md](bonedigger.md) | bonedigger integration guide, current status per repo, template sync, known issues |
| [hive-review.md](hive-review.md) | `~/src/hive-status` — session start, P0/P1 triage, hive label taxonomy |
| [queue-dashboard.md](queue-dashboard.md) | PR review and merge queue workflow — ruleset (1 approval, squash, ALLGREEN queue), triage tiers, rebase patterns, submodule boundary policy |
| [workflow-map.md](workflow-map.md) | What each `common` GitHub workflow is for — validation, E2E, release, and factory-policy boundaries |
| [e2e-ci.md](e2e-ci.md) | Pre/post-merge and promotion-candidate E2E CI for common — composed PR gate, testing-stream smoke/common checks, masked brew setup, quarantined scenarios |
| [ci-tooling.md](ci-tooling.md) | Pre-commit floating-tag guard, live skill-drift workflow, Renovate OCI digest tracking |
| [onboarding.md](onboarding.md) | Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos |
| [submodule-boundary.md](submodule-boundary.md) | What is/isn't editable in this repo — `system_files/shared/` is read-only (aurorafin-shared submodule), `system_files/bluefin/` is editable |
| [dconf-consistency.md](dconf-consistency.md) | GSettings override ↔ dconf lock file parity rules — must edit both files together for locked settings |
| [image-registry.md](image-registry.md) | ublue-os vs projectbluefin org split for OCI publishing — production images still at `ghcr.io/ublue-os/` |
| [rollback-helper.md](rollback-helper.md) | `ublue-rollback-helper` TUI state machine — three-way coordinated arrays, LTS/non-LTS branches, registry path derivation, testing guidance |
| [skill-drift.md](skill-drift.md) | How to satisfy the PR skill-drift check and what counts as a real skill update |
| [acmm-audit-level1.md](acmm-audit-level1.md) | ACMM Level 1 audit (2026-06-04) — blindspots, feedback mechanisms, structural obstacles, Level 2 recommendations and issue batch |
| [../factory/README.md](../factory/README.md) | Factory operating model entry point for org-level agent and maintainer workflow |

## Quality standard

All files in this directory are Claude Code skills. Each file must have YAML frontmatter with `name` and `description`. CI enforces this via `.github/workflows/docs-quality.yml`.
