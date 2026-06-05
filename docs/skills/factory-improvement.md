---
name: factory-improvement
description: "Self-improving factory loop for projectbluefin. Systematically closes gaps between design and implementation until every automatable step is automated and only intentional human gates remain."
version: 1.0.0
---

# Factory Improvement — Self-Improving Loop

## When to Use

- Dedicated "improve the factory" sessions
- After an architectural review surfaces gaps
- Onboarding a new repo into the factory standard
- Quarterly health check: design vs. reality drift

## When NOT to Use

- Fixing a specific bug (use the repo's AGENTS.md + relevant skill)
- Reviewing a single PR (use `hive-review` or `queue-dashboard`)
- Active incident response — fix the incident first, then run this loop

---

## Mission

**Full automation of everything that does not require a human judgment call.**

The factory should be self-healing: issues flow through the pipeline, agents handle
the mechanical work, and humans make only the decisions requiring accountability,
context, or trust. Every manual step that *could* be automated is a reliability tax.

---

## Human Gates — Intentional and Non-Negotiable

Never automate these. Never propose automating them without explicit maintainer approval:

| Gate | Why it must be human |
|---|---|
| `/approve` comment — lifecycle moves the issue directly to `status/queued` | Prioritization judgment; agent scope assignment |
| PR merge approval (1 human reviewer per CODEOWNERS) | Accountability; trust for org-critical changes |
| `hive/p0` and `hive/p1` label assignment | Release impact judgment |
| Production promotion decisions (Tuesday cadence) | Final go/no-go for user-facing changes |
| `/unclaim` on stale PRs | Judgment on abandoned vs. still-active claim |
| Any write or automated action to `ublue-os/*` namespace | Absolute prohibition — includes issues, PRs, reports, webhooks, dispatch. Reads only. |

Everything else is automatable.

---

## The Improvement Loop

```
MEASURE → TRIAGE → IMPLEMENT → CAPTURE → VERIFY → LOOP
```

### MEASURE

```bash
~/src/hive-status                                           # P0/P1 blockers
gh issue list --repo projectbluefin/common \
  --label "hive/p0,hive/p1" --state open                  # tracked gaps
```

Cross-reference `docs/factory/README.md` "Open gaps" section.

### TRIAGE

For each open gap:
- Human gate? → **SKIP** (log it, do not touch)
- Doc gap? → **IMMEDIATE** (cheapest fix)
- CI/tooling gap? → **QUEUE** as hive/p1
- Cross-repo gap? → assess blast radius before acting

### IMPLEMENT

- Work highest-blast-radius gap first
- Prefer: doc fix > CI change > code change
- Max 4 open PRs at once
- Always `just check` + `pre-commit run --all-files` before commit

### CAPTURE

- Update this skill with findings
- Update `acmm-audit-level2.md` with closed gaps
- Update `docs/factory/README.md` open gaps section
- File issues for new gaps

### VERIFY

Would a fresh agent reading only the skills avoid the gap just closed?
If no → the skill is still incomplete.

---

## Pipeline Uniformity Checklist

Each factory repo (`common`, `bluefin`, `bluefin-lts`, `dakota`, `testsuite`, `actions`)
must have ALL of:

| Requirement | Check command |
|---|---|
| `AGENTS.md` present | `gh api repos/projectbluefin/{repo}/contents/AGENTS.md` |
| `lifecycle-caller.yml` wired | `gh api repos/projectbluefin/{repo}/contents/.github/workflows/lifecycle-caller.yml` |
| `skill-drift.yml` wired | `gh api repos/projectbluefin/{repo}/contents/.github/workflows/skill-drift.yml` |
| Hive labels present | `gh label list --repo projectbluefin/{repo} \| grep hive` |
| pre-commit config present | `gh api repos/projectbluefin/{repo}/contents/.pre-commit-config.yaml` |
| Squash-only merge | `gh repo view projectbluefin/{repo} --json squashMergeAllowed,mergeCommitAllowed` |

Missing any row = a gap to close.

---

## E2E Gate Matrix

| Repo | Pre-merge | Post-merge | Promotion |
|---|---|---|---|
| common | `pr-e2e.yml` (composed + common suite) | `e2e.yml` | `promotion-candidate-e2e.yml` |
| bluefin | PR smoke gate | post-merge common suite | Tuesday promotion check |
| bluefin-lts | PR validation | **MISSING ← GAP** | promotion smoke |
| dakota | PR CI | post-merge gate | — |

Gaps in this matrix = testing blind spots. File issues for missing gates.

---

## Documentation Single-Source-of-Truth

Each rule must exist in exactly ONE location. Other files should have a one-line pointer.

| Rule | Canonical location |
|---|---|
| ublue-os prohibition | `common/AGENTS.md` |
| Issue lifecycle table | `docs/factory/agentic-model.md` |
| PR comment policy | `docs/factory/agentic-model.md` |
| Branch targets by repo | `docs/factory/agentic-model.md` |

Count duplicates during each audit pass. Each duplicate is a maintenance liability.

---

## Known Gaps (as of 2026-06-05)

### P0 — Critical

| Gap | Issue | Automatable? |
|---|---|---|
| Org AGENTS.md (projectbluefin/.github) lists ublue-os/aurora and ublue-os/bazzite as "consuming repos" and soft-prohibits PRs only — contradicts the absolute automation ban. Requires a human to update that file. | — | No — human must update projectbluefin/.github AGENTS.md |
| `bluefin-lts` has no post-merge e2e gate | #420 | Yes |

### P1 — Must land soon

| Gap | Issue | Automatable? |
|---|---|---|
| Renovate paused — invalid packageRules in base config | #487 | Yes |
| `bluefin` pre-push hook missing — `git push` goes to ublue-os/bluefin | #476 | Yes |
| Issue lifecycle table duplicated verbatim in 3 files | — | Yes |
| PR comment policy duplicated in 3 files | — | Yes |

### Backlog

| Gap | Automatable? |
|---|---|
| `docs-quality.yml` + `skill-drift.yml` could be one workflow with two jobs | Yes |
| `factory/README.md` + `agentic-model.md` could be merged (~50 lines unique content) | Yes |
| ~30 skills duplicated between workspace and `common/docs/skills/` with no sync mechanism | Partial |
| Regression contract across `latest`/`stable`/`gts`/`lts` streams undefined (#420) | No — requires human spec |

---

## Improvement Priority Order

1. Resolve the ublue-os policy contradiction (P0 — human input needed first)
2. Wire `bluefin-lts` post-merge e2e gate (P0)
3. Fix Renovate config (P1 — dependency drift is a security concern)
4. Consolidate duplicate docs (P1 — cheap, high leverage)
5. `bluefin` pre-push hook (P1 — repeat incident prevention)
6. Merge `docs-quality.yml` + `skill-drift.yml` (Backlog)
7. Merge `factory/README.md` + `agentic-model.md` (Backlog)

---

## What "Done" Looks Like

- [ ] Every factory repo has identical infrastructure (AGENTS.md, lifecycle-caller.yml, skill-drift, hive labels, pre-commit, squash-only)
- [ ] Every pipeline stage has a gate: pre-merge CI, post-merge e2e, promotion smoke
- [ ] All rules exist in exactly one canonical location with one-line pointers elsewhere
- [ ] Renovate is running across all repos
- [ ] No known AI blindspot (ACMM audit) is unmitigated
- [ ] Only the human gates listed above remain manual

---

## Session Close

After each improvement session:

1. Update the "Known Gaps" table above with closed items and new discoveries
2. Update `docs/factory/README.md` "Open gaps" section
3. Update `docs/skills/acmm-audit-level2.md` for closed blindspot items
4. File issues for new gaps (`status/queued` label if automatable)

This skill is the memory of the improvement loop. Keep it current.
