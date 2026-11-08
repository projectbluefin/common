# Card Fields Reference

## Required card fields

| Field | Source |
|---|---|
| Number, title, author | from dossier JSON |
| Age | `createdAt` → human-readable delta |
| Size | `+additions / -deletions` |
| Files touched | `files[].path` |
| Blast radius | see [Blast Radius Map](triage-operations.md#blast-radius-map) |
| CI status | `statusCheckRollup` — per-check, classified (see below) |
| `mergeStateStatus` | see table below |
| Linked issue | `closingIssuesReferences` |
| Competing / duplicate PRs | same files or same linked issue (auto-detected) |
| Summary | ONE factual sentence — what the change does |
| Effort | `trivial` · `small` · `needs-real-attention` · `blocked-on-something` |

> ⚠️ The agent classifies EFFORT but **never** states a verdict, recommendation,
> or approval judgment. Report facts only.

## `mergeStateStatus` values

`mergeable` and `mergeStateStatus` are computed **asynchronously** by GitHub
and can flip between calls with no push (observed: `UNKNOWN`→`CONFLICTING` on
#936 within 3 seconds). Always re-fetch immediately before staging a merge
command; never present `UNKNOWN` as if it were a definitive state.

| Value | Meaning |
|---|---|
| `CLEAN` | No conflicts, checks passing, ready |
| `BEHIND` | Head branch is out of date — needs `gh pr update-branch` |
| `DIRTY` | Real merge conflict — needs manual resolution |
| `BLOCKED` | Blocked by something other than checks/conflicts |
| `UNSTABLE` | Mergeable but a check is failing/pending |
| `UNKNOWN` | GitHub still computing — re-poll, state as unknown on the card |

## CI failure classification

Use the [red-check triage table](red-check-triage.md). A rerun uses the same
branch revision; it cannot pick up a fix that exists only on `main`.
