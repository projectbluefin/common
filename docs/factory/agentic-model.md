# Agentic Operating Model — projectbluefin

Cross-repo agent rules. Every agent working in any factory repo MUST read this.
Per-repo specifics live in that repo's `AGENTS.md` — start there, then load this.

## Agent onboarding and self-repair

The onboarding sequence, the fixture checklist, and the per-loop self-repair
rule live once in
[`factory-onboarding.md`](../skills/factory-onboarding.md). Repositories link
to that procedure rather than copying common policy.

## Hard rules

- **The standard is the codebase itself.** Use what is in production already. When making technical decisions (like choosing a GitHub Action or CLI tool), your first step is to grep the existing codebase. If a tool (e.g., `ublue-os/remove-unwanted-software`) is already heavily used across the org's repos, that is the standard. Use it.
- **AGENTS.md is the per-repo contract.** Read it before touching anything.
- **Project Bluefin MCP server.** The org knowledge base is served over MCP at `https://mcp.projectbluefin.io/mcp` (wired in `.vscode/mcp.json` and `.cursor/mcp.json`). The server exposes exactly three tools:
  - `search_knowledge(query, limit)` — engineering patterns, coverage gaps, CI conventions, and per-repository findings across `projectbluefin/*`.
  - `get_factory_status()` — hub health, contributor counts, actionable-item count, per-tier contribution limits.
  - `get_work_queue()` — live Hive queue and triage buckets.
  - Offline fallback: `~/agent.md`, refreshed by `~/.local/bin/sync-hive-kb` (search with `grep`; never load the whole file into context).
- **Standard agentic repo setup.** The fixture checklist lives once, in [`factory-onboarding.md`](../skills/factory-onboarding.md#what-a-factory-repo-needs). Do not restate it here or in a repo's own docs.
- **Centralized org documentation authority.** `projectbluefin/common` is the centralized knowledge base and "org brain" for all factory-wide operating models, label taxonomy, onboarding rules, and cross-cutting skills. Downstream and peripheral repositories must not clone or duplicate these policies locally:
  - Repositories import `common` as a pinned sidecar contract (optionally validated via `config/factory-contract.json`).
  - Public documentation sites (such as `projectbluefin/documentation` and `projectbluefin/website`) link to `common` as the canonical authority, rather than declaring `actions` or local docs as the skills hub.
  - Public documentation builders (e.g., Docusaurus) must exclude internal skill files (`skills/**`, `SKILL.md`, `superpowers/**`) from public rendering.
  - Banned session artifacts (`NOTES.md`, `PLAN.md`, `TODO.md`, `docs/superpowers/{plans,specs}/**`, `CHANGELOG.md`) are strictly prohibited org-wide; session state lives in local agent session folders only.
- **One agentic whole.** `common` provides the foundational layer for `dakota` and `utah`. `dakota` consumes it as a pinned git source through BuildStream (`elements/bluefin/common.bst`, `kind: git_repo`, `url: github:projectbluefin/common.git`). `bluefin` and `bluefin-lts` are archived in this repository; `ublue-os/bluefin` is Bluefin Classic. High blast radius across active downstream consumers.
- **Org-wide automation lives in `projectbluefin/actions`.** `projectbluefin/housekeeping` is live and its GitHub description reads "Org-wide maintenance workflows for projectbluefin", but the repository ships zero workflows. Do not add maintenance automation there without a maintainer decision.
- **Squash where the repo enforces it.** `common`'s `main` ruleset restricts merges to squash. `actions`, `testsuite`, and `iso` additionally permit merge commits and rebase, and `testsuite` and `iso` do not delete the branch on merge. Check the repo's settings before assuming squash-only.
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
- **Never push directly to `main`.** Always open a PR. `main` in `common` is covered by one active ruleset with no bypass actors, so every change — documentation included — goes through the merge queue. Required approvals and required checks are listed in [`governance.md`](../skills/governance.md#how-main-is-protected).
- **CI gates protect the OCI image artifact.** A check earns `exit 1` only if failure means a broken or wrong image ships. Process conventions (attribution, skill files, doc formatting) are enforced at developer time by `pre-commit`; CI may re-run that suite as a single aggregate step, and that aggregate step is the only permitted place a process convention may fail a build. Never add a bespoke per-convention CI job.
- **Attribution on every AI-authored commit (convention, not a CI gate):**
  Standard across all factory repositories (do not invent per-repo alternatives like omitting Co-authored-by):
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

Image build and promotion are automated. Triage is not. The live Hive queue
holds 280 issues in `triaging` against 15 `ready`, 1 `implementing`, and 1
`reviewing`, with 1 active contributor of 15 registered. Never describe the
factory as automated end-to-end.

For `bluefin` and `bluefin-lts`:

1. Builds fire automatically (push to `testing`, Renovate digest bump, or cron)
2. Post-build E2E runs automatically
3. `promote-testing-to-main.yml` opens or updates a squash PR. `bluefin`
   triggers it on `push: testing` plus a daily cron; `bluefin-lts` triggers it
   on completion of its "Post-Testing E2E" `workflow_run` plus the same cron
4. The PR enters the merge queue and auto-merges once required checks pass
5. `execute-release.yml` fires on `push: main` → skopeo-copies `:testing` to
   `:stable` → GitHub release

`dakota` has no `promote-testing-to-main.yml`; its `execute-release.yml` runs
on its own cron instead.

### Release cadences

This table is the only place cadence is stated. Link here; do not restate.

| Pipeline | Schedule | Source |
|---|---|---|
| `common` release | 1st of the month, 00:00 UTC — skipped if the last release was under 20 days ago, or if any PR against `main` carries `label:hold` | `.github/workflows/release.yml` (`cron: '0 0 1 * *'`, `workflow_dispatch`) |
| `common` promotion-candidate E2E | Tuesday 03:00 UTC | `.github/workflows/promotion-candidate-e2e.yml` (`cron: '0 3 * * 2'`) |
| `bluefin` / `bluefin-lts` promotion PR | daily 04:00 UTC, plus each repo's own event trigger (see above) | each repo's `.github/workflows/promote-testing-to-main.yml` (`cron: '0 4 * * *'`) |
| `dakota` release | Mon/Wed/Fri 18:00 UTC | `dakota/.github/workflows/execute-release.yml` (`cron: '0 18 * * 1,3,5'`) |

Do not report the factory as broken because a promotion PR is open — the merge
queue processes it automatically.

## Branch targets

| Repo | PR target | Notes |
|---|---|---|
| `common` | `main` | No testing branch — PRs target `main` and go through the merge queue |
| `bluefin` | `testing` | Never `main` |
| `bluefin-lts` | `testing` | Never `main` — testing-first model, same as bluefin and dakota |
| `dakota` | `testing` | Never `main` — testing-first model, same as bluefin |
| `knuckle` | `main` | Flatcar / CoreOS deployment TUI — no testing branch |
| `testsuite` | `main` | Test repo — no testing branch |
| `actions` | `main` | Shared actions — no testing branch |
| `review` | `main` | Review appliance and Hive contributor worker — no testing branch |

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
| `image/`, `deploy/` | `review` only |
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

See [`docs/skills/label-workflow.md`](../skills/label-workflow.md) for the label contract.
