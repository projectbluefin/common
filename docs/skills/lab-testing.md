---
name: lab-testing
description: "KubeVirt lab testing for common — how to boot bluefin, bluefin-lts, and dakota on ghost and verify common-layer changes before promotion. Use when testing a common PR or change against real variant images on the homelab cluster."
metadata:
  type: reference
  context7-sources: []
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

## Lab infrastructure

| Item | Value |
|---|---|
| Cluster | k3s on ghost (192.168.1.102) |
| VM compute host | `ghost` — all KubeVirt VMs pinned here |
| Argo UI | `http://192.168.1.102:32746` |
| WorkflowTemplates | `provision-bluefin-vm`, `bib-build-and-push`, `teardown-bluefin-vm`, `dakota-bst` |
| SSH key secret | `bluefin-test-ssh-key` in `argo` namespace |
| SSH user | `bluefin-test` |

**Critical networking rule:** log-collection and test pods MUST set
`nodeSelector: kubernetes.io/hostname: ghost`. KubeVirt masquerade NAT iptables
rules live in the virt-launcher pod netns. A pod on `exo-1` cannot reach VM IPs.

## Golden disk status and build times

| Variant | Golden disk | Build needed? | Approx time |
|---|---|---|---|
| `bluefin` | `/var/tmp/bluefin-golden/latest/disk.raw` | ✅ rebuilt nightly 02:00 UTC | ~3 min (reflink boot) |
| `lts` | `/var/tmp/bluefin-golden/lts/disk.raw` | ⚠️ rebuilt by `ensure-disk` if empty | ~20 min first time, ~3 min after |
| `dakota` | `/var/tmp/dakota-golden/<tag>/disk.raw` | ⏳ needs BST build | ~10 min warm cache, ~45 min cold |

BST cache kept warm by `bst-cache-warm` CronWorkflow (every 6h on ghost).
The last successful nightly build is the benchmark: if it ran < 6h ago, dakota builds fast.

## How to fire up all three variants

Load the personal `lab-test` skill for the full workflow YAML.
From the Argo MCP, the pattern is:

```
1. argo_lint_workflow   → validate manifest
2. argo_submit_workflow → submit (bluefin immediately, lts/dakota in parallel)
3. argo_get_workflow    → poll status
4. argo_logs_workflow   → collect journal output from collect-logs step
```

Submit bluefin, lts, and dakota simultaneously — bluefin will finish first
(disk exists), lts mid (BIB build), dakota last (BST build).

## What to look for in journal output

The `collect-logs` step runs:
- `systemctl --failed --no-pager` — any failed units
- `journalctl -p warning -b --no-pager -n 300` — warnings and above from boot

**Expected noise (safe to ignore in QEMU):**
- `nvidia-persistenced.service`, `ublue-nvctk-cdi.service` — require physical GPU
- `systemd-oomd.service`, `systemd-oomd.socket` — require `/proc/pressure/` (PSI), absent in QEMU

**Anything else in `systemctl --failed`** = real bug in the image or common layer.
File an issue in the owning repo (`common`, `bluefin`, `bluefin-lts`, or `dakota`).

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

## Nightly smoke as baseline

The nightly CronWorkflows run at:
- `nightly-smoke`: 02:00 UTC — `bluefin:latest`, suites `smoke,system`
- `nightly-smoke-lts`: 02:30 UTC — `bluefin:lts`, suites `smoke,system`
- `nightly-dakota`: 03:00 UTC — dakota default, suites `smoke,system`

If a nightly is failing, that is the most urgent signal. Check with:
```
argo_list_workflows namespace=argo labels=bluefin.io/trigger=nightly
```

A nightly failure on `system` suite means a regression in the common layer or
downstream image that broke a bootc/systemd contract. Prioritize over feature work.

## Quick capacity check

Before submitting heavy lab workflows, verify headroom:

```
k8s_nodes_top                            # ghost RAM/CPU
argo_list_workflows namespace=argo       # active builds
k8s_resources_list apiVersion=kubevirt.io/v1 kind=VirtualMachineInstance
```

The `ghost-heavy-compute` mutex serialises BST and BIB build steps.
If a nightly or PR build is running, the BST step will queue.
