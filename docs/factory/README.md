# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory.

## Operating principle

> **Humans approve design, security, and merge. Opted-in Common and ChairLift retain trusted human implementation acceptance and delivery evidence; automation advances only implemented transitions.**

Project Bluefin aims to be the most sophisticated CNCF showcase of cloud-native operating systems built with bootc. The factory is an **agentic CI/CD organism**: agents implement, humans set direction. Manual orchestration is treated as a reliability tax — every manual step that *can* be automated *will* be, every automated step must self-heal, and every remaining human gate is intentional and named in [`docs/skills/human-gates.md`](../skills/human-gates.md).

New workflows must self-heal: retry on transient failures, fast-fail on bad tokens, no silent skips. See [`docs/skills/ci-pitfalls.md`](../skills/ci-pitfalls/SKILL.md) for known pitfalls and [`docs/skills/ci-tooling.md`](../skills/ci-tooling/SKILL.md) for CI policy and config.

## Reference read order

1. Target repo `AGENTS.md` — start here
2. This file — org map, infrastructure topology, parity matrix
3. [`docs/factory/agentic-model.md`](agentic-model.md) — cross-repo hard rules, branch targets, PR policy, session start
4. Relevant `docs/skills/*` files — lazy-load for the specific task; use [`docs/SKILL.md`](../SKILL.md) as the router

For repository opt-in, migration, or client retirement, follow the canonical
[`factory-onboarding.md`](../skills/factory-onboarding.md) procedure: inspect
local authority and live readers/writers/gates, install shared Actions callers,
preview read-only, merge natively, prove released/main CI, archive/migrate quietly,
declare client cutoff, refresh reviewed statuses, and prove stable live outcomes.

## Mission and product boundary

- Factory org: `projectbluefin`
- Product: bootc-based OCI images and the automation that builds, validates, and promotes them
- Shared layer repo: `common` — https://github.com/projectbluefin/common
- Production image registry: `ghcr.io/projectbluefin/bluefin*`
- Registry reference: `docs/skills/image-registry.md`

```text
common ──────────────────────────┐
(shared OCI layer)               │
                                 ▼
bluefin     ──┐                  │
bluefin-lts ─┼──→ images ──→ testsuite ──→ iso
dakota      ─┘                  │
                                 │
                          bootc-installer / knuckle
                          (installer media + TUI)
```

- `common`: shared OCI layer and shared factory documentation (org brain)
- `bluefin`: mainline Bluefin image streams
- `bluefin-lts`: LTS image streams
- `dakota`: bootc image pipeline in the same factory orbit
- `testsuite`: end-to-end gate for downstream image behavior
- `iso`: installation media fed by validated image outputs
- `actions`: shared GitHub Actions used across the org
- `bootc-installer`: GTK4/Adwaita + KDE/XFCE multi-variant Flatpak installer for bootc images
- `knuckle`: Go-based TUI installer — `main` branch, no testing branch
- `chairlift`: application-level system-management experience, including delivery dependencies on image-installed helpers

For the workflow-by-workflow purpose map inside `common`, see [`../skills/workflow-map.md`](../skills/workflow-map.md).

## Factory repos

- `common` — https://github.com/projectbluefin/common
- `bluefin` — https://github.com/projectbluefin/bluefin
- `bluefin-lts` — https://github.com/projectbluefin/bluefin-lts
- `dakota` — https://github.com/projectbluefin/dakota
- `actions` — https://github.com/projectbluefin/actions
- `testsuite` — https://github.com/projectbluefin/testsuite
- `bootc-installer` — https://github.com/projectbluefin/bootc-installer
- `knuckle` — https://github.com/projectbluefin/knuckle
- `chairlift` — https://github.com/projectbluefin/chairlift

## Agentic operating model

The shared issue lifecycle in [`label-workflow.md`](../skills/label-workflow.md)
is an **explicit opt-in for Common and ChairLift**, not an organization-wide
migration. `projectbluefin/actions` owns the runtime/status/Prow modules,
`issue-lifecycle` and `prow-labels` actions, and reusable conductor; first-party
references use managed `@v1`, third-party CNCF Prow uses an immutable SHA.
Consumers own catalogs, constrained `.github/prow.yaml`, intake forms, delivery
contracts, and thin callers. Other repositories retain their local contracts.

Trusted humans accept current scope through GitHub's **Labels** picker.
Classification, analysis consent, legacy queues, and Hive `ready` are not
acceptance or assignment. Protected native reader/independent human gates,
human-only preferences, assignees, reviews, branches, operational labels, and
merge queues survive adoption. Prow only classifies open issues or applies/
withdraws negative holds; it cannot accept, assign, dispatch, review, or merge.
PR progress belongs to native GitHub controls, not issue-stage labels.

Common requires delivered-image evidence; ChairLift requires actual application/
package delivery, including required image-installed helpers. Unresolved product
reports use `Refs`, remain open after merge, and request normal reporter replies
only after specific information requests or authorized delivery evidence. Bot
reports use Status, role-headed action bullets, and explicit Reporter action;
structured notification identity prevents repeat mentions from formatting/repair.

Onboarding includes live ruleset review, human review/queue, actual main CI and
released Actions source, writer cutover, all-history archived quiet migration,
supported-client cutoff before definition retirement, reviewed comment/mention-
aware refresh, UI/state/Prow-outcome evidence, and a stable second preview.
Local-token apply is refused; use the reviewed default-branch caller with Bot
provenance. The onboarding skill is the single operator procedure.

Native `needs-human` enumeration gating is local protection, not verified global
Hive admission. Invisible Hive settings remain unverified; cached/assigned or
differently configured workers may differ. Read live coordination and verify
GitHub's accepted scope, actual assignment, overlays, and reporter preference.

Substantive product planning follows the [Spektacular workflow](../skills/spektacular-workflow.md)
and the [adoption specification](../specifications/spektacular-adoption.md)
with its downstream plan and Hive activation gates.
Hard rules, branch targets, PR comment policy, session start: [`docs/factory/agentic-model.md`](agentic-model.md)
Human decisions: [`docs/skills/human-gates.md`](../skills/human-gates.md).

## Factory infrastructure

Read each target repo's `AGENTS.md` and verify parity from GitHub below;
do not infer a workflow exists from a factory inventory.

- **Workflow state:** [label-workflow](../skills/label-workflow.md) applies to opted-in Common and ChairLift; other repositories keep their contracts.
- **Delivery:** the owning repository's live native reviews, checks, merge queue, and branch protection; all changes use branch + PR, with no REST/admin bypass.
- **Production:** the `factory-operations` environment requires two maintainer approvals before `:stable` tagging in `bluefin`, `bluefin-lts`, and `dakota`.
- **Hygiene:** repo-local `pre-commit` at developer time and its aggregate CI check, not a bespoke process gate.

Common and ChairLift own their local forms and chooser config. Intake starts
triage with kind and an explicit analysis preference; a human separately accepts
scope. Report intake integrations neither replace local ownership nor dispatch
unaccepted work. Opt-in does not propagate forms or lifecycle policy org-wide.
Common's queue/check ruleset `17513003` and separate two-review ruleset `23854231`
both expose `OrganizationAdmin` `always` bypass; read live state rather than
promising zero bypass, and never use that capability to evade the native gates.
Common owns the canonical CODEOWNERS triager block, but its absent sync workflow leaves
downstream propagation to reviewed repo-local changes.

## Factory parity

Parity is live state, so it is not tabulated here. A hand-maintained table
drifts, and a generated one is a table nobody remembers to regenerate. Ask
GitHub instead:

```bash
# Which core repos carry a given artifact
for repo in common bluefin bluefin-lts dakota actions testsuite; do
  printf '%-13s ' "$repo"
  gh api "repos/projectbluefin/$repo/contents/AGENTS.md" >/dev/null 2>&1 \
    && echo yes || echo "--"
done
```

Swap the path for whatever you are checking: `.pre-commit-config.yaml`,
`docs/SKILL.md`, `docs/skills/index.json`, or the target's own lifecycle workflow.

## Open gaps

Factory gaps live in GitHub, not a hand-maintained list. Use the
[factory-improvement procedure](../skills/factory-improvement/SKILL.md) for
the current audit and issue-filing process.

## Sensitive paths (require maintainer review)

All repos: `.github/workflows/`, `Justfile`, `build_files/`
dakota only: `elements/`
