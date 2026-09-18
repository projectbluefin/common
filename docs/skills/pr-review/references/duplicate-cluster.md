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
fork heads, so there is no reason to decide from titles alone:

```bash
gh pr diff <A>
gh pr diff <B>
```

If the diffs are complementary, stop this procedure and leave both PRs open;
return to the competing-pair review instead. The tool must not infer a
survivor from the shared issue or dependency alone.

**2. Arm the survivor after an explicit per-item merge keypress and before
touching anything else.**

Read the head SHA live and pin the merge to it:

```bash
sha=$(gh pr view <S> --json headRefOid --jq .headRefOid)
gh pr merge <S> --squash --auto --match-head-commit "$sha"
```

`--match-head-commit` makes a push that lands between your read and the merge a
server-side refusal rather than a silent merge of unreviewed code.

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

Never `--reason "not planned"`, and never a label swap in place of a close.
Both misreport why the work went away.

**5. Re-check the linked issues.**

A still-open issue whose last open PR you just closed is a **finding to
report**, not something to silently fix. Surface it to the human.

## Why the order matters

Arming the survivor first (step 2) means that if anything later in the sequence
fails, the work still lands. Closing first and failing to arm leaves the
cluster with no open PR and an open issue — strictly worse than where you
started.
