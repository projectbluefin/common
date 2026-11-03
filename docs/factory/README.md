# Project Bluefin factory

`common` provides the shared OCI layer consumed by `bluefin`, `bluefin-lts`,
and `dakota`. Those repositories own their image builds and promotion.

## Ownership

| Repository | Responsibility |
|---|---|
| `common` | Shared image content and local validation |
| `bluefin`, `bluefin-lts`, `dakota` | Downstream images and stream promotion |
| `actions` | Reusable GitHub Actions |
| `testsuite` | End-to-end image tests |
| `iso`, `bootc-installer`, `knuckle` | Installation media and installers |
| `chairlift` | System-management application |
| `.project` | Org Prow configuration and maintainer roster |

## Working across repositories

- The target repository's `AGENTS.md` is authoritative. Consult
  [cross-repo boundaries](agentic-model.md) only for cross-repo work.
- `ublue-os/*` is read-only. Do not copy its ownership or branch rules into
  `projectbluefin/*` by assumption.
- Verify the issue, target branch, owners, workflows, and live protections
  in the target repository. This overview is not a permissions inventory.
- In Prow repositories, humans accept issues and approve changes; Hive
  assigns work but does not grant acceptance or merge authority. See
  [labels and commands](../skills/label-workflow.md).
- Preserve native reviews, checks, and merge queues. Do not use direct-main,
  REST-merge, or admin-bypass routes. Stable-image promotion in `bluefin`,
  `bluefin-lts`, and `dakota` requires the `factory-operations` environment's
  two maintainer approvals.
- Design, security, ownership/protection changes, and cross-repo breakage
  require [human decisions](../skills/human-gates.md).

For common's workflows, use the [workflow map](../skills/workflow-map.md).
Keep gaps and proposals in their owning GitHub issues, not snapshot tables or
new mandatory agent checklists.
