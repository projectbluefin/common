# bluefin-common — Agent Operating Contract

`bluefin-common` is the shared OCI layer consumed by `bluefin`, `bluefin-lts`,
and `dakota`. Changes here propagate to every variant. Stay surgical.

## Read order

1. This file — repo rules, build commands, and boundaries.
2. [`docs/SKILL.md`](docs/SKILL.md) — find the skill for your task and load it.
3. [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md) — cross-repo
   rules if the task spans repos.

For repository opt-in, migration, client retirement, or downstream onboarding,
follow [`docs/skills/factory-onboarding.md`](docs/skills/factory-onboarding.md).
Target-repository authority comes first; Common supplies reusable contracts and
Actions supplies the shared implementation, not copied bots or user-level policy.

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

- **Explicitly opted-in Common and ChairLift lifecycle:**
  [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) defines five
  issue stages, overlays, trusted acceptance, constrained Prow, and notifications.
  Each consumer owns its catalog/forms and delivery contract; other repositories
  retain local lifecycle contracts until reviewed opt-in. PRs use native assignment,
  reviews, checks, and merge controls, not issue stages. Preserve active operational,
  descriptive, `agent/*`, and `hive/*` labels and existing work ownership.
- **Humans accept implementation** through a trusted label-picker event after
  clarifying scope and acceptance criteria. The runtime validates the immutable
  event actor's permissions and the issue body revision. Reporter consent to
  machine analysis, an old queue, or Hive `ready` is not acceptance. Reporters
  reply normally and never need label permissions or a public lifecycle command.
- **Agents implement accepted, assigned work** within the agreed scope and only
  after independent human gates permit it. Link unresolved product reports with
  `Refs #NNN`; use `Closes #NNN` only for merge-satisfied code-only work or already
  delivered/verified reports. Merge is not image/application delivery. Bot reports
  use Status, role headings/action bullets, and explicit Reporter action.
- **Hive coordination & Clankers relay:** Hive may select work for another
  monitored repository. Clankers is only the authenticated relay for that
  assignment; verify the assigned repository and issue in GitHub before acting.
  It does not bypass human approval, review, or merge gates.
- **Repository-owned intake:** Common owns `bug-report.yml`, `feature-request.yml`,
  and chooser `config.yml` in `.github/ISSUE_TEMPLATE/`; ChairLift owns its local
  forms. Intake initializes triage/kind server-side, including structured CLI bodies.
  Analysis preference never accepts implementation. Adoption does not replace
  other repositories' forms or security/report-intake ownership.
- **CODEOWNERS ownership:** The triager section is owned here; edit downstream
  copies only when the repository-specific section is explicitly in scope.
  Never write to `ublue-os/*`.
- **Shared lifecycle/Prow runtime:** `projectbluefin/actions` owns
  `scripts/issue_policy.py`, `scripts/issue_status.py`, and `scripts/prow_commands.py`,
  packaged as `issue-lifecycle` and `prow-labels`. Common owns its catalog,
  `.github/prow.yaml`, and `.github/workflows/issue-lifecycle.yml`, calling
  `reusable-issue-lifecycle.yml@v1`. The single serialized conductor reads trusted
  default-branch data; hourly repair and full-history migration are labels-only.
  Delivery stages require authorized human evidence. Prow is issue-only descriptive
  classification/negative hold control, not acceptance, assignment, review, or merge.
- **Protected readers and Hive boundary:** Preserve native `needs-human`, independent
  human/app gates, active catalog reader gates, and human-only preferences (a
  maintainer may waive `human-only` by removing the label). Only the
  lifecycle bot's automatic gate clears after eligible acceptance. Label presence
  or Hive `ready` does not verify scheduling/admission for every worker; inaccessible
  Hive settings remain unverified. Adoption adds no global API or credentials.

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
| Actions security baseline | [`ACTIONS-SECURITY.md`](ACTIONS-SECURITY.md) |

## See also

- [`README.md`](README.md) — project overview for humans.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contributor quick start.
- [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) — workflow index.
- [`docs/TESTING.md`](docs/TESTING.md) — testing contract and coverage targets.
- [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) — coding and configuration style guide.
