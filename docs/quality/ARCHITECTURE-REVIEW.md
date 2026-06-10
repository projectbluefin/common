# Architecture Review: Quality Improvement — projectbluefin/common

**Author:** Principal Architecture Review
**Date:** 2026-06-10
**Scope:** Testing strategy, issue deduplication, phased roadmap, acceptance criteria
**Status:** DRAFT — for maintainer review

---

## Executive Summary

The 11 open `[quality]` issues collectively point to a single systemic gap: **a testing philosophy was never written down**, so coverage accreted unevenly — the dispatcher pattern (`libsetup`, `ublue-system-setup`, `ublue-user-setup`) received solid bats coverage, while adjacent scripts of the same or lower complexity received none. Two of the 11 issues are ghost issues targeting a script that does not exist in this repo. One is a dead CI reference in `validate.yml`. The real remediation is smaller than the issue list implies, and three of the remaining issues can close with a single PR.

---

## 1. Systemic Root Cause

This repo is an OCI image layer factory, not an application. Its shell scripts fall into four structural categories:

| Category | Scripts | Complexity | Testability |
|---|---|---|---|
| **Dispatcher** | `ublue-privileged-setup`, `ublue-system-setup`, `ublue-user-setup` | Low — read config, loop over hooks | High — pure function logic, no hardware |
| **Config injector** | `ublue-bling`, `bling.sh`, profile.d/* | Medium — file mutation with sentinels | High — mock filesystem + `$SHELL` |
| **Interactive tool** | `luks-tpm2-autounlock` | Medium — gum TUI + hardware paths | Partial — control flow testable, device paths hardware-gated |
| **Trivial utility** | `ujust`, `ublue-motd`, `ublue-image-info.sh`, `rechunker-group-fix`, `ublue-bling-fastfetch`, `ublue-fastfetch` | Low | High — env mocking or temp dirs |

The pattern of missing tests is not a motivation or culture problem. It is a **structural one**: when `libsetup` + `ublue-system-setup` + `ublue-user-setup` got coverage, the team established a working pattern. The remaining scripts were never explicitly categorized as "needs tests" or "hardware-gated" — they fell through the gap.

The root cause is the absence of a written testing contract: *what types of scripts require tests, what technique to use, and what the hardware-gated boundary is.*

---

## 2. Duplication Analysis and Issue Disposition

### Ghost Issues — Close Immediately

**`ublue-rollback-helper` does not exist in this repo.** There is no file at `system_files/shared/usr/bin/ublue-rollback-helper` or `system_files/bluefin/usr/bin/ublue-rollback-helper`. The `validate.yml` workflow references it in both a shellcheck step and an image-ref check — these are dead references that silently no-op or fail without output.

| Issue | Action |
|---|---|
| [#559](https://github.com/projectbluefin/common/issues/559) — ublue-rollback-helper zero behavior tests | **Close as invalid** — script does not exist |
| [#564](https://github.com/projectbluefin/common/issues/564) — ublue-rollback-helper complex branching logic untested | **Close as duplicate/invalid** — same ghost script |

A separate issue should track the dead `validate.yml` references. Do not leave them — they erode trust in the CI output.

### True Duplicates — Consolidate

| Issue A | Issue B | Disposition |
|---|---|---|
| [#562](https://github.com/projectbluefin/common/issues/562) — Add bats tests for ublue-privileged-setup | [#563](https://github.com/projectbluefin/common/issues/563) — ublue-privileged-setup lacks unit tests despite elevated privileges | **Merge into #562.** Same deliverable, one filed as "add tests", one filed as "security risk". The risk framing belongs in the body of #562, not as a separate issue. |
| [#561](https://github.com/projectbluefin/common/issues/561) — Add coverage reporting and threshold gate | [#566](https://github.com/projectbluefin/common/issues/566) — Add coverage reporting and regression detection | **Merge into #561.** These are the same infrastructure ask at different levels of abstraction. |
| [#551](https://github.com/projectbluefin/common/issues/551) — Add shellcheck CI and bats tests for libsetup.sh and shell scripts | [#552](https://github.com/projectbluefin/common/issues/552) — Expand shellcheck CI to all 11 scripts | **Partially done.** libsetup, ublue-system-setup, ublue-user-setup now have shellcheck. Close #551 as partially resolved; keep #552 as the remaining expansion task. |

### Genuinely Distinct Issues (Keep)

| Issue | Distinct Concern |
|---|---|
| [#552](https://github.com/projectbluefin/common/issues/552) | Shellcheck expansion to remaining 8 scripts |
| [#553](https://github.com/projectbluefin/common/issues/553) | Tracking issue for overall coverage — repurpose as the epic |
| [#558](https://github.com/projectbluefin/common/issues/558) | ublue-bling injection behavior tests |
| [#562](https://github.com/projectbluefin/common/issues/562) | ublue-privileged-setup tests (absorbs #563) |
| [#561](https://github.com/projectbluefin/common/issues/561) | Coverage reporting infrastructure (absorbs #566) |
| [#565](https://github.com/projectbluefin/common/issues/565) | luks-tpm2-autounlock testable logic coverage |

**Net distinct work items after deduplication: 6** (down from 11). The 11-issue list was ~45% noise.

---

## 3. Testing Philosophy for a Shell-Script OCI Image Factory

### What SHOULD be tested vs. what CAN be tested

The two categories are not the same and conflating them is what generates ghost issues.

**Should + Can (mandatory coverage):**
- All pure-logic functions: config parsing, version gating, fallbacks
- File mutation logic: injection/removal with sentinel patterns, idempotency
- Control flow with hardware dependencies: mock the hardware boundary, test the logic
- Exit codes and error handling: missing files, malformed JSON, unknown shell types

**Can but lower priority (shellcheck is sufficient):**
- Single-line aliases and PATH manipulations (`open.sh`, `uutils.sh`, `ublue-fastfetch.sh`)
- Template rendering scripts with no branching (`ublue-motd` — 5 lines, one env substitution)
- Trivial wrappers (`ujust` — 2 lines, passes args to `just`)

**Cannot test in CI without hardware (document this explicitly):**
- `systemd-cryptenroll` device enrollment — requires real TPM2 chip
- `gum confirm` interactive prompts — requires TTY (mock the boundary instead)
- `bootc` rebase operations — requires booted ostree system
- Systemctl user session operations — requires running systemd user session

**The hardware-gated boundary rule:** When a script calls hardware APIs, extract the decision logic into testable functions before the hardware call. Test the decision tree. Mark the hardware path with a comment: `# hardware-gated: not testable in CI`. Do not file issues for the hardware-gated portion — it is deliberate, not a gap.

### Framework Decision: bats is the right long-term choice

The repo has bats infrastructure, institutional knowledge, and working examples. bats + PATH-manipulation mocking (already used effectively in `qa-test-pr.bats` in the knuckle tests) is the correct pattern for this codebase.

**Reject** shellspec: different syntax, no existing usage, higher learning curve for no measurable benefit at this scale.

**Keep** pytest for Python hooks (`hooks.py`). It is the right tool for Python, and the existing `test_hooks.py` is high quality.

**Add** `bats-assert` and `bats-file` helper libraries when writing the bling injection tests — `[ -f ... ]` assertions scale poorly for file content verification.

### How to test privileged operations without root in CI

`ublue-privileged-setup` runs hook scripts with `bash $script`. In CI:
1. Create a temp hooks directory with non-privileged test scripts
2. Point `SETUP_CONFIG_FILE` at a test JSON overriding the hooks directory
3. Verify hook execution via side effects (marker files, exit codes)

This is identical to the existing `test_setup_scripts.bats` pattern for `ublue-system-setup`. No root is required. The privilege comes from what the *hooks themselves* do — not from the dispatcher.

### How to test luks-tpm2-autounlock without hardware

The script is 1322 bytes. Its testable surface is:
- `/proc/cmdline` parsing → `rd.luks.uuid` extraction (pure string logic)
- `/dev/disk/by-uuid/` existence check (mock `/dev` path)
- `gum confirm` boundary (mock `gum` via PATH)
- `sudo systemd-cryptenroll` invocation with correct arguments (mock via PATH, capture args)
- The wipe-slot vs. enroll branch based on `$EXIT_CODE`

The script as written **cannot be tested** because it mixes all of this in a flat script. The fix is a one-time refactoring into functions (`find_luks_device`, `enroll_tpm2`, `wipe_tpm2`) before writing the tests. This is a 20-minute structural change that unlocks full logic coverage. This belongs in Phase 2, not Phase 1.

---

## 4. Phased Roadmap

### Phase 1: Foundation — Low Risk, High Leverage (1–2 PRs)

**Goal:** Close the obvious gaps with zero architectural change required.

**P1.1 — Close ghost issues and fix dead CI reference (PR 1 of Phase 1)**
- Close issues #559 and #564 (ublue-rollback-helper doesn't exist)
- Remove the dead `ublue-rollback-helper` references from `validate.yml` shellcheck step and image-ref check
- File a separate tracking issue: *"Determine whether ublue-rollback-helper was planned, removed, or belongs in a different repo"*

**P1.2 — Add ublue-privileged-setup tests and shellcheck expansion (PR 2 of Phase 1)**

`ublue-privileged-setup` is structurally identical to `ublue-system-setup`. The tests write themselves:
- Copy the `test_setup_scripts.bats` pattern (get_config fallback, JSON reads, hook execution, missing directory)
- Add `ublue-privileged-setup` to the shellcheck step in `unit-tests.yml`

At the same time, add shellcheck for the remaining scripts where it passes without suppressions:
- `system_files/bluefin/etc/profile.d/uutils.sh`
- `system_files/bluefin/etc/profile.d/caffeinate.sh`
- `system_files/bluefin/usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh`
- `system_files/shared/usr/bin/rechunker-group-fix`
- `system_files/shared/usr/bin/ublue-bling`

Scripts where shellcheck would require `# shellcheck disable` for every line (POSIX sourced fragments, aliases, template outputs): add them to shellcheck with explicit inline suppression comments and a note explaining why. Do not simply skip them — the CI record should be explicit.

**Closes after Phase 1:** #551 (retroactively), #552, #562, #563 (merged)

**Risk:** Low. No architectural change. Same test patterns already proven.

---

### Phase 2: Coverage — Systematic Expansion (2–3 PRs)

**Goal:** Cover all non-trivial logic. Establish the hardware-gated boundary in code.

**P2.1 — ublue-bling injection behavior tests**

`ublue-bling` has real logic worth testing:
- `is-bling-installed` returns false when config file is absent
- `is-bling-installed` returns false when no sentinel line exists
- `is-bling-installed` returns true when sentinel line is present
- Install path: appends correct sentinel block to config file
- Install idempotency: second install does not append a second block (current code has no idempotency guard — this test will reveal a bug)
- Uninstall path: sed removal correctly removes the sentinel block and not adjacent content
- Unknown shell: exits 1 with error message
- `gum` boundary: mock `gum confirm` via PATH override

Test technique: create temp `$HOME` in `$BATS_TEST_TMPDIR`, set `$SHELL` env var, override `$XDG_CONFIG_HOME`.

**P2.2 — luks-tpm2-autounlock — refactor then test**

Perform a minimal structural refactoring:
1. Extract `/proc/cmdline` parsing into `find_luks_uuid()`
2. Extract the device path resolution into `find_crypt_disk()`
3. Extract `systemd-cryptenroll` invocation into `enroll_tpm2()` and `wipe_tpm2()`
4. Keep the gum interaction at the top-level (hardware-gated, document it)

After refactoring, write bats tests:
- `find_luks_uuid` parses `rd.luks.uuid=` correctly from mock `/proc/cmdline`
- `find_luks_uuid` parses `rd.luks.name=luks-<uuid>` format
- `find_luks_uuid` returns empty when no luks entry in cmdline
- Device-not-found path exits 1 with correct message (mock `/dev`)
- Enroll path calls cryptenroll with `--tpm2-device=auto` and correct disk arg
- Wipe path calls cryptenroll with `--wipe-slot=tpm2` and correct disk arg
- PIN arg is included when user confirms PIN setup

This is the most complex testing work in Phase 2 because it requires the refactoring first. Do not write tests against the flat script — the refactoring is the prerequisite.

**P2.3 — Dynamic wallpaper hook test**

`20-dynamic-wallpaper.sh` uses `version-script` from libsetup and calls `systemctl --user`. Mock systemctl via PATH. Test:
- First run invokes systemctl enable
- Second run (same version) exits 0 early via `version-script`

**Closes after Phase 2:** #553, #558, #565

---

### Phase 3: Maturity — Gates, Regression Detection, Refactoring (1–2 PRs)

**Goal:** Make quality self-reinforcing. New scripts cannot ship without tests.

**P3.1 — Coverage reporting and threshold gate**

bats does not natively produce coverage reports. Options:
- `kcov` wraps bats execution and produces LCOV output — works for bash scripts
- GitHub Actions step: `kcov --include-path=system_files/ coverage/ bats tests/`
- Upload to Codecov or post as PR comment via `gh pr comment`

Set an initial threshold of **70% line coverage** for `system_files/shared/usr/bin/*` and `system_files/bluefin/usr/bin/*`. Ratchet upward over time.

For Python: `pytest --cov=system_files/bluefin/etc/bazaar/hooks.py --cov-fail-under=80` — this is trivially addable to the existing pytest step.

**P3.2 — Add a TESTING.md contract to the repo**

Document in `docs/TESTING.md`:
1. Which test file covers which script
2. The hardware-gated boundary rule (what goes in bats vs. what is intentionally untested)
3. The mock pattern (PATH manipulation for external commands)
4. Coverage threshold targets
5. Required test additions for any new script in `system_files/`

This document is the enforcement mechanism for future scripts not falling through the same gap.

**P3.3 — Add shellcheck to the Containerfile build validation**

Run shellcheck as a build-time lint step in `just check` (not just in CI) so contributors get immediate feedback. Add all remaining scripts to a `shellcheck.includes` file, checked in CI.

**Closes after Phase 3:** #561, #566 (merged)

---

## 5. Architectural Risks

### Risk 1: ublue-privileged-setup hooks ship without validation — CRITICAL

`ublue-privileged-setup` runs every script in `privileged-setup.hooks.d/` as `bash $script` (note: unquoted `$script` — shellcheck would have caught this). The hook scripts run with elevated privileges. There are **zero tests** for the dispatcher and no validation that the hooks directory contents are safe to execute.

**Current mitigations:** none in code. The hooks are installed from the OCI image, so the trust boundary is the image build — but a malformed hook script would execute silently with no error propagation.

**Impact:** 100% of Bluefin users who run first boot. A regression in any privileged hook ships to every new installation.

**Fix:** The dispatcher tests (Phase 1.2) address the dispatcher logic. A separate review of the hook scripts themselves for error propagation (missing `set -e`, missing exit code checks) is warranted.

### Risk 2: ublue-bling injection is not idempotent — HIGH

The `is-bling-installed` function checks for the presence of a `source ...` line. The install path appends the sentinel block. The uninstall path removes the sentinel block. However: `is-bling-installed` checks for `source $BLING_CLI_DIRECTORY/$BLING_SCRIPT_SOURCE` but the install path writes `test -f ... && source ...`. These are **not the same string**. A user who installs bling with `ublue-bling`, then runs `ublue-bling` again, may get a second injection instead of triggering the uninstall path.

This is a latent bug that the Phase 2 bats tests will surface. The fix is trivial (check for the sentinel comment, not the source line) but must be made alongside the tests.

### Risk 3: validate.yml references a nonexistent script — MEDIUM

`system_files/bluefin/usr/bin/ublue-rollback-helper` appears in:
1. The shellcheck step of `validate.yml` — if the file path is checked before execution, this fails silently or produces a misleading error
2. The image-ref regression check in the same workflow

If CI passes despite this, it indicates either the step is silently skipping the missing file or the path is never reached. Either way, the CI record cannot be trusted for this check. Fix: remove both dead references and file a separate issue for the rollback helper's status.

### Risk 4: No test coverage threshold — LOW (but compounds)

Without a threshold gate, the current good coverage can erode. A new script can ship with zero tests, a new author can remove tests in a refactoring, and CI will stay green. The Phase 3 kcov + threshold addresses this, but it is the lowest-priority item in the roadmap. The manual `TESTING.md` contract (Phase 3.2) is a cheaper interim control.

### Risk 5: luks-tpm2-autounlock control flow has no tests — CRITICAL (for security users)

This script manages disk encryption enrollment. It affects users who have enabled FDE. The script has no function decomposition, making the control flow opaque. The wipe-slot path (`--wipe-slot=tpm2`) is invoked based on a `gum confirm` exit code — if the exit code mapping is wrong, a user could inadvertently disable TPM2 auto-unlock when intending to enable it (or vice versa).

The Phase 2.2 refactoring + tests directly address this. Until then, this script is a security-adjacent black box.

---

## 6. What "Quality-Healthy" Looks Like — Acceptance Criteria

The common repo is quality-healthy when all of the following are true:

**Test coverage (measurable):**
- [ ] All scripts in `system_files/shared/usr/bin/` have either (a) bats behavior tests or (b) a documented `# hardware-gated` exemption in `docs/TESTING.md`
- [ ] All scripts in `system_files/bluefin/usr/bin/` same criteria
- [ ] All profile.d and env.sh scripts pass shellcheck with zero suppressions (or documented suppressions with justification)
- [ ] Python hook coverage ≥ 80% (`pytest --cov-fail-under=80`)
- [ ] Shell script line coverage ≥ 70% via kcov across `/usr/bin/` scripts

**Process (structural):**
- [ ] `docs/TESTING.md` exists and covers hardware-gated boundary, mock pattern, and threshold targets
- [ ] `unit-tests.yml` fails if shellcheck covers fewer files than the declared baseline (no silent regression)
- [ ] Any PR adding a new file to `system_files/*/usr/bin/` requires either a test file in `tests/` or a documented exemption

**Issue hygiene:**
- [ ] Zero open `[quality]` issues more than 90 days old without a `status/blocked` label and a documented blocker reason
- [ ] No ghost issues (issues for scripts that don't exist)

**CI health:**
- [ ] `validate.yml` contains no dead file references
- [ ] Every shellcheck step covers a file that actually exists at the referenced path

---

## 7. Issue Consolidation Summary

**Close as invalid:** #559, #564 (ublue-rollback-helper ghost issues)
**Close as duplicate (merge into #562):** #563
**Close as duplicate (merge into #561):** #566
**Close as partially resolved:** #551 (libsetup + setup scripts done; remainder tracked by #552)
**Repurpose as quality epic:** #553

**Remaining work items (6 distinct, actionable):**

| Issue | Phase | Effort | Owner |
|---|---|---|---|
| [#552](https://github.com/projectbluefin/common/issues/552) — Shellcheck expansion + dead validate.yml refs | Phase 1 | Small | Any |
| [#562](https://github.com/projectbluefin/common/issues/562) — ublue-privileged-setup tests | Phase 1 | Small | Any |
| [#558](https://github.com/projectbluefin/common/issues/558) — ublue-bling behavior tests | Phase 2 | Medium | Any |
| [#565](https://github.com/projectbluefin/common/issues/565) — luks-tpm2-autounlock refactor + tests | Phase 2 | Medium | Experienced contributor |
| [#561](https://github.com/projectbluefin/common/issues/561) — Coverage reporting + threshold | Phase 3 | Small | Any |
| [#553](https://github.com/projectbluefin/common/issues/553) — Epic tracking | Ongoing | Triage | Maintainer |

---

## Appendix: Script Inventory with Test Status

| Script | Lines | Type | Shellcheck | Bats/pytest | Notes |
|---|---|---|---|---|---|
| `libsetup.sh` | 34 | Library | ✅ | ✅ 9 tests | Solid |
| `ublue-system-setup` | ~30 | Dispatcher | ✅ | ✅ 5 tests | Solid |
| `ublue-user-setup` | ~30 | Dispatcher | ✅ | ✅ 4 tests | Solid |
| `ublue-privileged-setup` | ~25 | Dispatcher | ❌ | ❌ | Same pattern as above — gap |
| `ublue-bling` | ~60 | Config injector | ❌ | ❌ | Has a latent idempotency bug |
| `bling.sh` | 68 | Shell source | ❌ | ❌ | Low-risk, shellcheck sufficient |
| `luks-tpm2-autounlock` | ~50 | Interactive tool | ❌ | ❌ | Needs refactoring first |
| `rechunker-group-fix` | ~20 | Utility | ❌ | ❌ | Low-risk |
| `caffeinate.sh` | 10 | Profile function | ❌ | — | Shellcheck only needed |
| `open.sh` | 1 | Alias | ❌ | — | Shellcheck only needed |
| `uutils.sh` | 10 | PATH setup | ❌ | — | Shellcheck only needed |
| `20-dynamic-wallpaper.sh` | 13 | Hook | ❌ | ❌ | Uses libsetup — testable |
| `ublue-fastfetch.sh` | 3 | Wrapper | ❌ | — | Trivial |
| `ublue-motd.sh` | 3 | Wrapper | ❌ | — | Trivial |
| `umotd.sh` | 3 | Alias | ❌ | — | Trivial |
| `ublue-image-info.sh` | 10 | Utility | ❌* | — | `shellcheck disable=2046` present |
| `hooks.py` | — | Python | — | ✅ | Good pytest coverage |

*`ublue-image-info.sh` already has a shellcheck suppress; this is intentional — the existing suppress is for a legitimate word-splitting use with jq.
