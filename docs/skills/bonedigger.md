# bonedigger — Crash Detection & Issue Lifecycle

**Repo:** https://github.com/projectbluefin/bonedigger

## What bonedigger does

bonedigger has two functions:

1. **Issue lifecycle automation** — manages the `filed → approved → queued → claimed → done` pipeline via `lifecycle.yml`
2. **Diagnostic template sync** — syncs issue templates from `bonedigger/templates/` to all factory repos via `sync-templates.yml`

Crash/panic detection (planned): identifies kernel panics from pstore/kdump artifacts, classifies boot events into 4 buckets, scans for panic keywords in logs. Tracked in [bonedigger#11](https://github.com/projectbluefin/bonedigger/issues/11) and [bonedigger#12](https://github.com/projectbluefin/bonedigger/issues/12).

## Integration pattern

Each factory repo should have `.github/workflows/bonedigger.yml`:

```yaml
name: bonedigger
on:
  issues:
    types: [opened, labeled, closed]
  issue_comment:
    types: [created]
  schedule:
    - cron: '0 9 * * *'
permissions:
  issues: write
  contents: read
jobs:
  bonedigger:
    uses: projectbluefin/bonedigger/.github/workflows/lifecycle.yml@<PINNED-SHA>
    with:
      brand_name: "Bluefin"     # or repo name
      brand_emoji: "🦖"
    secrets: inherit
```

Always pin to a SHA, not a branch ref.

## Current integration status

| Repo | bonedigger.yml | Status |
|---|---|---|
| bluefin | ✅ | Active — pinned to SHA 743f564 |
| bluefin-lts | ❌ | Missing — see common#412 |
| common | ❌ | Missing — see common#412 |
| dakota | ❌ | Missing — see common#412 |
| knuckle | ❌ | Missing — uses actionadon instead — see common#412 |

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates to all factory repos. **Current issue:** it targets `ublue-os/*` (old namespace) instead of `projectbluefin/*` — tracked in [common#408](https://github.com/projectbluefin/common/issues/408).

When fixed, templates will sync from `bonedigger/templates/` automatically on push to main.

## Known issues

| Issue | Status |
|---|---|
| [bonedigger#13](https://github.com/projectbluefin/bonedigger/issues/13) | sync-templates uses banned PAT — open |
| [common#408](https://github.com/projectbluefin/common/issues/408) | sync-templates wrong namespace (ublue-os/*) — open |
| [common#412](https://github.com/projectbluefin/common/issues/412) | bonedigger.yml missing from 4 repos — open |
| [common#418](https://github.com/projectbluefin/common/issues/418) | bonedigger has no AGENTS.md or hive labels — open |
| [common#424](https://github.com/projectbluefin/common/issues/424) | bonedigger not wired into promotion decisions — open |
