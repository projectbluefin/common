# Duplicate-Cluster Resolution

A competing pair that shares a *closing issue* — or two Renovate PRs that
normalize to the *same dependency* — is a **candidate** duplicate cluster,
not proof that one PR must be closed. Compare the actual diffs: complementary
work stays as separate PRs. Resolve as a duplicate only after the human
confirms that it is the same work and names the survivor.

Resolve a confirmed cluster as a unit, halting on the first failure.

## Procedure

**1. The human confirms the duplicate and names the survivor.**

Present diff evidence first, then let the human choose. `gh pr diff` works for
fork heads, so there is no reason to decide from titles alone. Capture each
head SHA *with* the diff, so the evidence and the SHA describe the same code:

```bash
sha_A=$(gh pr view <A> --json headRefOid --jq .headRefOid)
sha_B=$(gh pr view <B> --json headRefOid --jq .headRefOid)
gh pr diff <A>
gh pr diff <B>
```

If the diffs are complementary, stop this procedure and leave both PRs open;
return to the competing-pair review instead. The tool must not infer a
survivor from the shared issue or dependency alone.

**2. Arm the survivor after an explicit per-item merge keypress and before
touching anything else.**

Pin the merge to the SHA you captured in step 1 — the head the human actually
reviewed. Never re-read the head at keypress time: a push that lands between
the evidence and the keypress would become the pinned head and merge
unreviewed.

`sha_S` is whichever of `sha_A` / `sha_B` belongs to the survivor the human
named — substitute that variable, do not re-read the head:

```bash
sha_S=$sha_A  # or $sha_B — the survivor's SHA from step 1
gh pr merge <S> --squash --auto --match-head-commit "$sha_S"
```

`--match-head-commit` makes any head that is not the reviewed one a
server-side refusal rather than a silent merge of unreviewed code. Reading the
SHA before rendering the diff (step 1) keeps drift in that safe direction: the
worst case is a refusal, never an unreviewed merge.

`--auto` only arms a merge that is still waiting on something. On a repo
without a merge queue, a survivor whose checks already pass has nothing to
queue, and GitHub rejects the request with `Pull request is in clean status`.
That is the common case for an already-green survivor, and it is **not** a
failure that should halt the cluster. Re-run without `--auto`, keeping the
same pin:

```bash
gh pr merge <S> --squash --match-head-commit "$sha_S"
```

The pin is the invariant, not the arming mode: both forms refuse if the head
moved off `$sha_S`. Never drop `--match-head-commit` to get a merge through,
and never reach for `--admin` without explicit human instruction.

On `common`, where `main` has a merge queue, the arming form is the one that
works and the direct form is the one that gets rejected — see
[`merge-queue.md`](merge-queue.md). Read the error before choosing: only
`in clean status` justifies the direct form. Any other rejection stops the
procedure.

A refusal is not an error to retry around. It means the survivor moved after
the human looked at it: go back to step 1, re-present the fresh diff, and take
a new keypress. Never re-read the SHA to make the merge succeed.

**3. After a separate explicit keypress for each item, comment on each
superseded PR** naming the survivor and the evidence. Run each command
individually; never use a loop, `xargs`, or another batch mutation.

Use `--body-file` — never pass prose through a shell with `--body`:

```bash
gh pr comment <D> --body-file /tmp/superseded.md
```

**4. After a separate explicit per-item close keypress, close one superseded
PR at a time.**

```bash
gh pr close <D>
```

Never close the whole cluster from a script or batch command.

Never swap a label in place of a close: the PR stays open while the board
claims the work went away.

**5. Re-check the linked issues.**

A still-open issue whose last open PR you just closed is a **finding to
report**, not something to silently fix. Surface it to the human.

Do not close that issue yourself, and never reach for
`gh issue close --reason "not planned"` to tidy it up. The work was superseded,
not abandoned, so that reason misreports why the issue went away.

## Why the order matters

Arming the survivor first (step 2) means that if anything later in the sequence
fails, the work still lands. Closing first and failing to arm leaves the
cluster with no open PR and an open issue — strictly worse than where you
started.
