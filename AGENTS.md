# bluefin-common — Agent Operating Contract

`bluefin-common` is the shared layer for `dakota`, `utah`, and installation media.
Downstream consumption is focused on active systems: `dakota` consumes it as a pinned
git source via BuildStream (`elements/bluefin/common.bst`), while `utah` builds on
common definitions. Legacy `bluefin` and `bluefin-lts` images are archived here;
`ublue-os/bluefin` is now Bluefin Classic. Changes here propagate downstream. Stay surgical.

## Read order

1. This file — repo rules, build commands, and boundaries.
2. [`docs/SKILL.md`](docs/SKILL.md) — find the skill for your task and load it.
3. [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md) — cross-repo
   rules if the task spans repos.

For downstream factory onboarding, follow
[`docs/skills/factory-onboarding.md`](docs/skills/factory-onboarding.md):
target-repository authority comes first, common is a shared sidecar, and every
task loop must self-repair safely and write back durable learning.

## Instruction ownership

`.github/copilot-instructions.md` is strictly a thin pointer to `AGENTS.md` and nothing else. Never duplicate policy, instructions, or environment guidance into it or any user-level agent instruction file. `AGENTS.md` is the single authoritative repository contract.

## Build, test, and lint

```bash
just check                 # lint Justfile
just test                  # pytest + bats
just build                 # full OCI build (slow, requires podman + network)
pre-commit run --all-files # yaml/json/sha/actionlint hygiene
```

Run `just check` and `pre-commit run --all-files` before every commit.
Always audit staging (`git status`, `git diff --cached --name-only`) before committing; never `git add -A`.
Full testing contract (what must be tested, hardware gate boundaries, coverage
targets, exemptions): [`docs/TESTING.md`](docs/TESTING.md). Coding and
configuration style conventions: [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md).

## Factory workflow and ownership

The factory is automation-first. Workflows, branches, assignees, PR links, and merge queues advance work. Do not simulate workflow state by hand.

Triage is human and is the primary bottleneck. Query `get_factory_status()` / `get_work_queue()` for live state.

- **Canonical workflow-state labels:** [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md). Select at most one numbered state (`1-triage`, `2-discussing`, `3-human-queue`, `3-clanker-queue`, `4-review`), with optional `blocked` or `hold`. Conformance varies; inspect target repos with `python3 scripts/factory-conformance.py`.
- **Human intent:** Humans set intent via issues, forms, Hive metadata, reviews, and hold/routing decisions.
- **Agent execution:** Agents implement assigned work and link PRs with `Closes #NNN`. Do not claim work with slash commands.
- **Hive & Clankers relay:** Hive routes work; Clankers relays authenticated assignments. Verify repository and issue in GitHub before acting.
- **Issue forms:** Managed in `.github/ISSUE_TEMPLATE/` (`report.yml` and `config.yml`).
- **CODEOWNERS:** Reviews route by CODEOWNERS, but `require_code_owner_review: false` on active rulesets. Do not write to `ublue-os/*`.
- **Lifecycle automation:** Shared actions belong in `projectbluefin/actions`; bonedigger owns intake automation. `common` documents and consumes contracts.
Details: [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) and [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md).

## Agent fast path

- Query the org knowledge base via the `projectbluefin` MCP server
  (`https://mcp.projectbluefin.io/mcp`) before investigating, designing, or
  implementing. It serves exactly three tools:
  - `search_knowledge(query, limit)` — engineering patterns, coverage gaps, CI conventions across `projectbluefin/*`.
  - `get_factory_status()` — hub health, contributor counts, per-tier limits.
  - `get_work_queue()` — actionable queue and triage buckets.
  - Offline fallback: `~/agent.md` (refreshed by `~/.local/bin/sync-hive-kb`; query with `grep`, never load whole file into context).
- Skill routing: run `just skill <query>` or `python3 scripts/select-skill.py <query>` to discover relevant skills from `docs/skills/index.json`.
- Read source before asserting project-internal facts (image names, tags,
  workflow outputs). Use `gh api` to inspect workflows, not memory.
- Look up external tool docs via Context7 first — see `docs/skills/context7.md`.
- When a session surfaces a non-obvious pattern or workaround, update the
  matching `docs/skills/*.md` file in the same PR.

## Self-Improvement

Every session: ship the work AND update the relevant skill file in `docs/skills/`.
Same PR. Not a follow-up.

Banned:
- No changelog files. Delete `IMPROVEMENTS.md`, `CHANGELOG.md`, `SESSION.md` if found.
- No session notes committed to the repo (`NOTES.md`, `PLAN.md`, `TODO.md`).
- No "append here" docs. Route to `docs/skills/` instead.

Before marking work done:
- [ ] Discovered a workaround, pattern, or convention?
- [ ] Skill file updated (or created)?
- [ ] Committed in this same PR?

## What agents may touch

- `system_files/shared/` — global config. Directly tracked; the
  `aurorafin-shared` submodule dependency was severed.
- `system_files/bluefin/` — GNOME/Bluefin-specific config only.
- `system_files/nvidia/` — NVIDIA overlay.
- `Justfile`, `Containerfile`, tests, `docs/`, `AGENTS.md`, and
  `.github/workflows/`.

## What agents must not touch

- Any `ublue-os/*` repository (read-only; no writes of any kind).
- Vendored files under `system_files/bluefin/usr/share/gnome-shell/extensions/`.
- Org/app credential pairs; use `GITHUB_TOKEN` or provisioned GitHub Apps.

## Merging

**Every change requires a branch + PR targeting `main`. There is no exception.**

`main` is governed by the active ruleset `main — merge queue` (zero bypass actors). Classic branch protection is absent (`branches/main/protection` returns 404). Real gates:
- 2 required approving reviews (`require_code_owner_review: false`)
- 3 required status checks: `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)`
- Merge queue, squash-only, `ALLGREEN` grouping

Docs-only PRs merge without friction: `build.yml` ignores `docs/**`, `*.md`, and `AGENTS.md`, so the build checks skip and `validate` is the check that runs.

Re-derive live ruleset enforcement:
```bash
gh api repos/projectbluefin/common/rulesets --jq '.[]|select(.enforcement=="active")|.name'
```

## PR rules
- Conventional Commits title (`feat:`, `fix:`, `docs:`, `ci:`, `refactor:`).
- One logical change per PR.
- Skill doc updated in the same PR when implementation context changed.
- AI-authored commits include both attribution trailers as a convention:
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- Ask before opening PRs autonomously; prepare the branch and diff first.
- After pushing, verify CI is green:
  `gh run list --repo projectbluefin/common --limit 5`.

## Human decision gates

Stop and request human input before: Design, Security, Breakage (cross-repo
breaking changes), or Merge review. See `docs/skills/human-gates.md`.

## Scope warning

A broken change in `system_files/shared/` breaks `bluefin`, `bluefin-lts`, `dakota`, and installation media `iso` simultaneously. `dakota` additionally carries two patches against this repo (`patches/common/0001-fastfetch-install-date.patch`, `0002-ghostty-dual-theme.patch`), so changes to fastfetch or Ghostty configs can break its build without touching anything `dakota` owns. Test locally where possible.

## Code ownership

Code ownership rules live in [`.github/CODEOWNERS`](.github/CODEOWNERS). The real block is inside the `# BEGIN TRIAGERS` / `# END TRIAGERS` sentinels — read the file directly rather than relying on summarized excerpts.

CODEOWNERS configures reviewer routing only (`require_code_owner_review: false` on active rulesets; no CODEOWNERS entry blocks merges). See [`docs/skills/governance.md`](docs/skills/governance.md) for full team mappings and ruleset derivation.

## Canonical sources

| Topic | Source |
|---|---|
| Factory org structure | `docs/factory/README.md` |
| Which repos are on the factory workflow | `scripts/factory-conformance.py` (generated, not a table) |
| Cross-repo agent hard rules | `docs/factory/agentic-model.md` |
| Issue lifecycle / labels | `docs/skills/label-workflow.md` |
| Label vocabulary Hive expects | `scripts/hive-label-sync.py` (generated, not a table) |
| CI tooling / SHA pinning | `docs/skills/ci-tooling/SKILL.md` |
| Image registry / tags | `docs/skills/image-registry.md` |
| Skill improvement mandate | `docs/skills/skill-improvement.md` |
| PR review checklist | `docs/skills/pr-review/SKILL.md` |
| Testing contract | `docs/TESTING.md` |
| Apptainer SIF appliances / brew wrappers | `docs/skills/apptainer-sif/SKILL.md` |
| Review appliance & worker | `docs/skills/review-appliance.md` |
| Coding / config style guide | `docs/contributing/style-guide.md` |

## See also

- [`README.md`](README.md) — project overview for humans.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contributor quick start.
- [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) — workflow index.
- [`docs/TESTING.md`](docs/TESTING.md) — testing contract and coverage targets.
- [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) — coding and configuration style guide.
