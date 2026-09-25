# Reviewer Coverage Map — Per-Repo Reviewer Assignment (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed for [common#1058](https://github.com/projectbluefin/common/issues/1058);
> companion to [reviewer-ladder.md](reviewer-ladder.md) (common#1029).
> Nothing below changes GitHub roles, CODEOWNERS, branch protection, or agent-lane
> routing until a maintainer adopts it.
>
> The throughput columns are a **live snapshot, not a constant** — see
> [Refresh procedure](#refresh-procedure). Snapshot date: **2026-09-25**.

## What this is

[common#1058](https://github.com/projectbluefin/common/issues/1058) asked for a
per-repo reviewer coverage map — maintainer ↔ repo — so hold-gate growth can be
treated as repo-concentrated rather than volume-driven. This document is that
map, plus the commands that regenerate it, so it is a living reference instead
of a stale snapshot.

Two columns make up the map:

- **Owners of record** — what each repo's `.github/CODEOWNERS` names as the
  default reviewers. This is the *recorded* coverage, not a guarantee that any
  named owner is currently reviewing.
- **Throughput signal** — open hold-gated PRs (labelled `hold`) and PRs merged
  in the trailing 7 days, all authors counted. Merged counts measure review
  capacity in aggregate; they do not distinguish human review from auto-merge.

## Snapshot 2026-09-25

| Repo | Owners of record | Open hold-gated PRs | Merged, trailing 7d | Signal |
|---|---|---|---|---|
| common | `@projectbluefin/maintainers` + named owners (see `.github/CODEOWNERS`) | 3 | 57 | healthy |
| bluefin | `@projectbluefin/maintainers` | 4 | 26 | healthy |
| bluefin-lts | `@projectbluefin/maintainers` | 2 | 21 | healthy |
| dakota | `@projectbluefin/maintainers` | 0 | 58 | healthy |
| server | **none on record** | 1 | 40 | healthy; no CODEOWNERS |
| actions | @castrojo @p5 @m2Giles @tulilirockz | 1 | 34 | healthy |
| testsuite | **none on record** | 0 | 51 | healthy; no CODEOWNERS |
| finpilot | **none on record** | 1 | 27 | healthy; no CODEOWNERS |
| dakota-iso | **none on record** | 2 | 28 | healthy; no CODEOWNERS |
| fsdk-containers | **none on record** | 1 | 42 | healthy; no CODEOWNERS |
| **Total** | | **15** | | |

The `@projectbluefin/maintainers` team roster is only enumerable with
`admin:org` scope (`gh api orgs/projectbluefin/teams/maintainers/members`);
a maintainer can fill in the individual names, but the team is already the
owner of record, so the map above is complete as recorded.

## What changed since the #1058 finding (2026-09-05)

The finding measured a 33 → 88 hold-gate growth with four repos at or near zero
throughput (common 4, server 1, actions 0, dakota-iso 0 merges/7d). Re-measured
on 2026-09-25 that state has fully drained:

- Open hold-gated PRs: **88 → 15** across the same ten repos.
- Every repo the finding flagged now has double-digit weekly merges:
  actions 0 → 34, dakota-iso 0 → 28, server 1 → 40, common 4 → 57.

**Consequence for the #1058 decision:** option (b) — pause agent lanes feeding
un-reviewed repos — is **not supported by current data**. No repo is at
zero throughput, and the hold-gated queue is below the roadmap's <40 target
(common#1073 Phase 0). Pausing lanes now would remove supply from repos that
are demonstrably draining.

## What remains a maintainer decision (option (a))

Option (a) — assign/confirm an active reviewer for common, server, actions,
dakota-iso — remains open and is a human decision. The map makes the two
concrete gaps explicit:

1. **Five repos have no CODEOWNERS on record** (server, testsuite, finpilot,
   dakota-iso, fsdk-containers). Adding a CODEOWNERS line naming the owning
   team or individuals is the cheapest durable fix — it routes review requests
   automatically instead of relying on whoever notices the queue.
2. **Named-reviewer confirmation** for the repos the finding flagged. The
   throughput data shows somebody is reviewing, but the map cannot name who
   where only the team (not individuals) is recorded.

Until a maintainer acts on either, no lane changes are proposed here.

## Refresh procedure

Regenerate the throughput columns before acting on any decision that cites
this snapshot. From any checkout with a `GH_TOKEN`:

```bash
# Open hold-gated PRs per repo (label: hold)
for r in common bluefin bluefin-lts dakota server actions testsuite finpilot dakota-iso fsdk-containers; do
  echo "$r: $(gh pr list --repo projectbluefin/$r --state open --label hold --json number --jq 'length')"
done

# Merged in the trailing 7 days per repo (all authors)
for r in common bluefin bluefin-lts dakota server actions testsuite finpilot dakota-iso fsdk-containers; do
  since=$(date -u -d '7 days ago' +%F)
  echo "$r: $(gh api -X GET search/issues -f q="repo:projectbluefin/$r is:pr is:merged merged:>=$since" --jq '.total_count')"
done

# Owners of record per repo (404 = no CODEOWNERS)
for r in common bluefin bluefin-lts dakota server actions testsuite finpilot dakota-iso fsdk-containers; do
  echo "== $r"
  gh api repos/projectbluefin/$r/contents/.github/CODEOWNERS --jq .content 2>/dev/null | base64 -d | grep -v '^#' | grep -v '^$' || echo "  (none)"
done
```

Update the snapshot date in the status header and the table whenever the map
is cited for a decision. A snapshot older than ~14 days should be treated as
background, not evidence.

## What this document deliberately does not do

- No CODEOWNERS edits, here or downstream (maintainer decision; downstream
  copies are synced from this repo's triager section only).
- No agent-lane pausing or throttling (tracked in common#1052).
- No changes to merge protection, review requirements, or hold-gate
  enforcement (maintainer decision).
- No changes to the reviewer ladder itself — see
  [reviewer-ladder.md](reviewer-ladder.md).

## Related

- [common#1058](https://github.com/projectbluefin/common/issues/1058) — reviewer coverage map / repo-concentration finding (this doc's tracker)
- [common#1029](https://github.com/projectbluefin/common/issues/1029) — reviewer-scaling rung ([reviewer-ladder.md](reviewer-ladder.md))
- [common#1052](https://github.com/projectbluefin/common/issues/1052) — demand-side lane throttle
- [common#1043](https://github.com/projectbluefin/common/issues/1043) — hold-gate prioritization rubric
- [common#1073](https://github.com/projectbluefin/common/pull/1073) — org-wide ROADMAP.md (Phase 0: hold-gated queue <40)
