---
name: bonedigger
version: "1.0"
last_updated: 2026-06-23
tags: [bonedigger, triage, automation]
description: "bonedigger + kubestellar-bot lifecycle automation - ujust report issue filing, priority escalation, and how fixes ship back to the image. Use when understanding how ujust report works, investigating bonedigger behavior, or diagnosing issue lifecycle automation."
metadata:
  type: reference
---

# bonedigger & kubestellar-bot

**Repo:** https://github.com/projectbluefin/bonedigger

## The full loop

bonedigger and kubestellar-bot together form the closed improvement loop that drives Bluefin 2.0:

```
user runs ujust report
  └─ bonedigger agent collects system diagnostics
       └─ scrubs PII on-device
            └─ files structured issue to image repo
                 └─ issue triaged and assigned to agent
                      └─ kubestellar-bot detects assigned issue
                           └─ dispatches agent to implement fix
                                └─ PR shipped back to image repo
                                     └─ merged → better OS
                                          └─ better bonedigger
                                               └─ loop
```

## bonedigger - what it does

bonedigger has two functions:

1. **ujust report detection** - when an issue is filed via `ujust report` on a live system, bonedigger detects the diagnostic signature and sets `source:ujust-report`
2. **Priority auto-escalation** - tracks `ujust confirm` counts and escalates:
   - 3+ confirms → adds `priority/p1`
   - 5+ confirms → adds `priority/p0`

**Packaging note:** in common, keep `ujust report` as a thin recipe wrapper in
`system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` and put the
real shell implementation in `/usr/libexec/bonedigger-report`. Keep the
`BONEDIGGER_VERSION` line in the Justfile because Renovate watches that path.

## bonedigger — what it does NOT do

The legacy **full** issue lifecycle (slash commands, pipeline widget, label transitions, stale sweep, auto-merge on lgtm) previously driven by `projectbluefin/actions/.github/workflows/lifecycle.yml` is **retired**. All active FSM tracking is replaced by Branch-as-State GitHub Flow.

See [`label-workflow.md`](./label-workflow.md) for the modern lightweight lifecycle reference.

## kubestellar-bot - what it does

kubestellar-bot is the implementation agent layer. It:
- Monitors open, unassigned, triaged issues across all factory repos
- Dispatches agents to claim and implement fixes
- Manages the PR lifecycle from claim → ship
- Reports progress back to the hive dashboard

kubestellar-bot does NOT make design or security decisions. Those hit a human gate. See [`human-gates.md`](./human-gates.md).

## Integration status

The mutable label-based active FSM automation is **retired**. We use a standard branch-as-state model where keyword associations and projects handle transitions.

All internal `projectbluefin/` workflow refs use `@main` — **not SHA pins**. SHA pins on internal refs caused repeated `startup_failure` cascades when pins drifted; the pre-commit floating-tag guard already exempts `projectbluefin/*`. See [`ci-tooling.md`](./ci-tooling.md) § Internal refs.

bonedigger’s `sync-templates.yml` continues to propagate issue templates to factory repos.

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates from `bonedigger/templates/` to factory repos.

Requires `MERGERAPTOR_APP_ID` (var) and `MERGERAPTOR_PRIVATE_KEY` (secret) on the bonedigger repo. PAT-based auth was replaced with mergeraptor app token in bonedigger#21.

## Lessons Learned

### Persist local report copies before cleanup (2026-06-20)

`/usr/libexec/bonedigger-report` builds its gist payload inside a temporary report
directory and removes that directory via `trap cleanup EXIT`. Any optional local
copy (`summary.md`, `journal.txt`, OTEL attachments) must be copied to a stable
location before the script exits, and copy failures must never abort a
successful gist upload.
