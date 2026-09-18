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

### The seven labels

Triage runs on exactly seven labels. Nothing else is a workflow state, and there are no slash
commands:

| Label | Meaning |
|---|---|
| `1-triage` | Filed, awaiting a human read |
| `2-discussing` | Needs a decision or a clearer spec |
| `3-human-queue` | Accepted, queued for a person |
| `3-clanker-queue` | Accepted, queued for an automated agent |
| `4-review` | A pull request is awaiting review |
| `blocked` | Waiting on human input or an external dependency |
| `hold` | Intentionally paused |

### Queueing work for an agent

Add `3-clanker-queue` to a triaged issue you want an autonomous agent to implement:

```bash
gh issue edit <number> --repo projectbluefin/common --add-label 3-clanker-queue
```

The issue description must be clear enough to implement without follow-up questions. Vague issues
sit in the queue indefinitely — no agent will guess at the spec.

Full lifecycle: [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md).

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
- [`docs/contributing/reviewer-ladder.md`](docs/contributing/reviewer-ladder.md) —
  draft proposal for a four-rung contributor ladder (Triager, Domain
  Reviewer); unadopted until a maintainer decision.
