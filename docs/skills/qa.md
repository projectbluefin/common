# QA Model — projectbluefin Factory

## Test coverage by repo

| Repo | Existing gates | Critical gaps |
|---|---|---|
| **bluefin** | lint, PR build+smoke, post-merge e2e, upgrade test, weekly pre-promotion | Installability gate, real-hardware gate, Bazaar/Flatpak test |
| **bluefin-lts** | PR validation, PR smoke | Post-merge e2e, testing→stable gate, upgrade gate, installability gate |
| **common** | PR build, just/brewfile validation, post-merge suite | **No pre-merge downstream composition** |
| **dakota** | validate/build, PR smoke, publish gate | Installability gate, hardware gate |
| **knuckle** | unit/race/lint/vuln/coverage/BATS/headless/VM e2e | Bare-metal installer validation |

## Known gaps (tracked)

| Issue | Gap | Priority |
|---|---|---|
| [#419](https://github.com/projectbluefin/common/issues/419) | software.feature tests GNOME Software, not Bazaar | P0 |
| [#421](https://github.com/projectbluefin/common/issues/421) | No pre-merge composition gate for common | P0 |
| [#423](https://github.com/projectbluefin/common/issues/423) | No installability gate before promotion | P1 |
| [#420](https://github.com/projectbluefin/common/issues/420) | No regression contract across streams | P1 |
| [#422](https://github.com/projectbluefin/common/issues/422) | Hardware-only bug classes invisible to gate | P1 |
| [#424](https://github.com/projectbluefin/common/issues/424) | bonedigger not wired into promotion | P1 |
| [#425](https://github.com/projectbluefin/common/issues/425) | bluefin-lts testing→stable gate too weak | P1 |

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
