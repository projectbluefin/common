# bluefin-common — Agent Operating Contract

`common` is the shared OCI layer for `bluefin`, `bluefin-lts`, and `dakota`.
Changes propagate to every variant; keep fixes scoped to the requested work.
Read only task-relevant source and documentation. Routine fixes need no skill
update, knowledge-base lookup, or unrelated documentation restructuring.

## Scope and boundaries

- `system_files/shared/` is global configuration, also consumed by Aurora.
- `system_files/bluefin/` is GNOME/Bluefin-specific configuration.
- Build files, tests, workflows, and documentation may change within task scope.
- Never write to any `ublue-os/*` repository: no issues, PRs, comments, forks,
  reports, or other write actions. Read-only inspection is allowed; ask a human
  to report upstream when a write would be needed.
- Do not edit vendored `system_files/bluefin/usr/share/gnome-shell/extensions/`.
- Do not create, propose, add, or change secrets, PATs, tokens, GitHub Apps, or
  credential pairs. Use existing `GITHUB_TOKEN` or provisioned Apps; capability
  gaps go to a human, not a new credential.

## Build and verification

```bash
just check                 # lint Justfile
just test                  # pytest + bats
just build                 # full OCI build; requires podman + network
pre-commit run --all-files # repository hygiene checks
```

Run `just check` and `pre-commit run --all-files` before committing. Exercise
changed behavior with relevant tests; report what ran, results, and any untested
behavior. Do not claim a build or hardware result without evidence. Testing
scope and hardware boundaries: [docs/TESTING.md](docs/TESTING.md).
After pushing, inspect CI: `gh run list --repo projectbluefin/common --limit 5`.

## Accepted work and ownership

- Agents implement issues with `triage/accepted`, no `needs-human`, and no
  `blocked` or `hold`. A maintainer accepts with `/triage accepted` and removes
  `needs-human`; assignment or Hive readiness is not acceptance.
- Never grant yourself acceptance, `lgtm`, or `approved`, or remove human holds.
- Verify a Hive/Clankers assignment's repository and issue in GitHub before
  acting. Clankers is an authenticated relay, not approval authority.
- Preserve assignees and routing labels. Link issues with `Refs #NNN` or
  `Fixes #NNN`. Use implemented workflow state, not invented transitions.
- `OWNERS` is generated from `maintainers.yaml` in `projectbluefin/.project`;
  do not hand-edit it. Org Prow configuration lives there in `prow.yaml`.

## Branch, PR, and human gates

- Every change, including documentation, uses a branch and PR targeting `main`.
  Check for an existing PR before duplicating work; keep one logical change per PR.
- Ask before opening a PR autonomously; prepare the branch and diff first.
- Use Conventional Commits titles. AI-authored commits carry both trailers:
  `Assisted-by: <Model> via GitHub Copilot` and
  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Stop for human approval on **Design** (architecture, subsystems, user-visible
  behavior), **Security** (auth, signing, supply chain, sources, protection or
  ownership), **Breakage** (public inputs or downstream-dependent defaults),
  and **Merge** (final review and landing). Explain impact and the decision needed.
- PRs use the merge queue with non-author `lgtm`, `OWNERS` approval, Common's
  two required GitHub approvals, and green checks. Agents never self-merge.
- Honor live review/check/queue rules. Never bypass them with direct-main,
  REST merge, force-push, or admin privileges; bypass capability is not approval.

Optional task references: [skills](docs/SKILL.md),
[cross-repo operations](docs/factory/agentic-model.md), and
[human gate details](docs/skills/human-gates.md).
