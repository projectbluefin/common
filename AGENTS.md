# bluefin-common — Agent Operating Contract

`bluefin-common` is the shared OCI layer consumed by `bluefin`, `bluefin-lts`,
and `dakota`. Changes here propagate to every variant. Stay surgical.

## Read order

1. This file — repo rules, build commands, and boundaries.
2. [`docs/SKILL.md`](docs/SKILL.md) — find the skill for your task and load it.
3. [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md) — cross-repo
   rules if the task spans repos.

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

- **Issues and PRs run on Prow:** see
  [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) for the flow,
  labels, and `/commands`. New issues carry `needs-human`; a maintainer accepts
  with `/triage accepted` and removes `needs-human` by hand when agents may take
  the work. PRs merge through the merge queue once they have `lgtm`, `approved`,
  Common's 2 GitHub approvals, and green checks.
- **Agents implement accepted work only:** `triage/accepted`, no `needs-human`,
  no `blocked` or `hold`. Never set those labels, `lgtm`, or `approved` on your
  own work. Link issues with `Refs #NNN` or `Fixes #NNN`.
- **Hive coordination & Clankers relay:** Hive may select work for another
  monitored repository. Clankers is only the authenticated relay for that
  assignment; verify the assigned repository and issue in GitHub before acting.
  It does not bypass human approval, review, or merge gates.
- **Ownership:** the root `OWNERS` file lists who may `/approve`. It is generated
  from `maintainers.yaml` in `projectbluefin/.project`; never edit it by hand.
  Org-wide Prow config is `prow.yaml` in the same repository. Never write to
  `ublue-os/*`.

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
- `Justfile`, `Containerfile`, tests, `docs/`, `AGENTS.md`, and
  `.github/workflows/`.

## What agents must not touch

- Any `ublue-os/*` repository (read-only; no writes of any kind).
- Vendored files under `system_files/bluefin/usr/share/gnome-shell/extensions/`.
- Org/app credential pairs; use `GITHUB_TOKEN` or provisioned GitHub Apps.

## Branch and native merge gates

**Every change requires a branch and PR targeting `main`, including `docs/**`
and `AGENTS.md`.** This supersedes older doc-only direct-push exceptions.
Honor live native reviews, required checks, and merge-queue controls; use no
direct-main, REST merge, or admin-bypass route to evade them.

Common's queue/check ruleset is `17513003`; its separate two-review ruleset is
`23854231`. Both expose `OrganizationAdmin` `always` bypass in current source
state; do not claim zero bypass or use that capability as approval. Re-read live
repository/organization rulesets and branch protection before landing changes.
Changes to protection/ownership/security remain human decisions.

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

The root [`OWNERS`](OWNERS) file lists the approvers for the whole repository.

## Canonical sources

| Topic | Source |
|---|---|
| Factory org structure | `docs/factory/README.md` |
| Cross-repo agent hard rules | `docs/factory/agentic-model.md` |
| Issues, PRs, labels, Prow commands | `docs/skills/label-workflow.md` |
| CI tooling / SHA pinning | `docs/skills/ci-tooling/SKILL.md` |
| Image registry / tags | `docs/skills/image-registry.md` |
| Skill improvement mandate | `docs/skills/skill-improvement.md` |
| PR review checklist | `docs/skills/pr-review/SKILL.md` |
| Testing contract | `docs/TESTING.md` |
| Coding / config style guide | `docs/contributing/style-guide.md` |
| Actions security baseline | [`ACTIONS-SECURITY.md`](ACTIONS-SECURITY.md) |

## See also

- [`README.md`](README.md) — project overview for humans.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contributor quick start.
- [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) — workflow index.
- [`docs/TESTING.md`](docs/TESTING.md) — testing contract and coverage targets.
- [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) — coding and configuration style guide.
