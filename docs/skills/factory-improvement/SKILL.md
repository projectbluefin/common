---
name: factory-improvement
version: "1.1"
last_updated: "2026-08-08"
id: factory-improvement
one_line_purpose: Audit and propose factory self-improvement automation.
entry_point: docs/skills/factory-improvement/SKILL.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [factory, automation, improvement]
description: >-
  Self-improving factory loop for projectbluefin. Use when identifying
  automation gaps, proposing workflows, or auditing ACMM maturity.
metadata:
  type: reference
---

# Factory Improvement — Self-Improving Loop

## When to Use

- Dedicated "improve the factory" sessions
- After an architectural review surfaces gaps
- Onboarding a new repo into the factory standard
- Quarterly health check: design vs. reality drift

## When NOT to Use

- Fixing a specific bug (use the repo's AGENTS.md + relevant skill)
- Reviewing a single PR (use `hive-review` or `pr-review`)
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
| Admitting an issue to a queue (`3-human-queue` / `3-clanker-queue`) | Prioritization judgment; agent scope assignment |
| PR merge approval (1 human reviewer per CODEOWNERS) | Accountability; trust for org-critical changes |
| Release blocker calls during a promotion window | Release impact judgment |
| Production promotion decisions (Tuesday 06:00 UTC, N=7 floor) | Final go/no-go for user-facing changes |
| Reassigning or closing a stale PR | Judgment on abandoned vs. still-active work |
| Any write or automated action to `ublue-os/*` namespace | Absolute prohibition — reads only. |

Everything else is automatable.

---

## The Improvement Loop

```
MEASURE → TRIAGE → IMPLEMENT → CAPTURE → VERIFY → LOOP
```

See [`references/loop-detail.md`](references/loop-detail.md) for the full MEASURE/TRIAGE/IMPLEMENT/CAPTURE/VERIFY commands and patterns.

```bash
# Quick status
~/src/hive-status

# Everything awaiting triage
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

---

## Pipeline Uniformity Checklist

Each factory repo must have ALL of:

| Requirement | Check command |
|---|---|
| `AGENTS.md` present | `gh api repos/projectbluefin/{repo}/contents/AGENTS.md` |
| `bonedigger.yml` wired (image repos only) | `gh api repos/projectbluefin/{repo}/contents/.github/workflows/bonedigger.yml` |
| Canonical lifecycle labels present | `gh label list --repo projectbluefin/{repo} \| grep -E '1-triage\|3-clanker-queue'` |
| pre-commit config present | `gh api repos/projectbluefin/{repo}/contents/.pre-commit-config.yaml` |
| Squash-only merge | `gh repo view projectbluefin/{repo} --json squashMergeAllowed,mergeCommitAllowed` |

---

## What "Done" Looks Like

- [ ] Every factory repo has identical infrastructure (AGENTS.md, the seven labels, pre-commit, squash-only)
- [ ] Every pipeline stage has a gate: pre-merge CI, post-merge e2e, promotion smoke
- [ ] All rules exist in exactly one canonical location with one-line pointers elsewhere
- [ ] Renovate is running across all repos
- [ ] Only the human gates listed above remain manual
- [ ] ISO rebuilds are event-driven (triggered by stable promotion, not manual dispatch)
- [ ] Supply chain: keyless signing + SBOM + SLSA L2 provenance on all image builds
- [ ] Self-healing: retry + token health check on all workflows with external dependencies

---

## Red Flags

- Self-applying a queue label (triage and queue admission are human decisions)
- Maintaining gap lists or changelogs in this skill file — GitHub issues are the live backlog
- Automating any item in the Human Gates table above without explicit maintainer approval
- Using `secrets.GITHUB_TOKEN` for cross-repo dispatch (it will silently fail — see references)

---

## Verification

After each improvement session:

1. For each gap discovered: file a GitHub issue (see CAPTURE in references)
2. For significant improvements shipped: update the relevant skill file in `docs/skills/`
3. Would a fresh agent reading only the skills avoid the gap just closed? If no → the skill is still incomplete.

Always `just check` + `pre-commit run --all-files` before commit.

---

## References

| Reference | Description |
|---|---|
| [`references/loop-detail.md`](references/loop-detail.md) | Full MEASURE/TRIAGE/IMPLEMENT/CAPTURE/VERIFY commands; E2E gate matrix; documentation single-source-of-truth table |
| [`references/ci-patterns.md`](references/ci-patterns.md) | Known CI pitfalls (consumer PR format, caller permissions, workflow_run name mismatch); cross-repo dispatch patterns |
