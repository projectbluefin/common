# Testing in `projectbluefin/common`

This document is the testing contract for the `common` repo. Read it before
adding a script to `system_files/` or a test to `tests/`.

## Quick Start

```bash
just test                   # runs all wired pytest and bats suites
just check                  # just-fmt --check on the Justfile and every *.just
just fix                    # just-fmt, writing in place
pre-commit run --all-files  # shellcheck, yaml, sha-pinning, skill-index gates
```

`just check` only formats-checks just syntax. It runs no linter and no
validator — `pre-commit` and `just test` are the real gates.

`just check-brewfiles` and `just check-chairlift-config` are networked and
deliberately outside `check`. `check-brewfiles` syncs and trusts the taps
declared by the shared Brewfiles but installs nothing; use a disposable
Homebrew prefix locally. Its offline regression suite is
`bats tests/test_validate_brewfiles.bats`.

## What Must Be Tested

### Rule: new executable in `system_files/*/usr/{bin,libexec}/` → new test file in `tests/`

Both directories ship executables. `usr/bin/` holds the user-facing entry
points (`ujust`, `ublue-fastfetch`, the three setup wrappers); `usr/libexec/`
holds helpers invoked by systemd units, polkit actions, or other scripts
(`bluefin-countme`, `ublue-image-repo`, `bonedigger-report`).
Neither is exempt by location.

Every executable added to either directory must have either:

1. A `tests/test_<name>.bats` (or `.py`) file covering its branching logic, or
2. A row in the Exemptions table below with a one-sentence justification.

Add the new bats file to the `test` recipe in the `Justfile` in the same
change. A test file that is not in the recipe never runs — `tests/test_image_repo.bats`
is the live example of that failure mode.

## Test Frameworks

| Language | Framework | File pattern |
|----------|-----------|-------------|
| Shell | [bats-core](https://bats-core.readthedocs.io/) | `tests/test_*.bats` |
| Python | pytest | `tests/test_*.py` |

**Do not introduce additional frameworks.** `bats` for shell, `pytest` for Python.

## Hardware Gate Boundary

Nothing in CI has real hardware. Every hardware dependency is crossed by a
mocked boundary, and the fixture shape is part of the contract:

| Dependency | Scripts | Fixture used by the tests |
|---|---|---|
| DMI vendor/product strings | `10-framework.sh`, `11-asus.sh`, `10-theming.sh`, `20-oem-brew.sh` | `SYSROOT` prefix over a fake `sys/devices/virtual/dmi/id/` tree |
| TPM2 chip | `luks-tpm2-autounlock` | PATH stubs for `systemd-cryptenroll` and `gum`; full integration lives in `projectbluefin/testsuite` |
| GeoClue2 over D-Bus | `get-geoclue-latitude`, `bluefin-dynamic-wallpaper` | PATH stub for `gdbus` returning realistic GeoClue2 property strings |
| NVIDIA kernel module | `ublue-nvidia-flatpak-runtime-sync` | `NVIDIA_VERSION_FILE` pointed at a fixture instead of `/sys/module/nvidia/version` |
| Booted bootc deployment | `bluefin-countme`, `ublue-image-info.sh` | `IMAGE_INFO_FILE` / `BOOTED_IMAGE_FILE` overrides plus a `bootc` PATH stub |
| Interactive TTY | any script calling `gum` | PATH stub for `gum` |

**Never block CI on hardware.** Every one of those boundaries exists because
the script reads its hardware fact through a `${VAR:-default}` override. Keep
that pattern; see [`docs/skills/shell-scripts/SKILL.md`](skills/shell-scripts/SKILL.md).

## Bats patterns and testability idioms

Shell-specific bats patterns live in [`docs/skills/shell-scripts/SKILL.md`](skills/shell-scripts/SKILL.md).

## Exemptions

Executables and sourced scripts with no branching logic, shellcheck-only:

| Path | Reason |
|---|---|
| `shared/etc/profile.d/ublue-fastfetch.sh` | Four lines — guards on an interactive shell and calls `ublue-fastfetch`. The callee is covered by `tests/test_ublue_fastfetch.bats`. |
| `shared/usr/libexec/bootc-update-stage` | A single `exec /usr/bin/bootc upgrade` with no arguments, no flags, and no branches. Its contract (ignore caller arguments, never pass `--apply`/`--download-only`/`--from-downloaded`) is a review rule, not a runtime branch. |
| `shared/usr/share/fish/vendor_conf.d/*.fish` | Fish shell config fragments; `bats` cannot source fish. `fish_greeting.fish` is exercised indirectly by `tests/test_motd_integration.bats`. |

**Adding an exemption:** add a row with a one-sentence justification. Do not
exempt anything that branches.

## Coverage Targets

- Bazaar hook and config unit tests run `--cov-fail-under=80` in `unit-tests.yml` (covering Bazaar files only; remaining pytest files are not evaluated under this threshold). Because `unit-tests` is not a required check on `main`, this gate can fail a CI job without blocking the merge queue.
- `codecov.yml` targets (project 70% / patch 50%) are never evaluated because nothing in this repo uploads to Codecov.
- The `Justfile` test recipe invokes pytest with `--cov=tests`, measuring test files rather than code under test; treat local coverage percentages as noise.

### Shellcheck Gates

- `validate.yml` shellchecks shell scripts in `system_files` with `-e SC2207`.
- Extensionless helper scripts in `usr/libexec/` (`bluefin-countme`, `ublue-image-repo`, `bootc-update-stage`, `bonedigger-report`, and `ensure-libvirt-session-config`) are not matched by `*.sh` globs and are not shellchecked in CI; verify them with `shellcheck` manually when editing.

## Test Inventory Derivation

Do not maintain hardcoded test count tables. Re-derive live test coverage and recipe wiring directly from the repository tree:

```bash
# Count total test files
ls tests/test_*.bats tests/test_*.py | wc -l

# List bats files not wired into Justfile test recipe
comm -13 <(grep -oE 'tests/test_[a-z_]+\.bats' Justfile | sort -u) \
         <(ls tests/test_*.bats | sort)
```

Exceptions to keep in mind:
- `tests/test_image_repo.bats`: not wired into any recipe or workflow; it never runs.
- `tests/test_libvirt_helper.bats`: excluded from `just test` because it requires a running libvirtd session.
