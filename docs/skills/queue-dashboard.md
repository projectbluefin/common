---
name: queue-dashboard
description: "PR review and merge queue workflow for projectbluefin/common — ruleset, triage tiers, rebase patterns, and what to do with each PR state."
---

# Queue Dashboard — projectbluefin/common

## When asked to "merge PRs"

The intent is: **fix any blockers and land the PR**. Do not just review and leave comments.

1. Triage the PR using the table below
2. Fix the issue (rebase, correct code, update docs) — don't just comment
3. Merge immediately with `gh pr merge <N> --squash --admin`

Do **not** wait for approval count to tick up or for non-required checks to pass. `--admin` bypasses all of that. Reserve skipping for genuine design objections or explicit user-requested holds.

## Merge ruleset (`main-review-required-with-renovate-bypass`)

| Setting | Value |
|---|---|
| Required approvals | **1** (+ code owner review required) |
| Dismiss stale reviews | Yes (on push) |
| Required check | `Build and push image` only |
| Merge method | Squash only |
| Merge queue | Enabled — `ALLGREEN` grouping strategy |
| Max entries to build | 2 |

E2E checks are **informational** — they do not block merging. Only `Build and push image` is required.

## Triage tiers

### Ready to land
- `reviewDecision: APPROVED` + CI green (`Build and push image: SUCCESS`) + `mergeable_state: clean`
- Action: `gh pr merge <N> --squash --admin`
- Use `--admin` to bypass stale/failing non-required checks (e.g. e2e, validate from before a fix landed on main)

### Needs rebase (DIRTY)
- `mergeable_state: dirty`
- For **main-repo branches**: `git checkout <branch> && git rebase origin/main`, resolve conflicts, `git push --force-with-lease`, then admin-merge
- For **fork PRs**: you cannot push to the fork; fetch it locally, rebase, push as a new branch to origin, open a new PR, then admin-merge. Original PR can be noted in the new PR body.

```bash
git fetch https://github.com/<fork-owner>/common.git <branch>
git checkout -b <branch>-rebase FETCH_HEAD
git rebase origin/main
# resolve conflicts…
git push origin <branch>-rebase
gh pr create --base main --head <branch>-rebase --title "…" --body "Rebased from #N …"
gh pr merge <new-N> --squash --admin
```

### Needs review
- `reviewDecision: REVIEW_REQUIRED` or blank
- Agent can still admin-merge with `--admin` — this bypasses approval requirement
- Use judgment: skip only if there is an active objection or the PR is clearly not ready

### Previously blocked by submodule boundary — now unblocked
- PRs touching `system_files/shared/**` are now **directly mergeable** — the aurorafin-shared submodule has been removed and these files live here
- Edit `system_files/shared/` directly in this repo

### CHANGES_REQUESTED
- Read the review comment to understand what's needed
- If it's a **stale doc** — rebase, update the content, admin-merge
- If it's a **missing implementation** (e.g. binary not packaged) — fix it in the branch (or create a new one), then admin-merge
- If it's a **genuine design objection** — leave a comment and skip

## PR review workflow

```bash
# 1. Get full open PR list with CI status
gh pr list --state open \
  --json number,title,mergeStateStatus,reviewDecision,statusCheckRollup \
  | jq -r '.[] | "\(.number) | \(.mergeStateStatus) | \(.reviewDecision) | \(.title[:55])"'

# 2. Check specific PR failures
gh pr view <N> --json statusCheckRollup \
  | jq -r '.statusCheckRollup | map(select(.conclusion == "FAILURE")) | map(.name) | .[]'

# 3. Admin-merge (bypasses required checks AND approval requirement)
gh pr merge <N> --squash --admin

# 4. Disable auto-merge (if a PR was queued by mistake)
gh pr merge --disable-auto <N>
```

## Rebase pattern for fork PRs

```bash
# Get fork info
gh pr view <N> --json headRefName,headRepository \
  --jq '{branch: .headRefName, repo: .headRepository.nameWithOwner}'

# Fetch and rebase locally
git fetch https://github.com/<fork-owner>/common.git <branch>
git checkout -b <branch>-rebase FETCH_HEAD
git rebase origin/main
# resolve conflicts…
git push origin <branch>-rebase
gh pr create --base main --head <branch>-rebase \
  --title "<original title>" \
  --body "Rebased from #N. Co-authored-by: <original-author>"
gh pr merge <new-N> --squash --admin
```

> Note: you cannot push back to the original fork branch. Always create a new branch on origin.

## Known infra issues (as of 2026-06-04)

### E2E disabled in pr-e2e.yml
The `e2e` job in `pr-e2e.yml` has `if: false` — it is **intentionally skipped** while the
GNOME smoke suite is known broken. The `compose` job still builds and pushes the test image.
Re-enable by removing the `if: false` once the suite is fixed.

### Validate failures from pre-existing shellcheck issues
Historical PRs may show `validate` failures caused by shellcheck warnings in `build.yml` and
`validate-brewfiles.yaml` that have since been fixed on `main`. These are safe to admin-merge
— the failures do not exist on the current codebase.

### Fork PRs and Compose failures
Fork PRs will always show `Compose PR test image: FAILURE` because the GitHub Actions token
cannot push to `ghcr.io/projectbluefin/*` from a fork context. This is expected behavior,
not a code defect. Admin-merge these safely when the code change is correct.

## Common PR comment templates

**Previously blocked by submodule — now unblocked:**
```
This PR touches system_files/shared/ — which is now directly editable here since
the aurorafin-shared submodule was removed. Rebase onto main and reopen.
```

**Superseded:**
```
Superseded — [explain what on main covers this]. Closing.
```
