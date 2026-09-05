---
name: shell-scripts
version: "1.1"
last_updated: "2026-08-08"
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

## Bats Test Structure

Standard file layout, mocking, and pitfalls in
[references/bats-patterns.md](references/bats-patterns.md).

## Bluefin-family host runsc provisioning

Common's shared overlay owns the reusable host-side gVisor runtime provisioner
for Bluefin-family images. The provisioner does not change Podman's default
runtime; consumers explicitly select `runsc` when they need the outer
isolation boundary.

The pinned upstream release is `release-20260817.0`. The helper selects the
exact architecture asset and digest before it inspects or extracts the archive:

- `x86_64`: `ae345a8c1466586b3a163fb534301913da663a97b8ed446bc711b2e1963a32c5`
- `aarch64`: `a3c2443e9564dbf500893e66fd2463be3b79fe42f66825971c44dc1624d454b2`

The acquisition is HTTPS-only and the archive member allowlist requires both
`runsc` and its adjacent `gvisor-bin` payload. Installation stages a complete
version, publishes `/usr/local/bin/runsc` atomically, and records ownership so
install/update/remove refuse foreign, unowned, or symlinked paths. Repeating
install or update is idempotent, and a failed update leaves the active version
in place. The supported user commands are:

```text
ujust runsc install
ujust runsc update
ujust runsc remove
```

This capability does not add `ignore-cgroups=true`, use host networking, or
claim native runtime acceptance. A consumer must separately prove executable
`runsc`, rootless `podman --runtime=runsc`, `OCIRuntime=runsc`, ordinary
networking, lifecycle behavior, and each supported architecture on real
hardware.

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
