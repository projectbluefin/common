# Factory Improvement — Loop Detail

Part of [factory-improvement](../SKILL.md) — full MEASURE/TRIAGE/IMPLEMENT/CAPTURE/VERIFY commands, E2E gate matrix, and documentation single-source-of-truth table.

---

## The Improvement Loop — Full Detail

```
MEASURE → TRIAGE → IMPLEMENT → CAPTURE → VERIFY → LOOP
```

### MEASURE

```bash
~/src/hive-status

# Everything awaiting triage (legacy repos: 1-triage; opted-in: needs-triage)
gh search issues --label "needs-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work already accepted (legacy repos: 3-clanker-queue; opted-in: triage/accepted)
gh search issues --label "triage/accepted" --owner projectbluefin --state open \
  --json number,title,repository
```

> `projectbluefin/common` uses shared stages (`needs-triage`,
> `triage/needs-information`, `triage/accepted`, `awaiting-release`,
> `needs-verification`), not `1-triage` or `3-clanker-queue`. These queries exclude
> common issues. To triage Common work, query its shared lifecycle directly —
> see [`../../label-workflow.md`](../../label-workflow.md).

### TRIAGE

For each open gap:
- Human gate? → **SKIP** (log it, do not touch)
- Doc gap? → **IMMEDIATE** (cheapest fix, push directly to main)
- CI/tooling gap? → file as a GitHub issue and let triage route it
- Cross-repo gap? → assess blast radius before acting

> Do **not** self-apply a queue label. Triage and queue admission are human
> decisions; agents file the issue and stop.

### IMPLEMENT

- Work highest-blast-radius gap first
- Prefer: doc fix > CI change > code change
- Max 4 open PRs at once
- Always `just check` + `pre-commit run --all-files` before commit

### CAPTURE

When you discover a gap:

1. File a GitHub issue in `projectbluefin/common`
2. Write a clear description — what is broken, what the fix looks like, whether it's automatable
3. Stop. Do not self-apply a queue label — triage and queue admission are human decisions

```bash
# Example: file a factory CI gap
gh issue create --repo projectbluefin/common \
  --title "ci: pre-commit not wired in testsuite" \
  --body "..."
```

### VERIFY

Would a fresh agent reading only the skills avoid the gap just closed?
If no → the skill is still incomplete.

---

## E2E Gate Matrix

| Repo | Pre-merge | Post-merge | Promotion |
|---|---|---|---|
| common | `pr-e2e.yml` (composed + common suite) | `e2e.yml` | `promotion-candidate-e2e.yml` |
| bluefin | PR smoke gate | post-merge common suite | Tuesday 06:00 UTC, N=7 floor, broad e2e suite |
| bluefin-lts | PR validation (`pr-testsuite.yml`) + advisory e2e (`pr-e2e.yml`) | post-merge e2e | upgrade-test + failure issue reporting |
| dakota | BST graph validation (`bst show`) | post-merge publish gate | Tuesday 06:00 UTC, N=7 floor, smoke+common e2e suite |

Gaps in this matrix = testing blind spots. File issues for missing gates.

---

## Documentation Single-Source-of-Truth

Each rule must exist in exactly ONE location. Other files should have a one-line pointer.

| Rule | Canonical location |
|---|---|
| ublue-os prohibition | `common/AGENTS.md` |
| Issue lifecycle table | `docs/skills/label-workflow.md` |
| PR comment policy | `docs/factory/agentic-model.md` |
| Branch targets by repo | `docs/factory/agentic-model.md` |
| Session start ritual | `common/AGENTS.md` (+ pointer in agentic-model.md) |
| Task→skill routing | `docs/SKILL.md` |

---

## Finding Open Gaps

Factory gaps are tracked as GitHub issues. Do not maintain gap lists in this doc — they drift. Always query GitHub for the current state:

```bash
# Everything awaiting triage (legacy repos: 1-triage; opted-in: needs-triage)
gh search issues --label "needs-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work already accepted (legacy repos: 3-clanker-queue; opted-in: triage/accepted)
gh search issues --label "triage/accepted" --owner projectbluefin --state open \
  --json number,title,repository
```

> Common and ChairLift use the opted-in shared stages, not `1-triage` or
> `3-clanker-queue`. The queries above exclude their issues. Query each
> repository's current stages directly — see
> [`../../label-workflow.md`](../../label-workflow.md).

---

## Automation Audit — completed 2026-06-11

All 7 automation phases deployed. The audit directory has been removed. Key outcomes:

| Measure | Result |
|---|---|
| Workflow automation | ~97% (124 workflows, 7 repos) |
| Human gates | 4 intentional (promotion review, actions merge, priority assignment, stale PR unclaim) |
| Supply chain | Keyless OIDC + SBOM + SLSA L2 live ([common#595](https://github.com/projectbluefin/common/pull/595)) |
| C1 reusable-promote | dakota ✅, bluefin-lts ✅, **bluefin pending** ([common#584](https://github.com/projectbluefin/common/issues/584)) |

---

## Session Close

After each improvement session:

1. For each gap discovered: file a GitHub issue (see CAPTURE above)
2. For significant improvements shipped: update the relevant skill file in `docs/skills/`

Do **not** maintain gap lists or changelogs in this skill file or anywhere in the repo. GitHub issues are the live backlog; `docs/skills/` is the knowledge base.
