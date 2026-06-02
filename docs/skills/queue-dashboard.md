# Queue Dashboard — queue.projectbluefin.io

Reference for agents reviewing PRs and checking merge readiness.

## What it shows

https://queue.projectbluefin.io/ is a static site regenerated hourly by GitHub Actions
from `projectbluefin/queue`. It shows:

- **P0 / P1 issues** — hive-tracked blockers and this-cycle items across the org
- **PR tiers** — open PRs bucketed by review state
- **Victories** — merged PRs and closed issues (7-day and 30-day windows)

## PR tiers (how your PR appears)

The generator queries GitHub search with these filters:

```
is:pr is:open -is:draft status:success review:approved   → ✅ Approved (ready to merge)
is:pr is:open -is:draft status:success review:required   → ⚠️  Needs reviews
is:pr is:open -is:draft status:success review:none       → 🔵  No reviews yet
```

**Key:** `review:approved` only turns green when ALL required approvals are satisfied.
`review:required` means at least one review is still needed.

## Merge ruleset for projectbluefin/common

Ruleset: `main-review-required-with-renovate-bypass`

- **Required approvals: 2** — one review leaves a PR in `review:required`, not `review:approved`
- **Required status check: `Build and push image`** only
- Smoke tests (`E2E — */GNOME 50 — smoke`) are **not** required checks — stale failures
  from prior runs don't block merge
- Renovate PRs bypass the review requirement (auto-merge eligible)

## When a PR has one review

`review:required` → appears in the yellow "Needs reviews" tier on the dashboard.
A second human approval moves it to the green "Approved" tier.

## Refresh cadence

- Regenerated hourly via GitHub Actions in `projectbluefin/queue`
- `hive-progress-sync.yml` in this repo posts Common-specific stats to the org project board
  at :20 past the hour (staggered from bluefin :15, dakota :00, knuckle :30, lts :45)

## Repos tracked

`bluefin`, `bluefin-lts`, `common`, `dakota`, `actions`, `renovate-config`, `bonedigger`, `knuckle`

## Source

Generator: https://github.com/projectbluefin/queue/blob/main/generate.js
