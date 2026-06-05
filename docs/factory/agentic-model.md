# Agentic Operating Model — projectbluefin

Deep reference for label taxonomy, branch targets, and sensitive paths. **Entry point is the target repo's `AGENTS.md`.** Load this file when you need label, branch, or path details beyond what AGENTS.md covers.

## Agent rules (hard)

- **AGENTS.md is the per-repo contract.** Read it first. Every repo has one.
- **One agentic whole.** Changes that touch common affect bluefin, bluefin-lts, and dakota. Think before merging.
- **No castrojo fork.** Agents push branches directly to projectbluefin repos and open PRs with `gh pr create --repo projectbluefin/<repo>`.
- **Attribution on every AI commit — both trailers required (CI-enforced in `validate.yml`):**
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- **Squash only.** All 5 repos use squash merge. Never merge-commit or rebase-merge.
- **Max 4 open PRs per agent at once.**
- **`just check` and `pre-commit run --all-files` before every commit.** `just check` validates Justfile syntax; `pre-commit` catches trailing whitespace, missing newlines, YAML/JSON hygiene, and floating action tags across all files.
- **Prefer the smallest change that fully satisfies the requirement.** If a `.desktop` file with `Exec=xdg-open https://help.gnome.org/` fixes a broken help URI handler, that is the fix — not a custom script that parses URI components. Only add indirection or generalization when a concrete requirement demands it.

## Issue lifecycle

```
filed → triage → queued → claimed → done
```

| Stage | Trigger |
|---|---|
| `filed` | Issue opened |
| `triage` | `status/triage` added automatically on open |
| `queued` | Maintainer comments `/approve` (requires `kind/` + `area/` to be set) |
| `claimed` | Contributor comments `/claim` — gets assigned, removed from pool |
| `done` | Fix shipped, verified |

No activity for 7 days returns a claimed issue to the queue (daily stale sweep).

Lifecycle automation lives in `projectbluefin/common/.github/workflows/lifecycle.yml` and is
called by every factory repo. See [`../skills/label-workflow.md`](../skills/label-workflow.md)
for the full reference.

## Label taxonomy

The full label reference, workflow, and human/agent instructions live in
[`../skills/label-workflow.md`](../skills/label-workflow.md). That file is the canonical
source of truth. The summary below is for quick agent lookup.

### Next-step lookup — who acts based on label

| Label | Actor | Do this |
|---|---|---|
| `status/triage` 🟣 | **Human** | Set `kind/` + `area/`, then comment `/approve` or add `status/discussing` |
| `status/discussing` 🔵 | **Human** | Drive to consensus, update spec, then comment `/approve` |
| `status/queued` 🟣 | **Agent** | Comment `/claim` |
| `status/claimed` 🟡 | **Agent** | Implement → open PR with `Closes #NNN` |
| `agent/blocked` 🔴 | **Human** | Read issue comment, unblock, remove label |
| `status/hold` ⬜ | *nobody* | Off-limits — read comments for reason |
| `pr/needs-review` 🟠 | **Human** | Review PR → add `lgtm` or request changes |
| `lgtm` + CI green 🟢 | *automation* | Merges automatically |

### Lifecycle (ordered)
```
status/triage → [status/discussing] → status/queued → status/claimed → done
```
`/approve` is the transition from triage/discussing → queued. No `status/approved` label exists.
Overlays (can coexist with any stage): `status/hold`, `agent/blocked`

### Hive labels (dynamic — reset each release cycle)
| Label | Meaning |
|---|---|
| `hive/p0` 🔴 | Cycle release blocker — fix before next promotion. Drop all other work. |
| `hive/p1` 🟠 | Must land this cycle. Pick over all `priority/` labels. |

### Priority labels (static backlog)
| Label | Meaning |
|---|---|
| `priority/p0` | Repo-level blocker — fix before other work |
| `priority/p1` | High priority |
| `priority/p2` | Normal backlog |

### Kind labels (set exactly one per issue during triage)
`kind/bug` · `kind/enhancement` · `kind/improvement` · `kind/tech-debt` · `kind/documentation` · `kind/translation` · `kind/epic` · `kind/wontfix`

### Source labels (set by automation — do not change manually)
| Label | Meaning |
|---|---|
| `source:agent` | Filed by an AI agent |
| `source:manual` | Filed by a human contributor |
| `source:gha` | Filed by GitHub Actions |
| `source:ujust-report` | Filed via `ujust report` on a live system |

### Labels being retired (do not use for new issues)
`bug`, `type/bug`, `type/feature`, `needs-human/agent-ready`, `agent/claimed`, `size:*` (colon variants), `copilot-ready`, `hold` (bare), `status/approved` — these are cleaned up automatically by `sync-labels.yml` when it runs.

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
gh search issues --label "status/queued" --owner projectbluefin --state open

# Live hive snapshot
just hive   # from ~/src
```
