# Agentic Operating Model — projectbluefin

Cross-repo agent rules. Every agent working in any factory repo MUST read this.
Per-repo specifics live in that repo's `AGENTS.md` — start there, then load this.

## Hard rules

- **AGENTS.md is the per-repo contract.** Read it before touching anything.
- **One agentic whole.** `common` changes propagate to `bluefin`, `bluefin-lts`, and `dakota` at next build. High blast radius.
- **Org-wide automation lives in `projectbluefin/actions`.** Treat `projectbluefin/housekeeping` as a deprecated placeholder repo, not an active home for maintenance workflows.
- **No castrojo fork.** Push branches directly to `projectbluefin/*` repos, open PRs with `gh pr create --repo projectbluefin/<repo>`.
- **Squash only.** All factory repos use squash merge. Never merge-commit or rebase-merge.
- **Max 4 open PRs per agent at once.** No WIP PRs.
- **One PR per feature.** Never batch unrelated changes into a single PR. Each logical fix or feature gets its own branch and PR, even if the code changes are small. Reviewers should be able to review and revert independently.
- **Ask before opening PRs.** Do not open PRs autonomously. Present the plan and the diff, get explicit human approval, then open. Exception: Renovate bot PRs are pre-approved.
- **`just check` before every commit** in repos that have a Justfile.
- **`pre-commit run --all-files` before every commit** in repos with `.pre-commit-config.yaml`.
- **Never push directly to a protected branch.** Always open a PR. PRs require `lgtm` from a human.
- **Doc-only exception in `common`:** `docs/` edits and `AGENTS.md` changes may be pushed directly to `main` — no PR required. Before using this exception, confirm every changed path is under `docs/` or is `AGENTS.md`:
  ```bash
  git diff --cached --name-only  # must show only docs/* or AGENTS.md
  ```
- **CI gates protect the OCI image artifact.** A check earns `exit 1` only if failure means a broken or wrong image ships. Process conventions (attribution, skill files, doc formatting) are self-enforced by agents and must never appear as CI gates.
- **Attribution on every AI-authored commit (convention, not a CI gate):**
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
  Include both trailers. Do not implement attribution checking as a blocking CI step.

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
| `bootc-installer` | `dev` | Active work branch; `prod` triggers Flatpak release CI — never target `prod` directly |
| `testsuite` | `main` | Test repo — no testing branch |
| `actions` | `main` | Shared actions — no testing branch |

**Branch creation rule:** Always cut feature branches from the PR target, not from whatever is currently checked out.

```bash
# Before creating a branch, always fetch and branch from the target:
git fetch projectbluefin <target>
git checkout -b feat/my-change projectbluefin/<target>
# Example for bluefin (target = testing):
git fetch projectbluefin testing
git checkout -b feat/my-change projectbluefin/testing
```

Branching from the wrong base (e.g. `testing` when target is `main`, or vice versa) will cause the PR to show every diverged commit as new, polluting the diff and making review impossible. Verify before pushing:

```bash
git log feat/my-change ^projectbluefin/<target> --oneline  # must show ONLY your commits
```

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

- Read-only `gh api` calls to inspect `ublue-os` repos are permitted
- Everything else → **BANNED** without exception
- If a task requires `ublue-os` write access → **stop and tell the human to report it manually**

## Capturing gaps

When you discover something broken or missing in the factory during a session:

1. File a GitHub issue in `projectbluefin/common`
2. Required labels: one `kind/*` + at least one `area/*` (lifecycle guard enforces this)
3. Add `ai-context` if the gap affects how AI agents reason about the factory
4. **Do not** self-apply `hive/p0`, `hive/p1`, or `status/queued` — priority and queue admission are human decisions
5. **Do not** add it to a static doc section — docs are operating procedure, not backlogs

See [`docs/skills/label-workflow.md`](../skills/label-workflow.md) for the full label taxonomy and filing workflow.

## PR comment policy

- One comment per PR event, max. Combine all findings into one comment.
- Never duplicate GitHub UI state (approvals, CI status).
- Test reports: what ran + pass/fail + blockers only. No diff summaries.
- `@` mentions only when asking someone to do something specific. Never standalone.
- When in doubt, post nothing.

## Finding work

```bash
# P0 blockers across org
gh search issues --label "hive/p0" --owner projectbluefin --state open

# Ready for agent pickup
gh search issues --label "status/queued" --owner projectbluefin --state open
```

See [`docs/skills/hive.md`](../skills/hive.md) for the full hive label taxonomy and org board fields.
