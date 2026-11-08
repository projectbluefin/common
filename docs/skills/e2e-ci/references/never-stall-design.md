# E2E CI — Promotion Gate Never-Stall Design

Part of [e2e-ci](../SKILL.md) — the `reusable-release-gate.yml` never-stall design: E2E on testing branch, feedback trigger, jq selector, and bluefin bootstrap.

## Promotion gate — never-stall design

The `reusable-release-gate.yml` checks for a completed E2E run **keyed by the testing branch's HEAD SHA**. The gate queries:
```
GET /repos/{repo}/actions/runs?head_sha={TESTING_SHA}&status=completed&per_page=100
```
It then filters by workflow name. Two requirements must both hold for the gate to self-clear without human intervention:

### Requirement 1 — E2E must fire on testing branch builds, not only main

`workflow_run` triggers always evaluate the workflow file from the **default branch** (main). A fix to `post-testing-e2e.yml` or `post-merge-e2e.yml` only takes effect when it reaches main. Putting the fix only on `testing` has no effect.

`post-testing-e2e.yml` (bluefin) and `post-merge-e2e.yml` (bluefin-lts) must have `branches: [main, testing]` in their `workflow_run` trigger:

```yaml
on:
  workflow_run:
    workflows: ["Testing Images"]   # or "Build Bluefin LTS"
    types: [completed]
    branches: [main, testing]       # testing branch must be included
```

Also guard the `promote-to-testing` job to main-only to avoid double-promoting:
```yaml
if: >-
  needs.run-e2e.result == 'success' &&
  github.event.workflow_run.head_branch == 'main'
```

### Requirement 2 — gate must re-evaluate immediately after E2E, not only on next push

Without a feedback trigger, `promote-testing-to-main.yml` only re-runs on the next push to `testing` or the midnight cron. A successful E2E can sit unnoticed until then.

Add a `workflow_run` trigger to `promote-testing-to-main.yml` in **each image repo**:

```yaml
# bluefin
on:
  push:
    branches: [testing]
  schedule:
    - cron: '0 23 * * *'
  workflow_dispatch:
  workflow_run:
    workflows: ["Post-Testing E2E"]        # must match the exact workflow name
    types: [completed]
    branches: [testing]
```

```yaml
# bluefin-lts
  workflow_run:
    workflows: ["Post-Merge E2E — Testing Parity"]
    types: [completed]
    branches: [testing]
```

This trigger is also subject to the default-branch constraint — it only takes effect when `promote-testing-to-main.yml` is on main.

### Requirement 3 — gate jq selector must match the exact workflow name

The `reusable-release-gate.yml` in `projectbluefin/actions` uses a three-pattern jq selector to find E2E runs:

```jq
| select(
    ((.path // "") | endswith("post-testing-e2e.yml"))
    or (((.name // "") | ascii_downcase) | contains("post-testing-e2e"))
    or (((.name // "") | ascii_downcase) | contains("post-merge e2e"))  # note: hyphen
  )
```

The third pattern matches `"post-merge e2e"` (with hyphen). LTS's workflow is named `Post-Merge E2E — Testing Parity`, which lowercases to `post-merge e2e — testing parity`. The selector uses `contains("post-merge e2e")` — **hyphenated, not spaced**. A space instead of a hyphen (`"post merge e2e"`) will never match and permanently blocks LTS promotions.

### Gate bootstrap for bluefin (circular dependency)

Bluefin enforces all PRs target `testing` (enforced by `Check PR base branch` CI). `workflow_run` trigger fixes on `testing` don't activate until they reach `main` via promotion. But promotion requires E2E. This is circular.

Breaking it:
- **First cycle only:** a maintainer must comment `/e2e` on the open promotion PR (`auto/promote-testing-to-main`) to manually trigger E2E evidence. Once it passes and the first promotion completes, the fix lands on main and the system is self-sustaining.
- LTS and dakota have no circular dependency — their PRs target `main` directly.
