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

| Kind | Detection | Action |
|---|---|---|
| **stale-red** | `validate` failure on a branch that predates the fix now on `main` | `gh pr update-branch <N>` — the branch carries its own copy of the broken script, so `gh run rerun` reproduces the same failure |
| **fork-expected** | `Compose PR test image` red + PR author is from a fork | Expected — the Actions token cannot push to `ghcr.io/projectbluefin/*` from fork context |
| **real failure** | Anything else | Report to human as blocking |
