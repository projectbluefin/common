# Hive Label Taxonomy & Org Board

## What is the hive

The "hive" is the agentic operations layer for the projectbluefin factory. It uses GitHub labels and automated workflows to maintain a shared queue of work across all 5 repos, visible on the org project board.

**Org board:** https://todo.projectbluefin.io → https://github.com/orgs/projectbluefin/projects/2

## Label taxonomy

### Hive labels (dynamic)
Reset each cycle by hive agents and human triage. Apply to issues currently being tracked.

| Label | Color | When to use |
|---|---|---|
| `hive/p0` | 🔴 `#d93f0b` | Release blocker — must be fixed before next image promotion |
| `hive/p1` | 🟠 `#e4a117` | Must land this cycle |

**`hive/*` vs `priority/*`:** `priority/p0` is the repo's static backlog ordering. `hive/p0` means the hive is **actively tracking this as a blocker right now**. An issue can have both.

### Queue labels
| Label | Meaning |
|---|---|
| `queue/agent-ready` | Ready for an agent to pick up — no blockers |
| `queue/claimed` | Agent has claimed this, work in progress |
| `queue/hold` | Do not close or auto-merge yet |
| `agent/blocked` | Agent hit a blocker — needs human input before continuing |

## Hive sync workflows

Each repo posts its health data to the org board on a schedule:

| Repo | Workflow | Schedule | Status |
|---|---|---|---|
| dakota | hive-status-sync.yml | `:00 hourly` | ✅ active (label bug: counts `P0` not `hive/p0` — see common#406) |
| bluefin | hive-progress-sync.yml | `:15 hourly` | ❌ missing — see common#407 |
| common | hive-progress-sync.yml | `:20 hourly` | ❌ missing — see common#407 |
| knuckle | hive-progress-sync.yml | `:30 hourly` | ✅ active (label bug: counts `priority:p0` — see common#406) |
| bluefin-lts | hive-progress-sync.yml | `:45 hourly` | ❌ missing — see common#407 |

## Finding work

```bash
# P0 blockers — start here every session
gh search issues --label "hive/p0" --owner projectbluefin --state open --json number,title,repository

# P1 this-cycle
gh search issues --label "hive/p1" --owner projectbluefin --state open --json number,title,repository

# Ready for agent pickup
gh search issues --label "queue/agent-ready" --owner projectbluefin --state open --json number,title,repository

# Live snapshot
just hive   # from ~/src
```

## Setting hive labels

Hive labels are set by:
1. Human triage at cycle start
2. Automated hive agents reviewing open issue queues
3. Agents self-escalating via `gh issue edit --add-label "hive/p0"`

Labels are reset between cycles — stale hive labels should be removed when an issue is resolved or deprioritized.

## Org board fields

| Field | Options |
|---|---|
| Status | Todo / In Progress / Blocked / Backlog / Done |
| Priority | P0 (release blocker) / P1 (this cycle) / P2 (backlog) |
| Size | XS / S / M / L / XL |
| Component | Core OS / Dakota / Installer / Homelab / Dev Experience / Documentation / Infrastructure |
