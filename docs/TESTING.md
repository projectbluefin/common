# Testing in `projectbluefin/common`

This document is the testing contract for the `common` repo. Read it before
adding a new script to `system_files/`.

## Quick Start

```bash
just test          # run full test suite (pytest + bats)
just check         # lint Justfile
pre-commit run --all-files  # docs/config hygiene; CI runs shellcheck separately
```

`just check-brewfiles` is a separate networked check against real Homebrew
metadata. It syncs/trusts taps declared by the shared Brewfiles, but does not
install formulae or casks. Use a disposable Homebrew environment when testing
it locally. Its offline regression suite is `bats tests/test_validate_brewfiles.bats`.

## What Must Be Tested

### Rule: new script in `system_files/*/usr/bin/` → new test file in `tests/`

Every script added to `system_files/*/usr/bin/` must have either:
1. A `tests/test_<scriptname>.bats` file covering its branching logic, OR
2. A documented exemption in this file explaining why tests are not feasible.

Profile scripts with branching behavior need tests too; only pure alias or
environment declarations can be exempted from behavioral coverage.

## Test Frameworks

| Language | Framework | File pattern |
|----------|-----------|-------------|
| Shell scripts | [bats-core](https://bats-core.readthedocs.io/) | `tests/test_*.bats` |
| Python hooks | pytest | `tests/test_*.py` |

**Do not introduce additional frameworks.** `bats` for shell, `pytest` for Python.

## Integration Contract

A test that nothing runs is noise, not coverage. Every suite in `tests/` must
be wired to a runner, and that wiring is **enforced in CI** — not left to
whoever remembers to add it.

- **Every `tests/test_*.bats` / `tests/test_*.py` must be named in the Justfile
  `test` recipe, or declared excluded** with a one-line reason in the comment
  block directly above the recipe (e.g. `# test_x.bats is excluded — requires
  hardware not present in CI`). Drift is caught by
  [`tests/test_suite_registration.bats`](../tests/test_suite_registration.bats),
  which runs in
  [`.github/workflows/unit-tests.yml`](../.github/workflows/unit-tests.yml) on
  pull requests that touch `tests/`, `system_files/`,
  `scripts/`, the `Justfile`, or the workflow itself (that workflow's `paths`
  filter). Adding or renaming a suite means editing the runner and the gate
  together — the gate failing is the signal that you forgot one of them.
- **Never reference a suite that does not exist.** A dangling runner line makes
  the whole `just test` recipe fail.
- **Permanently-red tests are prohibited.** A test that always fails (e.g. one
  that stamps `date.today()` and compares against "today") trains everyone to
  ignore failures. Fix it or remove it — do not commit a known-red suite.

This is the org-wide convention called for in [projectbluefin/common#1046](https://github.com/projectbluefin/common/issues/1046):
a nightly cross-repo job that flags test files matched by no runner is **proposed**
in [`projectbluefin/actions`](https://github.com/projectbluefin/actions) so every
factory repo inherits it; this section is the `common`-side statement of the
same contract.

## Hardware Gate Boundary

Some scripts interact with hardware that cannot be present in CI:

| Script | Hardware dependency | Test boundary |
|--------|--------------------|--------------------|
| `luks-tpm2-autounlock` | TPM2 chip | Test UUID parsing, device resolution, flag construction. Mock `gum` and `systemd-cryptenroll` via PATH. Full integration: `projectbluefin/testsuite`. |
| Any script using `gum` | Interactive TTY | Mock `gum` via PATH stub in `tests/` setup. |

**Never block CI on hardware.** Extract hardware-dependent calls behind mocked
system boundaries.

## Bats patterns and testability idioms

Shell-specific bats patterns live in [`docs/skills/shell-scripts/SKILL.md`](skills/shell-scripts/SKILL.md).

## Exemptions

`system_files/shared/etc/profile.d/ublue-fastfetch.sh` only defines aliases;
shellcheck is sufficient. Add an exemption here only for an existing script
without branching behavior, with a one-sentence reason.

## Coverage Targets

| Layer | Tool | Current target |
|-------|------|---------------|
| Python hooks | pytest-cov | 80% via `--cov-fail-under=80` gate in CI |
| Shell scripts | shellcheck | CI checks `.sh` scripts and the explicitly listed extensionless setup scripts |
| Shell behavior | bats | All `usr/bin` scripts with branching logic |

## Test inventory

The `tests/` directory and `just test` recipe are the source of truth for
registered suites. Do not maintain a second file-by-file test list here.
