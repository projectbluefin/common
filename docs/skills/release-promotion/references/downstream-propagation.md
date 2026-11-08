# How common Updates Reach Downstream :testing Builds

Part of [release-promotion](../SKILL.md) — The two canonical propagation paths (Renovate digest bump for bluefin/bluefin-lts, BST daily cron for dakota), max propagation delays, and how to poke each path manually.

---

## How common updates reach downstream :testing builds

When `common/build.yml` publishes a new `common:latest`, downstream `:testing` builds are triggered by two canonical paths. There is **no** direct dispatch from `build.yml` — the `notify-downstream` job was removed (it used fragile cross-repo token dispatch that silently failed across 9+ commits of churn).

### bluefin and bluefin-lts (Renovate digest bump — canonical)

`projectbluefin/renovate-config` runs a self-hosted Renovate runner every 3 hours. When it detects a new `ghcr.io/projectbluefin/common:latest` digest it opens `chore(deps): update common digest` PRs against the `testing` branch in bluefin and bluefin-lts. These PRs automerge immediately (`automerge: true, schedule: ["at any time"]`), which triggers `build-image-testing.yml` → downstream build fires.

Max propagation delay: ~3 hours after `common:latest` publishes.

**To poke Renovate manually:**
```bash
gh workflow run renovate.yml --repo projectbluefin/renovate-config
```

### dakota (BST daily cron — canonical)

Dakota does **not** consume `common` as an OCI digest. It tracks common via a `git_repo` BST source in `elements/bluefin/common.bst` pinned to a git ref on `common/main`. `track-bst-sources.yml` in dakota runs daily at 06:00 UTC and accepts `workflow_dispatch`.

Max propagation delay: ~24 hours.

**To poke manually:**
```bash
gh workflow run track-bst-sources.yml --repo projectbluefin/dakota -f group=auto-merge
```
