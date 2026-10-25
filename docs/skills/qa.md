---
name: qa
version: "1.0"
last_updated: "2026-09-13"
id: qa
one_line_purpose: Run and understand the projectbluefin QA test coverage model.
entry_point: docs/skills/qa.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [qa, testing, issues]
description: >-
  QA model, test coverage matrix, promotion gates by repo, hardware gap, and
  how to run the test suite for projectbluefin factory repos. Use when
  understanding QA coverage, running tests, or checking promotion gate
  status.
metadata:
  type: reference
---

# QA Model — projectbluefin Factory

## Test gates by repo

Workflow filenames, read from each repo's `.github/workflows/`. These are the
checkable facts; the prose interpretation below them is not.

| Repo | Gate workflows |
|---|---|
| **common** | `validate`, `unit-tests`, `pr-e2e`, `e2e`, `promotion-candidate-e2e`, `run-testsuite`, `validate-brewfiles`, `validate-chairlift-config`, `build`, `release`, `scorecard` |
| **bluefin** | `pr-validation`, `build-image-testing`, `post-testing-e2e`, `run-testsuite`, `promote-testing-to-main`, `execute-release`, `bonedigger`, `vulnerability-scan`, `scorecard`, `nightly`, `lab-check` |
| **bluefin-lts** | `merge-queue-validate`, `unit-tests`, `pr-e2e`, `pr-testsuite`, `post-testing-e2e`, `post-testing-e2e-nvidia`, `run-testsuite`, `promote-testing-to-main`, `execute-release`, `bonedigger`, `vulnerability-scan`, `lab-check` |
| **dakota** | `validate`, `build`, `build-aarch64`, `boot-test-aarch64`, `e2e`, `publish-smoke`, `publish`, `run-testsuite`, `execute-release`, `rollback-stable`, `bonedigger`, `codeql`, `vulnerability-scan`, `scorecard` |
| **knuckle** | `ci`, `post-merge-smoke`, `vm-e2e`, `nightly`, `security`, `bonedigger`, `release` |

Only `common`'s required checks are stated anywhere in this repo — see
[`docs/TESTING.md`](../TESTING.md#coverage-targets). A workflow existing does
not mean it is required; check the ruleset before claiming a gate blocks.

The gap every repo shares: all of the above run in VMs or containers. See
"Hardware coverage gap" below.

## Known gaps

Do not maintain a gap table here — every row of the previous one pointed at an
issue that has since closed. Query instead:

```bash
gh search issues --owner projectbluefin --state open 'label:quality'
gh issue list --repo projectbluefin/common --state open --label quality
```

## Promotion

Every repo moves images `testing` → `stable` through a
`promote-testing-to-main` or `publish`/`rollback-stable` workflow, with a
post-merge e2e suite in front of it. Do not restate per-repo promotion
sequences here — they drift with every workflow edit. Read the workflow:

```bash
gh api repos/projectbluefin/<repo>/contents/.github/workflows/promote-testing-to-main.yml \
  --jq '.content' | base64 -d
```
## Hardware coverage gap

Testing-lab uses KubeVirt VMs only. The following bug classes are **invisible** to the required gate:

- Suspend/resume (ACPI S3/S0ix)
- USB-C / docks / alt-mode
- GPU power management / display hotplug
- Wi-Fi / Bluetooth / firmware
- TPM / Secure Boot / disk unlock
- Audio / webcam / microphone
- Battery / thermals / ACPI platform behavior

**Concrete example:** exo-1 (Framework 13) ucsi_acpi panic on 2026-06-01 — not caught by any current required gate.

## Running tests

| Repo | Command |
|---|---|
| **common** | `just test` (pytest + bats), then `pre-commit run --all-files`. `just check` is `just-fmt --check` only — it lints no shell, validates no YAML, and runs no test. |
| **bluefin / bluefin-lts** | `just check` |
| **dakota** | `bst show elements/...` |
| **knuckle** | `go test ./...`, `just bats` |

For common, the full testing contract — what must be tested, the exemption
list, the hardware-mock boundaries, and which checks actually gate a merge —
is [`docs/TESTING.md`](../TESTING.md). Bats authoring patterns are in
[`shell-scripts/SKILL.md`](shell-scripts/SKILL.md).

## bonedigger integration

bonedigger crash/panic detection is not wired into the promotion workflow. See [docs/skills/bonedigger/SKILL.md](bonedigger/SKILL.md).

## Setup services

`libsetup.sh`'s `version-script` idempotency guard and the `hookrunner.sh`
dispatcher shared by `ublue-system-setup`, `ublue-user-setup` and
`ublue-privileged-setup` are documented once, in
[`oem-hardware-hooks/SKILL.md`](oem-hardware-hooks/SKILL.md#the-version-script-contract).
