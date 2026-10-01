# Merge Queue Defaults and gh CLI Traps

Part of [pr-review](../SKILL.md) — merge queue settings, branch update commands, fork PR rebase procedure, and shell-level gh CLI traps.

## Merge Queue Defaults

| Setting | Value |
|---|---|
| Merge method | Squash only (`allow_rebase_merge: false`) |
| Grouping strategy | `ALLGREEN` ("only merge non-failing pull requests") |
| Max entries to build | 5 |
| Required checks | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |
| Required approvals | **0** — and no code-owner review |

> ⚠️ The ruleset is named `main-review-required-with-renovate-bypass`, but the
> live rule requires **no** approval and **no** code-owner review. Never infer
> approval behavior from the ruleset name — read the live parameters.

Because approvals are not enforced, the human verdict in this loop is the only
real review gate on `main`. Treat it accordingly.

E2E checks are **informational** — they do not block merging. Only the required
checks listed above gate a merge.

Default landing command. Capture `REVIEWED_HEAD_SHA` alongside the card and
diff **before** the human verdict; never refresh it to make a merge pass:

```bash
gh pr merge <N> --squash --auto --match-head-commit "$REVIEWED_HEAD_SHA"
```

> ⚠️ Do NOT use `--delete-branch` — the repo has `deleteBranchOnMerge: true`
> and the flag **hard-fails** when a merge queue is enabled.

### Reading queue state

`autoMergeRequest` becomes `null` once a PR enters the queue. Never probe with
`gh pr merge --auto`: that command can arm an unqueued PR. Read queue state:

```bash
gh api graphql -F number="$N" \
  -f query='query($number:Int!){repository(owner:"projectbluefin",name:"common"){pullRequest(number:$number){mergeQueueEntry{id}}}}' \
  --jq '.data.repository.pullRequest.mergeQueueEntry'
```

A non-null entry means the PR is queued; otherwise check its current checks
and human verdict before any mutation.

`mergeStateStatus` also goes `UNKNOWN` for a minute or two while GitHub
recomputes mergeability after anything lands on `main`. That is not an error;
poll again rather than acting on it.

> ⚠️ Pushing directly to `main` — including the doc-only exception — bumps every
> queued PR behind the new head. Re-check the armed set after any direct push.

### Updating branches

`gh pr update-branch <N>` (default merge mode) works for both main-repo and
fork PRs — it is a server-side GitHub operation.

> The `--rebase` flag does NOT work on fork PRs (requires force-push across
> permission boundaries). Use the default merge mode.

### Fork PR rebase (when update-branch is insufficient)

When a fork PR has real conflicts that require manual resolution:

```bash
gh pr view <N> --json headRefName,headRepository \
  --jq '{branch: .headRefName, repo: .headRepository.nameWithOwner}'

git fetch https://github.com/<fork-owner>/common.git <branch>
git checkout -b <branch>-rebase FETCH_HEAD
git rebase origin/main
# resolve conflicts…
git push origin <branch>-rebase
gh pr create --base main --head <branch>-rebase \
  --title "<original title>" \
  --body "Rebased from #N. Co-authored-by: <original-author>"
```

---

## gh CLI Traps

Two shell-level traps that cost real session time:
`--body` runs prose through the shell (use `--body-file` with a quoted
heredoc), and non-trivial `--jq` expressions error rather than filter.
Details: [red-check-triage.md](red-check-triage.md#gh-cli-traps).

### Re-derivation commands

Verify the repo merge settings and rulesets with:

```bash
# Merge settings (deleteBranchOnMerge, squashMergeAllowed)
gh repo view --json deleteBranchOnMerge,squashMergeAllowed

# Rulesets and required checks
gh api repos/projectbluefin/common/rulesets

# Confirm merge queue behavior
gh api repos/projectbluefin/common/rulesets | jq '.[].rules[] | select(.type == "merge_queue")'
```
