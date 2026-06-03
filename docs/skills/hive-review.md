---
title: "Hive-Status: Triaging Tool"
load_when: "Starting your session — reviewing P0/P1 issues, triaging incoming reports"
categories: ["triage", "hive-labels"]
---

# Hive-Status — P0/P1 Triage Tool

Load when: Starting your session, reviewing P0/P1 issues, or performing daily triage.

## Quick start

```bash
# On your Bluefin machine or within your work session
~/src/hive-status

# Interactive menu:
# ├─ P0 (critical) — show all
# ├─ P1 (high) — filter by repo
# ├─ P2 (medium) — search by term
# └─ P3+ (backlog) — pagination only
```

## Hive Label Taxonomy

The **hive system** prioritizes issues based on impact and reproducibility. bonedigger automatically assigns hive labels based on:

1. **User confirm count** — `ujust confirm <issue>` comments
2. **Impact scope** — Does it affect all variants or specific streams?
3. **System impact** — Is it a blocker or degradation?

### Priority Tiers

| Label | Color | Meets | Action |
|-------|-------|-------|--------|
| **P0** | 🔴 Red | 5+ confirms OR critical security OR blocks release | Immediate (24hr triage) |
| **P1** | 🟠 Orange | 3–4 confirms OR key feature broken | High (48hr triage) |
| **P2** | 🟡 Yellow | 1–2 confirms OR minor functionality | Standard (1-week triage) |
| **P3** | 🟢 Green | 0 confirms OR feature request | Backlog (no SLA) |

### Examples

```
3 users confirm same bug
    ↓
bonedigger sees 3+ ujust confirm comments
    ↓
Auto-assign p1 label
    ↓
Appears in "P1 (High Priority)" section of hive-status
```

## Hive-Status Interface

### P0 View (All Issues, No Paging)

Shows every P0 issue across all repos. **Do not ignore these.**

```
P0 Critical (14 total)
───────────────────────────────────────
[x] #1234 — Bluefin won't boot (latest, 5 confirms)
             @alice claimed, 2 days old
             
[x] #1235 — GNOME doesn't start after update (stable, 7 confirms)
             NO OWNER — escalate to @maintainers
```

### P1 View (Filter by Repo)

High-priority work that can be triaged and distributed:

```
P1 High Priority (31 total)
───────────────────────────────────────
Dakota (7):
  [x] #999 — toolbox pull slow on slow networks (3 confirms)
  [x] #1001 — podman socket issues in DX (4 confirms)

Bluefin (12):
  [x] #888 — Firefox crashes on startup (3 confirms)
  [x] #890 — Fedora 41 kernel modules missing (4 confirms)

Common (6):
  [x] #500 — Flatpak permission issue (3 confirms)
```

### P2 View (Search & Pagination)

Medium-priority issues — manageable backlog:

```
P2 Medium Priority (147 total) — Page 1
───────────────────────────────────────
[x] #401 — Suggest "ujust install-flatpaks" in setup
[x] #402 — Minor GNOME Shell theme fix
[x] #403 — Improve error message for brew install

[PgDn] Next page (20/147)
```

### P3+ View (Backlog, Backlog, Backlog)

Feature requests and aspirational work. **Not triaged on deadline.**

```
P3 Low Priority (1200+ total) — backlog
───────────────────────────────────────
[x] Request: Support macOS (probably never)
[x] Request: Add Wayland on Raspberry Pi (blocked by upstreams)

[This view is paginated heavily to avoid noise]
```

## Workflow: Daily Triage Session

### 1. Start: Open hive-status, check for new P0s

```bash
~/src/hive-status

# P0 count should not grow. If it does, investigate + escalate.
```

### 2. Scan P1s by repo

```
Review each P1 in top repos:
├─ Dakota (7) — are any duplicates?
├─ Bluefin (12) — any recent spikes?
└─ Common (6) — platform-blocking issues?
```

### 3. For each unclaimed P1:

```
1. Click into the issue
2. Read the bonedigger diagnosis card (auto-generated)
3. Assign to the owning team's area lead:
   ├─ GNOME/Desktop → @desktop-leads
   ├─ Flatpak/Apps → @flatpak-leads
   ├─ Hardware → @hardware-leads
   └─ System/CI → @system-leads
4. Leave a triage comment with area assignment
5. Click `/approve` (bonedigger will queue it)
```

### 4. Review P2s opportunistically

```
P2s can wait a week, but:
├─ Look for duplicates (merge or comment `ujust confirm`)
├─ Check if any should really be P1 (escalate if needed)
└─ Watch for patterns (if 3+ P2s mention same thing, escalate to P1)
```

## Commands in hive-status

| Key | Action |
|-----|--------|
| `p` | Go to P0 view |
| `1` | Go to P1 view |
| `2` | Go to P2 view |
| `3` | Go to P3 view |
| `/search {term}` | Filter by search term |
| `Enter` | Open issue in browser |
| `q` | Quit |

## Escalation Matrix

If you see a pattern, escalate:

| Pattern | Who to notify | Label to add |
|---------|---------------|--------------|
| Same bug in 3+ repos | @projectbluefin/maintainers | `regression:parity` |
| Security issue | @security-team | `type:security` |
| Build/CI failing | @ci-team | `area:ci` |
| Blocker for 5+ users | @core-team | `needs-immediate-action` |

## Stale Issues

If a P0 or P1 is **unclaimed for 72+ hours**:

```bash
# Add this comment in the issue:
@projectbluefin/maintainers help? No claims in 3 days.
```

The system will escalate it to team leads automatically.

## Integration with bonedigger

Every issue filed via `ujust report` starts here. bonedigger:

1. Collects diagnostics (OS version, logs, hardware info)
2. **Auto-assigns P0/P1** based on `ujust confirm` count
3. Posts diagnosis card (read this first!)
4. Adds `needs-triage` label (you remove via `/approve`)

See [bonedigger-overview](./bonedigger-overview.md) for mechanics.

## Integration with Trail of Bits CI

The skill-drift CI validates that this guide stays synchronized with code changes:

- **Code changes**: When workflows, scripts, or systems change, corresponding skill docs must update
- **Trigger**: On every PR, `skill-drift-check.yml` compares code changes to skill updates
- **Enforcement**: If code changes without skill updates, the check fails and the PR is blocked
- **Waiver**: If the code change truly needs no skill update, note this in the PR description

Read [skill-drift documentation](./SKILL_DRIFT_CI.md) for how to handle CI failures.

## See also

- [bonedigger-lifecycle](./bonedigger-lifecycle.md) — State machine and slash commands
- [queue-dashboard](./queue-dashboard.md) — Repository-wide queue view
- [REGRESSION_CONTRACT](../qa/REGRESSION_CONTRACT.md) — Feature parity across streams
