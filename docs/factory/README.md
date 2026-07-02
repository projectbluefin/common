# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory.

## Operating principle

> **Humans approve design, security, and merge. Everything else is automated, self-healing, and non-blocking.**

Project Bluefin aims to be the most sophisticated CNCF showcase of cloud-native operating systems built with bootc. The factory is an **agentic CI/CD organism**: agents implement, humans set direction. Manual orchestration is treated as a reliability tax — every manual step that *can* be automated *will* be, every automated step must self-heal, and every remaining human gate is intentional and named in [`docs/skills/human-gates.md`](../skills/human-gates.md).

New workflows must self-heal: retry on transient failures, fast-fail on bad tokens, no silent skips. See [`docs/skills/ci-tooling.md`](../skills/ci-tooling.md) for known pitfalls.

## Reference read order

1. Target repo `AGENTS.md` — start here
2. This file — org map, infrastructure topology, parity matrix
3. [`docs/factory/agentic-factory.modelith.md`](agentic-factory.modelith.md) — load lifecycle/domain contract before lifecycle or factory implementation work
4. [`docs/factory/agentic-model.md`](agentic-model.md) — cross-repo hard rules, branch targets, PR policy, session start
5. Relevant `docs/skills/*` files — lazy-load for the specific task; use [`docs/SKILL.md`](../SKILL.md) as the router

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

We use a lightweight, GitOps-first **Branch-as-State** model for the factory's lifecycle. Issues have static labels for categorization (type, area, priority) while the active work state is tracked purely through branches, PR associations, standard assignees, and projects. Mutable label-based FSMs and comment commands (like `/claim` or `/approve`) are retired.

Full workflow, label taxonomy, epics, project board, and PR labels: [`docs/skills/label-workflow.md`](../skills/label-workflow.md)
Hard rules, branch targets, PR comment policy, session start: [`docs/factory/agentic-model.md`](agentic-model.md)

## Automation coverage

~97% automated across 124 workflows in 7 in-scope repos. **4 intentional human gates:** promotion review, actions merge, priority assignment, stale PR unclaim — see [`docs/skills/human-gates.md`](../skills/human-gates.md). ISO auto-rebuild remains manual (iso repo out of scope).

## Factory infrastructure

**Core pipeline repos** (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`, `testsuite`) share full factory infrastructure. **Extended repos** (`bootc-installer`, `knuckle`, `iso`) have AGENTS.md and basic CI but are not yet on the full parity checklist.

The following are wired across the factory today (applies to core pipeline repos unless noted):

- **AGENTS.md** — per-repo operating contract (all repos including extended)
- **Label taxonomy** — canonical definitions in `labels.json` (67 labels; includes `hardware/*` for promotion gates), synced to all repos by `sync-labels.yml` (⚠️ requires `MERGERAPTOR_APP_ID`/`MERGERAPTOR_PRIVATE_KEY` secrets — issue #511); key labels: `hive/p0`, `hive/p1`, `agent/blocked`, `source:*`, `hardware/blocker`
- **Squash-only merge + delete-branch-on-merge**
- **5 standard issue templates**
- **CODEOWNERS** with triage sentinel — synced from `common` to downstream repos via `sync-codeowners.yml`
- **GitOps Flow** — standard, zero-maintenance branch-as-state model using standard GitHub projects and `Closes #NNN` PR linkages. The legacy active FSM bot is retired.
- **bonedigger** — scoped to ujust report filing and priority auto-escalation only
- **skill-drift.yml** — PR advisory gate for doc/impl parity (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`; `testsuite` pending)
- **pre-commit** — json/yaml/toml hygiene and `no-floating-action-tags` (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`)
- **Renovate** — automated dependency updates (`common`, `bluefin`, `bluefin-lts`, `actions`, `testsuite`; `dakota` not yet)
- **promotion-candidate-e2e.yml** — weekly Tuesday smoke/common on `bluefin:testing` and `bluefin:lts-testing` before downstream promotions
- **pr-e2e.yml** — pre-merge composed-image common suite gate for `common` PRs (active)
- **post-merge-e2e.yml** (bluefin-lts) — smoke/common on `:lts-testing` after every main-branch build
- **2-human production gate** — `factory-operations` environment requires two maintainer approvals before `:stable` tag in `bluefin`, `bluefin-lts`, `dakota`
- **consumer-validation.yml** (actions) — validates consumer PR/CI evidence before merging actions changes

## Current parity matrix (2026-06-06) — core pipeline repos

| Artifact | common | bluefin | bluefin-lts | dakota | actions | testsuite |
|---|---|---|---|---|---|---|
| AGENTS.md | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| pre-commit | ✅ | ✅ | ✅ | ✅ | — | — |
| skill-drift.yml | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| no-floating-action-tags | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| GitOps Flow (standard) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Renovate config | ✅ | ✅ | ❓ org-inherited | ❌ | ✅ | ✅ |
| Post-merge e2e | ✅ | ✅ | ✅ | partial | — | — |
| Pre-merge e2e | ✅ (common suite) | ✅ (pr-smoke) | ❌ | ❌ | — | — |
| Installability gate | ⚠️ smoke/common only | ❌ | ❌ | ❌ | — | ❌ |
| 2-human production gate | ✅ | ✅ | ✅ | ✅ | — | — |
| docs/skills/ populated | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Factory ACMM status: **Level 3 (Instructed)** as of 2026-06-06.

## Open Gaps

Factory gaps are tracked as GitHub issues — not in this doc. Query GitHub for the live state:

```bash
# P0 and P1 this cycle (all factory repos)
gh search issues --label "hive/p0" --owner projectbluefin --state open \
  --json number,title,repository
gh search issues --label "hive/p1" --owner projectbluefin --state open \
  --json number,title,repository

# AI/LLM context blindspots affecting agents
gh search issues --label "ai-context" --owner projectbluefin --state open \
  --json number,title,repository
```

For the gap audit protocol and how to file factory issues, see [`docs/skills/factory-improvement.md`](../skills/factory-improvement.md).
Tracking epics: [#404](https://github.com/projectbluefin/common/issues/404) (infra parity) · [#405](https://github.com/projectbluefin/common/issues/405) (QA model)

## Sensitive paths (require maintainer review)

All repos: `.github/workflows/`, `Justfile`, `build_files/`
dakota only: `elements/`
