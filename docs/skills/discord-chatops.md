# Discord ChatOps — Skill File

## What this covers

Discord integration for the Bluefin factory: failure/release notifications and
maintainer lifecycle commands. Two channels, Botkube on ghost k3s, GitHub native
webhooks for read-only notifications.

## Stack

| Component | What it does |
|---|---|
| GitHub native webhooks → Discord | CI failure + release notifications, zero code |
| Botkube v1.14.0 on ghost k3s | Lifecycle commands in #factory |
| GitHub App "Bluefin Botkube" | Botkube → GitHub auth, no PAT |
| `mcp-discord` MCP server | Agent-driven Discord server management |
| `discord-release-notify` composite action | Posts release thread to #releases on promotion |

## Channel layout

Category: `/usr/factory` (ID: `1519241025254592617`)

| Channel | Type | ID | What posts here |
|---|---|---|---|
| `#factory` | Text | `1519233261438631936` | CI failures (GitHub webhook), Botkube !release commands |
| `#releases` | Forum | `1519239480526110761` | Release threads (one thread per release, via composite action) |
| `#hive` | Text | `1507425837891457114` | Hive queue updates |

## Webhook IDs

| Webhook | Channel | ID | Secret name |
|---|---|---|---|
| `factory-ci` | `#factory` | `1519233290643705936` | `DISCORD_FACTORY_WEBHOOK` |
| releases-notify | `#releases` | `1519239518752870470` | `DISCORD_RELEASES_WEBHOOK` |

Human must create `#releases` forum channel (Discord UI: Server Settings > Channels > + > Forum > name: releases),
then create a webhook on it and store the URL as `DISCORD_RELEASES_WEBHOOK` in GitHub org secrets.

## MCP server (agent Discord management)

Config lives in `~/.copilot/mcp-config.json`. Token stored there — never in code or docs.

```json
{
  "discord": {
    "type": "local",
    "command": "/var/home/jorge/.local/share/pi-node/current/bin/npx",
    "args": ["-y", "mcp-discord"],
    "env": { "DISCORD_TOKEN": "<from ~/.copilot/mcp-config.json>" },
    "tools": ["*"]
  }
}
```

Tools available (next session after reload): create/edit channels, roles, webhooks,
forum posts, threads, message sending, permissions.

Bot name: **Bluefin** | App ID: `1519228970032169050`
Server: Project Bluefin (`1345470678408626206`)

## Lifecycle commands (#factory, anyone)

```
!fresh            — OCI digest + age for all images (reads image-polling-digests ConfigMap)
!fresh testing    — :testing images only
!fresh dakota     — Dakota stream only
!lab              — Node status + running VMs + Argo queue depth
!queue            — Open hive issues with status:queued
!building         — In-progress GHA runs across factory repos
!last-failure     — Last 3 failed workflow runs with links
```

## Release commands (#releases, Maintainer role only)

```
!release bluefin          — dispatches execute-release.yml on bluefin/main
!release bluefin-lts      — dispatches execute-release.yml on bluefin-lts/main
!release dakota           — dispatches execute-release.yml on dakota/main
!release common           — dispatches release.yml on common/main
```

## Release thread format (#releases Forum channel)

Each release = one Forum thread. Created by `discord-release-notify` composite action
at the end of `reusable-execute-release.yml`.

Thread opener (creates the thread):
- Title: `<repo> <tag>` (e.g. `bluefin v20250624.0`)
- Embed: green, clickable title linking to GitHub release, ISO timestamp
- `allowed_mentions: {"parse": []}` — prevents @everyone injection

Follow-up in thread (full detail):
- Inline embed fields: one per promoted variant (image:tag + short digest)
- `flags: 4096` (SUPPRESS_NOTIFICATIONS — no double-ping)

## Botkube RBAC note

Botkube v1.14 `rbac.groups` renders K8s ClusterRole objects — it does NOT map Discord
roles to executor authorization. The real auth boundary is **Discord channel isolation**:
`github-dispatch` executor is bound only to the channel where Maintainer role has
exclusive access (configured in Discord Developer Portal → App Commands → Permissions).

## Secrets (human-managed, never in git or docs)

| Secret | Where | Contains |
|---|---|---|
| `botkube-discord` | k8s namespace `botkube` | `token` (bot token) |
| `botkube-github-app` | k8s namespace `botkube` | `appID`, `installationID`, `privateKey` |
| `DISCORD_FACTORY_WEBHOOK` | GitHub org secrets | #factory webhook URL |
| `DISCORD_RELEASES_WEBHOOK` | GitHub org secrets | #releases webhook URL |
| Bot token | `~/.copilot/mcp-config.json` only | Never committed |

Store PEM key with `--from-file=privateKey=bluefin-botkube.pem` — never `--from-literal`.

## Upgrading Botkube

Edit `targetRevision` in `testing-lab/argocd/botkube-app.yaml`, update plugin index URL
to match version, commit. ArgoCD handles the rest.

## Adding a new repo to failure notifications

Add a GitHub webhook in repo settings:
- Failures: `<DISCORD_FACTORY_WEBHOOK>/github`, events: `workflow_run` + `check_run`
- Releases: `<DISCORD_RELEASES_WEBHOOK>/github`, events: `release` + `deployment`

No code changes needed.

## Implementation status

| Task | Status | Notes |
|---|---|---|
| Discord bot app created | Done | Bot: Bluefin#0600, App ID: 1519228970032169050 |
| `#factory` text channel | Done | ID: 1519233261438631936 |
| `factory-ci` webhook | Done | ID: 1519233290643705936, store URL as `DISCORD_FACTORY_WEBHOOK` in org secrets |
| `#releases` Forum channel | Done | ID: 1519239480526110761, webhook ID: 1519239518752870470 |
| `Maintainer` role | Pending human | Discord Server Settings > Roles > Create Role |
| GitHub App "Bluefin Botkube" | Pending human | github.com/organizations/projectbluefin/settings/apps |
| k8s secrets on ghost | Pending human | See Secrets section above |
| GitHub native webhooks | Pending human | Wire each repo to #factory and #releases (see "Adding a new repo") |
| Botkube ArgoCD manifests | PR open | projectbluefin/testing-lab feat/botkube-chatops |
| `discord-release-notify` action | PR open | projectbluefin/actions feat/discord-release-notify |
| Restrict github-dispatch to Maintainer | Pending human | Discord Developer Portal > App Commands > Permissions |
| `DISCORD_RELEASES_WEBHOOK` org secret | Pending human | URL: https://discord.com/api/webhooks/1519239518752870470/<token> — store in GitHub org secrets |

## Where each file lives

| File | Repo |
|---|---|
| `argocd/botkube-app.yaml` | `projectbluefin/testing-lab` |
| `botkube/values.yaml` | `projectbluefin/testing-lab` |
| `.github/actions/discord-release-notify/action.yml` | `projectbluefin/actions` |
| This skill file | `projectbluefin/common/docs/skills/discord-chatops.md` |
