# Lab Testing — Methodology Reference

Detailed procedures referenced from [`../SKILL.md`](../SKILL.md). Read the top-level skill first for when/how to post results; come here for the step-by-step mechanics of golden disks, live toggle testing, firing up variants, and reading journal output.

## Contents

- [Golden disk status and build times](#golden-disk-status-and-build-times)
- [Live toggle-testing methodology (production-accurate rebase testing)](#live-toggle-testing-methodology-production-accurate-rebase-testing)
- [How to fire up all three variants](#how-to-fire-up-all-three-variants)
- [What to look for in journal output](#what-to-look-for-in-journal-output)
- [Quick-start: submit smoke+system for a PR](#quick-start-submit-smoke+system-for-a-pr)

---

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

**Purpose:** Verify that the native `ujust toggle-testing` recipe works correctly
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
- It must execute the native `ujust toggle-testing` recipe, not a separate wrapper
- It exercises `--enforce-container-sigpolicy` against the real production cosign signatures

### Live toggle workflow pattern

Inspect the deployed `toggle-testing-rebase` WorkflowTemplate before using it
with stable as the starting point. Templates that still invoke `bctl` or
substitute a direct `bootc switch` after recipe failure need updating in their
owning repository. They do not prove the native recipe works. The requirements
below do not imply that the deployed template has already been updated:

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

### Required workflow behavior (step by step)

```
1. ensure-disk    → build/verify golden disk from :stable (BIB, ~20 min first run)
2. provision-vm   → btrfs reflink clone (~32ms), boot VM with stable image
3. pre-state      → collect-evidence: bootc status shows booted=stable ✓
4. toggle-to-target →
   a. Verify the VM contains the recipe revision under test
   b. Run ujust toggle-testing and accept its gum confirmation in a TTY
   c. Verify: bootc status shows staged=testing (live pull from GHCR)
   d. Fail if the recipe fails or no target is staged; do not bypass it
5. reboot-forward → VM reboots into the newly staged :testing image
6. verify-on-target → collect-evidence: bootc status shows booted=testing ✓
7. toggle-back    → same process, testing → stable (tests the reverse direction)
8. reboot-backward → VM reboots back to :stable
9. verify-on-start → collect-evidence: bootc status shows booted=stable ✓
10. teardown      → delete VM + disk.raw
```

### Required toggle-testing evidence

For each VM, per direction (forward + backward):
- **Recipe revision**: does the VM contain the change being tested?
- **Native recipe**: does `ujust toggle-testing` succeed after confirmation?
- **ujust toggle-testing logic** (verify actual behavior, not just a reimplementation):
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

> ⚠️ **Always check `systemctl is-enabled` in the baseline.** A clean boot and empty `systemctl --failed` does NOT mean the service is working — it may simply not be enabled. If a unit is disabled, it never runs and produces no journal output. This is silent: no errors, no warnings, just a no-op.
>
> ```bash
> systemctl is-enabled <unit-name>.service
> # "disabled" means it will never run at boot regardless of WantedBy
> ```
>
> If the service is disabled in the baseline, the review must also confirm there is a preset file or explicit `WantedBy=` + want symlink that will enable it in the built image. A unit file shipping without an enable mechanism means the change does nothing for users until the preset is also present.
>
> **Common scenario:** a preset file is added in the same or a prior PR but the current testing image was built before it merged — the service appears disabled in the lab even though the preset is correct in source. Always cross-check the preset file in the repo against the running image state.

## Quick-start: submit smoke+system for a PR

Copy-paste these to submit targeted lab tests. Always lint first with `argo-mcp-lint_workflow` before submitting.

### systemd unit / shared script — all 3 variants

Submit one per variant. Use `smoke` suite for a fast first pass; add `system` if you need full bootc contract verification.

```yaml
# bluefin:testing — smoke + system
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: pr-lab-bluefin-
  namespace: argo
spec:
  workflowTemplateRef:
    name: bluefin-qa-pipeline
  arguments:
    parameters:
    - name: image
      value: ghcr.io/projectbluefin/bluefin
    - name: image-tag
      value: testing
    - name: suites
      value: smoke,system
    - name: namespace
      value: bluefin-test
```

For lts: set `image: ghcr.io/projectbluefin/bluefin-lts` and `image-tag: lts-testing`.

### NVIDIA overlay — non-nvidia baseline check

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: pr-lab-nvidia-baseline-
  namespace: argo
spec:
  workflowTemplateRef:
    name: bluefin-qa-pipeline
  arguments:
    parameters:
    - name: image
      value: ghcr.io/projectbluefin/bluefin
    - name: image-tag
      value: testing
    - name: suites
      value: smoke
    - name: namespace
      value: bluefin-test
```

> ⚠️ This only confirms the nvidia service is absent on non-nvidia images (correct). To verify the actual change, run on a bluefin-dx or nvidia-enabled image variant after merge.

### Log collection pattern

Poll and collect logs immediately — log pods are recycled after workflow completion, **including Failed workflows**. If you wait until after the workflow object is archived, the failure diagnostics are gone.

```bash
# Poll until Succeeded/Failed
argo_get_workflow name=<workflow-name> namespace=argo

# Collect WHILE Running or immediately after Succeeded/Failed
argo_logs_workflow name=<workflow-name> namespace=argo

# Key commands to run inside the VM (via workflow steps or virsh guest-exec):
systemctl --failed --no-pager
journalctl -p warning -b --no-pager -n 200
systemctl is-enabled <unit-name>.service
systemctl cat <unit-name>.service
```

> ⚠️ Do NOT use `argo_wait_workflow` — it issues a blocking MCP call that times out before most workflows complete. Use `argo_get_workflow` to poll.

### Stale image gotcha

If the containerdisk was built before a recent PR merged, new files from that PR won't be present even though they're in the source. Always cross-check:

```bash
# Check when the current testing image was built
skopeo inspect docker://ghcr.io/projectbluefin/bluefin:testing | jq '.Created'

# Cross-check: when did the PR that added the file merge?
gh pr view <N> --repo projectbluefin/common --json mergedAt
```

If the containerdisk predates the PR, the lab baseline is stale. Wait for a rebuild (nightly at 02:00 UTC) or note it clearly in the report.

---
