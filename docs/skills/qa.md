---
name: qa
description: "QA model, test coverage matrix, promotion gates by repo, hardware gap, and how to run the test suite for projectbluefin factory repos. Use when understanding QA coverage, running tests, or checking promotion gate status."
metadata:
  type: reference
---

# QA Model — projectbluefin Factory

## Test coverage by repo

| Repo | Existing gates | Critical gaps |
|---|---|---|
| **bluefin** | lint, PR build+smoke, post-merge e2e, upgrade test, weekly pre-promotion | Installability gate, real-hardware gate, Bazaar/Flatpak test |
| **bluefin-lts** | PR validation, PR smoke, post-merge e2e | testing→stable gate, upgrade gate, installability gate |
| **common** | PR composed-image gate, just/brewfile validation, post-merge suite | installability gate, hardware gate |
| **dakota** | validate/build, PR smoke, publish gate | Installability gate, hardware gate |
| **knuckle** | unit/race/lint/vuln/coverage/BATS/headless/VM e2e | Bare-metal installer validation |

## Known gaps (tracked)

| Issue | Gap | Priority | Status |
|---|---|---|---|
| [#419](https://github.com/projectbluefin/common/issues/419) | software.feature tests GNOME Software, not Bazaar | P0 | open |
| [#420](https://github.com/projectbluefin/common/issues/420) | No regression contract across streams | P1 | open |
| [#422](https://github.com/projectbluefin/common/issues/422) | Hardware-only bug classes invisible to gate | P1 | open |
| [#424](https://github.com/projectbluefin/common/issues/424) | bonedigger not wired into promotion | P1 | open |
| [#421](https://github.com/projectbluefin/common/issues/421) | No pre-merge composition gate for common | P0 | ✅ closed |
| [#423](https://github.com/projectbluefin/common/issues/423) | No installability gate before promotion | P1 | ✅ closed |
| [#425](https://github.com/projectbluefin/common/issues/425) | bluefin-lts testing→stable gate too weak | P1 | ✅ closed |

## Promotion quality gates (current state)

### bluefin (strongest)
1. PR: build + smoke e2e
2. Post-merge: common suite + upgrade test
3. Weekly: broader e2e before latest/stable promotion

### bluefin-lts (weak)
1. PR: validation + smoke (targets `:lts-testing` tag, not PR image)
2. No post-merge gate
3. scheduled-lts-release.yml promotes without defined pass/fail criteria

### common (moderate)
1. PR: build + just/brewfile validation
2. Post-merge: e2e against production tags (not PR-composed image)

### dakota (moderate)
1. PR: bst show (validate only)
2. Post-merge: PR image pushed to `:testing` with smoke gate
3. Weekly: testing promotion to latest/stable

### knuckle (strong for installer)
1. Unit + race + lint + vuln scan + coverage
2. BATS tests
3. Headless ISO smoke
4. VM e2e

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

See each repo's AGENTS.md for repo-specific test commands. Common entry points:

```bash
# common
just check              # lint + validate

# bluefin/bluefin-lts
just check              # pre-commit + validate

# dakota
bst show elements/...   # validate BST elements

# knuckle
go test ./...           # unit tests
just bats               # BATS integration tests
```

## bonedigger integration

bonedigger crash/panic detection should gate promotions — currently it is disconnected from the promotion workflow. See [#424](https://github.com/projectbluefin/common/issues/424) and [docs/skills/bonedigger.md](bonedigger.md).

## libsetup.sh — setup versioning

`version-script` in `system_files/shared/usr/lib/ublue/setup-services/libsetup.sh` is the idempotency guard for all first-boot setup scripts.

**Pattern for callers:**
```bash
source /usr/lib/ublue/setup-services/libsetup.sh
version-script my-service user 1 || exit 0
# ... setup steps here, run exactly once per version bump ...
```

**Protections built into `version-script`:**
- **Concurrent execution safe:** uses `flock -x` (fd 200 on a `.lock` file adjacent to the state file) so that user-setup and privileged-setup starting simultaneously on first boot cannot both read before either writes — each call is serialised.
- **Malformed state file safe:** validates JSON with `jq` before reading. If `setup_versioning.json` is corrupted, resets to `{}` with a warning rather than silently skipping setup.
- **Temp file cleanup:** uses `trap 'rm -f "${tmp}"' EXIT` inside the subshell so no orphaned temp files remain on error.

**State file:** `~/.local/share/ublue/setup_versioning.json` (user-scoped, not global).

**Test coverage:** `tests/test_libsetup.bats` — 9 tests. Run `just test` to verify.
