# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory.

## Operating principle

> **Humans approve design, security, and merge. Everything else is automated, self-healing, and non-blocking.**

Project Bluefin aims to be the most sophisticated CNCF showcase of cloud-native operating systems built with bootc. The factory is an **agentic CI/CD organism**: agents implement, humans set direction. Manual orchestration is treated as a reliability tax — every manual step that *can* be automated *will* be, every automated step must self-heal, and every remaining human gate is intentional and named in [`docs/skills/human-gates.md`](../skills/human-gates.md).

New workflows must self-heal: retry on transient failures, fast-fail on bad tokens, no silent skips. See [`docs/skills/ci-pitfalls.md`](../skills/ci-pitfalls/SKILL.md) for known pitfalls and [`docs/skills/ci-tooling.md`](../skills/ci-tooling/SKILL.md) for CI policy and config.

## Reference read order

1. Target repo `AGENTS.md` — start here
2. This file — org map, infrastructure topology, parity matrix
3. [`docs/factory/agentic-model.md`](agentic-model.md) — cross-repo hard rules, branch targets, PR policy, session start
4. Relevant `docs/skills/*` files — lazy-load for the specific task; use [`docs/SKILL.md`](../SKILL.md) as the router

For a new or relocated agent, follow the copyable
[`factory-onboarding.md`](../skills/factory-onboarding.md) procedure. It
verifies the target repository first, attaches common as the shared-contract
sidecar, and requires self-repair and durable learning on every task loop.

### Open proposals awaiting human review

- [`skill-catalog-proposal.md`](skill-catalog-proposal.md) — cross-repo
  survey of every factory repo's skill-doc system and a proposed shared
  catalog standard. Not adopted; requires a Design-gate decision before any
  repo acts on it.

## Mission and product boundary

- Factory org: `projectbluefin`
- Product: bootc-based OCI images and the automation that builds, validates, and promotes them
- Shared layer repo: `common` — https://github.com/projectbluefin/common
- Production image registry: `ghcr.io/projectbluefin/bluefin*`
- Registry reference: `docs/skills/image-registry.md`

```text
common ──────────────────────────┐
(shared OCI layer)               │
                                 ▼
bluefin     ──┐                  │
bluefin-lts ─┼──→ images ──→ testsuite ──→ iso
dakota      ─┘                  │
                                 │
                          bootc-installer / knuckle
                          (installer media + TUI)
```

- `common`: shared OCI layer and shared factory documentation (org brain)
- `bluefin`: mainline Bluefin image streams
- `bluefin-lts`: LTS image streams
- `dakota`: bootc image pipeline in the same factory orbit
- `testsuite`: end-to-end gate for downstream image behavior
- `iso`: installation media fed by validated image outputs
- `actions`: shared GitHub Actions used across the org
- `bootc-installer`: GTK4/Adwaita + KDE/XFCE multi-variant Flatpak installer for bootc images
- `knuckle`: Go-based TUI installer — `main` branch, no testing branch

For the workflow-by-workflow purpose map inside `common`, see [`../skills/workflow-map.md`](../skills/workflow-map.md).

## Factory repos

- `common` — https://github.com/projectbluefin/common
- `bluefin` — https://github.com/projectbluefin/bluefin
- `bluefin-lts` — https://github.com/projectbluefin/bluefin-lts
- `dakota` — https://github.com/projectbluefin/dakota
- `actions` — https://github.com/projectbluefin/actions
- `testsuite` — https://github.com/projectbluefin/testsuite
- `bootc-installer` — https://github.com/projectbluefin/bootc-installer
- `knuckle` — https://github.com/projectbluefin/knuckle

## Agentic operating model

`filed → triage → queued → claimed → done`

Lifecycle automation lives in [`projectbluefin/bonedigger`](https://github.com/projectbluefin/bonedigger) and is consumed by `bluefin`, `bluefin-lts`, and `dakota` through their own `bonedigger.yml` callers. `common` has no lifecycle caller.
Full lifecycle, epics, project board, and PR labels: [`docs/skills/label-workflow.md`](../skills/label-workflow.md)
Hard rules, branch targets, PR comment policy, session start: [`docs/factory/agentic-model.md`](agentic-model.md)

## Automation coverage

~97% automated across 124 workflows in 7 in-scope repos. **4 intentional human gates:** promotion review, actions merge, priority assignment, stale PR unclaim — see [`docs/skills/human-gates.md`](../skills/human-gates.md). ISO auto-rebuild remains manual (iso repo out of scope).

## Factory infrastructure

**Core pipeline repos** (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`, `testsuite`) share full factory infrastructure. **Extended repos** (`bootc-installer`, `knuckle`, `iso`) have AGENTS.md and basic CI but are not yet on the full parity checklist.

The following are wired across the factory today (applies to core pipeline repos unless noted):

- **AGENTS.md** — per-repo operating contract (all repos including extended)
- **Label taxonomy** — the seven canonical lifecycle labels defined in [`docs/skills/label-workflow.md`](../skills/label-workflow.md). Applied per repo; there is no cross-repo label sync.
- **Squash-only merge + delete-branch-on-merge**
- **One issue form per repo**, which also introduces the filer to the label workflow
- **CODEOWNERS** with triage sentinel — synced from `common` to downstream repos via `sync-codeowners.yml`
- **bonedigger lifecycle** — issue intake, `ujust report` handling, and priority escalation. Owned by `projectbluefin/bonedigger`; consumed by `bluefin`, `bluefin-lts`, and `dakota` via `bonedigger.yml`. Not present in `common`, `actions`, or `testsuite`.
- **pre-commit** — json/yaml/toml hygiene, skill front-matter, doc links, and `no-floating-action-tags` (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`). This is where process conventions are enforced; there is no per-convention CI job.
- **Renovate** — automated dependency updates (`common`, `bluefin`, `bluefin-lts`, `actions`, `testsuite`; `dakota` not yet)
- **promotion-candidate-e2e.yml** — weekly Tuesday smoke/common on `bluefin:testing` and `bluefin:lts-testing` before downstream promotions
- **pr-e2e.yml** — pre-merge composed-image common suite gate for `common` PRs (active)
- **post-merge-e2e.yml** (bluefin-lts) — smoke/common on `:lts-testing` after every main-branch build
- **2-human production gate** — `factory-operations` environment requires two maintainer approvals before `:stable` tag in `bluefin`, `bluefin-lts`, `dakota`
- **consumer-validation.yml** (actions) — validates consumer PR/CI evidence before merging actions changes

## Factory parity

Parity is live state, so it is not tabulated here. A hand-maintained table
drifts, and a generated one is a table nobody remembers to regenerate. Ask
GitHub instead:

```bash
# Which core repos carry a given artifact
for repo in common bluefin bluefin-lts dakota actions testsuite; do
  printf '%-13s ' "$repo"
  gh api "repos/projectbluefin/$repo/contents/AGENTS.md" >/dev/null 2>&1 \
    && echo yes || echo "--"
done
```

Swap the path for whatever you are checking: `.pre-commit-config.yaml`,
`docs/SKILL.md`, `docs/skills/index.json`, `.github/workflows/bonedigger.yml`.

A gap worth fixing becomes a GitHub issue, not a row in this file.

Factory ACMM status: **Level 3 (Instructed)** as of 2026-06-06.

## Open Gaps

Factory gaps are tracked as GitHub issues — not in this doc. Query GitHub for the live state:

```bash
# Everything still awaiting triage across the factory
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

For the gap audit protocol and how to file factory issues, see [`docs/skills/factory-improvement.md`](../skills/factory-improvement/SKILL.md).
Tracking epics: [#404](https://github.com/projectbluefin/common/issues/404) (infra parity) · [#405](https://github.com/projectbluefin/common/issues/405) (QA model)

## Sensitive paths (require maintainer review)

All repos: `.github/workflows/`, `Justfile`, `build_files/`
dakota only: `elements/`
