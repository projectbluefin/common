# Troubleshooting the testing→main Squash Promotion

Part of [release-promotion](../SKILL.md) — Diagnosis and resolution for common promotion failures: gate stuck, UD conflicts, merge queue blocked, branch divergence, zombie publish runs, and actions branch policy.

## Contents
- [How the squash works](#how-the-squash-works)
- [Gate stuck — release/blocked with no E2E evidence](#gate-stuck--releaseblocked-with-no-e2e-evidence)
- [UD (Updated/Deleted) conflict](#ud-updateddeleted-conflict)
- [Merge queue enqueue blocked](#merge-queue-enqueue-blocked)
- [Source/target branch divergence on a shared file](#sourcetarget-branch-divergence-on-a-shared-file)
- [Zombie publish runs blocking the concurrency queue](#zombie-publish-runs-blocking-the-concurrency-queue)
- [Branch policy on projectbluefin/actions](#branch-policy-on-projectbluefinactions)

---

## How the squash works

`promote-testing-to-main.yml` squash-merges `testing` onto `main` by doing:

```bash
git checkout -B auto/promote-testing-to-main origin/main
git merge --squash origin/testing
git commit -m "chore: promote testing to main"
git push --force origin auto/promote-testing-to-main
```

---

## Gate stuck — release/blocked with no E2E evidence

**Symptom:** The promotion PR has `release/blocked` and the sticky gate comment reads:
> No completed post-testing-e2e run found for suites smoke,common on this PR head SHA.

The gate queries `GET /repos/{repo}/actions/runs?head_sha={TESTING_SHA}`. It looks for a completed run matching `post-testing-e2e.yml` (bluefin) or `Post-Merge E2E — Testing Parity` (bluefin-lts) associated with that exact SHA.

**Root causes in priority order:**

1. **E2E workflow only fires on main branch builds, not testing** — check `branches:` filter on the `workflow_run` trigger in `post-testing-e2e.yml` / `post-merge-e2e.yml`. Must be `[main, testing]`.
2. **The fix is on `testing` but not yet on `main`** — `workflow_run` triggers use the default branch (main) workflow file. A fix to the branches filter only takes effect once it reaches main.
3. **Gate jq selector mismatch** — the `reusable-release-gate.yml` selector uses `contains("post-merge e2e")` (hyphenated). Any variation (space instead of hyphen) silently fails to match.

> **Previously documented root cause — now fixed:** `reusable-promote-squash.yml` used to hardcode `E2E_HEAD_BRANCH: main` instead of resolving from `inputs.source_branch`. This caused the gate to query post-testing-e2e runs with the wrong SHA. Fixed in June 2026 — the reusable now uses `E2E_HEAD_BRANCH: ${{ inputs.source_branch }}`.

**Manual escape for the current cycle (bluefin only):**

```bash
# Comment /e2e on the open promotion PR to manually trigger E2E evidence
# Must be done by a maintainer with write access
gh pr comment <N> --repo projectbluefin/bluefin --body "/e2e"
```

Once the E2E passes for the testing SHA and the gate clears, the promotion PR auto-enqueues. After that first promotion, the fix lands on main and the system is self-sustaining.

**LTS and dakota** have no circular dependency — their PRs target main directly. Merging the fix PR is sufficient.

---

## UD (Updated/Deleted) conflict

**Symptom:** `promote-testing-to-main.yml` fails with `Automatic merge failed` and `git status` shows lines like:

```
UD .github/workflows/scheduled-stable-release.yml
UD .github/workflows/weekly-testing-promotion.yml
```

`UD` means: **testing deleted** the file, but **main still has it** (or vice versa). This happens when a PR removes a workflow from `testing` (e.g., consolidating to a reusable in `projectbluefin/actions`) but the deletion hasn't reached `main` yet.

**Resolution:** Accept the deletions from `testing` — they represent the intended state:

```bash
cd ~/src/bluefin
git fetch projectbluefin main testing
git checkout -B fix/rebuild-squash-promo projectbluefin/main
git merge --squash projectbluefin/testing  # will fail with UD conflict

# For each UD file, accept the deletion from testing:
git rm .github/workflows/scheduled-stable-release.yml

git commit -m "chore: promote testing to main"
git push projectbluefin fix/rebuild-squash-promo:auto/promote-testing-to-main --force
```

Then re-run `promote-testing-to-main.yml` via `workflow_dispatch` — it will detect the squash branch already matches testing and proceed to the enqueue step.

**Verify it's pre-existing** before touching anything: check if the `promote-testing-to-main.yml` run that failed predates your own merged PR. If it does, the conflict is not yours to own — but you can still fix the squash branch.

---

## Merge queue enqueue blocked

After rebuilding the squash branch, if `enqueuePullRequest` fails with:

```
Required status check "PR Validation — testsuite/validate (pull_request)" is expected.
```

The PR's CI checks have not yet completed against the new squash-branch HEAD. Wait for the `PR Validation — testsuite` workflow run to finish, then retry the enqueue.

If the error is `At least 1 approving review is required`:

- The `github-actions[bot]` (app ID 15368) is **not** in the bypass actors for `main-review-required-with-renovate-bypass`. It cannot self-approve.
- An OrganizationAdmin must approve the PR. The workflow's enqueue step will retry after approval.
- Do not bypass the ruleset with `--admin`; inspect approval state with the owning maintainer.

---

## Source/target branch divergence on a shared file

**Symptom:** `Promote main to lts` (or any squash promote run) fails with:

```
Auto-merging build_scripts/scripts/kernel-swap.sh
Process completed with exit code 1
```

`reusable-promote-squash` builds a squash of the source branch onto the target. If both branches independently modified the same file relative to their common ancestor, git hits a true merge conflict and exits 1. This repeats on **every** promote run until the divergence is resolved.

**Resolution:** Align the target branch (e.g. `lts`) to use the same content as the source branch (`main`) for the conflicting file. Since `lts` is a promotion snapshot of `main` — not an independent development branch — it must never diverge on shared build scripts.

```bash
# Find the exact diff:
gh api repos/<org>/<repo>/compare/lts...main --jq '.files[] | select(.filename == "<file>") | .patch'

# Fix: open a PR to lts syncing the diverged lines to match main
# Then the next squash promotion will apply cleanly
```

**Prevention:** After any rename of a build flag or variable (e.g. `ENABLE_GDX` → `ENABLE_NVIDIA`), search ALL branches and ALL scripts that consume it before merging. See bluefin-lts PRs #245, #249.

---

## Zombie publish runs blocking the concurrency queue

**Symptom:** `Publish` workflow runs stuck `in_progress` for > 30 min; new publish runs sit in `pending` indefinitely. The factory status script shows `Publish [main]: never` despite successful builds.

**Root cause:** `cancel-in-progress: false` on the publish concurrency group means stuck runner jobs hold the group indefinitely.

**Resolution:**

```bash
# Find the zombie runs
gh run list --repo projectbluefin/dakota --status in_progress \
  --json databaseId,name,headBranch,createdAt | jq '.[]'

# Cancel each one
gh run cancel <databaseId> --repo projectbluefin/dakota

# Re-trigger the promote workflow to rebuild the stale squash if PR is CONFLICTING
gh workflow run <promote-workflow-id> --repo projectbluefin/dakota --ref testing
```

---

## Branch policy on `projectbluefin/actions`

`projectbluefin/actions` has a branch policy that blocks non-admin merges (including the agent token). PRs to `actions` always require a human to merge. After merge, the `@v1` tag must be force-pushed:

```bash
cd ~/src/actions
git tag -f v1 HEAD
git push --force origin v1
```
