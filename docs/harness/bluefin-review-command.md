---
description: "Monitored PR backlog review for projectbluefin repos. Usage: /bluefin-review [owner/repo]"
argument-hint: "[owner/repo]"
---

Run the bluefin-review workflow for: "$ARGUMENTS". Empty means the org-wide queue: `gh search prs --owner projectbluefin --state open --limit 500` with `--review-requested @me`, `--author @me`, and `--assignee @me`, minus the standing exclusions and archived repos.

Before any other action, load the `bluefin-review` skill in full: `skill://bluefin-review` in omp, or `docs/skills/bluefin-review/SKILL.md` in projectbluefin/common. It is the rulebook for this run and wins over anything you remember from earlier sweeps.

Follow its run shape. Plan on this model using API reads only. Then call `todo init` with one item per lane and `write` the ledger's initial state. That write is the prewalk handoff to the fast model, so spawn no lanes, review no diffs, and create no worktrees before it.

After the handoff, fan out one lane per repo or PR cluster with `agent: "bluefin-review"` where the harness supports subagents. You own the policy tables, verification of every lane claim, and the final ledger.
