# Permissions and Triggers — ci-pitfalls

Part of [ci-pitfalls](../SKILL.md) — caller-level permissions starvation, workflow_run exact name matching, and merge_group + upload-sarif ref failures.

---

## Caller-level permissions starvation

When a workflow calls a reusable workflow, the **caller's `permissions:` block is the maximum grant**. A reusable job that declares `permissions: contents: write` cannot exceed what the caller grants — it silently receives only `read`.

```yaml
# WRONG — caller grants only read; reusable's write permission is silently downgraded
jobs:
  call:
    permissions:
      contents: read
    uses: projectbluefin/actions/.github/workflows/reusable-promote.yml@<sha>

# CORRECT — caller grants the union of all permissions the reusable jobs need
jobs:
  call:
    permissions:
      contents: write
      packages: write
      id-token: write
      attestations: write
    uses: projectbluefin/actions/.github/workflows/reusable-promote.yml@<sha>
```

**Symptom:** The reusable job shows `startup_failure` with no further error output. Check the caller's `permissions:` block first — it is the most common root cause.

*Observed: caused `startup_failure` on every bluefin-lts promote push until fixed in bluefin-lts #162.*

---

## workflow_run trigger — exact workflow name matching

`workflow_run` triggers match on the **exact `name:` field** of the target workflow YAML file, not the filename. If the name drifts between repos or variants, the trigger silently never fires.

```yaml
# WRONG — watches "Build Bluefin LTS" but the HWE image is built by "Build Bluefin LTS HWE"
on:
  workflow_run:
    workflows: ["Build Bluefin LTS"]
    types: [completed]

# CORRECT — watch the workflow that actually produces the artifact you're testing
on:
  workflow_run:
    workflows: ["Build Bluefin LTS HWE"]
    types: [completed]
```

**Diagnostic checklist:**
1. Open the target workflow YAML and read the top-level `name:` field
2. Confirm that workflow actually produces the artifact you're gating on
3. Check: does the triggering workflow run on the branch you expect?

*Observed: bluefin-lts post-merge-e2e was watching `Build Bluefin LTS` but testing the HWE image (produced by `Build Bluefin LTS HWE`) — gate always skipped. Fixed in bluefin-lts #163.*

---

## merge_group + upload-sarif ref failure

`github/codeql-action/upload-sarif` fails for merge queue builds with:

```
##[error]ref 'refs/heads/gh-readonly-queue/main/pr-NNN-...' not found in this repository
```

The ephemeral `gh-readonly-queue/...` refs are not resolvable by `upload-sarif`. The PR Build already ran the scan; the merge queue build is redundant for CVE checking — its purpose is only to verify the combined commit builds cleanly.

**Fix:** Add `if: github.event_name != 'merge_group'` to both the export and scan steps:

```yaml
- name: Export image for scanning
  if: github.event_name != 'merge_group'
  ...

- name: Scan image for CVEs
  if: github.event_name != 'merge_group'
  ...
```

*Observed: blocked every PR in the merge queue until fixed in common #660.*

**Follow-up trap (common #826):** #660 skipped only the export/scan steps, but `Promote image to root storage`, `Push image`, `Write digest to file`, `Upload digest`, and the `manifest` job all ran on `!= 'pull_request'` — which includes `merge_group`. The promote step then read the never-exported `/tmp/scan-image.tar` and failed, silently ejecting every queue entry for two weeks. **Rule: the merge queue lane is build-only.** Any step that consumes an artifact from a step skipped in `merge_group`, or that pushes/signs/tags, must carry `github.event_name != 'pull_request' && github.event_name != 'merge_group'`. When adding a step to `build.yml`, trace which lanes (`pull_request`, `merge_group`, `push`) produce every file it reads.
