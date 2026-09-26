---
name: shell-scripts
version: "1.2"
last_updated: "2026-09-23"
id: shell-scripts
one_line_purpose: Write and test shell scripts under system_files/.
entry_point: docs/skills/shell-scripts/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [shell, bash, testing, bats, shellcheck]
description: >-
  Shell script authoring and testability. Use when writing or testing shell
  scripts under system_files/, removing scripts, or adding bats tests.
metadata:
  type: reference
  context7-sources:
    - /koalaman/shellcheck
    - /bats-core/bats-core
---

# Shell Scripts — authoring and testability

> Split from [`ci-tooling.md`](../ci-tooling/SKILL.md) on 2026-06-24. This file holds shell script authoring patterns, testability idioms, and the mandatory touch-points when removing a script. [`ci-tooling.md`](../ci-tooling/SKILL.md) retains CI policy and config; [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md) retains the incident log.

<!-- TODO(context7): verify shellcheck directive syntax (SC1072/SC1073, SC1091, SC2148, SC2207) and bats setup/teardown semantics against upstream docs. These were documented from live test debugging, not from Context7 lookups. -->

## When to Use

- Writing or modifying a shell script under `system_files/`
- Writing bats tests for a shell script
- Debugging a shellcheck failure in validate.yml
- Removing a shell script from common (the 4 mandatory touch-points)

## When NOT to Use

- CI workflow configuration (pre-commit, actionlint, SHA pinning) → [`ci-tooling.md`](../ci-tooling/SKILL.md)
- CI incident log and silent failure patterns → [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md)

---

## Removing a shell script from common — 4 mandatory touch-points

When deleting `system_files/bluefin/usr/bin/<script>`, check all four:

| File | What to remove |
|---|---|
| `.github/workflows/unit-tests.yml` | The script path from the shellcheck `run:` block |
| `.github/workflows/validate.yml` | The `shellcheck` step that invokes it (if script-specific) **and** any `candidates.append(Path("..."))` entry in the Python OCI-ref guard |
| `system_files/bluefin/usr/share/ublue-os/just/system.just` | The `just` target and all aliases |
| `docs/skills/` | The script's skill file (if it has one) + its `docs/SKILL.md` routing row and any related skill links + all cross-references |

### Dead apt step hazard

If the `validate.yml` shellcheck step was the **only** consumer of `Install shellcheck` in that job, delete the apt install step too — it becomes a silent no-op that wastes ~20 seconds per CI run and confuses future readers.

### Cross-reference sweep

After deleting the script and its skill file, run:
```bash
grep -rn "<script-name>" docs/ specs/ --include="*.md" --include="*.json"
```
Common survivors: `devmode.md` advisories, `image-registry.md` section headers, `specs/` JSON chunks.

---

## Core Testability Idioms

Quick reference — full patterns with WRONG/CORRECT examples in
[references/testability-patterns.md](references/testability-patterns.md).

| Pattern | Summary |
|---|---|
| `BASH_SOURCE` main guard | Wrap main flow so `source` in bats only loads functions |
| `${VAR:-default}` override | Make every `/proc`, `/dev`, `/usr/share` path overridable |
| PATH-stub mocking | Drop executable stubs into `${WORKDIR}/bin`, prepend to `PATH` |
| XDG_CONFIG_HOME isolation | `unset XDG_CONFIG_HOME` in `setup()` alongside `export HOME=...` |
| stdin redirect override | Use `${IMAGE_INFO_FILE:-/path}` so bats can inject a fixture |
| Subshell export check | Instrument the `$(...)` call, not the exec'd process |
| Guard optional commands | `command -v foo >/dev/null` before doing work |
| `NO_COLOR` propagation | Disable ANSI from both the script and subprocesses; assert captured output has no ESC bytes |

## Bats Test Structure

Standard file layout, mocking, and pitfalls in
[references/bats-patterns.md](references/bats-patterns.md).

## Shellcheck Reference

Directive syntax, SC code notes, and quoting fix examples in
[references/shellcheck-examples.md](references/shellcheck-examples.md).

---

## Red Flags

- A shell script reads from a hardcoded `/proc`, `/dev`, or `/usr/share/...` path without an env-var override — untestable in CI
- A bats test overrides `HOME` but not `XDG_CONFIG_HOME` — leaks to the real runner config dir
- A shellcheck `disable=` directive has an inline comment after it (SC1072/SC1073)
- A script's main flow runs on `source` (no `BASH_SOURCE` guard) — breaks bats loading
- `--cov=tests` in a pytest invocation — measures test files, not source under test

---

## Verification

- [ ] `shellcheck -S warning <file>` passes on the modified script
- [ ] `just test` passes locally (bats + pytest)
- [ ] If a shellcheck directive was added, verify its syntax against Context7 (shellcheck library) and confirm the SC code is correct
- [ ] If a bats test uses env-var overrides, confirm the script uses `${VAR:-default}` at the read site — the override does nothing without it
- [ ] If a script was removed, all 4 touch-points were checked and the cross-reference sweep returned no survivors

---

## References

| File | Contents |
|---|---|
| [references/testability-patterns.md](references/testability-patterns.md) | All testability patterns with full WRONG/CORRECT code examples |
| [references/bats-patterns.md](references/bats-patterns.md) | Standard bats file structure, mocking, and assertion pitfalls |
| [references/shellcheck-examples.md](references/shellcheck-examples.md) | Shellcheck directive syntax, SC codes, and quoting fix examples |

## Opt-in hibernation setup

`ujust hibernation [enable|disable|status]` (alias `toggle-hibernation`) calls
Bluefin's `/usr/libexec/bluefin-hibernation`. With no argument it prompts.
This is opt-in: installing the image does not create swap or change sleep.

The helper requires Btrfs under `/var`, writable UEFI variables, kernel
hibernation support, and `mkswap --file`. It refuses an existing `/var/swap`,
resume kernel arguments, or conflicting recipe-owned paths. Swap size rounds
up to whole GiB: twice RAM below 2 GiB, 1.5 times below 8 GiB, otherwise RAM.
The dedicated `var-swap-swapfile.swap` unit persists activation without editing
fstab. No kernel arguments, SELinux policy, Secure Boot settings, GNOME
settings, or `uupd-resume.timer` are changed.

GNOME retains its AC/battery idle timeouts. On GNOME installations, a drop-in
makes `systemd-suspend.service` perform suspend-then-hibernate; this also affects
other callers of that service. Lid handling uses logind's normal inhibitor and
docked/external-power behavior. The recipe sets a 60-minute hibernation delay,
but does not change the power button or logind idle policy. Reboot after either
enabling or disabling to apply logind configuration without restarting sessions.

Ownership lives in `/var/lib/bluefin-hibernation`; configuration uses
`60-bluefin-hibernation.conf` drop-ins. `status` reports `disabled`, `enabled`,
or `incomplete` for the recipe's setup, not a guarantee of hardware resume.
After interrupted setup, run `disable` before retrying `enable`. Cleanup must
stop swap successfully before deleting it and must refuse unrelated files in
the subvolume. Never replace that check with recursive deletion. Keep setup
and cleanup serialized with the same lock.

Tests in `tests/test_hibernation.bats` mock privileged operations. Hardware
validation still requires an updated Bluefin UEFI/Btrfs system with a working
systemd resume generator in its initramfs: save work, enable, reboot, verify
`systemctl hibernate` resumes, then test GNOME idle suspend on AC/battery and
lid close through the delay. Check encrypted storage unlock and GPU resume on
the actual machine. Disable, reboot, and verify original suspend behavior and
unrelated configuration survive. Do not weaken kernel lockdown or SELinux if
capability checks fail; inspect the journal instead.

Documentation checked through Context7: `/systemd/systemd` (HibernateLocation,
sleep configuration), `/kdave/btrfs-progs` (Swapfile and map-swapfile),
`/util-linux/util-linux` (mkswap), `/casey/just` (recipe parameters), and
`/bats-core/bats-core` (run assertions). Primary references:

- [systemd resume generator](https://github.com/systemd/systemd/blob/main/man/systemd-hibernate-resume-generator.xml): automatic EFI resume discovery.
- [systemd swap units](https://github.com/systemd/systemd/blob/main/man/systemd.swap.xml): path-derived names and automatic mount dependencies.
- [Btrfs swapfile requirements](https://github.com/kdave/btrfs-progs/blob/devel/Documentation/Swapfile.rst): `map-swapfile` validates layout before activation.
- [mkswap implementation](https://github.com/util-linux/util-linux/blob/master/disk-utils/mkswap.c): labels the swapfile `swapfile_t`; do not undo that with `restorecon` on the file.
