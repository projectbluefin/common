# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

This directory is the org-level entry point for agents and maintainers working across the Project Bluefin factory.

## Operating principle

> **Humans approve design, security, and merge. Everything else is automated, self-healing, and non-blocking.**

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

`1-triage` → `2-discussing` when needed → `3-human-queue` or
`3-clanker-queue` → `4-review` → merge. `blocked` and `hold` are overlays,
not stages; there is no claim command or `done` label.

Lifecycle automation lives in [`projectbluefin/bonedigger`](https://github.com/projectbluefin/bonedigger); `bluefin`, `bluefin-lts`, `dakota`, and `knuckle` own callers. `common` has none.
Full lifecycle, epics, project board, and PR labels: [`docs/skills/label-workflow.md`](../skills/label-workflow.md)
Substantive product planning follows the [Spektacular workflow](../skills/spektacular-workflow.md)
and the [adoption specification](../specifications/spektacular-adoption.md)
with its downstream plan and Hive activation gates.
Hard rules, branch targets, PR comment policy, session start: [`docs/factory/agentic-model.md`](agentic-model.md)
Human decisions: [`docs/skills/human-gates.md`](../skills/human-gates.md).

## Factory infrastructure

Read each target repo's `AGENTS.md` and verify parity from GitHub below;
do not infer a workflow exists from a factory inventory.

- **Workflow state:** the seven labels in [label-workflow](../skills/label-workflow.md), owned by automation.
- **Delivery:** squash-only merge and the owning repo's branch protection.
- **Production:** the `factory-operations` environment requires two maintainer approvals before `:stable` tagging in `bluefin`, `bluefin-lts`, and `dakota`.
- **Hygiene:** repo-local `pre-commit` at developer time and its aggregate CI check, not a bespoke process gate.

[`bonedigger/templates/`](https://github.com/projectbluefin/bonedigger/tree/main/templates)
owns canonical issue forms and proposes changes to `common` and image repos by
PR. `common` currently has only `report.yml` plus `config.yml`, so the next
sync can add forms and change its chooser; review that PR. `common` owns the
canonical CODEOWNERS triager block, but its absent sync workflow leaves
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
`docs/SKILL.md`, `docs/skills/index.json`, `.github/workflows/bonedigger.yml`.

## Open gaps

Factory gaps live in GitHub, not a hand-maintained list. Use the
[factory-improvement procedure](../skills/factory-improvement/SKILL.md) for
the current audit and issue-filing process.

## Sensitive paths (require maintainer review)

All repos: `.github/workflows/`, `Justfile`, `build_files/`
dakota only: `elements/`
