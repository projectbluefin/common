# CONTRIBUTING

Thanks for helping out!

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is the **shared layer** for Bluefin images (`bluefin`, `bluefin-lts`) and downstream systems (`dakota`, `utah`, and installation media `iso`). A change to `system_files/shared/` propagates downstream, so stay surgical — see the scope warning in [`AGENTS.md`](./AGENTS.md).

- For Bluefin-specific image changes: `projectbluefin/bluefin`
- For LTS image changes: `projectbluefin/bluefin-lts`
- For shared global config: edit `system_files/shared/` directly in this repo

## Issues and agents

Humans file and triage issues; agents implement approved work. The label
workflow, who may set which label, and how to queue work for an agent are all
in [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md). The rules
agents operate under are in [`AGENTS.md`](./AGENTS.md). Neither is restated
here.

## Getting a PR merged

`main` is gated by the ruleset `main — merge queue`. Merging needs **two**
approving reviews plus three green required checks — `validate`,
`Build and push image (x86_64)`, and `Build and push image (aarch64)` — and
then the merge queue. There are no bypass actors.

Other checks run and are worth reading, but do not block: Unit Tests, PR E2E,
Validate Brewfiles, Validate ChairLift Config, Scorecard. Docs-only PRs skip
the two Build checks entirely and land on `validate` alone.

Live parameters and how to re-derive them:
[`docs/skills/governance.md`](docs/skills/governance.md#how-main-is-protected).

Full layer validation (the `common` behave suite from
[`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs
on every merge to main.

## Testing and style

- [`docs/TESTING.md`](docs/TESTING.md) — the testing contract: what must be
  tested, hardware gate boundaries, coverage targets, and exemptions.
- [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) —
  coding and configuration conventions for shell scripts, Just recipes,
  JSON/YAML, and the Containerfile.
