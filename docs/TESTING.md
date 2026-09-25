# Testing in `projectbluefin/common`

This document is the testing contract for the `common` repo. Read it before
adding a new script to `system_files/`.

## Quick Start

```bash
just test          # run full test suite (pytest + bats)
just check         # lint Justfile
pre-commit run --all-files  # hygiene checks (shellcheck, yaml, sha-pinning)
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

Profile scripts (`etc/profile.d/*.sh`) are **shellcheck-only** — they run on login
and have no testable logic beyond syntax.

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
  block directly above the recipe (e.g. `# test_x.bats is excluded — requires a
  running libvirtd session`). Drift is caught by
  [`tests/test_suite_registration.bats`](../tests/test_suite_registration.bats),
  which runs in
  [`.github/workflows/unit-tests.yml`](../.github/workflows/unit-tests.yml) on
  pull requests that touch `tests/`, `system_files/`,
  `scripts/validate-brewfiles.sh`, or the `Justfile` (that workflow's `paths`
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

Scripts exempt from behavioral testing (shellcheck-only):

| Script | Reason |
|--------|--------|
| `etc/profile.d/caffeinate.sh` | Profile.d sourced script — sets aliases only, no branching logic |
| `etc/profile.d/uutils.sh` | Profile.d sourced script — PATH manipulation only |
| `etc/profile.d/ublue-fastfetch.sh` | Profile.d sourced script — display only |
| `etc/profile.d/ublue-motd.sh` | Profile.d sourced script — display only |
| `etc/profile.d/uwelcome.sh` | Profile.d sourced script — display only; the legacy opt-out migration it carries is covered by `tests/test_motd_integration.bats` |
| `usr/share/ublue-os/bling/bling.sh` | Sourced helper — sets aliases/functions, no side effects |
| `usr/share/ublue-os/bling/env.sh` | Sourced helper — sets env vars only |
| `usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh` | One-shot hook — logic tested indirectly via setup integration tests |
| `usr/bin/ublue-motd` | Display-only wrapper — cosmetic tput/glow call, no decision logic |
| `usr/bin/ublue-image-info.sh` | Read-only reporting wrapper — jq + rpm-ostree status, no branching that affects system state |

**Adding an exemption:** add a row to this table with a one-sentence justification.
Do not add exemptions for scripts with branching logic.

## Coverage Targets

| Layer | Tool | Current target |
|-------|------|---------------|
| Python hooks | pytest-cov | 80% via `--cov-fail-under=80` gate in CI |
| Shell scripts | shellcheck | 100% of all `.sh` + `usr/bin` scripts |
| Shell behavior | bats | All `usr/bin` scripts with branching logic |

## Test Files Reference

| File | What it covers |
|------|---------------|
| `tests/test_hooks.py` | `system_files/bluefin/etc/bazaar/hooks.py` — Bazaar transaction hooks |
| `tests/test_libsetup.bats` | `libsetup.sh` — `version-script()` function |
| `tests/test_setup_scripts.bats` | `ublue-system-setup`, `ublue-user-setup`, `hookrunner.sh` — shared hook dispatcher + thin-wrapper guard |
| `tests/test_privileged_setup.bats` | `ublue-privileged-setup` — privileged hook runner logic |
| `tests/test_bling.bats` | `ublue-bling` — shell config injection install/uninstall |
| `tests/test_bling_preexec_rearm.bats` | `bling/bash-preexec-rearm.sh` — DEBUG trap re-arm with array/scalar `PROMPT_COMMAND`, idempotency, degradation when bash-preexec is absent |
| `tests/test_luks_tpm2.bats` | `luks-tpm2-autounlock` — UUID parsing, device resolution, cryptenroll flag construction |
| `tests/test_rechunker_group_fix.bats` | `rechunker-group-fix` — group/gshadow append, duplicate detection, format |
| `tests/test_bling_fastfetch.bats` | `ublue-bling-fastfetch` — all 9 accent colors, dconf/gsettings fallback chain, FASTFETCH_FORCE_THEME override |
| `tests/test_changelog.bats` | `changelog.just` — LTS/non-LTS repo selection, URL construction, exit behaviour |
| `tests/test_native_recipes.bats` | Native recipes with a leftover `bctl`: CLI setup, devmode, signed channel switching, VM setup, Flatpak bundles, and both reset confirmations |
| `tests/test_ublue_fastfetch.bats` | `ublue-fastfetch` — config reads, shuffle branch, DEFAULT_THEME export to ublue-bling-fastfetch |
| `tests/test_theming_hook.bats` | `10-theming.sh` — Framework/Thelio branches and setup idempotency |
| `tests/test_brew_preinstall.bats` | Managed Brewfile lifecycle plus user-unit ordering, resource priority, and preset delivery |
| `tests/test_validate_brewfiles.bats` | Brewfile metadata validation, tap setup failures, ambiguity diagnostics, safe argument passing, and qualified wallpaper/Zed references |
| `tests/test_brew_tap_trust.bats` | `apps.just`, `system.just`, `bazaar-hook` — `brew tap` + `brew trust` are separate commands; `brew tap --trust` is invalid (#814) |
| `tests/test_apps_just.bats` | `apps.just` — `install-opentabletdriver` pinned-download + sha256 gates (tampered payload, HTTP error, unit-before-enable ordering), install/uninstall branches, and `cncf` |
| `tests/test_image_repo.bats` | `usr/libexec/ublue-image-repo` — image-name/tag routing to upstream GitHub repos |
| `tests/test_shared_just.bats` | `shared.just` — `powerwash` (double confirmation) and `toggle-tpm2` recipes |

## Quality Epic

Ongoing test coverage improvement is tracked in [#553](https://github.com/projectbluefin/common/issues/553).
