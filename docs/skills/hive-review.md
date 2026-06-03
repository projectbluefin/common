---
name: hive-review
description: Hive priority review — run ~/src/hive-status at the start of every projectbluefin/* session to get P0/P1 blockers.
---

# Hive Priority Review — Project Bluefin

> **Load this skill at the start of every session in any `projectbluefin/*` repo.**
> Step 1 in every agent session is to run the hive status check. Don't skip it.

## One command — always start here

```bash
~/src/hive-status
```

That's it. This script is deterministic, requires no auth, and gives you everything
you need to triage the current hive cycle in under 5 seconds.

## What it shows

```
🐝 Hive: hive-optimistic-bluefin  [2026-06-02 04:45Z]  ACMM L3

🔴 P0 BLOCKERS          — fix before anything else
🟡 P1 THIS CYCLE        — must land this cycle
📊 SCANNER SUMMARY      — what the scanner agent last reported
🤖 AGENTS               — which agents are running/paused and how long
📝 ADVISORY ITEMS       — ranked findings from all agents (CRITICAL → HIGH → ...)
```

## Flags

| Flag | Effect |
|---|---|
| _(none)_ | One-shot snapshot |
| `--watch` | Auto-refresh every 300 s (clears screen) |
| `--json` | Raw snapshot JSON — useful for scripting |

## How the script works

- Fetches `https://raw.githubusercontent.com/kubestellar/docs/main/public/live/hive/bluefin/index.html`
- Parses the embedded `render({...})` JSON payload (no auth required)
- Extracts: P0/P1 blockers from ci-maintainer agent text, advisory items from `advisoryDigest.by_agent`, agent states/cadences
- Advisory items are ranked: `critical → high → medium → low → info`, up to 2 per agent, 8 total

## Where the script lives

```
~/src/hive-status   (executable Python 3, no dependencies beyond stdlib)
```

If it's missing, check `castrojo/copilot-config` — it's part of the workspace setup.

## What to do with the output

### P0 blockers
These are release blockers the hive formation is actively tracking. If any exist,
address them before any other work in this session. File a PR or claim the issue.

### P1 items
Must land this cycle. Triage whether any are claimable now.

### Advisory items
Cross-repo findings from hive agents. Each is tagged `[CRITICAL]`/`[HIGH]`/etc. plus the
agent name and a one-line description. Dig into any CRITICAL items that fall in your repo.

Common follow-up commands after reading advisories:

```bash
# Find the specific issue an advisory references
gh issue view <number> --repo projectbluefin/<repo>

# See all hive-tracked blockers org-wide
gh search issues --label "hive/p0" --owner projectbluefin --state open

# See all hive P1 this-cycle items
gh search issues --label "hive/p1" --owner projectbluefin --state open

# See agent-ready queue (claimable work)
gh search issues --label "queue/agent-ready" --owner projectbluefin --state open
```

## Hive label taxonomy (quick ref)

| Label | Meaning |
|---|---|
| `hive/p0` | Release blocker — hive is actively tracking |
| `hive/p1` | This-cycle item — hive is actively tracking |
| `queue/agent-ready` | Ready for agent pickup |
| `queue/claimed` | Agent has claimed this issue |
| `agent/blocked` | Needs human input |

`hive/` labels are **dynamic** (reset each cycle by hive agents). `priority/p0` etc. are
the repo's own static labels. An issue can have both.

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `fetch failed: HTTP 404` | kubestellar/docs hasn't published a snapshot yet | Try again in a few minutes |
| `parse failed: no render(...)` | HTML structure changed upstream | Check the raw URL manually; update the parser if needed |
| Script missing | Workspace not fully set up | Run `just setup` in `~/src` or copy from `castrojo/copilot-config` |
