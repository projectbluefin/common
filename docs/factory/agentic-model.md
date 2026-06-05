# Agentic Operating Model — projectbluefin

Deep reference for label taxonomy, branch targets, and sensitive paths. **Entry point is the target repo's `AGENTS.md`.** Load this file when you need label, branch, or path details beyond what AGENTS.md covers.

## Agent rules (hard)

- **AGENTS.md is the per-repo contract.** Read it first. Every repo has one.
- **One agentic whole.** Changes that touch common affect bluefin, bluefin-lts, and dakota. Think before merging.
- **No castrojo fork.** Agents push branches directly to projectbluefin repos and open PRs with `gh pr create --repo projectbluefin/<repo>`.
- **Attribution on every AI commit:** `Assisted-by: <Model> via <Tool>`
- **Squash only.** All 5 repos use squash merge. Never merge-commit or rebase-merge.
- **Max 4 open PRs per agent at once.**
- **`just check` and `pre-commit run --all-files` before every commit.** `just check` validates Justfile syntax; `pre-commit` catches trailing whitespace, missing newlines, YAML/JSON hygiene, and floating action tags across all files.
- **Prefer the smallest change that fully satisfies the requirement.** If a `.desktop` file with `Exec=xdg-open https://help.gnome.org/` fixes a broken help URI handler, that is the fix — not a custom script that parses URI components. Only add indirection or generalization when a concrete requirement demands it.

## Issue lifecycle

```
filed → approved → queued → claimed → done
```

| Stage | Trigger |
|---|---|
| `filed` | Issue opened |
| `approved` | Maintainer adds `status/approved` or comments `/approve` |
| `queued` | `queue/agent-ready` label added |
| `claimed` | Agent comments `/claim` — gets assigned, removed from pool |
| `done` | Fix shipped, verified |

No PR activity in 7 days returns a claimed issue to the queue.

## Label taxonomy

### Hive labels (dynamic — reset each cycle)
| Label | Meaning |
|---|---|
| `hive/p0` 🔴 | Release blocker — fix before next promotion |
| `hive/p1` 🟠 | Must land this cycle |

### Queue labels
| Label | Meaning |
|---|---|
| `queue/agent-ready` | Ready for an agent to pick up |
| `queue/claimed` | Agent has claimed this issue |
| `queue/hold` | Do not merge/close yet |
| `agent/blocked` | Agent blocked — needs human input |

### Priority labels (static backlog)
| Label | Meaning |
|---|---|
| `priority/p0` | Repo-level blocker |
| `priority/p1` | Must land soon |
| `priority/p2` | Backlog |

### Source labels
| Label | Meaning |
|---|---|
| `source:agent` | Filed or created by an agent |
| `source:manual` | Filed by a human |
| `source:gha` | Filed by GitHub Actions |

## PR policy

- One comment per PR event, max. Combine all findings into one comment.
- Never duplicate GitHub UI state (approvals, CI status).
- Test reports: what ran + pass/fail + blockers only. No diff summaries.
- `@` mentions only when asking someone to do something specific.
- When in doubt, post nothing.

## Branch targets

| Repo | PR target | Notes |
|---|---|---|
| bluefin | `testing` | Never `main` |
| bluefin-lts | `main` | `main→lts` is the promotion path |
| common | `main` | No testing branch |
| dakota | `testing` | Never `main` |
| knuckle | `main` | Installer, no testing branch |

## Sensitive paths (require maintainer review)

All repos: `.github/workflows/`, `Justfile`, `build_files/`
dakota only: `elements/`

## Finding work

```bash
# P0 blockers across org
gh search issues --label "hive/p0" --owner projectbluefin --state open

# Ready for pickup
gh search issues --label "queue/agent-ready" --owner projectbluefin --state open

# Live hive snapshot
just hive   # from ~/src
```
