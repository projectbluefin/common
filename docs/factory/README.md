# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory. Read this first, then load the target repo's `AGENTS.md` and any relevant `docs/skills/*` files.

## Mission and product boundary

- Factory org: `projectbluefin`
- Product: bootc-based OCI images and the automation that builds, validates, and promotes them
- Shared layer repo: `common` — https://github.com/projectbluefin/common
- Production image registry: `ghcr.io/ublue-os/bluefin*` **not** `projectbluefin` yet; migration is incomplete as of 2026-06-04
- Registry reference: `docs/skills/image-registry.md`

## Repo map and data flow

```text
common ──────────────────────────┐
(shared OCI layer)               │
                                 ▼
bluefin     ──┐                  │
bluefin-lts ─┼──→ images ──→ testsuite ──→ iso
dakota      ─┘                  │
```

- `common`: shared OCI layer and shared factory documentation
- `bluefin`: mainline Bluefin image streams
- `bluefin-lts`: LTS image streams
- `dakota`: bootc image pipeline in the same factory orbit
- `testsuite`: end-to-end gate for downstream image behavior
- `iso`: installation media fed by validated image outputs
- `actions`: shared GitHub Actions used across the org

## Factory repos

- `common` — https://github.com/projectbluefin/common
- `bluefin` — https://github.com/projectbluefin/bluefin
- `bluefin-lts` — https://github.com/projectbluefin/bluefin-lts
- `dakota` — https://github.com/projectbluefin/dakota
- `actions` — https://github.com/projectbluefin/actions
- `testsuite` — https://github.com/projectbluefin/testsuite

## Agentic operating model

Lifecycle: `filed → approved → queued → claimed → done`

| Stage | Meaning |
|---|---|
| `filed` | Issue exists but is not ready for execution |
| `approved` | Maintainer adds `status/approved` or comments `/approve` |
| `queued` | `queue/agent-ready` marks the issue ready for pickup |
| `claimed` | Agent comments `/claim`; issue is assigned and leaves the pool |
| `done` | Fix is shipped and verified; standard target is 3× `ujust verify`, or maintainer override |

Operational notes:
- Bonedigger manages this lifecycle in `bluefin`.
- actionadon manages the equivalent flow in `dakota`/`knuckle`.
- `common` now has bonedigger lifecycle automation; `bluefin-lts` still does not.
- `bluefin-lts` still requires manual care to avoid double-claiming and stale claims until lifecycle automation lands there.
- No PR activity in 7 days should return the claim (`/unclaim`) until org-wide automation exists.

## Agent rules of engagement

- Start here, then open the target repo's `AGENTS.md`.
- Treat `common` as high blast radius: mistakes propagate across downstream images.
- Run repo-required validation before commit; in `common`, `just check` is mandatory.
- Do not rewrite image refs from `ghcr.io/ublue-os/bluefin*` to `projectbluefin` without explicit maintainer approval.
- Prefer existing skills and workflows over inventing new process.

## Migration status — parity matrix snapshot (2026-06-04)

| Artifact | common | bluefin | bluefin-lts | dakota | actions | testsuite |
|---|---|---|---|---|---|---|
| AGENTS.md | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| pre-commit | ✅ | ✅ | ✅ | ❌ | — | — |
| skill-drift.yml | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| no-floating-action-tags hook | ✅ | ✅ | ✅ | ❌ | ✅ | — |
| bonedigger lifecycle | ✅ | ✅ | ❌ | ❌ | — | — |
| Renovate config | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Post-merge e2e | ✅ | ✅ | ❌ | partial | — | — |
| Installability gate | ⚠️ testing-stream smoke/common only | ❌ | ❌ | ❌ | — | ❌ |
| CODEOWNERS active | ✅ | ✅ | ✅ | ✅ | — | — |
| docs/skills/ populated | ✅ | ✅ | partial | ✅ | ✅ | ✅ |

Read this table as an execution warning, not a scorecard: parity is incomplete, automation is fragmented, and agents must still compensate for missing guardrails across the factory, especially in `bluefin-lts`.

`common` also has a new **promotion-candidate smoke/common gate** in `.github/workflows/promotion-candidate-e2e.yml`. It is not a full installer gate, but it gives repo-local signal on `bluefin:testing` and `bluefin:lts-testing` before the downstream Tuesday promotions.

## Per-repo AGENTS.md entry points

- `common` — https://github.com/projectbluefin/common/blob/main/AGENTS.md
- `bluefin` — https://github.com/projectbluefin/bluefin/blob/main/AGENTS.md
- `bluefin-lts` — https://github.com/projectbluefin/bluefin-lts/blob/main/AGENTS.md
- `dakota` — https://github.com/projectbluefin/dakota/blob/main/AGENTS.md
- `actions` — https://github.com/projectbluefin/actions/blob/main/AGENTS.md
- `testsuite` — https://github.com/projectbluefin/testsuite/blob/main/AGENTS.md

## Minimum read order for agents

1. This file
2. Target repo `AGENTS.md`
3. Relevant `docs/skills/*` files for the task
4. Repo-local validation/build workflow before commit or merge
