# Dismissed-Approval Regression Check

A `DISMISSED` review is not merely a stale approval to be re-collected. The
dismissal exists **because the head moved**, and the commits that moved it can
undo the very thing the reviewer approved.

## Why CI does not catch this

Observed in #815: a reviewer approved a PR whose two Go builder stages were
pinned to immutable commit SHAs. A later commit swapped both to mutable git
tags, dismissing that approval.

Every check stayed green — JSON lint, actionlint, and both image builds —
because the tags resolved to real, newer commits. The image built fine. The
only thing lost was the immutability guarantee, which no check asserts.

The regression was visible only by diffing against the approved SHA.

## Procedure

Find the commit each review was submitted against:

```bash
gh api repos/{owner}/{repo}/pulls/<N>/reviews \
  --jq '.[] | select(.state == "APPROVED" or .state == "DISMISSED")
        | {user: .user.login, state: .state, sha: .commit_id}'
```

Review only what changed since that approval:

```bash
git diff <approved_sha>...<current_head>
```

For a fork PR, fetch the approved commit first — it is not in the local repo:

```bash
git fetch https://github.com/<fork-owner>/<repo>.git <approved_sha>
git show <approved_sha>:<path>
```

Then read the dismissed reviewer's stated concerns as a checklist against the
**current head**, not against the branch as it stood when they wrote them.
Anything they called out as fixed must be re-verified as still fixed.

## What to look for

Changes that pass every check but silently weaken a guarantee:

| Regression | Why CI misses it |
|---|---|
| SHA pin → tag or branch | Still resolves; still builds |
| Digest pin → floating image tag | Still pulls; still runs |
| Checksum verification → `:no_check` | Install still succeeds |
| Test assertion commented out | Suite still reports green |
| Guard or `mkdir -p` removed | Only fails on a machine in the pre-migration state |

## Verification

- [ ] Every `DISMISSED` review's `commit_id` was resolved.
- [ ] The diff from that SHA to the current head was read in full.
- [ ] Each concern the reviewer marked resolved was re-verified against the head.
- [ ] Any weakened pin, checksum, or assertion was treated as blocking.
