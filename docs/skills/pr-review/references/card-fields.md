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
| **stale-red** | `validate` failure + run timestamp < PR #937 merge (2026-08-07 00:41 UTC) | `gh pr update-branch <N>` (NOT `gh run rerun` — that re-executes the buggy branch copy) |
| **fork-expected** | `Compose PR test image` red + PR author is from a fork | Expected — Actions token cannot push to `ghcr.io/projectbluefin/*` from fork context |
| **real failure** | Anything else | Report to human as blocking |

> **Why not `gh run rerun` for stale-red?** The branch's own copy of
> `scripts/generate_skill_index.py` still contains the `date.today()` bug that
> #937 fixed. Re-running reproduces the same failure. The branch must ingest
> main first via `gh pr update-branch`.
