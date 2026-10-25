# Factory Improvement — Loop Detail

Part of [factory-improvement](../SKILL.md) — full MEASURE/TRIAGE/IMPLEMENT/CAPTURE/VERIFY commands, E2E gate matrix, and documentation single-source-of-truth table.

---

## The Improvement Loop — Full Detail

```
MEASURE → TRIAGE → IMPLEMENT → CAPTURE → VERIFY → LOOP
```

### MEASURE

```bash
# Everything awaiting triage across the factory
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work already admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

`get_factory_status()` and `get_work_queue()` on the `projectbluefin` MCP
server return the same hub health and triage buckets without authentication.

### TRIAGE

For each open gap:
- Human gate? → **SKIP** (log it, do not touch)
- Doc gap? → **IMMEDIATE** (cheapest fix) — still via a PR; `main` has no direct-push path
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
| bluefin | PR smoke gate | post-merge common suite | broad e2e suite; see [release cadences](../../../factory/agentic-model.md#release-cadences) |
| bluefin-lts | PR validation (`pr-testsuite.yml`) + advisory e2e (`pr-e2e.yml`) | post-merge e2e | upgrade-test + failure issue reporting |
| dakota | BST graph validation (`bst show`) | post-merge publish gate | smoke+common e2e suite; see [release cadences](../../../factory/agentic-model.md#release-cadences) |

Gaps in this matrix = testing blind spots. File issues for missing gates.

---

## Documentation Single-Source-of-Truth

Each rule must exist in exactly ONE location. Other files should have a one-line pointer.

| Rule | Canonical location |
|---|---|
| ublue-os prohibition | `AGENTS.md` |
| Label taxonomy and lifecycle | `docs/skills/label-workflow.md` |
| How `main` is protected | `docs/skills/governance.md` |
| PR comment policy | `docs/factory/agentic-model.md` |
| Branch targets by repo | `docs/factory/agentic-model.md` |
| Release cadences | `docs/factory/agentic-model.md` |
| Factory fixture checklist | `docs/skills/factory-onboarding.md` |
| Hive host, endpoints, trust tiers | `docs/skills/hosted-hive.md` |
| Skill front-matter and size rules | `docs/skills/write-a-skill.md` |
| Task→skill routing | `docs/SKILL.md` |

---

## Finding Open Gaps

Factory gaps are tracked as GitHub issues. Do not maintain gap lists in this
doc — they drift. Use the MEASURE queries above against live GitHub.

---

## Session Close

After each improvement session:

1. For each gap discovered: file a GitHub issue (see CAPTURE above)
2. For significant improvements shipped: update the relevant skill file in `docs/skills/`

Do **not** maintain gap lists or changelogs in this skill file or anywhere in the repo. GitHub issues are the live backlog; `docs/skills/` is the knowledge base.
