# Queue Dashboard — queue.projectbluefin.io

The **Clanker Control Panel** — live view of everything waiting for a human decision
across the `projectbluefin` org.

**Machine-readable reviewer briefing:** https://queue.projectbluefin.io/review-guide.md  
**Live data snapshot (JSON):** https://queue.projectbluefin.io/data.json

## What it shows

https://queue.projectbluefin.io/ is a dashboard regenerated every 10 minutes by GitHub Actions
from `projectbluefin/queue`. It shows:

- **Stats bar** — P0 · P1 · Triage · Issues · PRs · velocity counts at a glance
- **P0 / P1 column** — hive-tracked blockers and this-cycle items (right column)
- **PR tiers** — open PRs bucketed by review state, each card shows approval count
- **Dark / Light / System theme toggle** — persists via `localStorage`

The browser auto-refreshes every 5 minutes without a page reload, comparing the
`generated` timestamp in `/data.json` to avoid unnecessary re-renders.

## PR tiers (how your PR appears)

The generator queries GitHub search with these filters:

```
is:pr is:open -is:draft status:success review:approved   → ✅ Approved (ready to merge)
is:pr is:open -is:draft status:success review:required   → ⏳  Needs reviews
is:pr is:open -is:draft status:success review:none       → ○  No reviews yet
```

**Key:** `review:approved` only turns green when ALL required approvals are satisfied.
`review:required` means at least one review is still needed.

Each PR card displays the **approval count** prominently (e.g. `1 / 2`) so reviewers
can see at a glance how close a PR is to merge.

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

## Data architecture

```
GitHub API (every 10 min, GHA cron)
  → generate.js (25-min file TTL cache layer)
  → data.json  ← committed to repo root, served as static asset
  → index.html ← bakes data.json contents as __DATA__ for instant first paint

Browser (on load)
  → renders immediately from embedded __DATA__
  → polls /data.json every 5 min, re-renders if generated timestamp changed
```

`data.json` contains: full PR lists per tier, hive issue lists per priority,
review counts per PR, velocity counts, and a `generated` ISO timestamp.

## Refresh cadence

- Regenerated every 10 minutes via GitHub Actions cron in `projectbluefin/queue`
- `hive-progress-sync.yml` in this repo posts Common-specific stats to the org project board
  at :20 past the hour (staggered from bluefin :15, dakota :00, knuckle :30, lts :45)

## Repos tracked

`bluefin`, `bluefin-lts`, `common`, `dakota`, `actions`, `renovate-config`, `bonedigger`, `knuckle`

## Full reviewer guide

For everything needed to review a Bluefin PR (merge rules, what to check, human gates,
label taxonomy, hive labels, quick reference commands):

**https://queue.projectbluefin.io/review-guide.md**

Also see: https://docs.projectbluefin.io/agentic-contributing

## Source

Generator: https://github.com/projectbluefin/queue/blob/main/generate.js
