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
| `lts-hwe` | `ghcr.io/projectbluefin/bluefin-lts-hwe:stable` | `/var/tmp/bluefin-golden/lts-hwe/` | ⚠️ built by `ensure-disk` on demand | ~20 min first time |
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
toggle-live-lts-hwe    bluefin-lts-hwe:stable → testing → stable
```

**`lts-hwe` status:** The HWE variant is published as its own image package:
`ghcr.io/projectbluefin/bluefin-lts-hwe:{stable,testing}`. It does **not** use
`bluefin-lts:lts-hwe` or `:lts-hwe-testing` tags. Use the dedicated image name
when exercising the HWE toggle flow. Monitor:
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

## Known issue: collect-evidence SSH hangs

**Template:** `bluefin-migration-test:collect-evidence` — used as an evidence-collection step in
some pipelines.

**Symptom:** The step runs for 10+ minutes without log output and eventually hits its
`activeDeadlineSeconds: 900` deadline, killing the pod and failing the workflow.

**Root cause:** The Python script inside `collect-evidence` uses `subprocess.run()` WITHOUT
a `timeout=` parameter for every SSH call. If any SSH command hangs on the VM (e.g.,
`loginctl status` waiting for a GDM session that's still starting, `bootc status` while
ostree is initialising, or `journalctl` on a large journal), the subprocess blocks
indefinitely. Since there is no `timeout=`, the Python process never returns from that call.
The step only dies when Kubernetes kills the pod after `activeDeadlineSeconds` seconds.

**Impact:** Workflows that use `collect-evidence` as a sequential step block the entire DAG
for up to 15 minutes before the step is killed. All downstream tasks (toggle, reboot,
verify) never execute.

**Fix applied in `toggle-testing-rebase`:** The `verify-bootc-state` inline template
(which replaced `collect-evidence` in the toggle pipeline) adds `timeout=<N>` to every
`subprocess.run()` call:
```python
subprocess.run(["dnf", "install", ...], timeout=120)
remote("sudo bootc status --json", timeout=45)
remote("cat /usr/share/ublue-os/image-info.json", timeout=15)
remote("systemctl --failed --no-pager", timeout=15)
```

**Upstream fix needed:** `projectbluefin/testing-lab` — add `timeout=` to all
`subprocess.run()` calls in the `collect-evidence` script template. Filed as a lab issue.

**Workaround for existing workflows using collect-evidence:** Set `continueOn: {failed: true}`
on the collect-evidence step so a timeout doesn't block downstream tasks. Or replace the
step with a focused inline `verify-bootc-state` template.

## Argo `workflowTemplateRef` resolves at submission time — not lazily

**Critical for lab ops:** When a Workflow uses `workflowTemplateRef`, Argo snapshots the
WorkflowTemplate at **submission time**. If you update the WorkflowTemplate after submission,
already-submitted workflows continue using the old definition — even for steps that haven’t
started yet.

This means:
- Fixing a bug in a WorkflowTemplate does NOT fix in-flight workflows submitted before the fix
- You must stop and resubmit to pick up the new template
- Applies to both cluster WorkflowTemplates and top-level `workflowTemplateRef`

**Symptom:** You update a template to remove a broken step (e.g. `collect-evidence`), resubmit
a workflow, but the workflow still runs the broken step — because it was submitted before the
template was updated.

**Workaround:** Always stop stuck old workflows (`argo_stop_workflow`) before resubmitting.
Verify the new workflow started AFTER the template update by checking `startedAt` in
`argo_get_workflow` vs. the template’s `resourceVersion`.

## toggle-testing-rebase and migration-upgrade-test only live on cluster

During this session, two WorkflowTemplates were created ad-hoc and applied to the ghost
cluster but are **not yet in the testing-lab GitOps repo**:

- `toggle-testing-rebase` — provision + toggle + reboot + verify, both directions
- `migration-upgrade-test` — ensure-disk from ublue-os image + provision + migration-sequence

Argo CD will NOT overwrite these (no conflicting GitOps definition exists), but they are not
managed and will be lost if the cluster is reset. File a PR to testing-lab to add them to
`argo/workflow-templates/`. See testing-lab#220 tracker thread for context.

## ublue-os image package inventory

Only two historical container packages existed under the `ublue-os` org:
- `ublue-os/bluefin` — main non-NVIDIA
- `ublue-os/bluefin-nvidia` — NVIDIA variant

There is NO `ublue-os/bluefin-lts` or LTS NVIDIA package. LTS-to-projectbluefin migration
testing is not possible from a ublue-os source image. Migration tests only cover the main
and NVIDIA variants.

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

## Known issue: BIB disk builds fail for bluefin-lts and dakota — SELinux PCRE2 mismatch

**Tracking:** [testing-lab#220](https://github.com/projectbluefin/testing-lab/issues/220)

**Symptom:** `bib-img-build` exits with code 1 within ~15 seconds:
```
setfiles: file_contexts.bin: Regex version mismatch, expected: 10.46 2025-08-27 actual: 10.44 2024-06-07
setfiles: Could not set context for kdump-dep-generator.sh: Invalid argument
CalledProcessError: setfiles returned non-zero exit status 255
```

**Root cause:** `quay.io/centos-bootc/bootc-image-builder:latest` ships `setfiles`/PCRE2 10.44.
`bluefin-lts:testing`, `bluefin-lts:lts`, and the dakota BST image ship an SELinux policy
compiled for PCRE2 10.46. The version mismatch causes `org.osbuild.selinux` to fail.

**Affected:** All `bluefin-lts-*` and `dakota-qa-*` golden disk builds.
**Unaffected:** `bluefin:testing` and `bluefin:stable` (older SELinux policy, PCRE2 10.44 compatible).

**Fix:** Update `bib-img-build` WorkflowTemplate to a newer `bootc-image-builder` image
that ships PCRE2 ≥ 10.46. Until fixed, skip all LTS and dakota lab tests that require BIB.

**Workaround:** None available server-side. `bluefin` (non-LTS) tests still work.

## BST build timing (dakota)

The BST build (freedesktop-sdk + dakota) takes:
- **Warm cache (~6h or less since last build):** ~10 min
- **Cold cache or new components:** 45+ min — builds gcc, python3, flex, etc. from source

Cache is warmed by `bst-cache-warm` CronWorkflow (00:00, 06:00, 12:00, 18:00 UTC).
If `nightly-dakota` (03:00 UTC) failed, the cache may be in an inconsistent state.
Check `argo_list_workflows status=["Failed"] namespace=argo` before submitting dakota.

## PR-specific composed image lab testing

The `pr-e2e.yml` workflow composes a full test image for every PR:
`ghcr.io/projectbluefin/common:e2e-pr-{pr_number}-{sha_short}`

**Critical:** `sha_short` is the first 7 chars of `GITHUB_SHA`, which for `pull_request`
events is the **merge commit** (PR branch merged into base) — NOT the PR branch HEAD.
To find the correct tag:

```bash
# 1. Get the merge commit for the PR
gh api "repos/projectbluefin/common/commits/$(gh pr view <N> --json headRefOid -q .headRefOid)" \
  --jq .sha | cut -c1-7
# That's wrong — GITHUB_SHA is the auto-merge commit, not the branch HEAD.

# Correct: check what tag was actually pushed to GHCR
gh api "orgs/projectbluefin/packages/container/common/versions?per_page=50" \
  --jq '.[].metadata.container.tags[]?' | grep "e2e-pr-<N>-"
```

The composed image exists in GHCR only briefly. The `pr-image-gc` CronWorkflow
(`nightly at 03:00`) removes old PR images. If the image is gone, push an empty commit
on the PR branch to retrigger `pr-e2e.yml`:

```bash
cd /var/home/jorge/src/common
git fetch origin <branch-name>
git checkout -B <branch-name> FETCH_HEAD
git commit --allow-empty -m "ci: retrigger PR E2E to rebuild composed image

Image was GC'd from GHCR by pr-image-gc cron.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push origin <branch-name>
# Then check GHCR for the new tag:
gh api "orgs/projectbluefin/packages/container/common/versions?per_page=20" \
  --jq '.[].metadata.container.tags[]?' | grep "e2e-pr-<N>-"
```

### Build the containerdisk first

`bluefin-qa-pipeline` has an `assert-cd` gate that fails if the containerdisk for the
image tag is not in the local Zot registry. The `build-containerdisk` WorkflowTemplate
must run successfully before submitting the qa-pipeline for a PR-specific tag:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: build-cd-pr<N>-
  namespace: argo
spec:
  workflowTemplateRef:
    name: build-containerdisk
  arguments:
    parameters:
    - name: image
      value: ghcr.io/projectbluefin/common
    - name: image-tag
      value: e2e-pr-<N>-<sha>     # exact tag from GHCR, not branch HEAD
    - name: containerdisk-tag
      value: e2e-pr-<N>-<sha>
    - name: force
      value: "false"
    - name: disk-size
      value: "20"
```

Then submit the qa-pipeline:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: pr<N>-actual-
  namespace: argo
spec:
  workflowTemplateRef:
    name: bluefin-qa-pipeline
  arguments:
    parameters:
    - name: image
      value: ghcr.io/projectbluefin/common
    - name: image-tag
      value: e2e-pr-<N>-<sha>
    - name: suites
      value: smoke
    - name: namespace
      value: bluefin-test
```

The `build-containerdisk` step takes ~20 minutes. The `assert-cd` check output
`missing` followed by `install-to-disk` beginning is expected — the pipeline builds
the containerdisk on demand.

### Build-containerdisk failure modes

| Symptom | Root cause | Fix |
|---|---|---|
| `manifest unknown` pulling image | Image was GC'd from GHCR | Re-trigger `pr-e2e.yml` via empty commit |
| `sfdisk: cannot open /dev/loop0: Invalid argument` + `Size: 0` | Loop device contention (multiple concurrent builds) | Wait for other `build-cd-sync-*` runs to finish, then retry |
| `readlink /var/lib/containers/storage/overlay/.../diff: no such file or directory` | Ghost containers storage overlay corruption | **Infrastructure issue** — needs ghost containers storage reset; file a lab issue |
| `no such table: ContainerConfig` | Podman SQLite DB corrupted on ghost | **Infrastructure issue** — all containerdisk builds will fail until ghost containers storage is cleaned |

When ghost's containers storage is corrupted, ALL `build-containerdisk` and
`build-cd-sync-*` workflows fail systemically. The `digest-watch` CronWorkflow will
generate a flood of failing retries every 5 minutes. Check for this pattern:

```
argo_list_workflows namespace=argo status=["Failed"]
# If you see many build-cd-sync-* failures in the last 10-15 min → ghost storage issue
# Check logs for "no such table: ContainerConfig" or readlink errors
```

This requires human intervention to clean ghost's containers storage. File an issue
in `projectbluefin/testing-lab` with the error and the failing workflow names.

### Auto-triggered vs. PR-specific pipeline

The `pr-label-poller` CronWorkflow triggers `bluefin-qa-pipeline` automatically when
a PR has the `lab-test` label. This auto-triggered run uses:
- `image-tag: testing` (not the PR-specific composed image)
- `containerdisk-tag: testing` (existing pre-built disk)

The auto-triggered run passes quickly (the `testing` containerdisk exists) but tests
the **base bluefin:testing** image, NOT the PR's new files. It confirms the VM boots
and smoke tests pass, but cannot verify PR-specific artifacts.

To verify PR-specific changes (new units, udev rules, drop-ins), you must:
1. Build a containerdisk from the PR-specific composed image (see above)
2. Submit the qa-pipeline with the PR-specific `image-tag`

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
