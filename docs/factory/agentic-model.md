# Agentic Operating Model — projectbluefin

Cross-repo agent rules. Every agent working in any factory repo MUST read this.
Per-repo specifics live in that repo's `AGENTS.md` — start there, then load this.

## Hard rules

- **AGENTS.md is the per-repo contract.** Read it before touching anything.
- **One agentic whole.** `common` changes propagate to `bluefin`, `bluefin-lts`, and `dakota` at next build. High blast radius.
- **No castrojo fork.** Push branches directly to `projectbluefin/*` repos, open PRs with `gh pr create --repo projectbluefin/<repo>`.
- **Squash only.** All factory repos use squash merge. Never merge-commit or rebase-merge.
- **Max 4 open PRs per agent at once.** No WIP PRs.
- **`just check` before every commit** in repos that have a Justfile.
- **`pre-commit run --all-files` before every commit** in repos with `.pre-commit-config.yaml`.
- **Never push directly to a protected branch.** Always open a PR. PRs require `lgtm` from a human.
- **Doc-only changes in `common`** (`docs/` edits, `AGENTS.md`) may be pushed directly to `main` — no PR required.
- **Attribution on every AI-authored commit:**
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```

## Smallest-change principle

**Prefer the smallest change that fully satisfies the requirement.** Only add indirection or generalization when a concrete requirement demands it. Resist scope creep — if it was not asked for, don't add it.

## Branch targets

| Repo | PR target | Notes |
|---|---|---|
| `common` | `main` | No testing branch — direct to main |
| `bluefin` | `testing` | Never `main` |
| `bluefin-lts` | `main` | `main→lts` is the promotion path |
| `dakota` | `testing` | Never `main` |
| `knuckle` | `main` | Installer — no testing branch |
| `testsuite` | `main` | Test repo — no testing branch |
| `actions` | `main` | Shared actions — no testing branch |

## Sensitive paths

Changes to these paths require maintainer review before merge:

| Path | Scope |
|---|---|
| `.github/workflows/` | All repos |
| `Justfile` | All repos |
| `build_files/` | All repos |
| `elements/` | `dakota` only |

## ublue-os absolute prohibition

**NEVER create issues, PRs, comments, forks, automated reports, webhook calls, or any programmatic write action targeting any `ublue-os/*` repository.**

- `ghcr.io/ublue-os` registry **reads** are fine — production images still published there
- Read-only `gh api` calls to inspect `ublue-os` repos are fine
- Everything else → **BANNED** without exception
- If a task requires `ublue-os` write access → **stop and tell the human to report it manually**

## Finding work

```bash
# Session start — run first, every time
~/src/hive-status

# P0 blockers across org
gh search issues --label "hive/p0" --owner projectbluefin --state open

# Ready for agent pickup
gh search issues --label "status/queued" --owner projectbluefin --state open
```
