---
name: hive-review
description: "Session start ritual — run ~/src/hive-status, interpret P0/P1 output, triage advisory items, and find agent-ready issues. Use at the start of every agent session to surface blockers and the advisory queue."
metadata:
  type: runbook
---

# Hive-Status — P0/P1 Triage Tool

Load when: Starting your session, reviewing P0/P1 issues, or performing daily triage.

## Contents
- [Quick start](#quick-start)
- [Hive Label Taxonomy](#hive-label-taxonomy)
- [Hive-Status Interface](#hive-status-interface)
- [Workflow: Daily Triage Session](#workflow-daily-triage-session)
- [Escalation Matrix](#escalation-matrix)
- [Integration with bonedigger and lifecycle automation](#integration-with-bonedigger-and-lifecycle-automation)

---

## Quick start

```bash
# Show live hive status (uses gh auth token automatically)
~/src/hive-status

# Watch mode — refresh every 300 seconds
~/src/hive-status --watch

# Dump raw JSON
~/src/hive-status --json
```

## Live API Endpoint

The hive exposes a real-time REST API. `hive-status` uses this automatically.
Manual curl (works from internet, requires GitHub auth):

```bash
# Standard HTTPS endpoint (works from anywhere with gh auth)
curl -H "Authorization: Bearer $(gh auth token)" \
  https://hosted-projectbluefin-knuckle-gjvq.hive.kubestellar.io/api/status

# LAN-direct endpoint (from ghost's subnet only)
curl -H "Authorization: Bearer $(gh auth token)" \
  https://hosted-projectbluefin-knuckle-gjvq.hive.kubestellar.io:3002/api/v1/status

# Public queue data (no auth needed, ~5 min refresh)
curl https://queue.projectbluefin.io/data.json
```

The response is JSON with keys: `timestamp`, `hiveId`, `acmmLevel`, `agents[]`, `advisoryDigest`.
`agents[]` items have: `name`, `displayName`, `state`, `busy`, `paused`, `cadence`, `model`, `sortOrder`.
`advisoryDigest.by_agent[name][]` items have: `title`, `severity`.

> The old `raw.githubusercontent.com/kubestellar/docs/.../index.html` static snapshot
> is no longer published. The live API is the only data source.


The **hive system** prioritizes issues based on impact and reproducibility. bonedigger auto-escalates priority based on:

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
5. Comment `/approve` (lifecycle automation will queue it)
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

## Integration with bonedigger and lifecycle automation

Every issue filed via `ujust report` starts with bonedigger intake. bonedigger:

1. Collects diagnostics (OS version, logs, hardware info)
2. **Auto-escalates hive priority** based on `ujust confirm` count
3. Posts diagnosis card (read this first!)

Lifecycle state changes now live in `projectbluefin/common`:

1. `.github/workflows/lifecycle.yml` owns slash commands, widget updates, label guards, and stale sweeps
2. `/approve` moves issues directly to `status/queued`
3. `status/approved` has been removed from the lifecycle

See [bonedigger-overview](./bonedigger-overview.md) for intake/reporting mechanics and [label-workflow](./label-workflow.md) for the lifecycle state machine.

## Integration with Trail of Bits CI

The skill-drift CI validates that this guide stays synchronized with code changes:

- **Code changes**: When workflows, scripts, or systems change, corresponding skill docs must update
- **Trigger**: On every PR, `skill-drift-check.yml` compares code changes to skill updates
- **Enforcement**: If code changes without skill updates, the check fails and the PR is blocked
- **Waiver**: If the code change truly needs no skill update, note this in the PR description

Read [skill-drift documentation](./SKILL_DRIFT_CI.md) for how to handle CI failures.

## See also

- [label-workflow](./label-workflow.md) — Lifecycle state machine and slash commands
- [queue-dashboard](./queue-dashboard.md) — Repository-wide queue view
- [REGRESSION_CONTRACT](../qa/REGRESSION_CONTRACT.md) — Feature parity across streams

---

## Executing hive advisory batches (2026-06-10 session learnings)

When executing a large hive advisory fleet (many repos, many PRs), these patterns prevent wasted retries:

### GitHub API parallel commit conflicts

Committing multiple files to the same branch in parallel calls causes HTTP 409 — the first commit advances the branch HEAD and the second call has a stale SHA.

**Pattern:** Commit serially. Re-fetch SHA before each update:
```bash
SHA=$(gh api "repos/OWNER/REPO/contents/PATH?ref=BRANCH" --jq '.sha')
# ... make changes ...
gh api "repos/OWNER/REPO/contents/PATH" -X PUT -f sha="$SHA" ...
# Then re-fetch SHA for the next file
SHA2=$(gh api "repos/OWNER/REPO/contents/OTHER?ref=BRANCH" --jq '.sha')
```

### Pass file content via temp file, not heredoc env vars

Python `os.environ['VAR']` inside a bash heredoc with `VAR=$(...)` fails — the var isn't exported. Write content to `/tmp/file.txt` and read with `open('/tmp/file.txt').read()`.

### Repo-specific branch targets

| Repo | PR target | Notes |
|---|---|---|
| `projectbluefin/bluefin` | `testing` | Never `main` |
| `projectbluefin/bluefin-lts` | `testing` | Never `main` — testing-first, same as bluefin and dakota |
| `projectbluefin/bootc-installer` | `dev` | Default branch is `dev`, not `main` |
| `projectbluefin/testsuite` | `main` | Merge queue enforced — doc changes still need CI green |
| All others | `main` | Standard |

### push_files vs create_or_update_file

`push_files` batches multiple files in one commit but can fail with cryptic "Required url" errors for certain input shapes. Use `create_or_update_file` for single files as the reliable fallback.

### Advisory digest is truncated

The hive advisory comment in `common#557` is truncated at 65KB. The full digest is ~315KB. When analyzing: there is a second half with more quality-agent findings that the CI-maintainer section doesn't repeat. Always request the full comment body via `gh issue view --comments` and check for the truncation warning at the bottom.
