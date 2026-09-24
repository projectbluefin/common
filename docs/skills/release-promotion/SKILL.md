---
name: release-promotion
version: "1.1"
last_updated: "2026-08-08"
id: release-promotion
one_line_purpose: Cut releases and verify promotion/hotfix artifacts.
entry_point: docs/skills/release-promotion/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [release, promotion, staging]
description: >-
  Promotion criteria, monthly release cadence, hotfix procedure, and artifact
  verification for projectbluefin/common. Use when cutting a release,
  understanding the promotion pipeline, or verifying release artifacts.
metadata:
  type: reference
---

# Release and promotion — common

Load this when cutting a release, evaluating whether a monthly tag is safe to create, doing a hotfix, or verifying signed artifacts.

## When to Use

- Cutting or evaluating a monthly release tag
- Doing a hotfix outside the monthly window
- Verifying cosign signatures, SBOM, or SLSA attestations on a published image
- Understanding how common changes propagate to downstream `:testing` builds
- Debugging the testing→main squash promotion pipeline

## When NOT to Use

- CI workflow editing (SHA pinning, pre-commit, Renovate) → [`ci-tooling.md`](../ci-tooling/SKILL.md)
- Debugging silent CI failures or `startup_failure` → [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md)
- PR review or issue triage workflows

---

## Promotion criteria

A `common` release is safe when **all** of the following are true:

| Criterion | How to verify |
|---|---|
| Post-merge E2E is green | Check `.github/workflows/e2e.yml` run on latest `main` commit |
| No PRs on `hold` targeting `main` | `gh pr list --repo projectbluefin/common --search "label:hold" --base main` |
| No open P0 issues | `~/src/hive-status` — zero 🔴 blockers |
| Promotion-candidate E2E passed this week | Check `.github/workflows/promotion-candidate-e2e.yml` (runs Tuesdays) — no open blocker issue from it |

If any criterion fails, **do not tag a release**. File or escalate the blocker issue and wait.

> **Planned gate (common#513):** The monthly `release.yml` will be updated to run the promotion-candidate E2E as a required prerequisite job before creating the GitHub Release. Until that ships, the check above is manual.

---

## Monthly release cadence

- **Schedule:** 1st of every month at 00:00 UTC (`release.yml` cron)
- **Tag format:** `v<YEAR>.<MONTH>` — e.g., `v2026.06`
- **What it creates:** A GitHub Release with a changelog since the previous tag, pointing at the current `main` HEAD
- **What it does NOT do:** Promote or retag the OCI image — `:latest` is always the most recent merge to `main`

---

## Emergency hotfix release

When a critical fix needs a versioned tag outside the monthly window:

1. Merge the fix to `main` via normal PR process
2. Verify all promotion criteria above are met
3. Run `release.yml` manually via `workflow_dispatch` — it will tag the current `main` with the current month's tag (or create a patch tag manually with `gh release create`)
4. Notify downstream image repos if the fix affects their builds

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "E2E is green, so we can tag." | Check **all four** criteria — E2E alone is not sufficient. |
| "The promotion PR will auto-merge once CI passes." | Merge queue enqueue can fail due to required status checks not completing; verify after squash branch rebuild. |
| "The squash conflict is from someone else's PR." | You can still fix the squash branch — see [troubleshooting](references/troubleshooting.md). |
| "The `ci(promote):` PR title is what triggers execute-release." | `execute-release.yml` matches the commit message that lands on the target branch (`chore: promote ...`), not the PR title. |

## Red Flags

- Promotion PR has `release/blocked` with no E2E evidence → check `post-testing-e2e.yml` `branches:` filter
- `promote-testing-to-main.yml` fails with `UD` conflicts → file deletions on testing haven't reached main
- `Publish` workflow stuck in_progress > 30 min → zombie run holding concurrency queue
- `execute-release.yml` not triggering after promotion PR merges → check commit subject match

## Verification

- [ ] Confirm all four promotion criteria are met before tagging
- [ ] For artifact verification: run `gh attestation verify` (keyless, post-2026-06-11), not just cosign verify
- [ ] After a hotfix: notify downstream repos if the fix affects their builds
- [ ] After a squash branch rebuild: wait for `PR Validation — testsuite` to complete before enqueuing

## References

| File | Description |
|---|---|
| [references/supply-chain.md](references/supply-chain.md) | Supply chain current state (signing, SBOM, SLSA, CVE), required permissions, and artifact verification commands. |
| [references/downstream-propagation.md](references/downstream-propagation.md) | How common updates reach bluefin, bluefin-lts, and dakota `:testing` builds (Renovate + BST). |
| [references/pr-based-release.md](references/pr-based-release.md) | PR-based squash promotion model, schedule, commit title rules, repo variants, E2E gate model, and reusable workflow patterns. |
| [references/troubleshooting.md](references/troubleshooting.md) | Troubleshooting the testing→main squash promotion: gate stuck, UD conflicts, merge queue blocked, branch divergence, zombie publish runs, actions branch policy. |
