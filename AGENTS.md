# bluefin-common — Agent & Copilot Instructions

**bluefin-common** is the shared OCI layer consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical.

Home repo: [projectbluefin/common](https://github.com/projectbluefin/common)

## Org pipeline — projectbluefin

### Repo map

```
common ──────────────────────────┐
(shared OCI layer)               │
                                 ▼
bluefin  (main→stable)       ←── images ──→ testsuite (e2e gate)
bluefin-lts (main→lts)       ←── images ──→ testsuite (e2e gate)
dakota  (main→:latest)       ←── images ──→ testsuite (e2e gate)
                                 │
                                 ▼
                                iso (installation media)
```

Each image repo pulls `ghcr.io/projectbluefin/common:latest` as a base layer.
testsuite gates `:latest` promotion in all three image repos.

### Issue lifecycle

`filed → approved → queued → claimed → done`

| Stage | How |
|---|---|
| `filed` | Issue opened |
| `approved` | Maintainer adds `status/approved` or comments `/approve` |
| `queued` | `queue/agent-ready` auto-added alongside approval |
| `claimed` | Comment `/claim` — assigned, removed from pool |
| `done` | Fix shipped + 3× `ujust verify` or maintainer override |

No PR activity in 7 days returns a claimed issue to the queue automatically.

### PR comment policy

One comment per PR event, max. Combine all findings. Never post a follow-up — edit the existing comment.
Never duplicate GitHub UI state (approvals, CI status).
Test reports: what ran + pass/fail + blockers only. No diff summaries.
@ mentions only when asking someone to do something specific. Never standalone.
When in doubt, post nothing.

### Mandatory gates

- `just check` before every commit
- PR title: Conventional Commits format (`feat:`, `fix:`, `chore(deps):`, etc.)
- Attribution on every AI-authored commit: `Assisted-by: <Model> via <Tool>`
- Max 4 open PRs at a time per agent
- No WIP PRs

## Repo layout

```
Containerfile              # OCI image build
Justfile                   # Build automation
system_files/
  shared/                  # Config applied to ALL Bluefin variants (and Aurora)
  bluefin/                 # Config applied to Bluefin-specific variants only
aurorafin-shared/          # Git submodule (ublue-os/aurorafin-shared)
  system_files/
    shared/                # Shared Aurora/Bluefin config (upstream-controlled)
    nvidia/                # NVIDIA-specific config (upstream-controlled)
bluefin-branding/          # Git submodule (projectbluefin/branding)
  system_files/            # Wallpapers, logos (local edits allowed)
.github/workflows/
  build.yml                # Build + push on merge to main
  e2e.yml                  # Post-merge e2e against bluefin, bluefin-lts, dakota
  release.yml              # Release automation and tagging
  validate-just.yml        # PR gate: just check
  validate-brewfiles.yaml  # PR gate: Brewfile validation
```

### Submodule editing boundaries

**aurorafin-shared** (upstream: `ublue-os/aurorafin-shared`)
- **DO NOT edit locally** — this is shared with Aurora
- Changes to `aurorafin-shared/system_files/shared/` must go upstream as a PR to ublue-os/aurorafin-shared
- Changes to `aurorafin-shared/system_files/nvidia/` must go upstream as a PR to ublue-os/aurorafin-shared
- Pull updates via `git submodule update --remote`

**bluefin-branding** (upstream: `projectbluefin/branding`)
- **CAN be edited locally** for wallpapers and logos
- Merge changes to projectbluefin/branding as needed
- Pull updates via `git submodule update --remote`

**system_files/** (this repo)
- **CAN be edited locally** — Bluefin-specific config
- Bluefin-specific overrides in `system_files/bluefin/`
- Shared config layer in `system_files/shared/`

## CODEOWNERS

```
system_files/shared/**   @inffy @renner0e @ledif @castrojo @hanthor @ahmedadan
system_files/bluefin/**  @castrojo @hanthor @ahmedadan
```

## Build and validate

```bash
just check      # lint Justfile
just build      # full container build (slow — requires podman + network)
pre-commit run --all-files   # hygiene checks (json/yaml/toml + actionlint)
```

## Scope warning

Changes here flow into ALL downstream Bluefin variants at next build. A broken `system_files/shared/` change will break bluefin, bluefin-lts, AND dakota simultaneously. Test locally before pushing.
