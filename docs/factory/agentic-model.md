# Cross-repository operations — projectbluefin

Optional reference for work spanning factory repositories. The target repo's
`AGENTS.md` governs its work; Common's [contract](../../AGENTS.md) holds its
safety boundaries and contribution rules. Read only the guidance needed for
the task, not every repository's skill catalog.

## Authority and ownership

- Verify a routed assignment's target repository and issue in GitHub before
  acting. Hive selects work; Clankers relays it. Neither grants acceptance,
  permission to bypass review, or authority to change policy.
- Prow repositories require maintainer `triage/accepted`, no `needs-human`, and
  no `blocked` or `hold`. Assignment and analysis consent are not acceptance.
  Other repositories retain their local acceptance procedure; do not copy
  labels across repositories or invent workflow transitions.
- Preserve assignees and `agent/*`/`hive/*` routing labels. Link issues with
  `Refs #NNN` or `Fixes #NNN`. Do not self-grant acceptance or review approval.
- Org-wide automation belongs in `projectbluefin/actions`, not the deprecated
  `projectbluefin/housekeeping` placeholder. Common's shared layer affects
  `bluefin`, `bluefin-lts`, and `dakota`; account for downstream consumers.
- Reuse existing codebase patterns and verify project facts from source.
  Knowledge search can help with unfamiliar factory behavior; it is not a
  prerequisite for routine tasks. Correct task-relevant guidance when needed,
  not as a compulsory self-repair loop or session deliverable.

The `ublue-os/*` read-only boundary, credential prohibition, and named human
gates in [Common's contract](../../AGENTS.md) still apply to cross-repo work.
Protection, ownership, security, and production decisions remain human-owned.
For product specifications and maintainer-operated review tools, see
[human-gates](../skills/human-gates.md).

## Branches and publication

| Repo | Content PR target | Notes |
|---|---|---|
| `common` | `main` | No testing branch; documentation also uses PRs |
| `bluefin` | `testing` | `main` receives promotion PRs |
| `bluefin-lts` | `testing` | Testing-first |
| `dakota` | `testing` | Testing-first |
| `knuckle` | `main` | Installer; no testing branch |
| `bootc-installer` | `dev` | `prod` triggers Flatpak releases; never target it directly |
| `testsuite` | `main` | Tests |
| `actions` | `main` | Shared actions |

Confirm the target repository's current local contract and workflows before
publishing. Branch from its current target, rebase onto that target before
pushing, and ensure the branch contains only intended commits. Search existing
open PRs before duplicating a fix. Use one branch/PR per logical change and
request human approval before opening a PR autonomously. Factory merges are
squash-only; never use merge-commit or rebase-merge.

Stage explicit paths, not `git add -A` or `git add .`; inspect staged paths before
commit. Auxiliary clones and nested `.git` directories can stage as gitlinks.
Run the target repository's required checks and report actual evidence.

Prow PRs require non-author `lgtm`, an `OWNERS` approver, required native GitHub
approvals, and green checks before the merge queue acts. `/hold` pauses merging.
Inspect live review/check/queue controls before landing; administrative bypass
capability is not approval. Agents do not self-merge or close PRs autonomously.

Changes to `.github/workflows/`, `Justfile`, `build_files/`, and Dakota's
`elements/` need maintainer review before merge. For other sensitive changes,
use the target repository's ownership rules and human gates.

## Workflow capabilities, not new credentials

Use documented git/GitHub primitives and already-provisioned authentication.
For example, a workflow pushing content may need `permissions: contents: write`,
not a new token. When syncing a branch whose `GITHUB_TOKEN` cannot push workflow
changes, preserve that target branch's own `.github/` files instead of replacing
them with the source branch's workflows. If an existing capability is
insufficient, stop and ask a human; do not create or propose credentials.

## Testing-first image repositories

For `bluefin`, `bluefin-lts`, and `dakota`, content PRs target `testing`; `main`
receives squash promotions from `auto/promote-testing-to-main`. Builds publish
`:testing`; promotion/release workflows publish stable streams. Inspect each
repository's workflows for the current schedule and required vs advisory E2E
gates rather than treating an open promotion PR as a factory failure.
Existing automated promotion policy is not permission for an agent to approve
or bypass human gates on its own changes.

Required workflows must report for eligible PR and merge-group refs. If a
documentation-only change needs no image rebuild, skip build steps rather
than filtering out a required workflow. Inspect each repository's actual build
inputs before changing filters; local composite actions are build inputs too.
When intentionally migrating a repository to testing-first, align build
triggers, promotion source/target, Renovate's base branch, common tracking,
branch protection, and the local contract; remove obsolete main-to-testing
sync automation. Do not apply a migration merely because a routine task touched
one of these files.

CI protects the image artifact. Do not add bespoke blocking jobs for skill
updates, attribution, documentation formatting, or other process bookkeeping.
Developer hygiene belongs in existing checks, not a new job per convention.

## Gaps and review communication

Use GitHub issues for actionable factory gaps, not static documentation backlogs.
Describe scope, impact, and the expected outcome; normal human triage still
applies. Discovering a gap does not authorize implementation or a docs sweep.

- Avoid COMMENT-state reviews and informational status comments that merely
  repeat GitHub UI state. Communicate a concrete fix or decision needed.
- At most one combined comment per PR event; mention people only with a request.
- Test reports contain what ran, pass/fail, and blockers, not diff summaries.

Prow command details are in [label-workflow](../skills/label-workflow.md).
Other repositories retain their local issue and review lifecycle.
