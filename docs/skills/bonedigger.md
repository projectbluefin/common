---
name: bonedigger
description: "bonedigger integration guide — ujust report filing, priority escalation from confirm counts, and current status per repo."
---

# bonedigger — ujust Report Filing & Priority Escalation

**Repo:** https://github.com/projectbluefin/bonedigger

## What bonedigger does

bonedigger has two functions:

1. **ujust report detection** — when an issue is filed via `ujust report` on a live system, bonedigger detects the diagnostic signature and sets `source:ujust-report`
2. **Priority auto-escalation** — tracks `ujust confirm` counts and escalates automatically:
   - 3+ confirms → adds `priority/p1`
   - 5+ confirms → adds `priority/p0`

## What bonedigger does NOT do

Issue lifecycle management (slash commands, pipeline widget, label transitions, stale sweep) moved to `projectbluefin/common/.github/workflows/lifecycle.yml` as of 2026-06-05.

See [`label-workflow.md`](./label-workflow.md) for the full lifecycle reference.

## Integration status

All 6 factory repos now call `projectbluefin/common/.github/workflows/lifecycle.yml` via `lifecycle-caller.yml`. bonedigger is no longer called directly for lifecycle from factory repos.

bonedigger's `sync-templates.yml` continues to propagate issue templates to factory repos.

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates from `bonedigger/templates/` to factory repos.

Known issues:
- [bonedigger#13](https://github.com/projectbluefin/bonedigger/issues/13) — sync-templates uses banned PAT
- [common#408](https://github.com/projectbluefin/common/issues/408) — sync-templates wrong namespace (ublue-os/*)
