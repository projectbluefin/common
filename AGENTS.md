# bluefin-common — Agent & Copilot Instructions

**bluefin-common** is the shared OCI layer consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical.

Home repo: [projectbluefin/common](https://github.com/projectbluefin/common)

## 🚫 ABSOLUTE PROHIBITION — ublue-os org

**NEVER create issues, pull requests, comments, forks, or any GitHub resource in any `ublue-os/*` repository.**

This applies in every situation, without exception:
- If a task seems to require touching an upstream `ublue-os` repo → **stop and tell the human to report it manually**
- `ghcr.io/ublue-os` image registry reads are fine — production images are still published there
- Writing to `ublue-os` GitHub repos is **never** permitted, under any framing

Violating this risks getting the organization banned.

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

No PR activity in 7 days: return the claim manually (`/unclaim`) — automation pending (see issue #432).

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

## Session start — mandatory

Run before any other work:

```bash
~/src/hive-status
```

No arguments, no auth required, completes in under 5 seconds. Surfaces P0/P1 blockers and the advisory queue. Do not proceed without it.

## Scope discipline

Read task intent literally:

- `"work on hive priority issues"` = pick the top issue from `hive-status` output and fix it
- `"do PR reviews"` = review open PRs only — do not start fix work
- If a session could involve both, confirm scope with the user before acting

## Repo layout

```
Containerfile              # OCI image build
Justfile                   # Build automation
bluefin-branding/          # Git submodule: wallpapers and logos
system_files/
  shared/                  # Shared config for ALL variants (and Aurora) — directly editable
  bluefin/                 # Local editable config for Bluefin-specific variants only
  nvidia/                  # NVIDIA overlay — directly editable
.github/workflows/
  bonedigger.yml           # Issue lifecycle automation for common
  build.yml                # Build + push on merge to main
  docs-quality.yml         # PR gate: skill frontmatter and Trail of Bits CI
  e2e.yml                  # Post-merge e2e against bluefin, bluefin-lts, dakota
  hive-progress-sync.yml   # Hourly queue stats → projectbluefin org project board
  pr-e2e.yml               # PR-time composed-image common-suite gate
  promotion-candidate-e2e.yml # Weekly smoke/common checks for testing promotion candidates
  release.yml              # Monthly versioned OCI release (1st of month, also workflow_dispatch)
  run-testsuite.yml        # Local wrapper that centralizes the testsuite SHA pin
  skill-drift.yml          # PR advisory gate for implementation/doc parity
  sync-codeowners.yml      # Syncs CODEOWNERS TRIAGERS block to downstream repos on push
  validate.yml             # PR gate: just check, pre-commit, shellcheck, submodule drift
  validate-brewfiles.yaml  # PR gate: Brewfile validation
```

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

## Submodules

- `bluefin-branding` → `projectbluefin/branding` (wallpapers, logos). `just build` initializes it automatically.

`system_files/shared/` and `system_files/nvidia/` are now directly tracked in this repo — edit them here directly.

## Scope warning

Changes here flow into ALL downstream Bluefin variants at next build. A broken `system_files/shared/` change will break bluefin, bluefin-lts, AND dakota simultaneously. Test locally before pushing.

## Skill routing

Load the relevant skill doc before making changes in these areas.

| Task | Load first |
|---|---|
| Any `system_files/` edit | [`docs/skills/submodule-boundary.md`](docs/skills/submodule-boundary.md) |
| GNOME settings / dconf | [`docs/skills/dconf-consistency.md`](docs/skills/dconf-consistency.md) |
| Image refs / registry paths | [`docs/skills/image-registry.md`](docs/skills/image-registry.md) |
| `ublue-rollback-helper` changes | [`docs/skills/rollback-helper.md`](docs/skills/rollback-helper.md) |
| CI / GitHub Actions | [`docs/skills/ci-tooling.md`](docs/skills/ci-tooling.md) |
| What a `common` workflow is for | [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) |
| E2E test changes | [`docs/skills/e2e-ci.md`](docs/skills/e2e-ci.md) |
| Governance / CODEOWNERS | [`docs/skills/governance.md`](docs/skills/governance.md) |
| PR queue / merge decisions | [`docs/skills/queue-dashboard.md`](docs/skills/queue-dashboard.md) |
| Hive monitoring | [`docs/skills/hive-review.md`](docs/skills/hive-review.md) |
| Onboarding / dev setup | [`docs/skills/onboarding.md`](docs/skills/onboarding.md) |

For the full factory operating model, see [`docs/factory/README.md`](docs/factory/README.md).
