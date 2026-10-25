---
name: factory-improvement
version: "2.0"
last_updated: "2026-09-13"
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

Automate what does not require a human judgment call, and leave the rest
visibly manual. Every manual step that *could* be automated is a reliability
tax; every automated step that should have been a judgment call is a liability.

---

## Human Gates — Intentional and Non-Negotiable

Never automate these. Never propose automating them without explicit maintainer approval:

| Gate | Why it must be human |
|---|---|
| Admitting an issue to a queue (`3-human-queue` / `3-clanker-queue`) | Prioritization judgment; agent scope assignment |
| PR merge approval | Accountability. In `common` the ruleset requires 2 approving reviews; CODEOWNERS assigns reviewers but does not gate the merge. See [`governance.md`](../governance.md#how-main-is-protected) |
| Release blocker calls during a promotion window | Release impact judgment |
| Production promotion decisions | Final go/no-go for user-facing changes. Schedules are in [`agentic-model.md`](../../factory/agentic-model.md#release-cadences) |
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
# Everything awaiting triage
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

The `projectbluefin` MCP tools `get_factory_status()` and `get_work_queue()`
return live hub health, contributor counts, and triage buckets without
authentication.

---

## Pipeline Uniformity Checklist

The agentic fixture list (AGENTS.md, `mcp.json`, `copilot-instructions.md`,
`copilot.yml`, `copilot-setup-steps.yml`, issue intake, skill catalog) lives
once in
[`factory-onboarding.md`](../factory-onboarding.md#what-a-factory-repo-needs).
Do not restate it here.

This skill adds only the checks that need a live API call.

**Every factory repo:**

| Requirement | Check command |
|---|---|
| `AGENTS.md` present | `gh api repos/projectbluefin/{repo}/contents/AGENTS.md` |
| Workflow-state labels present | `gh label list --repo projectbluefin/{repo} \| grep -E '1-triage\|3-clanker-queue'` |
| pre-commit config present | `gh api repos/projectbluefin/{repo}/contents/.pre-commit-config.yaml` |
| Merge methods match the repo's stated model | `gh repo view projectbluefin/{repo} --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` |

**Image repos only** (`bluefin`, `bluefin-lts`, `dakota`, `knuckle`):

| Requirement | Check command |
|---|---|
| `bonedigger.yml` wired | `gh api repos/projectbluefin/{repo}/contents/.github/workflows/bonedigger.yml` |

`common`, `actions`, and `testsuite` have no `bonedigger.yml` by design — they
do not produce an image that files `ujust report` issues.

Adoption is partial and measured, not assumed: of 39 live org repos, 11 carry
all seven workflow-state labels plus `AGENTS.md` and `CODEOWNERS`, 17 carry
none, and only 5 carry the `.github/copilot-instructions.md` pointer as well.
Audit before asserting uniformity.

## The largest unwired mechanism

`projectbluefin/actions` ships
`.github/workflows/reusable-design-enforcement.yml` ("Enforce the seven-label
issue and review workflow"). It is the only automation in the org that
implements the label contract, and exactly one repository calls it —
`projectbluefin/finpilot/.github/workflows/label-enforcement.yml`. Not
`bluefin`, not `dakota`, not `common`.

```bash
gh search code --owner projectbluefin "reusable-design-enforcement" \
  --json repository,path
```

Adopting it is a one-file change per repo. Every other label rule in these
docs is a convention nothing checks.

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

Run `just check` and `pre-commit run --all-files` before commit.

---

## References

| Reference | Description |
|---|---|
| [`references/loop-detail.md`](references/loop-detail.md) | Full MEASURE/TRIAGE/IMPLEMENT/CAPTURE/VERIFY commands; E2E gate matrix; documentation single-source-of-truth table |
| [`references/ci-patterns.md`](references/ci-patterns.md) | Known CI pitfalls (consumer PR format, caller permissions, workflow_run name mismatch); cross-repo dispatch patterns |
