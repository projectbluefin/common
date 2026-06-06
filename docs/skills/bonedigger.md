---
name: bonedigger
description: "bonedigger + kubestellar-bot — the full self-improvement loop. ujust report filing, priority escalation, and how fixes ship back to the image."
---

# bonedigger & kubestellar-bot

**Repo:** https://github.com/projectbluefin/bonedigger

## The full loop

bonedigger and kubestellar-bot together form the closed improvement loop that drives Bluefin 2.0:

```
user runs ujust report
  └─ bonedigger agent collects system diagnostics
       └─ scrubs PII on-device
            └─ files structured issue to image repo
                 └─ lifecycle bot moves issue through pipeline
                      └─ kubestellar-bot picks up status/queued issue
                           └─ dispatches agent to implement fix
                                └─ PR shipped back to image repo
                                     └─ merged → better OS
                                          └─ better bonedigger
                                               └─ loop
```

## bonedigger — what it does

bonedigger has two functions:

1. **ujust report detection** — when an issue is filed via `ujust report` on a live system, bonedigger detects the diagnostic signature and sets `source:ujust-report`
2. **Priority auto-escalation** — tracks `ujust confirm` counts and escalates:
   - 3+ confirms → adds `priority/p1`
   - 5+ confirms → adds `priority/p0`

## bonedigger — what it does NOT do

Issue lifecycle management (slash commands, pipeline widget, label transitions, stale sweep) moved to `projectbluefin/common/.github/workflows/lifecycle.yml` as of 2026-06-05.

See [`label-workflow.md`](./label-workflow.md) for the full lifecycle reference.

## kubestellar-bot — what it does

kubestellar-bot is the implementation agent layer. It:
- Monitors `status/queued` issues across all factory repos
- Dispatches agents to claim and implement fixes
- Manages the PR lifecycle from claim → ship
- Reports progress back to the hive dashboard

kubestellar-bot does NOT make design or security decisions. Those hit a human gate. See [`human-gates.md`](./human-gates.md).

## Integration status

All 6 factory repos call `projectbluefin/common/.github/workflows/lifecycle.yml` via `lifecycle-caller.yml`. bonedigger is no longer called directly for lifecycle from factory repos.

bonedigger's `sync-templates.yml` continues to propagate issue templates to factory repos.

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates from `bonedigger/templates/` to factory repos.

Requires `MERGERAPTOR_APP_ID` (var) and `MERGERAPTOR_PRIVATE_KEY` (secret) on the bonedigger repo. PAT-based auth was replaced with mergeraptor app token in bonedigger#21.
