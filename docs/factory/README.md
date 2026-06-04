# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory. Read this first, then load the target repo's `AGENTS.md` and any relevant `docs/skills/*` files.

## Mission and product boundary

- Factory org: `projectbluefin`
- Product: bootc-based OCI images and the automation that builds, validates, and promotes them
- Shared layer repo: `common` — https://github.com/projectbluefin/common
- Production image registry: `ghcr.io/ublue-os/bluefin*` **not** `projectbluefin` yet
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

For the workflow-by-workflow purpose map inside `common`, see
[`../skills/workflow-map.md`](../skills/workflow-map.md).

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

Bonedigger manages this lifecycle across all factory repos. No PR activity in 7 days should return the claim (`/unclaim`).

## Agent rules of engagement

- Start here, then open the target repo's `AGENTS.md`.
- Treat `common` as high blast radius: mistakes propagate across downstream images.
- Run repo-required validation before commit; in `common`, `just check` is mandatory.
- Do not rewrite image refs from `ghcr.io/ublue-os/bluefin*` to `projectbluefin` without explicit maintainer approval.
- Prefer existing skills and workflows over inventing new process.

## Factory infrastructure

The following are wired across all factory repos (bluefin, bluefin-lts, common, dakota, knuckle):

- **AGENTS.md** — per-repo operating contract
- **Label taxonomy** — `hive/p0`, `hive/p1`, `queue/agent-ready`, `queue/claimed`, `agent/blocked`, `source:*`
- **Squash-only merge + delete-branch-on-merge**
- **5 standard issue templates**
- **CODEOWNERS** with triage sentinel — synced from `common` to downstream repos via `sync-codeowners.yml`
- **hive-progress-sync.yml** — hourly org board update
- **bonedigger lifecycle automation** — issue pipeline active in all repos
- **skill-drift.yml** — PR advisory gate for doc/impl parity
- **pre-commit** — json/yaml/toml hygiene and no-floating-action-tags
- **Renovate** — automated dependency updates

`common` also has a **promotion-candidate smoke/common gate** (`promotion-candidate-e2e.yml`). It is not a full installer gate, but it gives early signal on `bluefin:testing` and `bluefin:lts-testing` before the downstream Tuesday promotions.

## Open gaps

- **bonedigger (the tool)** is not itself factory-onboarded — no AGENTS.md, no hive labels, CI issues pending [#418](https://github.com/projectbluefin/common/issues/418)
- **Renovate config** in `common` has invalid `packageRules` — Renovate is paused until fixed [#487](https://github.com/projectbluefin/common/issues/487)
- **Regression contract** across `latest`/`stable`/`gts`/`lts` streams is undefined [#420](https://github.com/projectbluefin/common/issues/420)
- **bonedigger crash/panic signal** not wired into promotion decisions [#424](https://github.com/projectbluefin/common/issues/424)

Tracking epics: [#403](https://github.com/projectbluefin/common/issues/403) (common as org brain) · [#404](https://github.com/projectbluefin/common/issues/404) (infra parity) · [#405](https://github.com/projectbluefin/common/issues/405) (QA model)

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
