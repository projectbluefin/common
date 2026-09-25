# Stale Snapshot Check

Part of [pr-review](../SKILL.md) — verifying strategist/roadmap findings against
live state before acting on them.

Strategist and roadmap findings (e.g. common#1043, #1058, #1078) cite
point-in-time metrics: open hold-gated PR counts, per-repo merge throughput,
triage age. Those numbers can be **weeks stale by the time the issue reaches an
implementer** — observed on common#1058: the finding reported 88 open
hold-gated PRs and four repos at zero weekly merges (2026-09-05); re-measured
20 days later the queue was 15 and every flagged repo had 28–57 merges that
week. Acting on the stale numbers would have meant pausing lanes that were
feeding healthy repos.

## Rule

Before opening a PR that implements a metrics-based finding — especially a
priority-shift or throttle proposal — re-run the finding's own measurements
live and record the fresh numbers in the deliverable alongside the original.

1. **Identify the metric definitions** in the issue (which label, which window,
   which repos). If the issue does not define them, derive the closest
   equivalent and say so.
2. **Re-measure.** Typical commands:

   ```bash
   # Open PRs carrying the hold label
   gh pr list --repo projectbluefin/<repo> --state open --label hold --json number --jq 'length'

   # Merged PRs in the trailing N days (search API; `gh pr list --state merged`
   # with a `merged:>=` search string silently ignores the state filter)
   gh api -X GET search/issues \
     -f q="repo:projectbluefin/<repo> is:pr is:merged merged:>=$(date -u -d '7 days ago' +%F)" \
     --jq '.total_count'
   ```

3. **Compare.** If the gap the finding described has closed, the deliverable
   becomes the *record* that it closed — publish the fresh numbers, mark the
   finding's proposed intervention as not supported by current data, and leave
   the remaining decision to the maintainer. Do not implement a throttle,
   pause, or reorganization against numbers that no longer hold.
4. **Date every snapshot** in the deliverable and include the regeneration
   commands so the next reader can refresh instead of inheriting another stale
   number (see docs/contributing/reviewer-coverage.md for the pattern).

## Why `gh api search/issues`, not `gh pr list --state merged --search`

`gh pr list --state merged --search "merged:>=<date"` returns counts that match
the repo's *open* PR total — the search string overrides the state filter and
the merged state is dropped. The search API with an explicit `is:pr is:merged`
clause is the reliable form.
