---
title: "Queue Dashboard: PR Tiers & Merge Ruleset"
load_when: "Reviewing queue.projectbluefin.io, checking PR status across repos, managing merge rules"
categories: ["queuing", "ci", "pr-workflow"]
---

# Queue Dashboard — PR Tiers & Merge Ruleset

Load when: Checking queue.projectbluefin.io, reviewing PR status, or managing merge rules.

## Quick start

```
queue.projectbluefin.io
├─ Common (requires 2 approvals)
├─ Bluefin (requires 1 approval, must pass CI)
├─ Bluefin-LTS (requires 1 approval, must pass CI + E2E)
└─ Dakota (requires 1 approval, must pass CI)
```

## Dashboard Overview

The **queue dashboard** provides a unified view of all pending PRs across Project Bluefin repositories. It's not about PR ordering — it's about **merge readiness** and **CI health**.

### What it shows

```
queue.projectbluefin.io
────────────────────────────────────────
Repo: common
├─ Waiting for review (4 PRs)
│   ├─ #441 feat(qa): regression contract [📋 docs]
│   ├─ #442 fix(system): broken script [⚙️ ci/cd]
│   └─ ...
├─ Waiting for CI (2 PRs)
│   ├─ #440 refactor: ... [🔄 running...]
│   └─ #439 test: ... [⏱️ timeout in 5min]
└─ Ready to merge (1 PR)
    ├─ #438 feat(...) [✓ 2 approvals]

Repo: bluefin
├─ Waiting for review (8 PRs)
├─ Waiting for CI (1 PR)
└─ Ready to merge (3 PRs)

[... and so on for bluefin-lts, dakota ...]
```

### Data sources

- GitHub PR status (open, draft, waiting for review)
- CI check status (checks-pending, checks-running, checks-passing, checks-failing)
- Review state (approved, changes-requested, pending-review)
- Mergability (conflicts, protected branch rules)

## PR Tiers by Repository

### Tier 1: Common (`projectbluefin/common`)

**Requirement**: 2 approvals + all checks passing + no conflicts

```yaml
Branch protection:
  require_code_owner_reviews: true
  require_status_checks: true
  dismiss_stale_pull_request_approvals: true
  require_branches_up_to_date: false
  
Ruleset: main-review-required-with-renovate-bypass
  enforcement_level: enforce
  required_approvals: 2
  bypass:
    - renovate[bot] (single commit, file changes only)
```

**Why 2 approvals**: Common is shared across all variants. Changes here affect:
- Flatpak bundles
- System configuration
- Shared scripts
- Justfile recipes

One approval is insufficient for this scope.

**Renovate bypass**: Dependency updates go through with 1 approval if:
- Only lockfile changes (e.g., `package-lock.json`)
- File scope is tiny (e.g., single `.just` file)
- No functional code changes

### Tier 2: Bluefin (`projectbluefin/bluefin`)

**Requirement**: 1 approval + all checks passing

```yaml
Branch protection (main):
  require_approvals: 1
  require_status_checks: true
  required_checks:
    - build
    - lint-syntax
    - e2e-smoke
  dismiss_stale_reviews: true
  require_branches_up_to_date: false
```

**Why 1 approval**: Bluefin is more stable than common but still core. Code review provides basic gates.

**E2E smoke requirement**: Every PR must pass smoke tests (GNOME boot + login).

### Tier 3: Bluefin-LTS (`projectbluefin/bluefin-lts`)

**Requirement**: 1 approval + all checks passing + E2E validation

```yaml
Branch protection (main):
  require_approvals: 1
  required_checks:
    - build
    - e2e-smoke
    - e2e-full (on merge)  # Full suite runs after merge
  dismiss_stale_reviews: true
  require_branches_up_to_date: false
```

**Why E2E full on merge**: LTS is long-term support. Post-merge E2E catches regressions before release.

### Tier 4: Dakota (`projectbluefin/dakota`)

**Requirement**: 1 approval + all checks passing

```yaml
Branch protection (main):
  require_approvals: 1
  required_checks:
    - build
    - lint-syntax
  dismiss_stale_reviews: true
```

**Why lighter**: Dakota is the reference implementation (experimental).

## Check Status Legend

| Status | Meaning | Action |
|--------|---------|--------|
| 🟢 Passing | Check passed, all green | Nothing needed |
| 🟡 Pending | Check running, please wait | Wait 5–15 min |
| 🔴 Failing | Check failed, review logs | Fix and force-push |
| ⚪ Skipped | Check not applicable to this PR | OK to ignore |
| ⚠️ Stale | Check passed but base branch changed | Re-run (push to refresh) |
| 🔒 Required | Check required to merge | Must pass before merge |

## Merge Rules by Repository

### Common

```
Merge rule: All conditions must be met

✓ 2 code approvals (CODEOWNERS + 1 other)
✓ 0 changes requested
✓ Build check passes
✓ All required CI checks pass
✓ No conflicts with main
✓ Branch protection rules satisfied

[Merge with "Create a merge commit"]
```

**Responsible parties**: Triagers (@projectbluefin/triagers) can approve docs. Core team approves code.

### Bluefin, Bluefin-LTS, Dakota

```
Merge rule: Simplified

✓ 1 code approval
✓ 0 changes requested
✓ All required CI checks pass
✓ Smoke tests pass (all repos)
✓ No conflicts with main

[Merge with "Create a merge commit"]
```

## Dashboard Refresh Cadence

| Event | Latency |
|-------|---------|
| PR opened | 2–5 seconds |
| Review submitted | 1–2 seconds |
| CI check completes | 5–10 seconds |
| Status page refresh | 30 seconds |

**Manual refresh**: Press `F5` in browser or `gh pr list` from CLI.

## Common Dashboard Patterns

### "Ready to merge" section is empty but PRs exist

**Cause**: Waiting for reviews or CI.

**Action**:
```bash
# Check why each PR isn't ready
gh pr status  # shows review and CI status
gh pr view {number} --json checks,reviews
```

### PR shows "conflicts with main"

**Cause**: Another PR merged to main since your PR was opened.

**Action**:
```bash
gh pr checks {number}  # confirms conflict
# Then locally:
git fetch origin main
git rebase origin/main  # rebase (preferred) or merge
git push origin --force-with-lease
```

### Check stuck in "pending" for 10+ minutes

**Cause**: CI runner stalled, network glitch, or timeout.

**Action**:
```bash
# Re-trigger the check
gh pr checks {number} --watch  # wait for completion

# If still stuck after 20 min, manually re-run:
gh workflow run [workflow] -R projectbluefin/[repo]
```

## Integration with bonedigger

Issues from bonedigger intake (filed via `ujust report`) link to PRs that fix them:

```
Issue #999 — "GNOME crashes on boot"
    ↓
bonedigger auto-assigns p1
    ↓
Appears in hive-status as high priority
    ↓
Developer claims + opens PR #1234
    ↓
PR #1234 links back to issue #999
    ↓
When PR merges → issue auto-verified (if fixed)
```

See [hive-review](./hive-review.md) for triage workflow.

## Integration with Trail of Bits CI

The skill-drift CI validates that dashboard documentation stays synchronized with repository rules:

- **Code changes**: When branch protection or CI rules change, this guide must update
- **Trigger**: On every PR, `skill-drift-check.yml` compares code changes to skill updates
- **Enforcement**: If rules change without skill updates, the check fails
- **Waiver**: Note in PR if no skill update is needed

See [skill-drift documentation](./SKILL_DRIFT_CI.md) for handling CI failures.

## Troubleshooting

### "Check is failing but I don't know why"

```bash
# View full check logs
gh pr checks {number}

# For specific failed check:
gh run list -R projectbluefin/[repo] --status failure -L 5
gh run view {run-id} --log
```

### "I'm blocked by E2E, can I merge anyway?"

**For common**: No. 2 approvals + all checks required.

**For bluefin/lts/dakota**: Only if:
1. E2E timeout (not failure) and 15+ min elapsed
2. Get maintainer approval via comment: `@maintainers LGTM anyway`
3. Maintainer can force-merge with `/lgtm force`

### "Branch protection rule changed, dashboard doesn't show it"

```bash
# Refresh manually
curl -s https://queue.projectbluefin.io/api/refresh
# or press F5 in browser
```

## See also

- [hive-review](./hive-review.md) — P0/P1 triage and issue prioritization
- [bonedigger-lifecycle](./bonedigger-lifecycle.md) — Issue state machine that feeds into queue
- [REGRESSION_CONTRACT](../qa/REGRESSION_CONTRACT.md) — Feature parity across streams, tested by CI
