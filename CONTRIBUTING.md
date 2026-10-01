# CONTRIBUTING

Thanks for helping out!

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is the **shared OCI layer** consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical — see the scope warning in [`AGENTS.md`](./AGENTS.md). Make sure you also check [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

- For Bluefin-specific image changes: [projectbluefin/bluefin](https://github.com/projectbluefin/bluefin)
- For LTS image changes: [projectbluefin/bluefin-lts](https://github.com/projectbluefin/bluefin-lts)
- For dakota changes: [projectbluefin/dakota](https://github.com/projectbluefin/dakota)
- For shared system config (Aurora-compatible files): edit `system_files/shared/` directly in this repo

## How this repo uses agents

This repo is **human-first for issues.** Humans file issues, triage them, and decide what gets built.
Automated agents implement approved work — they do not self-direct triage or close issues without
human approval.

Triage and queue state are managed strictly through the canonical seven labels.
See [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) for the full lifecycle.

To queue an accepted issue for an autonomous agent:
```bash
gh issue edit <number> --repo projectbluefin/common --add-label 3-clanker-queue
```
The issue description must be clear enough to implement without follow-up questions.

## CI

Pull requests must pass `Validate PR`, `Build`, `Unit Tests`, and `PR E2E` — no expensive VM boots.
Full layer validation (the `common` behave suite from
[`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs on every merge to main.

## Testing and style

- [`docs/TESTING.md`](docs/TESTING.md) — the testing contract: what must be
  tested, hardware gate boundaries, coverage targets, and exemptions.
- [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) —
  coding and configuration conventions for shell scripts, Just recipes,
  JSON/YAML, and the Containerfile.
- [`docs/specifications/reviewer-ladder.md`](docs/specifications/reviewer-ladder.md) —
  draft specification for contributor ladder scaling; unadopted until maintainer approval.
- [`docs/specifications/hold-gate-prioritization.md`](docs/specifications/hold-gate-prioritization.md) —
  draft specification for hold-gate PR queue prioritization tiers; unadopted until maintainer approval.
- [`docs/specifications/triage-first-response.md`](docs/specifications/triage-first-response.md) —
  draft specification for first-response SLA on issues; unadopted until maintainer approval.
- [`docs/specifications/agent-lane-throttle.md`](docs/specifications/agent-lane-throttle.md) —
  draft specification for demand-side throttling of agent-filed PRs; unadopted until maintainer approval.
- [`docs/contributing/self-collision-preflight.md`](docs/contributing/self-collision-preflight.md) —
  draft proposal for preflight check against overlapping open PR clusters.
- [`ACTIONS-SECURITY.md`](./ACTIONS-SECURITY.md) — organization GitHub Actions
  security baseline: top-level `permissions: {}`, SHA pinning, `pull_request_target`
  restrictions, and checksum verification.
