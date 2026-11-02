---
name: repair-lane
version: "1.0"
last_updated: "2026-11-02"
id: repair-lane
one_line_purpose: Resolve review findings on a repair branch instead of only refreshing it.
entry_point: docs/skills/repair-lane.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [repair-lane, review-lifecycle, progress-contract, governance, derived-data]
description: >-
  Move a repair branch from changes-requested to ready by fixing the reviewed
  findings, not by rebasing. Use when a repair branch refreshes commits instead
  of fixing, regenerates derived data, or records a repair-to-merge receipt.
metadata:
  type: policy
---

# The repair lane and its progress contract

The repair lane takes a branch that a reviewer has asked changes to and moves
that branch from "changes requested" to "ready to merge" by actually making
the requested changes. It is a fixer, not a re-publisher.

A branch that is only rebased, force-pushed, or refreshed against an upstream
change has not fixed anything. Its review findings are still open. This skill
defines the observable progress contract every repair branch must satisfy
before its progress can be reported.

## When to Use

Use this skill when working a branch that carries an open human review
(changes-requested or blocking) and the only work so far has been branch
maintenance, or when recording how a finding was resolved for Hive.

## The progress contract

A repair branch makes progress only when every item below is true. If any item
is false, the branch has not advanced and must not be reported as fixed.

1. **The finding is addressed, not just refreshed.** Each thing the reviewer
   asked for is changed in the branch. Re-basing onto newer upstream commits,
   or re-running the same commit, does not count as a fix. If the requested
   change is unchanged since the review, the branch has made no progress.

2. **Main's inventory policy is preserved.** When regenerating derived data
   (counts, reports, lock files, generated lists), keep the policy that main
   already defines. Do not silently drop, add, or reorder inventory entries to
   make a diff look smaller.

3. **Only still-supported derived data is regenerated.** Regenerate a derived
   file only if the product it is derived from is still built and supported.
   Do not regenerate data for something that has been removed or is no longer
   released.

4. **Source-lock entries are whole and sorted.** When a file lists source
   locks or pinned sources, each entry is complete (no half-written fields) and
   the entries are in a single, consistent sort order. Partial or mixed-order
   entries are not reconciled.

5. **Current-head checks are used.** Pins and locks point at the current
   released head (for example the current https release archive), not an
   old or non-identical copy. If the current head is only reachable over http
   because the upstream has not published https, name that explicitly instead of
   hiding it.

6. **Removed snapshots are not restored.** If a previous change removed a
   count, report, or snapshot, the repair must not bring it back just to make a
   conflict resolve. Keep it removed.

7. **Changed behavior is exercised.** Run the relevant local checks and tests
   (`just check`, `just test`, or the check the domain uses) after the change.
   Green checks are the evidence that the fix works; a diff without them is not.

8. **A new exact-head review is obtained.** After the fix, the branch is
   re-reviewed against its new head. Progress is the reviewer's fresh sign-off on
   the changed code, not a self-declared "done". Moving the review lifecycle
   forward means the open human review is re-opened and resolved on the new
   head under this policy.

9. **Substantive objections are not auto-dismissed.** A changes-requested or
   blocking review is not cleared merely to reach merge state. It is closed only
   by a new evidence-backed re-review or an authorized resolution by someone
   with that authority. Say which one and show the evidence.

10. **The dependency is named and linked, not hidden.** If the fix genuinely
    cannot proceed until something outside this branch lands (a runtime
    dependency, an upstream release, an owner decision), record the exact
    remaining dependency and link it. A refresh of commits is not a dependency.

## The repair-to-merge receipt

Progress is recorded as a real chain, not a branch-update receipt. The receipt
shows, in order:

- **Repair** — what changed to satisfy each finding (with the check output),
- **Review** — the new exact-head review that cleared the finding,
- **CI** — the checks that passed after the change,
- **Hive merge receipt** — the merge that carried the branch forward, distinct
  from a branch-update or rebase.

A branch that only refreshed its commits produces a branch-update receipt. That
is not a repair-to-merge receipt.

## Repeated or refresh-only cycles

If the same finding reappears, or a branch cycle touches only commits and
branch state, record an actionable diagnostic instead of reporting progress:

- State the unchanged finding and the cycle that produced it.
- Name the owning task that will resolve the real cause.
- Link that task.

This keeps a refresh-only cycle from being mistaken for a resolution.

## Red Flags

- Reporting a rebase, force-push, or refresh as "finding resolved".
- Clearing a human changes-requested or blocking review without a new re-review.
- Restoring removed counts, reports, or snapshots to resolve a conflict.
- Regenerating derived data for a removed or unreleased product.
- Hiding an http-only or otherwise incomplete source lock.
- Recording a branch-update receipt as if it were a merge receipt.

## Verification

- [ ] Every requested finding has a matching change in the branch diff.
- [ ] `just check` and `just test` (or the domain's local checks) pass after the change.
- [ ] The open human review was re-obtained against the new head, or the authoritative resolution is recorded with evidence.
- [ ] Derived data, if regenerated, is for a still-supported product and keeps main's inventory policy, with sorted whole source-lock entries.
- [ ] Removed counts/reports/snapshots were not restored.
- [ ] Any unblockable dependency is named and linked, not described as a refresh.
- [ ] The receipt shows repair → review → CI → Hive merge, not a branch-update.
- [ ] `bash scripts/check-skill-frontmatter.sh` passes and the skill index is regenerated.
