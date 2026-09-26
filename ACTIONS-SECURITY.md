# GitHub Actions Security Baseline — Project Bluefin Organization Standard

> **Status**: Normative organization standard.
> **Scope**: All repositories in `projectbluefin/*` (`common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`, `testsuite`, `server`, etc.).
> **Tracks**: [common#1036](https://github.com/projectbluefin/common/issues/1036)
> Consolidates piecemeal security hardening PRs into a single proactive baseline.

---

## 1. Context & Rationale

Across the Project Bluefin organization, workflow security has frequently been addressed reactively across multiple repositories:
- Missing permissions blocks inheriting broad ambient defaults (`common#961`, `common#969`, `bluefin-lts#505`, `bluefin-lts#511`, `dakota-iso#124`, `dakota-iso#130`).
- Floating action tags and unverified reusable workflow references (`dakota-iso#125`, `dakota-iso#126`).
- Unverified third-party release asset downloads (`actions#434`).

Per-repo, per-workflow whack-a-mole introduces continuous maintenance friction:
1. Every new workflow or repository risks repeating identical hardening oversights until a scanner flags them.
2. Maintainers and automated reviewers re-litigate the same policy boundaries (`permissions: {}`, SHA pinning, `pull_request_target`, first-party vs. third-party workflow refs) across separate pull requests.
3. New repositories lack a single normative document to conform to at creation time.

This document establishes the **Project Bluefin GitHub Actions Security Baseline**. All existing and newly created repositories within the organization must conform to the four core pillars described below.

---

## 2. The Four Security Pillars

### Pillar 1: Top-Level `permissions: {}` Fail-Closed Default & Least Privilege

**Requirement:** Every GitHub Actions workflow file (`.github/workflows/*.yml`, `*.yaml`) MUST explicitly declare `permissions: {}` at the top level, with least-privilege token permissions granted on a per-job basis.

#### Threat Model & Rationale
When a workflow omits a top-level `permissions` block, GitHub Actions assigns the workflow the repository-level default token permissions (which often defaults to read-and-write across all scopes). If a contributor, bot, or maintainer adds a new job without explicitly defining its permissions, that job automatically inherits elevated ambient write authority.

Declaring `permissions: {}` at the top level ensures a **fail-closed** security posture:
- The default `GITHUB_TOKEN` for every job in the file is completely unprivileged (`none` for all scopes).
- Any job that forgets its own `permissions` block fails immediately at runtime instead of silently executing with write access.
- Every privilege must be explicitly declared and justified in code review.

#### Standard Configuration Pattern
```yaml
name: CI Workflow

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

# Top-level fail-closed default: drops all ambient permissions
permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      contents: read # Granted only what is needed to checkout and validate
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
      - run: just check

  publish:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      contents: read
      packages: write # Scoped strictly to the job that publishes container images
    steps:
      ...
```

#### Rules
1. **Mandatory Declaration:** Every workflow file must declare top-level `permissions: {}` (or an explicit minimal top-level mapping if every job in the file shares the exact same read-only scope, e.g. `permissions:\n  contents: read`).
2. **Minimal Scopes:** Jobs must request only the minimal permissions required. Test and lint jobs must only receive `contents: read`.
3. **No Ambient Write:** Pull request validation jobs must never request `contents: write`, `packages: write`, or `id-token: write`.

---

### Pillar 2: SHA Pinning & Workflow Reference Trust Model

**Requirement:** All third-party GitHub Actions must be pinned to a full 40-character commit SHA with a human-readable version comment. First-party internal `projectbluefin/*` reusable workflows and composite actions use managed release tags (`@v1` or `@main`).

#### Threat Model & Rationale
Floating Git tags (such as `@v4`, `@main`, `@latest`) are mutable references. An attacker compromising an upstream action repository or developer account can redirect a tag to a malicious commit without alerting consumers or altering local workflow files. This malicious code runs directly inside the CI runner.

Pinning third-party actions to a 40-character commit SHA provides cryptographic immutability and reproducibility.

#### External Actions (Third-Party)
All actions from repositories outside `projectbluefin/*` MUST be pinned to a full 40-character commit SHA accompanied by a human-readable version comment:

```yaml
# Correct — 40-character SHA pin with version comment
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
uses: docker/login-action@dbcb813823bdd20940b903addbd779551569679f # v4
uses: rhysd/actionlint@03d0035246f3e81f36aed592ffb4bebf33a03106 # v1.7.7

# Forbidden — Floating tags
uses: actions/checkout@v4
uses: actions/checkout@main
uses: docker/login-action@latest

# Forbidden — Shortened commit SHAs (rejected by GitHub Actions validation)
uses: actions/checkout@3d3c42e
```

#### First-Party Actions & Reusable Workflows (`projectbluefin/*`)
All internal workflow references within the `projectbluefin` organization (`projectbluefin/actions`, `projectbluefin/bonedigger`, `projectbluefin/testsuite`) use managed release tags (`@v1` or `@main`), NOT commit SHAs.

**Why internal refs use managed tags:**
1. **Preventing Cross-Repo Update Cascades:** Pinning internal actions to individual commit SHAs creates extreme churn: every commit to `projectbluefin/actions` would require coordinated manual PRs across 10+ downstream consumer repositories.
2. **Eliminating the `startup_failure` Trap:** When a consumer workflow pins to an internal commit SHA that predated the addition of the called reusable workflow file, GitHub Actions terminates the run with an opaque `startup_failure: This run likely failed because of a workflow file issue` with no diagnostic error (see `bonedigger#27` and `dakota-iso#126`).
3. **No Unmerged PR Refs:** Workflows must NEVER reference unmerged PR head commits (`refs/pull/*/head`) or ephemeral branch tips (`aa318556... # clanker-queue-rollout`). Reusable workflows must resolve to stable release tags (`@v1`) or the upstream default branch (`@main`).

#### Automated Maintenance with Renovate
Renovate tracks pinned action SHAs across organization repositories. As policy targets:
- Digest and pin updates are tracked and verified continuously.
- Restricting minor and patch action updates to require human review and disabling automated merge is the intended security policy, tracked in `common#1074` and implemented in `common#1146`.

---

### Pillar 3: `pull_request_target` Scoping & Untrusted Code Isolation

**Requirement:** Workflows triggered by `pull_request_target` must never check out or execute untrusted code from pull request forks within a privileged runner context.

#### Threat Model & Rationale
Unlike `pull_request` from forks, the `pull_request_target` event runs in the context of the base repository (e.g. `main`), giving the runner access to repository secrets and a read/write `GITHUB_TOKEN`. Checking out untrusted PR head code (`actions/checkout` with `ref: ${{ github.event.pull_request.head.sha }}`) and running build commands, npm scripts, tests, or linters allows an untrusted fork author to execute arbitrary code with direct access to repository secrets and write tokens.

#### Mandatory Restrictions
1. **Zero Untrusted Execution:** Workflows triggered by `pull_request_target` MUST NOT execute untrusted scripts, build recipes (`just`, `make`, `Containerfile`), or package lifecycle scripts from the PR branch.
2. **Strict Metadata Scope:** `pull_request_target` is strictly reserved for lightweight repository metadata operations:
   - Issue and PR triage labeling
   - Milestone and project card assignment
   - PR title validation (Conventional Commits)
   - Automated routing and bot notifications
3. **Separation of Privileges:** Workflows executing tests, image builds, or compilation must run under the `pull_request` event (where PRs from forks have no access to repository secrets and run with read-only tokens). If a post-test privileged step is required (e.g. uploading results or publishing to a registry), use safe event separation (such as `workflow_run`) with strictly validated artifacts.

---

### Pillar 4: Release-Asset & Binary Download Checksum Verification

**Requirement:** Any workflow step or composite action that downloads external binaries, precompiled tools, or release assets MUST verify cryptographic checksums (SHA-256) before installation or execution.

#### Threat Model & Rationale
Downloading prebuilt release binaries over HTTP/HTTPS from third-party hosting without integrity verification leaves CI pipelines vulnerable to man-in-the-middle attacks, DNS spoofing, CDN compromise, or upstream asset replacement. This pattern was identified and remediated in `actions#434` for the cosign installer action.

#### Standard Implementation Pattern
1. **Pinned Checksums:** Default tool versions must have hardcoded SHA-256 checksums embedded directly in the action or workflow.
2. **Fail-Closed Verification:** Downloaded archives or binaries must be verified using `sha256sum -c` or equivalent cryptographic comparison before extraction or execution. If verification fails, the step must immediately abort (`set -euo pipefail`).
3. **Mandatory Input for Overrides:** If a custom version input is allowed (e.g. `tool-version`), the caller MUST supply an `expected-sha256` parameter. When omitted for non-default versions, the step must fail closed.
4. **Exact Cache Keys:** Runner caches for downloaded binaries must use exact keys (e.g. `${{ runner.os }}-${{ runner.arch }}-tool-${{ version }}-${{ sha256 }}`) rather than loose `restore-keys` prefixes that could restore an unverified binary from an older or mismatched release.

```bash
# Example: Cryptographic verification pattern before binary installation
set -euo pipefail
expected_sha="2d1146689b8cda280b9bc96326124645441f03bc6871dfa15f9b5cfa5e6b72d5"
curl -sSL -o tool.tar.gz "https://github.com/example/tool/releases/download/v1.0.0/tool-linux-amd64.tar.gz"
echo "${expected_sha}  tool.tar.gz" | sha256sum -c -
tar -xzf tool.tar.gz -C /usr/local/bin
```

---

## 3. Credential & Secrets Governance

All workflows must strictly adhere to the [Secrets Policy](docs/skills/secrets-policy.md):
- **Personal Access Tokens (PATs) are banned.** Workflows must use the built-in `GITHUB_TOKEN` (configured with least-privilege permissions) or provisioned GitHub Apps (e.g. `MERGERAPTOR`, `BLUEFINBOT`).
- **No New Secrets Without Security Review:** Any new repository secret requires an approved security review issue in `projectbluefin/common`.
- **No Blind Secret Inheritance:** Reusable workflow calls (`workflow_call`) must never pass `secrets: inherit` to third-party or untrusted workflows.

---

## 4. Conformance Verification & Tooling

To ensure new and existing repositories remain compliant with this baseline:

1. **Pre-commit Gate:**
   - `.pre-commit-config.yaml` runs `no-floating-action-tags` to prevent unpinned external action tags from being committed.
   - `scripts/check-actions-security.py` verifies top-level permissions declarations and action pinning.
2. **Automated CI Validation:**
   - `validate.yml` runs `pre-commit run --all-files` on all pull requests, calling `scripts/check-actions-security.py`. Conformance unit tests run locally via `Justfile` (`just test`).
3. **Cross-Repo Scanner:**
   - The shared script `scripts/check-actions-security.py` is available for inclusion in all repository CI lanes and scanner audits.

---

## 5. Reference Audit History & Remediation PRs

| Issue / PR | Repository | Hardening Class | Description |
|---|---|---|---|
| [common#961](https://github.com/projectbluefin/common/pull/961) | `common` | Pillar 1: Permissions | Added `permissions: contents: read` to `unit-tests.yml`. |
| [common#969](https://github.com/projectbluefin/common/pull/969) | `common` | Pillar 1: Permissions | Added top-level `permissions: {}` to `e2e.yml`, `pr-e2e.yml`, and `promotion-candidate-e2e.yml`. |
| [bluefin-lts#505](https://github.com/projectbluefin/bluefin-lts/pull/505) | `bluefin-lts` | Pillar 1: Permissions | Scoped `pr-testsuite.yml` permissions block. |
| [bluefin-lts#511](https://github.com/projectbluefin/bluefin-lts/pull/511) | `bluefin-lts` | Pillar 1: Permissions | Added top-level `permissions: {}` to `pr-e2e.yml`. |
| [dakota-iso#189](https://github.com/projectbluefin/dakota-iso/pull/189) | `dakota-iso` | Pillar 2: SHA Pinning | Pinned `action-shellcheck` SHA and scoped permissions in `lint.yml` (replacing closed #125). |
| [dakota-iso#169](https://github.com/projectbluefin/dakota-iso/pull/169) | `dakota-iso` | Pillar 1: Permissions | Added top-level `permissions: {}` in `test-luks-install.yml` and `test-plain-install.yml` (replacing closed #130). |
| [actions#434](https://github.com/projectbluefin/actions/pull/434) | `actions` | Pillar 4: Checksums | Added SHA-256 verification and exact cache keys to `install-cosign`. |
