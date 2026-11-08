---
name: lab-testing
version: "1.1"
last_updated: "2026-07-29"
id: lab-testing
one_line_purpose: Boot images on the KubeVirt lab and collect test logs.
entry_point: docs/skills/lab-testing/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [lab, testing, kubevirt]
description: >-
  KubeVirt lab testing for common. Use when testing a common PR against
  bluefin, bluefin-lts, or dakota on ghost.
metadata:
  type: reference
---


# Lab Testing — common layer on KubeVirt

`projectbluefin/common` is the shared OCI layer consumed by every downstream variant.
A regression in `system_files/shared/` breaks bluefin, bluefin-lts, AND dakota simultaneously.
Lab testing on ghost catches what GitHub Actions E2E cannot: KVM-backed full boots,
real systemd unit activation, services that need device nodes, and cold-start timing.

## When to use lab testing vs. GitHub Actions E2E

| Signal you want | Use |
|---|---|
| Pre-merge: does this common change compose correctly? | `pr-e2e.yml` (PR gate) |
| Post-merge: does the shared layer regress any variant? | `e2e.yml` (post-merge E2E) |
| **Real systemd journal — any service failures?** | **Lab: `log-scan-*` workflows** |
| Boot time, startup ordering, GNOME session smoke | Lab: `bluefin-qa-pipeline suites=smoke` |
| System contract (bootc, read-only /usr, staged deploy) | Lab: `bluefin-qa-pipeline suites=system` |
| Hardware-only bugs (suspend, USB-C, GPU PM) | Physical machines (exo-1 etc.) |

GitHub Actions E2E (`e2e.yml`) uses QEMU on `ubuntu-latest` runners.
The lab uses KubeVirt on `ghost` (Ryzen AI MAX+ 395, 64GB RAM, full KVM).
Neither replaces the other. Lab tests run on demand; E2E runs on every push.

## Scope by changed path

| Changed path | Lab variants to test |
|---|---|
| `system_files/shared/**` | bluefin + lts + dakota (all three) |
| `system_files/bluefin/**` | bluefin + lts |
| dconf / GNOME settings | bluefin + lts (dakota GNOME stack is BST-sourced) |
| `just/`, `Justfile`, `*.just` | all three (ujust ships to all variants) |
| `Containerfile` changes | all three |

## Posting lab results

When you verify a PR through the ghost cluster, the result must be posted as a
**Vanguard Lab Strike Report** PR comment. This is the canonical evidence format
for cluster verification. Copy the template from
[`projectbluefin/lab/docs/vanguard-report-template.md`](https://github.com/projectbluefin/lab/blob/main/docs/vanguard-report-template.md),
fill every field with real CLI evidence (workflow name/phase, `argo logs`, pod/VMI
state), and update an existing report comment from you rather than stacking duplicates.

This report is an explicit exception to the normal "don't post comments describing
your actions" convention — it is the lab result, not a status update.

## Lab infrastructure

| Item | Value |
|---|---|
| Cluster | k3s on ghost (192.168.1.102) |
| VM compute host | `ghost` — all KubeVirt VMs pinned here |
| Argo UI | `http://192.168.1.102:32746` |
| WorkflowTemplates | `provision-bluefin-vm`, `bib-build-and-push`, `teardown-bluefin-vm`, `dakota-bst`, `toggle-testing-rebase`, `bluefin-qa-pipeline`, `dakota-qa-pipeline`, `bluefin-migration-test` |
| SSH key secret | `bluefin-test-ssh-key` in `argo` namespace |
| SSH user | `bluefin-test` |

**Critical networking rule:** log-collection and test pods MUST set
`nodeSelector: kubernetes.io/hostname: ghost`. KubeVirt masquerade NAT iptables
rules live in the virt-launcher pod netns. A pod on `exo-1` cannot reach VM IPs.


## Detailed references

This skill was split on 2026-07-29 to stay under the 200-line soft budget (it
was 910 lines). Core when/scope/posting/infra guidance stays above; the rest
moved to `references/`:

| Need | Reference |
|---|---|
| Golden disk status, live toggle-testing methodology, firing up all three variants, reading journal output, submit smoke+system quick-start | [`references/methodology.md`](references/methodology.md) |
| Baseline vs delta methodology for reviewing a PR that touches systemd units/timers | [`references/pr-review-baselines.md`](references/pr-review-baselines.md) |
| Known issues and operational gotchas (SSH hangs, Argo template resolution, BIB build failures, capacity checks, VMI namespaces, etc.) | [`references/known-issues.md`](references/known-issues.md) |

## Relationship to GitHub Actions E2E

Lab tests and GitHub Actions E2E are complementary, not redundant:

```
common PR
    │
    ├─► pr-e2e.yml  ──────── PR gate: common suite on composed image
    │                         (QEMU, ubuntu-latest, ~12 min)
    │
    ├─► [merge to main]
    │
    ├─► e2e.yml  ───────────  post-merge: smoke+common on all 3 tags
    │                         (QEMU, ubuntu-latest, ~15 min)
    │
    └─► lab (on demand) ───── real KVM boot, systemd journal, system suite
                              (KubeVirt on ghost, full OS boot)
```

The lab catches:
- Services that fail silently in QEMU but crash with real KVM hardware topology
- Boot ordering regressions (`After=`, `Wants=` wiring in unit files)
- `ublue-system-setup.service` or `ublue-user-setup.service` failures
- Any service that reads `/sys` or `/proc` paths absent in QEMU
- First-boot setup regressions (`libsetup.sh` version-script failures)

## Filing bugs from lab results

For each failed unit or journal error found:

1. Identify which `system_files/` path owns the unit or config
2. Determine affected variants (shared → all three; bluefin/ → bluefin+lts)
3. File in the owning repo with label `bug`:
   - `common` if the unit/config ships from `system_files/`
   - `bluefin`/`bluefin-lts`/`dakota` if it's variant-specific
4. Include: variant name, kernel version, exact journal lines, workflow name
