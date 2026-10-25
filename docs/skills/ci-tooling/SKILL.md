---
name: ci-tooling
version: "2.4"
last_updated: "2026-09-13"
id: ci-tooling
one_line_purpose: Apply CI policy for SHA pinning, pre-commit, and Renovate tooling.
entry_point: docs/skills/ci-tooling/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [ci, workflows, github-actions]
description: >-
  CI policy and tooling — SHA pinning, pre-commit guards, Renovate digest
  tracking, and workflow config. Use when editing .github/workflows/ files.
metadata:
  type: reference
  context7-sources:
    - /websites/github_en_actions
    - /pre-commit/pre-commit.com
    - /sigstore/cosign
    - /containers/skopeo
    - /containers/buildah
    - /oras-project/oras
    - /anchore/syft
    - /anchore/grype
    - /aquasecurity/trivy
    - /renovatebot/renovate
    - /rhysd/actionlint
---

# CI tooling

> **Split notice (2026-06-24):** Incident-log / gotcha entries moved to [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md). Shell script authoring and testability patterns moved to [`shell-scripts.md`](../shell-scripts/SKILL.md). This file retains CI policy and configuration.

## When to Use

- Editing `.github/workflows/` or `.pre-commit-config.yaml`
- Debugging pre-commit failures around floating tags, auto-fix hooks, or schema validation
- Updating shared CI policy that propagates across factory repos
- Auditing whether a workflow change belongs in repo-local CI or `projectbluefin/actions`

## When NOT to Use

- Debugging a silent CI failure or `startup_failure` with no output → [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md)
- Writing or testing shell scripts under `system_files/` → [`shell-scripts.md`](../shell-scripts/SKILL.md)
- User-facing image content changes in `system_files/` or `Containerfile`
- Release promotion logic and stream semantics (use `release-promotion.md`)
- Issue lifecycle or queue automation (use `label-workflow.md` or bonedigger skills)
- One-off PR status checks with no reusable CI pattern to capture

---

## Core Process

1. Read the workflow or pre-commit hook before describing it; do not rely on memory.
2. Classify the ref or tool involved: external action, internal `projectbluefin/*` reusable, schema validator, or local hook.
3. For workflow steps that call repo-local entrypoints such as `just check`, read the full dependency chain and install every clean-runner dependency in that workflow before the step.
4. Keep `just check` hermetic. A check that reaches a third-party host belongs in its own workflow with a path filter and a cron, not in the repo-wide gate — otherwise someone else's outage reddens every open PR and the merge queue, and offline contributors cannot commit. Enforce this over the whole recipe **closure** — header, body, and every recipe `check` depends on — not the header line alone; `tests/test_chairlift_config.py::test_just_check_stays_hermetic` does this and carries mutation tests proving it. Keep workflow/job permissions minimal (`contents: read` unless more is required); GitHub Actions supports step-level `env` and workflow/job `permissions`, source: `/websites/github_en_actions`.
5. Apply the policy in this order: artifact-protecting CI gates first, agent-enforced process conventions second.
6. Run the lightest verification that matches the change (`pre-commit`, `actionlint`, or direct source inspection).
7. If the session uncovered a non-obvious CI trap, write it to [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md) in the same change. If it's a shell authoring/testability pattern, write it to [`shell-scripts.md`](../shell-scripts/SKILL.md).

---

## SHA pinning policy

**Every `uses:` reference in `.github/workflows/` is pinned to a full 40-character commit SHA with a version comment — external and internal alike.** Floating tags (`@v4`, `@main`, `@latest`) are rejected by the `no-floating-action-tags` pre-commit hook.

```yaml
# correct — full SHA + human-readable version comment
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
uses: projectbluefin/actions/bootc-build/scan-image@e2ccd51b41d9bb3abd9caeac626fb15c95589c3c # v1

# rejected by pre-commit
uses: actions/checkout@v4
uses: actions/checkout@main
```

The hook exempts `projectbluefin/*`, but **nothing in this repo uses that exemption** — both internal refs are SHA pins that Renovate digest-tracks. See [sha-pinning.md](references/sha-pinning.md) for the pin inventory and the one outstanding inconsistency (`projectbluefin/actions`'s own README still advertises `@v1`).

---

## Which workflows exist

Twelve files in `.github/workflows/`, enumerated with triggers and jobs in
[workflow-map.md](../workflow-map.md). That table is the single source; do not
restate it here. Confirm against the checkout before trusting any list:

```bash
ls .github/workflows/
```

---

## Pre-commit conventions

- Auto-fix hooks **modify files and abort the commit**. Re-stage changed files and rerun before retrying.
- AI-authored commits should carry both trailers (`Assisted-by:` + `Co-authored-by: Copilot`) — convention only, not a CI gate.
- Four `language: system` docs-hygiene hooks guard the skill tree. Two other hooks select nothing here: `check-jsonschema` is scoped to `.github/release-state.yaml`, which does not exist in `common`, and the `projectbluefin/*` arm of `no-floating-action-tags` matches no ref.

See [pre-commit-conventions.md](references/pre-commit-conventions.md) for the auto-fix loop, AI attribution, the full hook table, and the two no-op hooks.

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "pre-commit fixed it, so the commit probably succeeded." | Auto-fix hooks modify files **and fail the run**; re-stage the files and rerun the hooks. |
| "The `# v1` comment after the SHA means the ref floats." | It is a comment. The ref is the 40-char SHA before it; a bump requires a commit. |
| "This is only a process convention, so CI details are not worth documenting." | Factory CI policy is shared infrastructure; undocumented traps get rediscovered across multiple repos. |
| "I know what this workflow publishes." | Read the workflow file. Project-internal CI facts drift faster than model memory. |

## Red Flags

- A commit fails with `Files were modified by this hook` and you retry without `git add`-ing the changed files
- A Renovate config change is made in `.github/renovate.json5` — that file is dead; root `renovate.json` wins precedence
- A doc about CI policy describes current workflow behavior without quoting or deriving it from source
- A silent `startup_failure` is attributed to "GitHub being flaky" without checking caller `permissions:` or branch-from-target → see [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md)

## Verification

- [ ] Read the workflow or hook being documented, not a secondary doc
- [ ] If pre-commit modified files, review the diff and re-stage them before retrying
- [ ] For `.github/workflows/` changes, run `pre-commit run --all-files` and `actionlint .github/workflows/*.yml`
- [ ] For doc-only CI skill updates, verify the examples and regexes against the current repo files they describe
- [ ] If a named tool's behavior matters (for example `pre-commit`, `trivy`, `shellcheck`), verify it against Context7 and record the library ID in frontmatter
- [ ] If the trap belongs in the incident log, put it in [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md), not here
- [ ] If the pattern is about shell authoring or testability, put it in [`shell-scripts.md`](../shell-scripts/SKILL.md), not here

## References

| File | Description |
|---|---|
| [references/sha-pinning.md](references/sha-pinning.md) | The pin inventory (external and internal), how to find/update SHAs, the floating-tag guard's real scope, and the `projectbluefin/actions` `@v1` inconsistency. |
| [references/pre-commit-conventions.md](references/pre-commit-conventions.md) | Auto-fix loop, AI commit attribution, the four docs-hygiene hooks, the two no-op hooks, skill-drift retirement. |
| [references/renovate-and-tools.md](references/renovate-and-tools.md) | Which Renovate config governs, the four Containerfile OCI pins, Trivy scan-image archive input, multi-arch build matrix, shellcheck in validate.yml. |
