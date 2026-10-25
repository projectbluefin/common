# Merge Queue Defaults and gh CLI Traps

Part of [pr-review](../SKILL.md) — merge queue settings, branch update commands, fork PR rebase procedure, and shell-level gh CLI traps.

## Merge Queue Defaults

Live parameters of ruleset `main — merge queue` (id `17513003`), the only
ruleset on `common`. Full rule dump: [governance.md](../../governance.md#how-main-is-protected).

| Setting | Value |
|---|---|
| Merge method | Squash only (`allowed_merge_methods: ["squash"]`) |
| Grouping strategy | `ALLGREEN` |
| Max entries to build | 5 |
| Check response timeout | 90 minutes |
| Required checks | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |
| Required approvals | **2** |
| Code-owner review | not required |
| Bypass actors | **none** |

Two human approvals are enforced by GitHub. The human verdict in this loop is
what produces them; it is not a substitute for them, and nobody can bypass the
ruleset.

E2E checks are **informational** — they do not block merging. Only the three
required checks above gate a merge. Unit Tests, Validate Brewfiles, Validate
ChairLift Config, and Scorecard are likewise non-required.

Docs-only PRs are not stuck: `build.yml` path-ignores `docs/**`, `*.md`, and
`AGENTS.md`, so both Build checks are skipped rather than pending and
`validate` alone carries the PR.

Default landing command:

```bash
# Squash-merge via the merge queue
gh pr merge <N> --squash --auto
```

> ⚠️ Do NOT use `--delete-branch` — the repo has `deleteBranchOnMerge: true`
> and the flag **hard-fails** when a merge queue is enabled.

`--admin` does **not** work here. Ruleset bypass is granted through
`bypass_actors`, and `main — merge queue` has none, so an admin merge is
rejected like any other. There is no override path; get the two approvals.

### Reading queue state

`autoMergeRequest` reads `null` once a PR has actually **entered** the merge
queue — the queue entry supersedes the auto-merge request. Do not treat that as
"auto-merge fell off" and re-arm blindly. Probe instead:

```bash
gh pr merge <N> --auto   # → "is already queued to merge" means it IS queued
```

`mergeStateStatus` also goes `UNKNOWN` for a minute or two while GitHub
recomputes mergeability after anything lands on `main`. That is not an error;
poll again rather than acting on it.

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
