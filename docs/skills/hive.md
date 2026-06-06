---
name: hive
description: "The Hive system — what it is, how bonedigger/kubestellar-bot/hive form the self-improvement loop, label taxonomy, sync schedule, and how to find work."
---

# The Hive

## What the hive is

The hive is the agentic operations layer for the projectbluefin factory. It combines three components to form a closed self-improvement loop:

```
┌─────────────────────────────────────────────────────┐
│  KubeStellar Hive                                   │
│  ACMM orchestration — agents at increasing autonomy │
└────────────────┬────────────────────────────────────┘
                 │
     ┌───────────┴───────────┐
     ▼                       ▼
bonedigger              kubestellar-bot
(client + lifecycle)    (implementation agent)

ujust report            picks up status/queued issues
└─ agent collects  ───▶ implements fixes, ships PRs
   system diagnostics   back to the image repos
   humans can't
└─ files structured          │
   issue to image repo       ▼
                        better OS
                             │
                             ▼
                        better bonedigger
                             │
                             └─── loop
```

**bonedigger** runs on user systems. `ujust report` triggers it: an agent collects diagnostics, scrubs PII on-device, files a structured issue. Priority auto-escalates from `ujust confirm` counts (3+ → `priority/p1`, 5+ → `priority/p0`).

**kubestellar-bot** picks up `status/queued` issues from across the factory repos and dispatches agents to implement fixes. It ships PRs back and manages the claim lifecycle.

**The hive** (KubeStellar Hive dashboard at https://kubestellar.io/live/hive/bluefin/) provides the orchestration layer, ACMM scoring, and the agent dispatch queue.

The org board mirrors the queue: https://todo.projectbluefin.io

---

## Label taxonomy

### Hive labels (dynamic)
Reset each cycle by hive agents and human triage.

| Label | Color | When to use |
|---|---|---|
| `hive/p0` | 🔴 `#d93f0b` | Release blocker — must be fixed before next image promotion |
| `hive/p1` | 🟠 `#e4a117` | Must land this cycle |

**`hive/*` vs `priority/*`:** `priority/p0` is the repo's static backlog ordering. `hive/p0` means the hive is **actively tracking this as a blocker right now**. An issue can have both.

### Queue labels
| Label | Meaning |
|---|---|
| `status/queued` | Ready for an agent to pick up — no blockers |
| `status/claimed` | Agent has claimed this, work in progress |
| `status/hold` | Do not close or auto-merge yet |
| `agent/blocked` | Agent hit a blocker — needs human input before continuing |

---

## Hive sync workflows

Each repo posts its health data to the org board on a schedule:

| Repo | Workflow | Schedule | Status |
|---|---|---|---|
| dakota | hive-status-sync.yml | `:00 hourly` | ✅ active (label bug: counts `P0` not `hive/p0` — see common#406) |
| bluefin | hive-progress-sync.yml | `:15 hourly` | ❌ missing — see common#407 |
| common | hive-progress-sync.yml | `:20 hourly` | ❌ missing — see common#407 |
| knuckle | hive-progress-sync.yml | `:30 hourly` | ✅ active (label bug: counts `priority:p0` — see common#406) |
| bluefin-lts | hive-progress-sync.yml | `:45 hourly` | ❌ missing — see common#407 |

---

## Finding work

```bash
# P0 blockers — start here every session
gh search issues --label "hive/p0" --owner projectbluefin --state open --json number,title,repository

# P1 this-cycle
gh search issues --label "hive/p1" --owner projectbluefin --state open --json number,title,repository

# Ready for agent pickup
gh search issues --label "status/queued" --owner projectbluefin --state open --json number,title,repository

# Live snapshot (from ~/src)
just hive
```

Or run `~/src/hive-status` for the full P0/P1 + advisory summary — mandatory at session start.

---

## Setting hive labels

Hive labels are set by:
1. Human triage at cycle start
2. Automated hive agents reviewing open issue queues
3. Agents self-escalating via `gh issue edit --add-label "hive/p0"`

Labels are reset between cycles — stale hive labels should be removed when an issue is resolved or deprioritized.

---

## Org board fields

| Field | Options |
|---|---|
| Status | Todo / In Progress / Blocked / Backlog / Done |
| Priority | P0 (release blocker) / P1 (this cycle) / P2 (backlog) |
| Size | XS / S / M / L / XL |
| Component | Core OS / Dakota / Installer / Homelab / Dev Experience / Documentation / Infrastructure |

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
| `status/queued` | Ready for an agent to pick up — no blockers |
| `status/claimed` | Agent has claimed this, work in progress |
| `status/hold` | Do not close or auto-merge yet |
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
gh search issues --label "status/queued" --owner projectbluefin --state open --json number,title,repository

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
