# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory.

## Operating principle

> **Humans approve design, security, and merge. Common's pilot also retains trusted human implementation acceptance and delivery evidence; automation advances only implemented transitions.**

Project Bluefin aims to be the most sophisticated CNCF showcase of cloud-native operating systems built with bootc. The factory is an **agentic CI/CD organism**: agents implement, humans set direction. Manual orchestration is treated as a reliability tax — every manual step that *can* be automated *will* be, every automated step must self-heal, and every remaining human gate is intentional and named in [`docs/skills/human-gates.md`](../skills/human-gates.md).

New workflows must self-heal: retry on transient failures, fast-fail on bad tokens, no silent skips. See [`docs/skills/ci-pitfalls.md`](../skills/ci-pitfalls/SKILL.md) for known pitfalls and [`docs/skills/ci-tooling.md`](../skills/ci-tooling/SKILL.md) for CI policy and config.

## Reference read order

1. Target repo `AGENTS.md` — start here
2. This file — org map, infrastructure topology, parity matrix
3. [`docs/factory/agentic-model.md`](agentic-model.md) — cross-repo hard rules, branch targets, PR policy, session start
4. Relevant `docs/skills/*` files — lazy-load for the specific task; use [`docs/SKILL.md`](../SKILL.md) as the router

For a new or relocated agent, follow the copyable
[`factory-onboarding.md`](../skills/factory-onboarding.md) procedure. It
verifies the target repository first, attaches common as the shared-contract
sidecar, and requires self-repair and durable learning on every task loop.

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

## Agentic operating model

The issue lifecycle in [`label-workflow.md`](../skills/label-workflow.md) is a
**common-only pilot**, not an organization-wide migration. Common owns two
forms, a local policy script/catalog, and event plus hourly reconciliation.
Other repositories retain their current local labels, forms, and lifecycle
callers; read the target repository's `AGENTS.md` before acting.

Trusted humans accept implementation through GitHub's label picker after
clarifying scope. The runtime checks immutable event authority and issue-body
revision. Machine-analysis consent, an old queue, or Hive `ready` is not
acceptance. PRs use native assignment and review status, not issue-stage labels.
Existing approvals, reviews, branches, assignments, overlays, and unrelated
descriptive/operational/`agent/*`/`hive/*` labels remain intact.

Image reports stay open after implementation merge. An authorized human must
record delivered-image evidence before requesting reporter verification;
there is no release scraper or inferred shipped status. Every project-owned
lifecycle post names status, next actor, specific next steps, and reporter
action. Reporters reply normally and never need labels or lifecycle commands.

Preview local migration and reconciliation before an authorized apply:

```bash
python3 scripts/common_issue_policy.py --repo projectbluefin/common --dry-run
python3 scripts/common_issue_policy.py --repo projectbluefin/common --apply
```

The local runtime uses native `needs-human` enumeration gating while work is
unaccepted or human-only. It changes no global Hive custom approval API,
deployment, or credentials, and cannot guarantee scheduling enforcement for
every worker. Hive readiness and trusted implementation acceptance remain
separate facts. See the label skill for the operator procedure and evidence
requirements.

Substantive product planning follows the [Spektacular workflow](../skills/spektacular-workflow.md)
and the [adoption specification](../specifications/spektacular-adoption.md)
with its downstream plan and Hive activation gates.
Hard rules, branch targets, PR comment policy, session start: [`docs/factory/agentic-model.md`](agentic-model.md)
Human decisions: [`docs/skills/human-gates.md`](../skills/human-gates.md).

## Factory infrastructure

Read each target repo's `AGENTS.md` and verify parity from GitHub below;
do not infer a workflow exists from a factory inventory.

- **Workflow state:** common's pilot is defined in [label-workflow](../skills/label-workflow.md); other repositories retain their local contracts.
- **Delivery:** squash-only merge and the owning repo's branch protection.
- **Production:** the `factory-operations` environment requires two maintainer approvals before `:stable` tagging in `bluefin`, `bluefin-lts`, and `dakota`.
- **Hygiene:** repo-local `pre-commit` at developer time and its aggregate CI check, not a bespoke process gate.

Common owns `bug-report.yml`, `feature-request.yml`, and chooser `config.yml`
under `.github/ISSUE_TEMPLATE/`. Intake starts in triage with bug/feature kind
and an explicit analysis preference; maintainers refine acceptance criteria
later. Report intake automation is a separate integration, not authority to
replace common's forms or accept implementation. No form ownership or
downstream migration changes are part of this pilot.
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
