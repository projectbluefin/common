# Agentic Operating Model — projectbluefin

Cross-repo agent rules. Every agent working in any factory repo MUST read this.
Per-repo specifics live in that repo's `AGENTS.md` — start there, then load this.

## Agent onboarding and self-repair

The canonical downstream onboarding sequence is
[`factory-onboarding.md`](../skills/factory-onboarding.md). Every agent starts
with the target repository's `AGENTS.md` and local catalog, verifies its Hive
and GitHub assignment, then loads common as a pinned shared-contract sidecar.
Repositories should link to that procedure rather than copying common policy.

Every task loop performs preflight, detects stale or contradictory guidance,
repairs the nearest authoritative contract when safe and source-backed,
validates the repair, and records durable learning and evidence. Silent
fallback, wrong-repository work, repeated failures without a skill update, and
unrecorded learnings are failures. Self-repair never bypasses design, security,
cross-repository breakage, merge, or production human gates.

## Hard rules

- **The standard is the codebase itself.** Use what is in production already. When making technical decisions (like choosing a GitHub Action or CLI tool), your first step is to grep the existing codebase. If a tool (e.g., `ublue-os/remove-unwanted-software`) is already heavily used across the org's repos, that is the standard. Use it.
- **AGENTS.md is the per-repo contract.** Read it before touching anything.
- **Project Bluefin MCP server is mandatory.** Query the org knowledge base via `projectbluefin` MCP (`https://mcp.projectbluefin.io/mcp`) before investigating, designing, or implementing:
  - `search_knowledge(query, limit)` — engineering patterns, coverage gaps, CI conventions, and per-repository findings across `projectbluefin/*`. Always search relevant keywords first.
  - `get_factory_status()` / `get_work_queue()` — live Hive factory state.
  - Offline fallback: `~/agent.md`, refreshed by `~/.local/bin/sync-hive-kb` (search with `grep`, never load whole file into context).
- **One agentic whole.** `common` changes propagate to `bluefin`, `bluefin-lts`, and `dakota` at next build. High blast radius.
- **Org-wide automation lives in `projectbluefin/actions`.** Treat `projectbluefin/housekeeping` as a deprecated placeholder repo, not an active home for maintenance workflows.
- **Squash only.** All factory repos use squash merge. Never merge-commit or rebase-merge.
- **One PR per feature.** Never batch unrelated changes into a single PR. Each logical fix or feature gets its own branch and PR, even if the code changes are small. Reviewers should be able to review and revert independently.
- **Check for existing PRs before opening.** Before creating a branch for any issue, run:
  `gh pr list --repo projectbluefin/<repo> --state open --search "<topic>"`
  If an open PR already covers the work, comment on it rather than opening a duplicate.
- **Ask before opening PRs.** Do not open PRs autonomously. Present the plan and the diff, get explicit human approval, then open. Exception: Renovate bot PRs are pre-approved.
- **`just check` before every commit** in repos that have a Justfile.
- **`pre-commit run --all-files` before every commit** in repos with `.pre-commit-config.yaml`.
- **Staging audit before every commit.** Never use `git add -A` or `git add .`. After any script execution, build step, or cross-repo checkout, run:
  ```bash
  git status                        # check for unexpected tracked paths
  git diff --cached --name-only     # verify only intended files are staged
  ```
  Nested `.git` directories (worktrees, auxiliary clones) stage as gitlinks and silently corrupt history.
- **Never push directly to a protected branch.** Always open a PR. PRs require approval from a human reviewer.
- **Doc-only exception in `common`:** `docs/` edits and `AGENTS.md` changes may be pushed directly to `main` — no PR required. Before using this exception, confirm every changed path is under `docs/` or is `AGENTS.md`:
  ```bash
  git diff --cached --name-only  # must show only docs/* or AGENTS.md
  ```
- **CI gates protect the OCI image artifact.** A check earns `exit 1` only if failure means a broken or wrong image ships. Process conventions (attribution, skill files, doc formatting) are enforced at developer time by `pre-commit`; CI may re-run that suite as a single aggregate step, and that aggregate step is the only permitted place a process convention may fail a build. Never add a bespoke per-convention CI job — that is why `skill-drift.yml` was retired across the factory.
- **Attribution on every AI-authored commit (convention, not a CI gate):**
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
  Include both trailers. Do not implement attribution checking as a blocking CI step.

## Secrets and tokens — absolute prohibition

**Agents must never create, propose, or add new secrets, PATs, tokens, or credentials of any kind.**

- No new repository secrets, environment secrets, or organization secrets
- No PATs (personal access tokens) under any name
- No new GitHub App registrations or new app credential pairs
- No `secrets.NEW_THING` references in workflows that don't already exist

**When a workflow needs a capability it doesn't have, reach for documented git or GitHub primitives first:**

- Need to push content? → `permissions: contents: write`
- Sync workflow tries to push `.github/workflows/**` and `GITHUB_TOKEN` is blocked? → restore the target branch's own `.github/` after the merge so you never push workflow changes at all:
  ```bash
  git merge origin/main -X theirs --no-edit
  git checkout HEAD@{1} -- .github/   # restore target branch's own workflow files
  git add .github/ && git commit --amend --no-edit
  ```
- Some other gap? → stop and ask a human

Do not reach for tokens or credentials to solve what git operations can solve.

Humans decide when a new secret is needed. This is a security gate, not a convention.

## Smallest-change principle

**Prefer the smallest change that fully satisfies the requirement.** Only add indirection or generalization when a concrete requirement demands it. Resist scope creep — if it was not asked for, don't add it.

## What "autonomous" means for promotions

The factory is **fully automated** end-to-end. For bluefin, bluefin-lts, and dakota:

1. Builds fire automatically (push to `testing` / Renovate digest bump / daily cron)
2. Post-build E2E runs automatically (bluefin: required gate; bluefin-lts/dakota: advisory)
3. `promote-testing-to-main.yml` opens/updates a squash PR automatically on every push to `testing` and on the daily cron
4. The PR enters the merge queue and auto-merges once required checks pass (0 approvals required)
5. `execute-release.yml` fires on `push: main` → skopeo-copies `:testing` → `:stable` → GitHub release

**Releases are daily at 04:00 UTC** when `testing` differs from `main`. If there is nothing new, the promote workflow is a no-op.

Do not report the factory as broken because a promotion PR is open — the merge queue processes it automatically.

## Branch targets

| Repo | PR target | Notes |
|---|---|---|
| `common` | `main` | No testing branch — direct to main |
| `bluefin` | `testing` | Never `main` |
| `bluefin-lts` | `testing` | Never `main` — testing-first model, same as bluefin and dakota |
| `dakota` | `testing` | Never `main` — testing-first model, same as bluefin (PR 1004) |
| `knuckle` | `main` | Installer — no testing branch |
| `bootc-installer` | `dev` | Active work branch; `prod` triggers Flatpak release CI — never target `prod` directly |
| `testsuite` | `main` | Test repo — no testing branch |
| `actions` | `main` | Shared actions — no testing branch |

**Git workflow — three rules, no exceptions:**

```bash
# 1. Always branch from the current target, never from whatever is checked out
git fetch projectbluefin <target>
git checkout -b feat/my-change projectbluefin/<target>

# 2. Always rebase onto the target before pushing or opening a PR
git fetch projectbluefin <target>
git rebase projectbluefin/<target>

# 3. Verify your branch contains only your commits before pushing
git log HEAD ^projectbluefin/<target> --oneline  # must show ONLY your commits
```

After a PR merges: `git worktree remove <path> --force && git branch -D <branch>`. Clean up immediately, not later.

## Testing-first model

**The standard for all image-producing repos** (`bluefin`, `bluefin-lts`, `dakota`).

### Invariants

- All PRs target `testing`. **Never open a content PR against `main`.**
- `main` only receives squash-merge promotion commits from `auto/promote-testing-to-main`.
- GHA-only changes (workflow files, docs, markdown) **must not** trigger image builds.
- `:testing` tag publishes on every BST/Containerfile-changing push to `testing`.
- `:stable` / `:latest` tag publishes when `main` receives a promotion commit.
- If a repository uses a merge queue, every ruleset-required check workflow must include `merge_group: {types: [checks_requested]}` as well as its normal `pull_request` trigger; otherwise queued PRs wait forever for a check that never starts.

### CI pipeline shape

```
PR → testing branch
  └─ build.yml (push trigger, paths-ignore) → BST/container build → :testing published
  └─ e2e gate (post-merge-e2e.yml or testsuite) → pass/fail
  └─ promote-testing-to-main.yml → opens auto/promote-testing-to-main PR (daily cron or on e2e pass)
       └─ merge queue auto-merges PR → main → execute-release.yml publishes :stable
```

### paths-ignore pattern (required in build.yml push trigger)

```yaml
push:
  branches: [main, testing]
  paths-ignore:
    - '.github/workflows/**'   # workflow changes don't affect the image
    # .github/actions/** intentionally NOT ignored if local composite actions are used
    - 'docs/**'
    - '**.md'
    - 'AGENTS.md'
```

### Migration checklist (for adopting testing-first in a repo)

- [ ] `build.yml` push trigger includes `testing`, with `paths-ignore` block above
- [ ] `promote-testing-to-main.yml` source is `testing` → target is `main`
- [ ] Renovate `baseBranchPatterns` targets `testing`, not `main`
- [ ] `track-common.yml` (or equivalent) targets `testing`
- [ ] Any `sync-main-to-testing.yml` fast-forward workflow is removed
- [ ] Branch protection: `main` requires PRs; `testing` allows direct push for automation
- [ ] `agentic-model.md` branch table updated to `testing`
- [ ] Repo `AGENTS.md` fast-path updated to say "PRs target testing, never main"

## Sensitive paths

Changes to these paths require maintainer review before merge:

| Path | Scope |
|---|---|
| `.github/workflows/` | All repos |
| `Justfile` | All repos |
| `build_files/` | All repos |
| `elements/` | `dakota` only |

## Human decision gates

Agents implement autonomously **except** at the four named human gates:

| Gate | Trigger | Action |
|---|---|---|
| **Design** | Architectural changes, new subsystems, user-visible behavior changes | Present proposal, stop, wait for approval |
| **Security** | Authentication, signing, supply chain, secrets, third-party package sources | Present security impact, stop, wait for maintainer approval |
| **Breakage** | Public input changes, defaults affecting downstream repos (`bluefin`, `bluefin-lts`, `dakota`, `aurora`) | Identify consumers, describe blast radius, wait for approval |
| **Merge** | Final PR review and merge | Human reviewer approval required; agents never self-merge |

When hitting a gate: stop, present what was done and the decision needed, add the `blocked` label to the related issue, and wait for human decision. See [`docs/skills/human-gates.md`](../skills/human-gates.md).

## ublue-os absolute prohibition

**NEVER create issues, PRs, comments, forks, automated reports, webhook calls, or any programmatic write action targeting any `ublue-os/*` repository.**

- Read-only `gh api` calls to inspect `ublue-os` repos are permitted
- Everything else → **BANNED** without exception
- If a task requires `ublue-os` write access → **stop and tell the human to report it manually**

## Capturing gaps

When you discover something broken or missing in the factory during a session:

1. File a GitHub issue in `projectbluefin/common`
2. Describe the gap in the issue body — scope, impact, and what "fixed" looks like
3. **Do not** self-apply a queue label — triage and queue admission are human decisions
4. **Do not** add it to a static doc section — docs are operating procedure, not backlogs

See [`docs/skills/label-workflow.md`](../skills/label-workflow.md) for the full label taxonomy and filing workflow.

## PR comment policy

- One comment per PR event, max. Combine all findings into one comment.
- Never duplicate GitHub UI state (approvals, CI status).
- Test reports: what ran + pass/fail + blockers only. No diff summaries.
- `@` mentions only when asking someone to do something specific. Never standalone.
- When in doubt, post nothing.

## Finding work

```bash
# Work admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open
```

See [`docs/skills/label-workflow.md`](../skills/label-workflow.md) for the seven-label contract.
