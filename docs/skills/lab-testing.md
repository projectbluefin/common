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
| WorkflowTemplates | `provision-bluefin-vm`, `bib-build-and-push`, `teardown-bluefin-vm`, `dakota-bst`, `toggle-testing-rebase`, `bluefin-qa-pipeline`, `dakota-qa-pipeline`, `bluefin-migration-test` |
| SSH key secret | `bluefin-test-ssh-key` in `argo` namespace |
| SSH user | `bluefin-test` |

**Critical networking rule:** log-collection and test pods MUST set
`nodeSelector: kubernetes.io/hostname: ghost`. KubeVirt masquerade NAT iptables
rules live in the virt-launcher pod netns. A pod on `exo-1` cannot reach VM IPs.

## Golden disk status and build times

| Variant | GHCR image tag | Golden disk dir | Build needed? | Approx time |
|---|---|---|---|---|
| `bluefin:testing` | `ghcr.io/projectbluefin/bluefin:testing` | `/var/tmp/bluefin-golden/testing/` | ✅ rebuilt nightly 02:00 UTC | ~3 min (reflink boot) |
| `bluefin:stable` | `ghcr.io/projectbluefin/bluefin:stable` | `/var/tmp/bluefin-golden/stable/` | ⚠️ built by `ensure-disk` on demand | ~20 min first time |
| `lts:testing` | `ghcr.io/projectbluefin/bluefin-lts:testing` | `/var/tmp/bluefin-golden/lts-testing/` | ⚠️ built by `ensure-disk` on demand | ~20 min first time |
| `lts` (stable) | `ghcr.io/projectbluefin/bluefin-lts:lts` | `/var/tmp/bluefin-golden/lts/` | ⚠️ built by `ensure-disk` on demand | ~20 min first time |
| `lts-hwe` | `ghcr.io/projectbluefin/bluefin-lts:lts-hwe` | `/var/tmp/bluefin-golden/lts-hwe/` | ⚠️ built by `ensure-disk` on demand | ~20 min first time |
| `dakota` | built from BST on ghost | `/var/tmp/dakota-golden/<tag>/` | ⏳ needs BST build | ~10 min warm cache, ~45 min cold |

**Key distinction — `image` vs `image-tag` in `bib-build-and-push:ensure-disk`:**

```
image      = full GHCR ref including tag (e.g. ghcr.io/projectbluefin/bluefin-lts:testing)
               Used for: podman pull, BIB build source, skopeo digest check
image-tag  = golden disk directory name only (e.g. lts-testing)
               Used for: /var/tmp/bluefin-golden/<image-tag>/disk.raw path
```

These are NOT the same. Passing `image: ghcr.io/projectbluefin/bluefin-lts` without a tag
causes `podman pull` to attempt `:latest` which does not exist on projectbluefin images.
Always pass the full `image` ref with tag to `ensure-disk`.

The `bib-disk-check` step auto-appends `image-tag` to `image` when `image` has no `:` separator,
but `bib-img-pull` uses `image` verbatim — so always include the tag in `image`.

BST cache kept warm by `bst-cache-warm` CronWorkflow (every 6h on ghost).
The last successful nightly build is the benchmark: if it ran < 6h ago, dakota builds fast.

## Live toggle-testing methodology (production-accurate rebase testing)

**Purpose:** Verify that `ujust toggle-testing` / `bctl toggle-testing` works correctly
for real production users — not by testing with a pre-baked testing disk, but by starting
from a **stable** VM and rebasing live to **testing** exactly as a user would.

### Why this matters

There are two approaches to testing the toggle-testing recipe:

| Approach | Start | Toggle to | What it proves |
|---|---|---|---|
| **Disk-bake test** | `:testing` golden disk | `:stable` | Mechanics work; not production flow |
| **Live toggle test** ✅ | `:stable` golden disk | `:testing` (live GHCR pull) | Production user experience |

The live toggle test is the correct methodology because:
- It tests the actual recipe logic: reading `image-info.json`, detecting `stable` tag,
  constructing `ghcr.io/projectbluefin/bluefin:testing`, calling `bootc switch`
- The `:testing` image is pulled live from GHCR during the test — not from a local cache
- It validates `bctl toggle-testing` (bluefinctl path) AND `ujust toggle-testing` (bash fallback)
- It exercises `--enforce-container-sigpolicy` against the real production cosign signatures

### Live toggle workflow pattern

Use the `toggle-testing-rebase` WorkflowTemplate with stable as the starting point:

```yaml
# Bluefin: stable → testing → stable (production user flow)
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: toggle-live-bluefin-
  namespace: argo
spec:
  workflowTemplateRef:
    name: toggle-testing-rebase
  arguments:
    parameters:
    - name: image
      value: ghcr.io/projectbluefin/bluefin      # base for collect-evidence expected-image
    - name: disk-image
      value: ghcr.io/projectbluefin/bluefin:stable  # full ref for ensure-disk/bib-img-pull
    - name: start-tag
      value: stable                                  # golden disk dir + image-info tag
    - name: target-tag
      value: testing                                 # what toggle-testing switches TO
    - name: namespace
      value: bluefin-test
```

For LTS:
```yaml
    - name: image
      value: ghcr.io/projectbluefin/bluefin-lts
    - name: disk-image
      value: ghcr.io/projectbluefin/bluefin-lts:lts    # lts stable channel
    - name: start-tag
      value: lts
    - name: target-tag
      value: lts-testing
    - name: namespace
      value: bluefin-lts-test
```

### What the workflow does (step by step)

```
1. ensure-disk    → build/verify golden disk from :stable (BIB, ~20 min first run)
2. provision-vm   → btrfs reflink clone (~32ms), boot VM with stable image
3. pre-state      → collect-evidence: bootc status shows booted=stable ✓
4. toggle-to-target →
   a. Check bctl availability and version
   b. Run: echo yes | bctl toggle-testing  (or ujust toggle-testing)
   c. Verify: bootc status shows staged=testing (live pull from GHCR)
   d. If bctl didn't stage, guarantee via: sudo bootc switch ghcr.io/.../bluefin:testing
5. reboot-forward → VM reboots into the newly staged :testing image
6. verify-on-target → collect-evidence: bootc status shows booted=testing ✓
7. toggle-back    → same process, testing → stable (tests the reverse direction)
8. reboot-backward → VM reboots back to :stable
9. verify-on-start → collect-evidence: bootc status shows booted=stable ✓
10. teardown      → delete VM + disk.raw
```

### What the toggle-testing-rebase WorkflowTemplate tests

For each VM, per direction (forward + backward):
- **bctl availability**: is `bctl` installed and what version?
- **bctl toggle-testing**: does it correctly invoke `bootc switch` to the target?
- **ujust toggle-testing logic** (Python-side verification):
  - Reads `image-tag` from `/usr/share/ublue-os/image-info.json`
  - Applies the same mapping logic as the recipe (`stable→testing`, `lts→lts-testing`, etc.)
  - Confirms computed target matches expected
- **bootc switch**: does `bootc switch --enforce-container-sigpolicy <image>:<tag>` succeed?
- **Post-reboot state**: does `bootc status` show the correct booted image after reboot?

### Image tag mapping (toggle-testing recipe logic)

| Starting tag | Toggles to | Channel |
|---|---|---|
| `stable` or `latest` | `testing` | Bluefin stable → testing |
| `testing` | `stable` | Bluefin testing → stable |
| `lts` | `lts-testing` | LTS stable → testing |
| `lts-testing` | `lts` | LTS testing → stable |
| `lts-hwe` | `lts-hwe-testing` | LTS HWE stable → testing |
| `lts-hwe-testing` | `lts-hwe` | LTS HWE testing → stable |

Anything else produces: `Cannot toggle testing from channel '<tag>'`

### Coverage matrix

Run all three live toggle workflows in parallel:

```
toggle-live-bluefin    bluefin:stable → bluefin:testing → bluefin:stable
toggle-live-lts        bluefin-lts:lts → bluefin-lts:lts-testing → lts
toggle-live-lts-hwe    bluefin-lts:lts-hwe → lts-hwe-testing → lts-hwe  ← see note
```

**`lts-hwe` status:** As of 2026-06, `ghcr.io/projectbluefin/bluefin-lts:lts-hwe` and
`:lts-hwe-testing` are not yet published to GHCR. The `ujust toggle-testing` recipe
has the `lts-hwe` code path but the image variant has not shipped. Skip the lts-hwe
workflow until the variant appears in the image registry. Monitor:
```bash
ghcr.io/projectbluefin/bluefin-lts  # check available tags
```

These run alongside `bluefin-qa-pipeline` (smoke+developer suites) and `dakota-qa-pipeline`
for full coverage. Submit all 6 simultaneously — the `ghost-heavy-compute` mutex
serialises BIB builds safely.

## How to fire up all three variants

Load the personal `lab-test` skill for the full workflow YAML.
From the Argo MCP, the pattern is:

```
1. argo_lint_workflow   → validate manifest
2. argo_submit_workflow → submit (bluefin immediately, lts/dakota in parallel)
3. argo_get_workflow    → poll status
4. argo_logs_workflow   → collect journal output — MUST do while Running or immediately on Succeeded
```

Submit bluefin, lts, and dakota simultaneously — bluefin will finish first
(disk exists), lts mid (BIB build), dakota last (BST build).

### Check for existing log-scan workflows before submitting

Log-scan workflows run automatically (nightly and from CI). Before submitting a
new one, check if a recent run already has the data you need:

```bash
# kubectl is available on the local machine — use it to list + sort by age
kubectl get workflows -n argo --sort-by='.metadata.creationTimestamp' -o json \
  | python3 -c "
import json, sys
for w in sorted(json.load(sys.stdin)['items'],
                key=lambda x: x['metadata'].get('creationTimestamp',''),
                reverse=True)[:20]:
    print(w['status'].get('phase','?'), w['metadata']['creationTimestamp'], w['metadata']['name'])
"
```

`argo_list_workflows` returns a count but not names — use the kubectl command
above to get actual workflow names. `argo_get_workflow` then resolves the detail.

### Polling — do NOT use argo_wait_workflow

`argo_wait_workflow` issues a blocking MCP call that times out before most
workflows complete. Use `argo_get_workflow` to poll instead:

```
argo_get_workflow name=<workflow> namespace=argo
  → check nodeSummary.running / .succeeded counts and phase field
  → repeat every few minutes until phase = Succeeded or Failed
```

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
# NOTE: k8s_nodes_top is NOT available — metrics API absent on this cluster.
# Use kubectl for node resource view:
bash: kubectl top nodes 2>/dev/null || kubectl describe nodes | grep -A5 Allocated

argo_list_workflows namespace=argo       # active builds (returns count only — see kubectl command above for names)
k8s_resources_list apiVersion=kubevirt.io/v1 kind=VirtualMachineInstance  # running VMs (all namespaces)
```

The `ghost-heavy-compute` mutex serialises BST and BIB build steps.
If a nightly or PR build is running, the BST step will queue.

## Log retrieval timing — critical

**Logs from completed workflow pods are only available briefly.** Once Kubernetes
recycles the pod, `argo_logs_workflow` returns `{"logs":[], "message":"No logs available"}`
even for Succeeded workflows.

Strategy:
- Poll `argo_get_workflow` to know when the `collect-logs` step starts (phase Running,
  nodeSummary shows the collect-logs node running)
- Call `argo_logs_workflow` **while the workflow is still Running** to capture the journal output
- Or call it **immediately** after phase transitions to Succeeded
- If logs are already gone, re-submit a fresh log-scan workflow

## Observed disk check behaviour

The `bib-disk-check` step uses `skopeo inspect` to compare the live image digest
against the golden disk. Two outcomes observed:

| Output | Meaning | Next step |
|---|---|---|
| `stale` | skopeo inspect failed or digest changed | BIB rebuild triggered |
| `missing` | golden disk file does not exist | BIB build from scratch |
| `fresh` | digest matches | skip BIB build, boot directly |

`skopeo inspect` can fail transiently on rate limits or network hiccups — this
treats the disk as stale and triggers a rebuild, adding ~10 min. Expected occasionally.

## BST build timing (dakota)

The BST build (freedesktop-sdk + dakota) takes:
- **Warm cache (~6h or less since last build):** ~10 min
- **Cold cache or new components:** 45+ min — builds gcc, python3, flex, etc. from source

Cache is warmed by `bst-cache-warm` CronWorkflow (00:00, 06:00, 12:00, 18:00 UTC).
If `nightly-dakota` (03:00 UTC) failed, the cache may be in an inconsistent state.
Check `argo_list_workflows status=["Failed"] namespace=argo` before submitting dakota.

## Namespaces for VMIs

| Variant | VM namespace |
|---|---|
| bluefin | `bluefin-test` |
| lts | `bluefin-lts-test` |
| dakota | `bluefin-test` |

When checking if VMs are already running:
```
k8s_resources_list apiVersion=kubevirt.io/v1 kind=VirtualMachineInstance namespace=bluefin-test
k8s_resources_list apiVersion=kubevirt.io/v1 kind=VirtualMachineInstance namespace=bluefin-lts-test
```
No VMIs = no VMs currently booted (the log-scan workflows boot+teardown ephemerally).
Persistent VMs from failed teardowns are cleaned by `orphan-vm-cleanup` CronWorkflow (every 2h).
