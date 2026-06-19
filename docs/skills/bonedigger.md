---
name: bonedigger
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
                 └─ lifecycle bot moves issue through pipeline
                      └─ kubestellar-bot picks up status/queued issue
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

The **full** issue lifecycle (slash commands, pipeline widget, label transitions, stale sweep, auto-merge on lgtm) lives in `projectbluefin/actions/.github/workflows/lifecycle.yml`. It was first deployed to `common` (2026-06-05) then moved to `actions` ([common#570](https://github.com/projectbluefin/common/issues/570), closed 2026-06-10) to serve all factory repos as a single reusable.

bonedigger **does** still provide its own slim `lifecycle.yml` for bonedigger-specific features: agent donation fast-track and ujust-report intake. This is called separately from the actions lifecycle — see Integration status below.

See [`label-workflow.md`](./label-workflow.md) for the full lifecycle reference.

## kubestellar-bot - what it does

kubestellar-bot is the implementation agent layer. It:
- Monitors `status/queued` issues across all factory repos
- Dispatches agents to claim and implement fixes
- Manages the PR lifecycle from claim → ship
- Reports progress back to the hive dashboard

kubestellar-bot does NOT make design or security decisions. Those hit a human gate. See [`human-gates.md`](./human-gates.md).

## Integration status

The factory has two lifecycle workflows serving different purposes:

| Workflow | Location | Called by | Purpose |
|---|---|---|---|
| Full lifecycle | `projectbluefin/actions/.github/workflows/lifecycle.yml@main` | `common` via `lifecycle-caller.yml` | Pipeline widget, slash commands, label transitions, stale sweep, auto-merge |
| bonedigger slim | `projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main` | `bluefin`, `bluefin-lts`, `dakota` via `bonedigger.yml` | Agent donation fast-track, ujust-report intake |

All internal `projectbluefin/` workflow refs use `@main` — **not SHA pins**. SHA pins on internal refs caused repeated `startup_failure` cascades when pins drifted; the pre-commit floating-tag guard already exempts `projectbluefin/*`. See [`ci-tooling.md`](./ci-tooling.md) § Internal refs.

If you find a `lifecycle-caller.yml` still pointing at `projectbluefin/common`, it is stale — delete it or update the target to `projectbluefin/actions`.

bonedigger’s `sync-templates.yml` continues to propagate issue templates to factory repos.

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates from `bonedigger/templates/` to factory repos.

Requires `MERGERAPTOR_APP_ID` (var) and `MERGERAPTOR_PRIVATE_KEY` (secret) on the bonedigger repo. PAT-based auth was replaced with mergeraptor app token in bonedigger#21.
