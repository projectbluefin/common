---
name: pr-review
version: "2.0"
last_updated: 2026-06-24
tags: [review, testing, contributing]
description: "Reviewer's guide for PRs in projectbluefin/common — PR type taxonomy, per-type review checklist, CI gate interpretation, OEM hook review pattern, test quality standards, and report template. Use when reviewing any incoming PR to common. Lab testing methodology now lives in lab-testing.md."
metadata:
  type: procedure
---

# PR Review Guide — projectbluefin/common

`projectbluefin/common` is the shared OCI layer consumed by every downstream variant (bluefin, bluefin-lts, dakota). A broken `system_files/shared/` change cascades to all three simultaneously. Consistent, thorough review prevents those regressions from reaching users.

This guide documents PR type taxonomy, per-type review checklists, CI gate interpretation, OEM hook review, test quality standards, and the review report template — built from live review sessions on PRs #760, #767, #768, #769, and #785.

> **Lab testing moved (2026-06-24):** The baseline-vs-delta methodology, worked examples (PR #768, #769, #767), quick-start lab YAMLs, and the composed-image testing pattern now live in [`lab-testing.md`](lab-testing.md). This file focuses on review procedure; it links to `lab-testing.md` where lab verification is needed.

---

## Agent-accelerated review lane

Factory agents act as an additional quality layer alongside human reviewers. Because agents can submit and monitor many cluster smoke tests in parallel, they are authorized to accelerate the review of **low-risk, automated PRs** — specifically Renovate/chore dependency updates — in the RPM-based image repos (`common`, `bluefin`, `bluefin-lts`).

### Workflow

1. Identify PRs labelled `dependencies`, `chore/deps`, or with a `chore(deps):*` title (Renovate / mergeraptor / Dependabot).
2. Submit a cluster smoke test via `bluefin-qa-pipeline` using the appropriate `:testing` image:
   - `common` PR → `ghcr.io/projectbluefin/bluefin:testing`
   - `bluefin-lts` PR → `ghcr.io/projectbluefin/bluefin-lts:testing`
3. Poll to completion and collect logs.
4. On **pass**: post a Vanguard Lab Strike Report and an approving review. Enable auto-merge so the change lands in the testing branch.
5. On **fail**: post a Vanguard Lab Strike Report with diagnostics, apply `agent/blocked`, and leave the PR for human triage. Do **not** approve.

### Scope limits

- Applies only to dependency/chore PRs that do not touch `system_files/`, `Containerfile`, or CI workflow logic that affects artifact provenance.
- Dakota (BST) is excluded when BST builds are known broken.
- `actions` repo PRs are excluded unless the changed action is exercised by a consumer image build; most Actions dependency bumps should still go through normal maintainer review.
- If a maintainer has already requested changes, the agent must not override that review.

### Trust model

The cluster smoke test is the ground truth. A passing smoke test on the relevant `:testing` image is sufficient to land a low-risk dependency bump into the testing branch. Human review is still required for `system_files/`, `Containerfile`, and non-Routine PRs.

---

## PR type taxonomy

Identify the PR type first. It determines blast radius, review depth, and whether lab testing is needed.

| Type | Paths touched | Blast radius | Lab needed? |
|---|---|---|---|
| `systemd unit` | `system_files/shared/**/*.service`, `system_files/shared/**/*.timer`, `system_files/shared/**/*.path` | ALL variants | Yes |
| `systemd unit (nvidia)` | `system_files/nvidia/**/*.service` | nvidia images only | nvidia VM |
| `shell script` | `system_files/shared/usr/libexec/**`, `system_files/shared/usr/bin/**` | ALL variants | If behavior-changing |
| `dconf / GSettings` | `system_files/shared/**/*.gschema.override`, `system_files/shared/**/*.d/*.conf` | ALL variants | Optional |
| `OEM hardware hook` | `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/**`, `system_files/shared/usr/share/ublue-os/system-setup.hooks.d/**` | Scoped to DMI gate | If DMI gate changed |
| `test addition` | `tests/**` | None (tests only) | No — run `just test` |
| `CI workflow` | `.github/workflows/**` | CI pipeline | No, but needs maintainer review |
| `doc / skill update` | `docs/**`, `AGENTS.md` | None | No — doc-only exception, push direct to main |
| `Containerfile` | `Containerfile` | ALL variants | Yes |

For lab testing scope by changed path, quick-start YAMLs, and the baseline-vs-delta methodology, see [`lab-testing.md`](lab-testing.md).

---

## Universal checklist

Apply to every PR regardless of type:

- [ ] `just check` passes (Justfile lint)
- [ ] `pre-commit run --all-files` passes (JSON/YAML/TOML hygiene, actionlint, SHA pinning)
- [ ] PR title follows Conventional Commits format (`feat:`, `fix:`, `chore(deps):`, `docs:`, etc.)
- [ ] All `uses:` references to external GitHub Actions are SHA-pinned with a version comment — no `@main`, `@latest`, or `@v*` floating tags
- [ ] If `system_files/shared/`: blast radius acknowledged — change affects bluefin, bluefin-lts, AND dakota
- [ ] `system_files/` changes have lab verification or passing E2E CI before merge

---

## Per-type review checklists

### systemd unit

- [ ] `WantedBy=` target matches the intended boot path:
  - `multi-user.target` for network services, update daemons, background tasks — runs on all boots including headless
  - `graphical.target` only if the service genuinely requires a graphical session (e.g., GNOME-specific D-Bus activation)
  - **Do not downgrade `multi-user.target` to `graphical.target`** unless the service truly needs GNOME — this silently drops the service on non-graphical boots (PR #767: `flatpak-appstream-firstboot.service` was incorrectly changed to `graphical.target`)
- [ ] `StartLimitBurst=` and `StartLimitIntervalSec=` are in `[Unit]`, not `[Service]` — systemd ignores them in `[Service]` (PR #767: these were in wrong section)
- [ ] `Restart=on-failure` interaction with conditions:
  - `ConditionACPower=true` — if AC condition fails (not met), systemd exits `SERVICE_SKIP_CONDITION` (exit 0 from systemd's perspective), which does NOT trigger `Restart=on-failure`. Transient condition-skip is silent.
  - `ExecCondition=` — same behavior: skip-condition exits are not failures. A service that installs, then fails a later step, may be silently skipped on restart if the install step's check returns non-zero on re-entry (PR #769: GL runtime already installed → ExecCondition exits non-zero → unit skips on Restart)
- [ ] `StartLimitBurst=1` combined with rate-limiting window: if the service can be legitimately triggered multiple times in the window (e.g., brief AC plug-in fires udev → service starts → AC unplugged before activation → real plug-in later is silently dropped), consider whether the rate limit is correct (PR #768)
- [ ] `After=` includes ordering dependencies that `Wants=` alone does not provide — `Wants=network-online.target` does not guarantee network is up before the unit starts; add `After=network-online.target` if ordering matters (PR #768: `uupd.timer` missing `After=`)
- [ ] `TimeoutStartSec=` is adequate for the work being done (e.g., large flatpak updates need 900s+, not 600s)
- [ ] `RemainAfterExit=yes` is appropriate — correct for one-shot setup services that should stay "active" after completion
- [ ] `[Install]` section: its absence is intentional for udev-started units (document in review); its presence is required for timer-started or manually-enabled units
- [ ] **Enable mechanism present**: if `[Install]` / `WantedBy=` is set, confirm a preset file (`.preset`) or systemctl enable call will activate it in the built image — a unit file without an enable mechanism ships as a no-op (PR #767: preset existed in source but image pre-dated its merge, so service was disabled)
- [ ] Service name reflects current behavior — if a "firstboot" service was generalized to run on every boot, the name should be updated (PR #767: service is no longer firstboot-only)

### shell script

- [ ] `shellcheck` passes — at minimum, run `shellcheck -S warning <file>`
- [ ] SC1091 suppression (`. /path/to/sourced/file`): use `# shellcheck source=/path` annotation, not a blanket disable
- [ ] Variable quoting — unquoted variables in conditionals and loops are common failure modes
- [ ] Error handling — `set -euo pipefail` or explicit checks; silent failures in hooks cause hard-to-debug regressions
- [ ] D-Bus / systemd calls in user hooks: `systemctl --user` needs `$DBUS_SESSION_BUS_ADDRESS` — confirm environment is available at hook execution time

> **See also:** [`shell-scripts.md`](shell-scripts.md) for testability patterns (env-var override idiom, PATH-stub mocking, idempotent main guard, XDG isolation) and [`ci-tooling.md`](ci-tooling.md) § Shellcheck in validate.yml for CI config.

### dconf / GSettings

- [ ] Override file AND lock file change together — see [`dconf-consistency.md`](dconf-consistency.md)
- [ ] Lock file path matches override key exactly (key in `00-common` → lock entry in `00-common.conf`)
- [ ] `just check` catches parity mismatches via the dconf consistency checker

### OEM hardware hook

See the full OEM pattern section below. Quick checklist:

- [ ] Version-script guard wraps idempotent-but-not-safe work; purely idempotent work lives outside it
- [ ] DMI gate is scoped to the exact target hardware: `chassis_vendor` + `sys_vendor` + `product_name` (all three)
- [ ] Version bump acknowledged: existing users re-run the versioned block — all code inside must be safe to re-run (brew install is idempotent; dconf writes and systemctl enables are safe to re-run)
- [ ] WirePlumber fragments: written to user fragment dir (`~/.config/wireplumber/wireplumber.conf.d/`), not global system dir
- [ ] Hook is executable and follows naming convention (`NN-description`)
- [ ] **Brew availability early-exit**: brew-independent payloads (config file copies, WirePlumber fragments, etc.) are placed BEFORE the `BREW_BIN` check, not after it — if they are after, they silently don't run on first login when brew isn't yet available (PR #760)

### test addition

See the test quality checklist below. Quick checklist:

- [ ] Full argv asserted, not substring membership — catches missing flags, wrong spawn wrapper, wrong ordering
- [ ] Key kwargs verified (`start_new_session=True` for background spawns)
- [ ] Mock expands full received command line in bats (not a collapsed label like `"mock: grubby update"`)
- [ ] Test covers failure path, not only happy path
- [ ] `just test` passes locally

### CI workflow

- [ ] All external `uses:` SHA-pinned — pre-commit enforces this, but verify in review
- [ ] New composite actions sourced from `projectbluefin/actions` where a reusable exists — do not inline logic that already lives there
- [ ] No inline supply chain steps (signing, SBOM, provenance) — consume composite actions from `projectbluefin/actions` instead
- [ ] Sensitive paths (secrets, GHCR push, cosign) need maintainer eyes
- [ ] Workflow name follows existing conventions in the repo

> **See also:** [`ci-tooling.md`](ci-tooling.md) for SHA pinning policy and floating-tag guard. [`ci-pitfalls.md`](ci-pitfalls.md) for CI incident-log entries to watch for in review (branch-from-target, caller permissions starvation, workflow_run name matching).

---

## CI gate interpretation

| Check name | What it means | If it fails |
|---|---|---|
| `Build and push image` | OCI image composes successfully from Containerfile | Blocking — fix build error |
| `Compose PR test image` | common layer composed for E2E gate | GHCR 504/timeout = transient, re-trigger the workflow |
| `E2E — composed common suite` | GNOME common AT-SPI suite on composed image | Investigate test output; may be flaky — re-run once |
| `test` | pytest + bats unit tests | Blocking — fix test failures |
| `pre-commit` | SHA pinning, JSON/YAML/TOML hygiene, actionlint | Blocking — run `pre-commit run --all-files` locally |
| `ghost-lab` | PR-specific lab test on KubeVirt cluster | Stale pending = needs requeue (see below) |
| Renovate `dependencies` | Automated dependency update PR | Auto-merge on CI pass; agent may approve after passing ghost-lab smoke test (see Agent-accelerated review lane) |

### Transient failures

- **GHCR 504 on `Compose PR test image`**: This is a transient GitHub Container Registry timeout, not a code problem. Re-trigger the workflow with `gh workflow run` or the GitHub UI.
- **`ghost-lab` stale pending**: The lab check can get stuck in a "pending" loop. Requeue via `gh api` (see below).

---

## ghost-lab check — requeue a stale pending check

The `ghost-lab` status check is set via the GitHub Checks API from the lab cluster. If it gets stuck in a pending state:

```bash
# Check current status
gh api repos/projectbluefin/common/commits/<SHA>/check-runs \
  --jq '.check_runs[] | select(.name == "ghost-lab") | {status, conclusion, html_url}'

# Requeue by re-triggering the lab dispatch workflow
gh workflow run ghost-lab-dispatch.yml \
  --repo projectbluefin/common \
  --ref <branch-name>

# If the check run itself needs to be reset to queued:
gh api repos/projectbluefin/common/check-runs/<check-run-id> \
  -X PATCH \
  --field status=queued
```

If the lab is unavailable, a maintainer can manually set the check to `success` with a note:

```bash
gh api repos/projectbluefin/common/statuses/<SHA> \
  -X POST \
  --field state=success \
  --field context=ghost-lab \
  --field description="manually cleared — lab unavailable"
```

---

## OEM hook review pattern

OEM hardware first-boot hooks live in `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/`. Full context is in [`oem-hardware-hooks.md`](oem-hardware-hooks.md).

### Version-script guard

```bash
# Pattern: work inside the guard re-runs when version bumps
run_if_new_version() {
    local version="$1"
    # ... checks ~/.local/share/ublue-os/user-setup-complete against $version
}

run_if_new_version "20260101" << 'EOF'
  # Non-idempotent or expensive work — runs only when version > stored
  dconf write /org/gnome/... "'value'"
  systemctl --user enable some.service
EOF

# Idempotent-safe work — lives OUTSIDE the guard, runs every boot
if is_this_hardware; then
    brew install --cask some-app 2>/dev/null || true
fi
```

- **Inside guard**: dconf writes, systemctl enables, one-time migration tasks
- **Outside guard**: brew installs (idempotent), configuration checks, WirePlumber fragment installs (idempotent copy)

**Version bump implication**: when version changes, ALL existing users re-run the guarded block. Code inside must be safe to re-run — dconf writes and systemctl enables are idempotent by nature, but destructive operations (rm -rf, overwriting config files) need extra care.

### DMI gates

Scope to exact hardware using all three DMI fields:

```bash
if [[ "$(cat /sys/class/dmi/id/chassis_vendor)" == "Framework" ]] && \
   [[ "$(cat /sys/class/dmi/id/sys_vendor)" == "Framework Computer LLC" ]] && \
   [[ "$(cat /sys/class/dmi/id/product_name)" == "Framework Desktop" ]]; then
    # hardware-specific setup
fi
```

- Using only `product_name` can match unrelated hardware with the same name across vendors
- `chassis_vendor` + `sys_vendor` + `product_name` together uniquely identifies the target
- **QEMU lab caveat**: `/sys/class/dmi/id/product_name` in QEMU VMs is typically `"Standard PC (i440FX + PIIX, 1996)"` or similar — DMI gate will correctly NOT fire. Verify this in lab to confirm the install block is a no-op on non-target hardware.

### WirePlumber fragments

WirePlumber user-space audio profiles must be written to the **user** fragment directory:

```
~/.config/wireplumber/wireplumber.conf.d/    ← correct (user-setup hook)
/usr/share/wireplumber/wireplumber.conf.d/   ← wrong for user hooks (system-level, would need root)
```

The copy should be idempotent — check if the target exists and matches before writing, or use `install -m 644` which overwrites safely.

### Brew availability early-exit trap

User-setup hooks typically check for brew early and exit if it isn't available yet. This creates a **silent failure mode** for brew-independent work placed after the check:

```bash
# Common hook structure — DANGER ZONE
BREW_BIN="$(brew --prefix)/bin/brew" 2>/dev/null
if [[ ! -x "${BREW_BIN}" ]]; then
    exit 0   # ← early exit: brew not ready yet
fi

# ... versioned brew installs ...

# WirePlumber config copy — has NO brew dependency
# BUG: this never runs on first login when brew isn't present yet
install -m 644 "${SCRIPT_DIR}/51-hardware.conf" \
    "${HOME}/.config/wireplumber/wireplumber.conf.d/"
```

**Fix**: move brew-independent payloads (config file copies, DMI-gated fragments) **before** the `BREW_BIN` early-exit:

```bash
# Correct order: brew-independent work first
if is_target_hardware; then
    install -m 644 "${SCRIPT_DIR}/51-hardware.conf" \
        "${HOME}/.config/wireplumber/wireplumber.conf.d/"
fi

# Then gate on brew
BREW_BIN="$(brew --prefix)/bin/brew" 2>/dev/null
if [[ ! -x "${BREW_BIN}" ]]; then
    exit 0
fi

# brew-dependent versioned work below
```

**Review signal**: if a hook installs a config file after a `BREW_BIN` check and the config has no brew dependency, flag it — the config silently won't install on first login (PR #760: `51-framework-desktop.conf` hit this).

---

## Test quality checklist

Derived from review of PR #785 (unit tests for check-oci-refs, bazaar-hook, hardware hooks, nvidia-flatpak-sync).

### Python unit tests (pytest / mock)

**Assert full argv, not substring membership:**

```python
# BAD — misses --cask flag, wrong positional order, wrong spawn wrapper
assert "brew" in " ".join(mock_popen.call_args_list[0][0][0])

# GOOD — catches all of these
mock_popen.assert_called_once_with(
    ["brew", "install", "--cask", "some-app"],
    start_new_session=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
```

**Verify key kwargs:**
- `start_new_session=True` — required for background spawns that must survive the parent
- `env=` override — if the script sets environment variables, assert they are passed
- `cwd=` — if the script changes directory before the call

**Cover failure paths:**
- Non-zero return code from subprocess
- Missing file / path not found
- Permission error

**Mock granularity:**
- Mock at the level of the function under test, not the underlying OS call — `patch("module.subprocess.Popen")` not `patch("subprocess.Popen")` to avoid cross-module leakage

### Bats tests (shell)

**Echo the full received command line from mocks:**

```bash
# BAD — collapses all grubby calls to the same label, loses argument content
function grubby() { echo "mock: grubby update"; }

# GOOD — emits full argv, allows assertion on specific arguments
function grubby() { echo "mock: grubby $*"; }
```

Then assert against specific content:

```bash
run some-script-under-test
assert_output --partial "grubby --update-kernel=ALL --args=blacklist=nouveau"
```

**Framework mock pitfall**: if the bats test framework provides a mock helper that collapses argv to a label, do not use it for commands where the argument list matters. Write a minimal function mock instead.

**Assert `--now` and `--args` content:**

```bash
# BAD — discards content
assert_output --partial "systemctl enable"

# GOOD — verifies the full invocation including --now and service name
assert_output --partial "systemctl enable --now some.service"
```

> **See also:** [`shell-scripts.md`](shell-scripts.md) for bats setup/teardown patterns, PATH-stub mocking, XDG_CONFIG_HOME isolation, and the idempotent main guard.

---

## PR review report template

Use this format when reporting findings from a review session. One table row per PR, followed by per-PR detail blocks for any findings.

### Summary table

| PR | Title | Type | Code review | Lab result | CI | Verdict |
|---|---|---|---|---|---|---|
| #NNN | short title | `systemd unit` / `OEM hook` / etc | ✅ Clean / ⚠️ N findings | ✅ Green / ⚠️ Stale image / ❌ Failed | ✅ / ❌ transient | ✅ Ready / ⚠️ Needs fix / 🔁 Re-trigger CI |

### Per-PR detail block

```
### PR #NNN — <title>

**Type:** <PR type from taxonomy>
**Branch:** <branch-name>
**CI:** <status — all green / compose failed (transient GHCR 504) / ghost-lab pending>

**Code review findings:**
- [SEVERITY] Description — file:line — suggested fix

**Lab baseline** (workflow: <name>, phase: <Succeeded/Failed>):
| Artifact | Baseline state |
|---|---|
| `unit-name.service` | ABSENT / EXISTS (content: ...) |
| `systemctl is-enabled` | enabled / disabled |
| `systemctl --failed` | Clean / mcelog only (QEMU noise) |

**Post-merge verification:**
```bash
# paste the exact commands to verify after rebuild
```

**Verdict:** ✅ Ready to merge / ⚠️ Fix needed before merge / 🔁 Re-trigger CI / 🔬 Needs nvidia lab
```

### Example report — 2026-06-24 session

| PR | Title | Type | Code review | Lab result | CI | Verdict |
|---|---|---|---|---|---|---|
| #785 | unit tests: check-oci-refs, bazaar-hook, hw hooks | `test addition` | ⚠️ 2 findings (weak assertions) | N/A | ✅ | ⚠️ Strengthen assertions |
| #767 | flatpak appstream refresh every boot | `systemd unit (shared)` | ⚠️ 1 finding (`graphical.target` contextually OK; metered guard missing) | ⚠️ Service disabled in image — preset not yet built in | ❌ CI stale (GHCR 504) | ⚠️ Add metered guard, re-trigger CI |
| #768 | uupd AC-aware update scheduling | `systemd unit (shared)` | ⚠️ 1 finding (rate-limit consumes burst on brief AC plug) | ✅ Baseline captured — 3 new artifacts absent as expected | ✅ | ⚠️ Rate-limit logic needs review |
| #769 | nvidia flatpak runtime sync | `systemd unit (nvidia)` + `skill doc` | ⚠️ 1 finding (failed flatpak update not retried on restart) | ✅ Green — service absent on non-nvidia (correct) | ⚠️ ghost-lab stale pending | ⚠️ Fix retry logic; requeue ghost-lab |
| #760 | Framework Desktop WirePlumber OEM hook | `OEM hardware hook` + `skill doc` | ⚠️ 1 finding (wireplumber install after BREW_BIN check — won't run on first login) | ⚠️ Stale image — 20-oem-brew.sh not in testing build | ✅ | ⚠️ Move wireplumber install before brew check |
| #790 | chore(deps): update actions/cache | `dependencies` | N/A (Renovate) | N/A | ✅ | ✅ Auto-merge on CI pass |
| #789 | chore(deps): update taiki-e/install-action digest | `dependencies` | N/A (Renovate) | N/A | ✅ | ✅ Auto-merge on CI pass |

---

## Review sign-off checklist

Before approving any `system_files/` PR:

- [ ] Universal checklist passed
- [ ] Per-type checklist completed for all changed paths
- [ ] CI is green (or transient failures identified and re-triggered)
- [ ] `ghost-lab` check is not stale-pending (requeue if needed)
- [ ] Lab verification done or E2E CI pass accepted as equivalent — see [`lab-testing.md`](lab-testing.md) for baseline-vs-delta methodology and quick-start YAMLs
- [ ] Skill file update committed in the same PR if a new pattern was discovered
- [ ] PR title is Conventional Commits
- [ ] Attribution trailers present on AI-authored commits (convention, not a gate)
