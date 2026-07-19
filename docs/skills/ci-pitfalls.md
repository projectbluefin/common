---
name: ci-pitfalls
version: "1.0"
last_updated: 2026-07-19
tags: [ci, workflows, github-actions, pitfalls]
description: "Incident log of CI and workflow gotchas that caused silent failures or startup_failure across projectbluefin repos — branch-from-target, consumer PR format, caller permissions starvation, workflow_run name matching, merge_group sarif, Renovate automerge, buildah storage, ruleset check names, app token scoping. Use when debugging a CI failure that silently skips or shows startup_failure with no output."
metadata:
  type: reference
  context7-sources:
    - /actions/checkout
    - /actions/create-github-app-token
    - /github/codeql-action
    - /redhat-actions/buildah-build
    - /containers/skopeo
    - /renovatebot/renovate
---

# CI Pitfalls — incident log

> Split from [`ci-tooling.md`](ci-tooling.md) on 2026-06-24. This file holds the incident-log / gotcha entries — patterns that have caused silent CI failures or `startup_failure` across factory repos. [`ci-tooling.md`](ci-tooling.md) retains policy and config; [`shell-scripts.md`](shell-scripts.md) retains shell authoring and testability.

<!-- TODO(context7): verify all GitHub Actions behavior claims (workflow_run name matching, merge_group ref handling, create-github-app-token scoping, caller permissions inheritance) against upstream docs. These were documented from live incident debugging, not from Context7 lookups. -->

## When to Use

- Debugging a CI failure that silently skips a gate or shows `startup_failure` with no error output
- A merge queue PR is stuck or a post-merge e2e gate never fires
- A Renovate PR passes all checks but never merges
- A `build.yml` push step fails with `image not known` or `UNAUTHORIZED`
- A ruleset blocks the merge queue with no matching check name

## When NOT to Use

- Policy and configuration (SHA pinning, floating-tag guard, pre-commit hooks) → [`ci-tooling.md`](ci-tooling.md)
- Shell script authoring and testability patterns → [`shell-scripts.md`](shell-scripts.md)

---

## Contents
- [⛔ Branch-from-target rule (merge queue repos)](#-branch-from-target-rule-merge-queue-repos)
- [Bulk SHA bump — regex multiline trap](#bulk-sha-bump--regex-multiline-trap)
- [projectbluefin/actions PR — consumer validation evidence](#projectbluefinactions-pr--consumer-validation-evidence)
- [Caller-level permissions starvation](#caller-level-permissions-starvation)
- [workflow_run trigger — exact workflow name matching](#workflow_run-trigger--exact-workflow-name-matching)
- [merge_group + upload-sarif ref failure](#merge_group--upload-sarif-ref-failure)
- [Renovate automerge — how it works in common](#renovate-automerge--how-it-works-in-common)
- [build.yml — rootless buildah vs root podman storage](#buildyml--rootless-buildah-vs-root-podman-storage)
- [build.yml — GHCR login required before cosign signing](#buildyml--ghcr-login-required-before-cosign-signing)
- [renovate-automerge.yml — merge queue on main requires --auto, not direct merge](#renovate-automergeyml--merge-queue-on-main-requires---auto-not-direct-merge)
- [Ruleset required status check names must match exact CI job names](#ruleset-required-status-check-names-must-match-exact-ci-job-names)
- [create-github-app-token — do not use owner + repositories for cross-repo scoping](#create-github-app-token--do-not-use-owner--repositories-for-cross-repo-scoping)
- [Red Flags](#red-flags)
- [Verification](#verification)

---

## ⛔ Branch-from-target rule (merge queue repos)

Every projectbluefin repo runs a merge queue. A PR with merge conflicts or a dirty diff **cannot enter the queue** and stalls work for everyone on that branch.

**Root cause of dirty diffs:** Creating a branch from `main` when the PR targets `testing`. The `testing` branch in `bluefin`, `bluefin-lts`, and `dakota` accumulates CI and release-pipeline commits that never land on `main`. A branch created from `main` is missing those commits — the PR diff shows them all as "deleted".

### Branch targets

| Repo | PR targets | Branch FROM |
|---|---|---|
| `bluefin`, `bluefin-lts`, `dakota` | `testing` | `testing` |
| `common`, `actions`, `knuckle` | `main` | `main` |

### Mandatory pre-open gate (every PR)

```bash
TARGET=testing   # or main — match the PR target
git fetch origin

# 1. Only your files in the diff
git diff --name-only origin/${TARGET}..HEAD
# If unintended files appear → wrong base. Recreate from origin/${TARGET}.

# 2. No merge conflicts
git merge --no-commit --no-ff origin/${TARGET}
git merge --abort 2>/dev/null || true

# 3. No known red CI
# Do not open a PR if local tests fail. The merge queue will reject it.
just check && pre-commit run --all-files
```

### Recreating a branch with the wrong base

```bash
# Identify your commits
git log --oneline origin/${TARGET}..HEAD

# Recreate from the correct base
git checkout -b <branch>-clean origin/${TARGET}
git cherry-pick <your-sha1> <your-sha2> ...
```

*Observed violation: `projectbluefin/dakota` PR was created from `main` targeting `testing`. The `testing` branch had 20+ diverged commits — 12 workflow files, Justfile changes, and BST element updates all appeared as "deleted" in the diff. PR closed; clean PR recreated from `testing`.*

---

## Bulk SHA bump — regex multiline trap

When scripting a bulk `projectbluefin/actions` SHA pin update across workflow files, Python's `[^@]*` character class matches newlines. If the regex is `(projectbluefin/actions[^@]*)@([a-f0-9]{40})`, a line containing `projectbluefin/actions` in a **comment** (no `@` sign) will extend the match across subsequent lines until the next `@`, inadvertently replacing the SHA of unrelated actions (e.g., `actions/checkout`).

**Safe approach — line-scoped replacement:**

```python
import re

def bump_sha(content: str, new_sha: str) -> str:
    lines = content.splitlines(keepends=True)
    result = []
    for line in lines:
        # Only replace if projectbluefin/actions is on THIS line
        if 'projectbluefin/actions' in line:
            line = re.sub(
                r'(projectbluefin/actions[^@\n]*)@([a-f0-9]{40})',
                rf'\g<1>@{new_sha}',
                line,
            )
        result.append(line)
    return ''.join(result)
```

Key difference: `[^@\n]*` (excludes newline) instead of `[^@]*`.

**Verify after any bulk bump:**

```bash
# Find lines using the new SHA that are NOT from projectbluefin/actions
grep -rn "$NEW_SHA" .github/workflows/ | grep -v 'projectbluefin/actions'
```

If any non-`projectbluefin/actions` lines appear, restore their original SHAs.

---

## projectbluefin/actions PR — consumer validation evidence

Any PR to `projectbluefin/actions` that modifies an action or reusable workflow (`reusable-*.yml`, composite action `action.yml`) triggers the **Consumer Validation** CI check. The PR body must contain exactly these three lines:

```
Consumer PR: https://github.com/projectbluefin/{bluefin|bluefin-lts|dakota}/pull/{N}
Consumer CI run: https://github.com/projectbluefin/{repo}/actions/runs/{N}
Out-of-org consumer impact: {explanation or "N/A"}
```

### ⛔ Consumer PR body format — colon syntax is REQUIRED

The `check-consumer-contract.yml` regex matches `^Consumer PR:` **literally** (colon, no space before colon, space after). Using a Markdown heading silently fails:

```markdown
# WRONG — regex does not match a heading; check silently fails
## Consumer PR
https://github.com/projectbluefin/bluefin/pull/N

# CORRECT — colon format on one line
Consumer PR: https://github.com/projectbluefin/bluefin/pull/N
Consumer CI run: https://github.com/projectbluefin/bluefin/actions/runs/N
```

Same rule applies to `Consumer CI run:`. The CI run URL must point to a **passing** run in the consumer repo (bluefin, bluefin-lts, or dakota) that exercises the changed action.

Leaving these lines blank or using placeholder text (`TODO`, `TBD`, `<!-- ...-->`) fails the check. The CI error is: `Consumer validation evidence is required for action or reusable workflow changes. See docs/skills/consumer-validation.md.`

---

## Caller-level permissions starvation

<!-- TODO(context7): verify caller permissions inheritance behavior against GitHub Actions reusable-workflow docs -->

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

<!-- TODO(context7): verify workflow_run trigger name matching behavior against GitHub Actions docs -->

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

<!-- TODO(context7): verify merge_group ref behavior and upload-sarif limitations against codeql-action docs -->

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

---

## Renovate automerge — how it works in `common`

<!-- TODO(context7): verify platformAutomerge behavior and merge queue interaction against Renovate docs -->

`common` uses `platformAutomerge: true` in `renovate.json`. Renovate calls GitHub's native
auto-merge API when it opens an eligible PR (digest/pin/patch/minor). GitHub's auto-merge
enqueues the PR into the merge queue once all required checks pass — no separate workflow needed.

**Why `platformAutomerge` instead of a workflow:** `common/main` has a merge queue ruleset.
`github-actions[bot]` cannot bypass the merge queue, so any workflow attempting a direct
`--squash` merge would fail. `platformAutomerge` avoids this: Renovate is a bypass actor in the
PR review ruleset (actor_id 2740, bypass_mode: pull_request) and uses GitHub's own auto-merge
API, which the merge queue respects natively.

**Eligible update types:** `digest`, `pin`, `patch`, `minor`. Major bumps require human review.

**Bypass actors in the PR review ruleset:**
- OrganizationAdmin — `bypass_mode: always`
- Renovate (actor_id 2740) — `bypass_mode: pull_request`
- Mergeraptor (actor_id 3069633) — `bypass_mode: pull_request`

**Stuck Renovate PR (required checks passed but PR not merging):** Check that auto-merge is
enabled on the PR (`gh pr view <N> --json autoMergeRequest`). If null, Renovate hasn't enabled
it — check the `matchUpdateTypes` rule. If enabled but not merging, verify all required checks
(`validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)`) show SUCCESS or
SKIPPED. Org admin can force-merge via:
```bash
gh api repos/projectbluefin/common/pulls/<N>/merge -X PUT -f merge_method=squash
```

**`build.yml` paths-ignore and workflow-only Renovate PRs:** Renovate bumps GitHub Actions SHAs
via digest PRs that only change `.github/workflows/**`. The `pull_request` trigger in `build.yml`
intentionally does NOT ignore `.github/workflows/**` so required Build checks always run on these
PRs and the merge queue can satisfy them. The `push` trigger DOES ignore `.github/workflows/**`
to avoid redundant post-merge rebuilds.

---

## build.yml — rootless buildah vs root podman storage

<!-- TODO(context7): verify buildah rootless storage vs podman root storage namespace separation against buildah/podman docs -->

`build.yml` uses `redhat-actions/buildah-build` which stores images in **rootless user storage** (`~/.local/share/containers`). The `push-image` composite action uses `sudo podman push` which reads **root storage** (`/var/lib/containers`). These are different namespaces — the push will fail with `image not known` if the image is not in root storage.

**Fix already in place:** After `Export image for scanning`, a `sudo skopeo copy` step promotes the docker-archive into root `containers-storage` so `push-image` finds it.

```yaml
- name: Promote image to root storage for push
  if: github.event_name != 'pull_request'
  shell: bash
  run: |
    sudo skopeo copy \
      "docker-archive:/tmp/scan-image.tar:${{ env.IMAGE_NAME }}:${{ steps.generate-tags.outputs.local_tag }}" \
      "containers-storage:${{ env.IMAGE_NAME }}:${{ steps.generate-tags.outputs.local_tag }}"
```

Do not remove this step. Without it every push-to-GHCR fails silently until the next build.

---

## build.yml — GHCR login required before cosign signing

<!-- TODO(context7): verify cosign registry credential behavior and sign-and-publish step ordering against cosign docs -->

The `sign-and-publish` composite action's internal step order is: cosign sign (step 5) → ORAS registry login (step 12). Cosign has no GHCR credentials at step 5 and fails UNAUTHORIZED when pushing the signature blob.

**Fix already in place:** A `docker/login-action` step runs immediately before `sign-and-publish` in the manifest job.

Do not remove this step or reorder it after sign-and-publish.

---

## renovate-automerge.yml — merge queue on main requires --auto, not direct merge

<!-- TODO(context7): verify merge queue ruleset bypass actor behavior and gh pr merge --auto semantics against GitHub REST API docs -->

`common/main` has a **merge queue ruleset** (`main — merge queue`). `github-actions[bot]` is not a bypass actor for that ruleset. Calling `gh pr merge --squash` directly is rejected with:

```
The merge strategy for main is set by the merge queue
```

The reusable `reusable-renovate-automerge.yml` uses direct `--squash` merge (correct for `testing` branches which have no merge queue). Do **not** use it for `common`. The caller `renovate-automerge.yml` is intentionally inlined and uses `--auto --squash` to enqueue the PR. Since the workflow fires after a successful build, checks have already passed and the queue processes immediately.

**Symptom when broken:** The automerge workflow logs show `✅ Merged PR #N` but the PR remains open. The `||` catch in the merge command suppresses the real error; the success echo runs unconditionally after it.

**Fix already in place:** `renovate-automerge.yml` inlines the PR-find + enqueue logic with `gh pr merge --auto --squash` (PR #782). The reusable is not used here.

Do not "simplify" this back to the reusable — it will silently break again.

---

## Ruleset required status check names must match exact CI job names

<!-- TODO(context7): verify ruleset required status check matching semantics against GitHub branch protection / rulesets docs -->

The two branch rulesets on `main` must use the **exact** job names from `build.yml`. Wrong names silently block the merge queue — checks never arrive, queue waits forever.

Correct names (as of 2026-06-22):

| Ruleset | Required checks |
|---|---|
| `main — merge queue` (ID 17513003) | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |
| `main-review-required-with-renovate-bypass` (ID 17070417) | *(no required status checks — bypass actors cover Renovate/mergeraptor; merge queue ruleset handles build gate)* |

**Past breakage:** ruleset 17070417 had `"Build and push image"` (no arch suffix) — never matched any actual check, blocked every Renovate PR. Fixed 2026-06-22 by removing the check entirely from the review ruleset and using correct names in the merge queue ruleset.

If `build.yml` job names change, update both rulesets immediately via:
```bash
gh api --method PUT repos/projectbluefin/common/rulesets/17513003 --input ruleset.json
```

---

## create-github-app-token — do not use `owner` + `repositories` for cross-repo scoping

<!-- TODO(context7): verify create-github-app-token owner + repositories failure mode and cross-installation token creation against the action's docs -->

`create-github-app-token@v3` fails with `Invalid keyData` when `owner: <org>` + `repositories: <other-repos>` are specified. The action attempts cross-installation token creation which does not work reliably with this key format.

**Pattern to avoid:**
```yaml
uses: actions/create-github-app-token@...
with:
  owner: projectbluefin
  repositories: bluefin,bluefin-lts,dakota  # breaks
```

Use the token without `owner`/`repositories` restrictions — the mergeraptor app is installed org-wide and the default token already has access.

### notify-downstream token in common/build.yml

The `notify-downstream` job in `build.yml` uses `secrets.MERGERAPTOR_APP_ID` + `secrets.MERGERAPTOR_PRIVATE_KEY`. These secrets must be accessible to the `common` repo. If they are not, the job fails with:

```
The 'client-id' (or deprecated 'app-id') input must be set to a non-empty string.
```

Note: `vars.MERGERAPTOR_APP_ID` (variable, not secret) does **not** resolve in common — do not use it here. The correct ref is `secrets.MERGERAPTOR_APP_ID`. Verify at:
https://github.com/organizations/projectbluefin/settings/secrets/actions

The job has `continue-on-error: true` — build stays green while dispatches fail. Downstream tracking falls back to Renovate (bluefin/bluefin-lts) and dakota's daily cron.

---

## Red Flags

- A PR targets `testing` but the branch was created from `main`
- A reusable workflow job shows `startup_failure` with no error output (check caller `permissions:`)
- A `workflow_run`-triggered gate silently never fires (name mismatch)
- A Renovate PR passes all checks but never merges (check `autoMergeRequest`)
- A merge queue PR is stuck with no matching check name (ruleset check name drift)
- `create-github-app-token` fails with `Invalid keyData` (owner + repositories scoping)

---

## Verification

- [ ] For `.github/workflows/` changes, run `pre-commit run --all-files` and `actionlint .github/workflows/*.yml`
- [ ] If a pitfall describes GitHub Actions behavior (workflow_run, merge_group, permissions inheritance, app token), verify it against Context7 and record the library ID in frontmatter
- [ ] If a pitfall describes Renovate behavior (platformAutomerge, automerge API), verify it against Context7
- [ ] If a pitfall describes buildah/podman/cosign behavior, verify it against Context7
- [ ] Confirm the "Fix already in place" steps still exist in the workflow files they reference — do not document a fix that has been removed
