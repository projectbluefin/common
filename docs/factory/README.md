# projectbluefin/common — Org Brain

This repo is the **canonical documentation and skills hub** for the entire projectbluefin factory.

## What lives here

| Path | Purpose |
|---|---|
| `docs/factory/` | Factory operating model, migration status, gap analysis |
| `docs/skills/` | Machine-readable skill docs for agents and contributors |
| `.github/ISSUE_TEMPLATE/` | Canonical issue templates — synced to all repos via bonedigger |
| `.github/CODEOWNERS` | Canonical triage sentinel — synced to all repos via sync-codeowners.yml |
| `.github/workflows/sync-codeowners.yml` | Auto-propagates CODEOWNERS triage block to all factory repos |

## The Factory

The projectbluefin factory is **5 repos that operate as one agentic whole**:

| Repo | Role | Artifact |
|---|---|---|
| [bluefin](https://github.com/projectbluefin/bluefin) | Fedora-based desktop image | OCI image — gts/stable/latest/beta |
| [bluefin-lts](https://github.com/projectbluefin/bluefin-lts) | CentOS-based LTS variant | OCI image — lts stream |
| [common](https://github.com/projectbluefin/common) | Shared OCI layer + org brain | OCI layer, docs, templates |
| [dakota](https://github.com/projectbluefin/dakota) | CoreOS-model image (BuildStream 2) | OCI image — testing/latest/stable |
| [knuckle](https://github.com/projectbluefin/knuckle) | Flatcar TUI installer | ISO + installer binary |

### Data flow

```
common (shared OCI layer)
    │
    ├──► bluefin  ──► testsuite (e2e gate) ──► gts/stable/latest
    ├──► bluefin-lts ──► testsuite ──► lts
    └──► dakota (separate BST pipeline) ──► latest/stable
                                             │
                                     knuckle (installer)
                                             │
                                           ISO
```

## Org project board

https://todo.projectbluefin.io

P0 blockers: `gh search issues --label "hive/p0" --owner projectbluefin --state open`
P1 this-cycle: `gh search issues --label "hive/p1" --owner projectbluefin --state open`
Agent queue: `gh search issues --label "queue/agent-ready" --owner projectbluefin --state open`

## Key docs

- [Agentic model](agentic-model.md) — how agents operate in this org
- [Migration status](migration-status.md) — current state of factory infra parity
- [skills/INDEX.md](../skills/INDEX.md) — all skill docs
- [skills/governance.md](../skills/governance.md) — CODEOWNERS, triagers, branch protection
- [skills/hive.md](../skills/hive.md) — hive label taxonomy and org board
- [skills/qa.md](../skills/qa.md) — QA model, test coverage, quality gates
- [skills/bonedigger.md](../skills/bonedigger.md) — crash detection and issue lifecycle
