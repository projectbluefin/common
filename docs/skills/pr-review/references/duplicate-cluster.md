# Duplicate-Cluster Resolution

A competing pair that shares a *closing issue* — or two Renovate PRs that
normalize to the *same dependency* — is one piece of work submitted twice, not
an ordering hazard. Ordering does not fix it; one of the PRs has to go away.

Resolve the cluster as a unit, halting on the first failure.

## Procedure

**1. The human names the survivor.**

Present diff evidence first, then let the human choose. `gh pr diff` works for
fork heads, so there is no reason to decide from titles alone:

```bash
gh pr diff <A>
gh pr diff <B>
```

**2. Arm the survivor before touching anything else.**

Read the head SHA live and pin the merge to it:

```bash
sha=$(gh pr view <S> --json headRefOid --jq .headRefOid)
gh pr merge <S> --squash --auto --match-head-commit "$sha"
```

`--match-head-commit` makes a push that lands between your read and the merge a
server-side refusal rather than a silent merge of unreviewed code.

**3. Comment on each superseded PR** naming the survivor and the evidence.

Use `--body-file` — never pass prose through a shell with `--body`:

```bash
gh pr comment <D> --body-file /tmp/superseded.md
```

**4. Close the superseded PR.**

```bash
gh pr close <D>
```

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
