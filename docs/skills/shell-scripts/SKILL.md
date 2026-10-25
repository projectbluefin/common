---
name: shell-scripts
version: "1.1"
last_updated: "2026-09-13"
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

This file holds shell script authoring patterns, testability idioms, and the
mandatory touch-points when removing a script. [`ci-tooling.md`](../ci-tooling/SKILL.md)
holds CI policy and config; [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md) holds the
incident log.

## When to Use

- Writing or modifying a shell script under `system_files/`
- Writing bats tests for a shell script
- Debugging a shellcheck failure in validate.yml
- Removing a shell script from common (the 4 mandatory touch-points)

## When NOT to Use

- CI workflow configuration (pre-commit, actionlint, SHA pinning) → [`ci-tooling.md`](../ci-tooling/SKILL.md)
- CI incident log and silent failure patterns → [`ci-pitfalls.md`](../ci-pitfalls/SKILL.md)

---

## Removing a shell script from common — the mandatory touch-points

Executables live in two places per layer, and neither is `usr/bin/` only:

- `system_files/shared/usr/bin/` — 11 user-facing entry points
- `system_files/shared/usr/libexec/` — 4 helpers invoked by units and polkit
- `system_files/bluefin/usr/libexec/` — 5 Bluefin-only helpers
- `system_files/nvidia/usr/libexec/` — 1

There is no `system_files/bluefin/usr/bin/`. When deleting any of the above,
check all five:

| File | What to remove |
|---|---|
| `Justfile` | The `bats tests/test_<name>.bats` line from the `test` recipe |
| `tests/test_<name>.bats` | The test file itself |
| `.github/workflows/unit-tests.yml` | The script path from the explicit extensionless-script shellcheck list, if it is named there |
| `.github/workflows/validate.yml` | Any `candidates.append(Path("..."))` entry in the Python OCI-ref guard. The shellcheck step itself is a blanket `find system_files -name '*.sh'` and names no script, so there is nothing script-specific to delete there |
| `system_files/bluefin/usr/share/ublue-os/just/system.just` (or the owning `.just`) | The `just` target and all aliases |
| `docs/skills/` | The script's skill file (if it has one) + its `docs/SKILL.md` routing row and all cross-references |

If the script had a systemd unit or preset, remove those too — a preset that
enables a missing unit fails at first boot.

### Dead apt step hazard

If the `validate.yml` shellcheck step was the **only** consumer of `Install shellcheck` in that job, delete the apt install step too — it becomes a silent no-op that wastes ~20 seconds per CI run and confuses future readers.

### Cross-reference sweep

After deleting the script and its skill file, run:
```bash
grep -rn "<script-name>" docs/ --include="*.md" --include="*.json"
```
Common survivors: `devmode.md` advisories, `image-registry.md` section headers, skill index metadata.

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
- `--cov=tests` in a pytest invocation — measures the test files, not the source under test. **The `Justfile`'s `test` recipe does exactly this today**; it should be `--cov=system_files --cov=scripts`. Do not copy the pattern, and do not trust the local coverage percentage until it is fixed.

---

## Verification

- [ ] `shellcheck -S warning <file>` passes on the modified script
- [ ] `just test` passes locally (bats + pytest)
- [ ] If a shellcheck directive was added, verify its syntax against Context7 (shellcheck library) and confirm the SC code is correct
- [ ] If a bats test uses env-var overrides, confirm the script uses `${VAR:-default}` at the read site — the override does nothing without it
- [ ] If a script was removed, every touch-point in the table above was checked and the cross-reference sweep returned no survivors

---

## References

| File | Contents |
|---|---|
| [references/testability-patterns.md](references/testability-patterns.md) | All testability patterns with full WRONG/CORRECT code examples |
| [references/bats-patterns.md](references/bats-patterns.md) | Standard bats file structure, mocking, and assertion pitfalls |
| [references/shellcheck-examples.md](references/shellcheck-examples.md) | Shellcheck directive syntax, SC codes, and quoting fix examples |
