---
name: factory-onboarding
version: "2.0"
last_updated: "2026-09-13"
id: factory-onboarding
one_line_purpose: Onboard repositories to the Project Bluefin factory model.
entry_point: docs/skills/factory-onboarding.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [factory, onboarding, setup]
description: >-
  How to onboard a repo into the Project Bluefin factory model, and the
  measured state of adoption across the org. Load when setting up a new repo
  or auditing factory compliance.
metadata:
  type: reference
---

# Factory Onboarding

This file holds the factory fixture checklist and the agent onboarding
sequence. `agentic-model.md` and `factory-improvement/SKILL.md` link here;
neither restates it.

## Agent onboarding sequence

Use this when an agent enters a factory repository:

1. Read the target repository's `AGENTS.md`. It is authoritative for local
   paths, ownership, build commands, and branch targets.
2. Read the target repository's `docs/SKILL.md` (or `.agents/skills/` router)
   and its catalog (`docs/skills/index.json` where present). Load only the
   skill pages relevant to the task.
3. Resolve the Hive assignment and GitHub issue through their APIs. Verify the
   repository, issue, branch target, and requested scope before editing.
4. Load `projectbluefin/common` as the pinned shared-contract sidecar. Common
   supplies factory-wide rules; it never overrides the target repository's
   local authority.
5. Check ownership, workflow-state labels, credential rules, and the named
   human gates. Do not simulate workflow state or bypass approval boundaries.
6. Make the smallest scoped change, validate it with the target repository's
   existing checks, and hand off the task record and evidence.

A missing catalog is degraded mode, not permission to substitute arbitrary
sibling checkouts or stale instructions.

Every loop also self-repairs: verify preconditions, treat stale or
contradictory guidance as a repair signal rather than silently falling back,
fix the closest authoritative contract when the fix is safe and source-backed,
revalidate, and record the learning. Stop for design, security,
cross-repository breakage, merge, production, or unsupported-API decisions.

## The two-output rule

Every agent session produces two outputs: the work, and the learning a future
agent needs. The learning goes in `docs/skills/` in the same PR, not a
follow-up. Output 1 without Output 2 means the factory does not improve.

Banned artifacts (changelogs, session notes, "append here" docs, local copies
of factory contracts) are enumerated in
[`agentic-model.md`](../factory/agentic-model.md#hard-rules). Delete them on
sight.

## What a factory repo needs

This is the single copy of the fixture list.

| Fixture | Purpose |
|---|---|
| `AGENTS.md` | The repo contract. Agents read it first. |
| `docs/skills/` + `docs/SKILL.md` | Knowledge base and task→skill router. Minimum: `skill-improvement.md`. |
| `docs/skills/index.json` + `just skill <query>` | Catalog and matcher CLI. |
| `.vscode/mcp.json`, `.cursor/mcp.json` | Point at `https://mcp.projectbluefin.io/mcp`. |
| `.github/copilot-instructions.md` | Thin pointer to `AGENTS.md` and nothing else. |
| `.github/copilot.yml` | Repo-tailored file exclusion and indexing. |
| `.github/workflows/copilot-setup-steps.yml` | Must live under `.github/workflows/` so Actions and Copilot Cloud Agent detect it. |
| `.github/ISSUE_TEMPLATE/` | See below. |
| `.pre-commit-config.yaml` | Developer-time convention enforcement. |

The MCP server exposes exactly three tools — `search_knowledge`,
`get_factory_status`, `get_work_queue`. Nothing else is served; do not write
code or docs against other tool names.

`AGENTS.md` must state the two-output rule, the human gates, and the banned
artifacts explicitly. Agents read `AGENTS.md` first; if it is not there, they
will not do it.

### Issue intake

`common` ships two files in `.github/ISSUE_TEMPLATE/`: `report.yml`, the single
unified intake form, and `config.yml`, the GitHub chooser configuration.
`config.yml` is not a form and is not deprecated — every repo with issue forms
needs one.

The one-form shape is not universal. `bluefin`, `dakota`, and `knuckle` each
ship five forms (`bug-report`, `config`, `feature-request`,
`help-this-project`, `pin`). `projectbluefin/.github` ships zero issue
templates and zero workflows, so there are **no org-wide inherited defaults** —
a repo with no `.github/ISSUE_TEMPLATE/` has no issue form at all.

### Skill layout and budget

Path, front-matter, and size rules live in
[`write-a-skill.md`](write-a-skill.md). Commit attribution trailers are in
[`agentic-model.md`](../factory/agentic-model.md#hard-rules).

## Downstream sidecar pinning

Downstream repositories can pin the `common` contracts they rely on. The
pattern is live in `projectbluefin/utah-packages`:

1. Place `config/factory-contract.json` in the repo:
   ```json
   {
     "repository": "projectbluefin/common",
     "commit": "<pinned-common-sha>",
     "pinned_at": "YYYY-MM-DDTHH:MM:SSZ",
     "contracts": {
       "factory-onboarding": "docs/skills/factory-onboarding.md",
       "agentic-model": "docs/factory/agentic-model.md",
       "label-workflow": "docs/skills/label-workflow.md",
       "review-appliance": "docs/skills/review-appliance.md",
       "style-guide": "docs/contributing/style-guide.md"
     }
   }
   ```
2. Check it in pre-commit and CI: validate that local `AGENTS.md`,
   `docs/SKILL.md`, and the banned-file rules still agree with upstream.
3. Advance the SHA via Renovate or a regular promotion pass.

## Measured adoption

Uniformity is a goal, not a description. Across 39 live org repositories
(archived repos excluded), measured 2026-09-13:

- **11** carry all seven workflow-state labels plus `AGENTS.md` and
  `CODEOWNERS`: `actions`, `bluefin`, `bluefin-lts`, `bluespeed`, `bonedigger`,
  `chairlift`, `common`, `dakota`, `documentation`, `iso`, `knuckle`.
- Only **5** of those also carry the `.github/copilot-instructions.md` pointer:
  `actions`, `bluefin-lts`, `chairlift`, `common`, `documentation`. The pointer,
  not the labels, is now the narrowest gap.
- **17** carry none of the seven.
- Per-label adoption is uniform at **22/39** — a repo has all seven or none,
  following the Hive label sync. See [`label-workflow.md`](label-workflow.md).
- `documentation` and `website` additionally run a `queue/*` + `needs-human/*` +
  `size:*` + `priority/p*` dialect; `lab` runs both systems at once.

Audit the specific repo before asserting what it has. See
[`label-workflow.md`](label-workflow.md) for the label authority.

## Done when

- [ ] `docs/skills/` exists with `skill-improvement.md` and a `docs/SKILL.md` router
- [ ] `AGENTS.md` states the self-improvement mandate, the human gates, and the banned list
- [ ] `.vscode/mcp.json` and `.cursor/mcp.json` point at `https://mcp.projectbluefin.io/mcp`
- [ ] `.github/copilot-instructions.md` is a thin pointer to `AGENTS.md`
- [ ] `.github/workflows/copilot-setup-steps.yml` and `.github/copilot.yml` exist
- [ ] `.github/ISSUE_TEMPLATE/` has an intake form and a `config.yml` chooser
- [ ] `just skill <query>` is wired in the `Justfile`
- [ ] The seven workflow-state labels exist on the repo
- [ ] Onboarding points agents at local authority plus common as a sidecar,
      optionally pinned via `config/factory-contract.json`
- [ ] No changelog files, session notes, or `superpowers/` plans are committed

## Cross-repo patterns

Factory-wide learning → open an issue in `projectbluefin/common` with the
learning, affected component, and evidence in the body.

Never write to `ublue-os/*`. Tell the human to report upstream manually.
