---
name: ci-tooling
version: "2.4"
last_updated: "2026-09-26"
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

## When to Use

- Editing `.github/workflows/` or `.pre-commit-config.yaml`
- Debugging pre-commit failures around floating tags, auto-fix hooks, or schema validation
- Updating shared CI policy that propagates across factory repos
- Auditing whether a workflow change belongs in repo-local CI or `projectbluefin/actions`

## Core Process

1. Read the workflow or pre-commit hook before describing it; do not rely on memory.
2. Classify the ref or tool involved: external action, internal `projectbluefin/*` reusable, schema validator, or local hook.
3. For workflow steps that call repo-local entrypoints such as `just check`, read the full dependency chain and install every clean-runner dependency in that workflow before the step.
4. Keep `just check` hermetic. A check that reaches a third-party host belongs in its own workflow with a path filter and a cron, not in the repo-wide gate — otherwise someone else's outage reddens every open PR and the merge queue, and offline contributors cannot commit. Enforce this over the whole recipe **closure** — header, body, and every recipe `check` depends on — not the header line alone; `tests/test_chairlift_config.py::test_just_check_stays_hermetic` does this and carries mutation tests proving it. Keep workflow/job permissions minimal (`contents: read` unless more is required); GitHub Actions supports step-level `env` and workflow/job `permissions`, source: `/websites/github_en_actions`.
5. Apply the policy in this order: artifact-protecting CI gates first, agent-enforced process conventions second.
6. Run the lightest verification that matches the change (`pre-commit`, `actionlint`, or direct source inspection).
7. Update the relevant reference only when a CI constraint or useful workaround changes; routine fixes need no documentation edit.

---

## Required-check reachability

A workflow that provides a ruleset-required status check must not use
`pull_request` `paths` or `paths-ignore`: excluded PRs never schedule the
workflow, leaving the required check pending. Keep `merge_group` enabled for
merge-queue refs. To avoid expensive builds on documentation-only changes,
detect changed inputs in a preceding job and skip build steps rather than the
required jobs themselves. If change detection fails, default to running the
build.

---

## SHA pinning policy

**All third-party `uses:` references must be pinned to a full commit SHA with a version comment.** Floating tags (`@v4`, `@main`, `@latest`) are rejected by the pre-commit hook.

```yaml
# correct — full SHA + human-readable version comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4

# rejected by pre-commit
uses: actions/checkout@v4
uses: actions/checkout@main
```

### Internal refs

**Internal `projectbluefin/` refs use managed floating tags (`@main` or `@v1`), not SHA pins — with one documented exception: common's own `run-testsuite.yml` testsuite pin.** The `no-floating-action-tags` hook exempts all `projectbluefin/` refs. See [sha-pinning.md](references/sha-pinning.md) for the full policy, the testsuite exception, and Floating-tag guard details.

---

## Python tool pinning

Install Python tools in workflows with `pip install --require-hashes
--only-binary=:all: -r tests/requirements.txt`. Direct requirements live in
`tests/requirements.in` with an exact `==` version. `tests/requirements.txt`
is generated from that file with `uv pip compile --universal --python-version
3.12 --generate-hashes --output-file tests/requirements.txt
tests/requirements.in` and Renovate regenerates it on every update, so every
package -- including transitive dependencies -- is locked to an exact version
with a checksum. Pin a tool by editing `tests/requirements.in` and regenerating.

Renovate manages `tests/requirements.txt` through its `pip-compile` manager
(`pip_requirements` is disabled so the file is not updated twice). New
installer forms or shell wrappers need matching guard fixtures.

`tests/test_python_install_pins.py` checks workflow `run` steps and the root
Justfile for `pip`, `pip3`, and `python -m pip` installs, following requirements
files recursively. It rejects loose versions, missing files, and cycles.
The unit-test workflow runs it on workflow changes, and `just test` runs it
locally.

---

## Pre-commit conventions

- Auto-fix hooks **modify files and abort the commit**. Re-stage changed files and rerun before retrying.
- AI-authored commits should carry both trailers (`Assisted-by:` + `Co-authored-by: Copilot`) — convention only, not a CI gate.
- `.github/release-state.yaml` is validated with `check-jsonschema` against the pinned schema in `projectbluefin/actions`.

See [pre-commit-conventions.md](references/pre-commit-conventions.md) for auto-fix handling, attribution, release-state validation, and the shipped agent bundle.

---

## Documentation and shipped skills

Documentation formatting and skill-update bookkeeping are not CI gates.
`check-agent-bundle` runs `python3 scripts/generate_skill_index.py --check`
because the on-device bundle ships in the image. After changing a skill marked
`scope: on-device`, regenerate it with `--write`. Other docs need no catalog,
compulsory split, or generated-copy update.

---

## Verification

- [ ] Read the workflow or hook being documented, not a secondary doc
- [ ] If pre-commit modified files, review the diff and re-stage them before retrying
- [ ] For `.github/workflows/` changes, run `pre-commit run --all-files` and `actionlint .github/workflows/*.yml`
- [ ] For doc-only CI skill updates, verify the examples and regexes against the current repo files they describe
- [ ] Verify external API details in question against current upstream documentation.

## References

| File | Description |
|---|---|
| [ACTIONS-SECURITY.md](../../../ACTIONS-SECURITY.md) | Organization GitHub Actions security baseline (top-level `permissions: {}`, SHA pinning, `pull_request_target` scoping, checksum verification). |
| [references/sha-pinning.md](references/sha-pinning.md) | Full SHA pinning policy, how to find/update SHAs, internal refs, Floating-tag guard regex and exemptions, Renovate vs pre-commit. |
| [references/pre-commit-conventions.md](references/pre-commit-conventions.md) | Auto-fix handling, attribution, release-state validation, and the shipped agent bundle. |
| [references/renovate-and-tools.md](references/renovate-and-tools.md) | Renovate OCI digest tracking, Renovate Actions coverage outside `.github/workflows`, fork processing in the org runner, Trivy scan-image archive input, multi-arch build matrix, Shellcheck in validate.yml, Renovate versioned-binary tracking. |
