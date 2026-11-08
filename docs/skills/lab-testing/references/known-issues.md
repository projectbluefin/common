# Lab Testing — Known Issues and Operational Notes

Standing gotchas and infrastructure quirks referenced from [`../SKILL.md`](../SKILL.md). Skim the headings below before debugging a lab run that behaves unexpectedly.

## Contents

- [Nightly smoke as baseline](#nightly-smoke-as-baseline)
- [Quick capacity check](#quick-capacity-check)
- [Log retrieval timing — critical](#log-retrieval-timing---critical)
- [Known issue: collect-evidence SSH hangs](#known-issue-collect-evidence-ssh-hangs)
- [Argo workflowTemplateRef resolves at submission time — not lazily](#argo-workflowtemplateref-resolves-at-submission-time---not-lazily)
- [toggle-testing-rebase and migration-upgrade-test only live on cluster](#toggle-testing-rebase-and-migration-upgrade-test-only-live-on-cluster)
- [ublue-os image package inventory](#ublue-os-image-package-inventory)
- [Observed disk check behaviour](#observed-disk-check-behaviour)
- [Known issue: BIB disk builds fail for bluefin-lts and dakota — SELinux PCRE2 mismatch](#known-issue-bib-disk-builds-fail-for-bluefin-lts-and-dakota---selinux-pcre2-mismatch)
- [BST build timing (dakota)](#bst-build-timing-dakota)
- [PR-specific composed image lab testing](#pr-specific-composed-image-lab-testing)
- [Namespaces for VMIs](#namespaces-for-vmis)

---

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
    name: build-bluefin-migration-containerdisk
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

### Container-only smoke lane failure modes

The `bluefin-qa-pipeline` container-only path (no KubeVirt VM) fails fast when the
runner environment or the cluster-local registry is not ready. Treat these as
infrastructure blockers, not PR regressions.

| Symptom | Root cause | Fix |
|---|---|---|
| `test-lane` exits 1 before any `BEHAVE RESULTS JSON`; logs reference display / GNOME session startup | Container runner cannot reach a usable GNOME session (lab infrastructure issue) | Wait for the lab infrastructure fix; do not retry the same SHA until the issue is resolved |
| `assert-cd` reports `missing` for `bluefin-containerdisk:testing` and no tests execute | The expected containerdisk is absent from the cluster-local Zot registry (digest-watch sync lag or the upstream image was not pushed) | Check registry/digest-watch state and re-trigger the image publish; do not re-run `bluefin-qa-pipeline` until the containerdisk exists |

If you see either pattern on multiple PRs simultaneously, it is a systemic lab
failure — label the PR(s) for human attention and file or update a
`projectbluefin/testing-lab` issue rather than blocking individual PRs.

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
