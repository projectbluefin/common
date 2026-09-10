# bluefin-common — Agent Operating Contract

`bluefin-common` is the shared OCI layer consumed by `bluefin`, `bluefin-lts`,
and `dakota`. Changes here propagate to every variant. Stay surgical.

## Read order

1. This file — repo rules, build commands, and boundaries.
2. [`docs/SKILL.md`](docs/SKILL.md) — find the skill for your task and load it.
3. [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md) — cross-repo
   rules if the task spans repos.

For downstream factory onboarding, follow
[`docs/skills/factory-onboarding.md`](docs/skills/factory-onboarding.md):
target-repository authority comes first, common is a shared sidecar, and every
task loop must self-repair safely and write back durable learning.

## Build, test, and lint

```bash
just check                 # lint Justfile
just test                  # pytest + bats
just build                 # full OCI build (slow, requires podman + network)
pre-commit run --all-files # yaml/json/sha/actionlint hygiene
```

Run `just check` and `pre-commit run --all-files` before every commit.

Full testing contract (what must be tested, hardware gate boundaries, coverage
targets, exemptions): [`docs/TESTING.md`](docs/TESTING.md). Coding and
configuration style conventions: [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md).

## Factory workflow and ownership — Trust the Machines

The factory is automation-first: workflows, branches, assignees, projects,
PR linkages, and merge queues advance active work. Do not simulate workflow
state by hand or invent transitions that are not implemented in the checkout.

- **The seven canonical labels:**
  [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md).
  Select at most one numbered workflow label (`1-triage`, `2-discussing`,
  `3-human-queue`, `3-clanker-queue`, `4-review`), with `blocked` or `hold` as
  an optional overlay; automation enforces the combination and routes the next
  action.
- **Humans provide intent** through issue content, form fields, Hive metadata,
  review, and explicit hold or routing decisions.
- **Agents implement assigned work** and link it to a PR with `Closes #NNN`;
  they do not claim work with slash commands or manufacture queue state.
- **Hive coordination & Clankers relay:** Hive may select work for another
  monitored repository. Clankers is only the authenticated relay for that
  assignment; verify the assigned repository and issue in GitHub before acting.
  It does not bypass human approval, review, or merge gates.
- **Issue forms & CODEOWNERS ownership:** This repository owns its own issue
  forms in `.github/ISSUE_TEMPLATE/`; there is one form, and it doubles as the
  contributor's introduction to the label workflow. The triager section of
  CODEOWNERS is owned here and synced to downstream factory repositories; edit
  downstream copies only when the repository-specific section is explicitly in
  scope. Never write to `ublue-os/*`.
- **Reusable lifecycle automation** belongs to `projectbluefin/actions`;
  bonedigger owns report intake and report-specific automation. `common`
  documents and consumes these contracts; it does not own their
  implementations.

See [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) and
[`docs/factory/agentic-model.md`](docs/factory/agentic-model.md).

## Agent fast path

- Mandatory: query org knowledge base via `projectbluefin` MCP (`search_knowledge`) before investigating, designing, or implementing. Offline fallback: `~/agent.md`.
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

- `system_files/shared/` — global config (also consumed by Aurora).
- `system_files/bluefin/` — GNOME/Bluefin-specific config only.
- `system_files/nvidia/` — NVIDIA overlay.
- `Justfile`, `Containerfile`, tests, `docs/`, `AGENTS.md`, and
  `.github/workflows/`.

## What agents must not touch

- Any `ublue-os/*` repository (read-only; no writes of any kind).
- Vendored files under `system_files/bluefin/usr/share/gnome-shell/extensions/`.
- Org/app credential pairs; use `GITHUB_TOKEN` or provisioned GitHub Apps.

## Doc-only push exception

Changes that touch only `docs/**` and/or `AGENTS.md` may be pushed directly to
`main` without a PR. Verify first:

```bash
git diff --cached --name-only  # must show only docs/* or AGENTS.md
```

**Everything else requires a branch + PR targeting `main`.**

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

A broken change in `system_files/shared/` breaks `bluefin`, `bluefin-lts`,
and `dakota` simultaneously. Test locally where possible.

## Code ownership

```
system_files/shared/**   @inffy @renner0e @ledif @castrojo @hanthor @ahmedadan
system_files/bluefin/**  @castrojo @hanthor @ahmedadan
**/*.md                  @repires @KiKaraage @projectbluefin/maintainers
```

## Canonical sources

| Topic | Source |
|---|---|
| Factory org structure | `docs/factory/README.md` |
| Cross-repo agent hard rules | `docs/factory/agentic-model.md` |
| Issue lifecycle / labels | `docs/skills/label-workflow.md` |
| CI tooling / SHA pinning | `docs/skills/ci-tooling/SKILL.md` |
| Image registry / tags | `docs/skills/image-registry.md` |
| Skill improvement mandate | `docs/skills/skill-improvement.md` |
| PR review checklist | `docs/skills/pr-review/SKILL.md` |
| Testing contract | `docs/TESTING.md` |
| Coding / config style guide | `docs/contributing/style-guide.md` |

## See also

- [`README.md`](README.md) — project overview for humans.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contributor quick start.
- [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) — workflow index.
- [`docs/TESTING.md`](docs/TESTING.md) — testing contract and coverage targets.
- [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) — coding and configuration style guide.
