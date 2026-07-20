# Common Skill Router

Agent entry point for `projectbluefin/common`. Find the skill that matches
your task, load only that skill, then act.

## Read order

1. [`AGENTS.md`](../AGENTS.md) — repo contract, build commands, boundaries.
2. This file — task→skill mapping.
3. The skill file named in the table below.
4. [`docs/factory/agentic-model.md`](factory/agentic-model.md) for cross-repo rules.

## Skill index

| I need to... | Load |
|---|---|
| Set up a dev environment or clone a factory repo | [`onboarding.md`](skills/onboarding.md) |
| Understand CODEOWNERS, triagers, or branch protection | [`governance.md`](skills/governance.md) |
| Run hive priority review at session start | [`hive-review.md`](skills/hive-review.md) |
| Understand cross-repo agent rules | [`factory/agentic-model.md`](factory/agentic-model.md) |
| Know when to stop and ask a human | [`human-gates.md`](skills/human-gates.md) |
| Understand issue lifecycle / labels | [`label-workflow.md`](skills/label-workflow.md) |
| Check PR queue or merge ruleset | [`queue-dashboard.md`](skills/queue-dashboard.md) |
| Review an incoming PR | [`pr-review.md`](skills/pr-review.md) |
| Understand the hive / kubestellar-bot loop | [`hive.md`](skills/hive.md) |
| Improve factory automation or audit gaps | [`factory-improvement.md`](skills/factory-improvement.md) |
| Onboard a new repo into the factory | [`factory-onboarding.md`](skills/factory-onboarding.md) |
| Change a GNOME setting or dconf key | [`dconf-consistency.md`](skills/dconf-consistency.md) |
| Work on Bazaar config or hooks | [`bazaar.md`](skills/bazaar.md) |
| Edit `system_files/shared/`, `bluefin/`, or `nvidia/` | [`submodule-boundary.md`](skills/submodule-boundary.md) |
| Touch any image reference or registry path | [`image-registry.md`](skills/image-registry.md) |
| Modify the `Containerfile` or add a binary | [`containerfile.md`](skills/containerfile.md) |
| Use Context7 to look up external tools | [`context7.md`](skills/context7.md) |
| Change `.github/workflows/` | [`ci-tooling.md`](skills/ci-tooling.md) + [`workflow-map.md`](skills/workflow-map.md) |
| Debug a CI failure | [`ci-pitfalls.md`](skills/ci-pitfalls.md) |
| Work on E2E test changes | [`e2e-ci.md`](skills/e2e-ci.md) |
| Understand release / promotion | [`release-promotion.md`](skills/release-promotion.md) |
| Understand QA coverage or run tests | [`qa.md`](skills/qa.md) |
| Submit a hardware test report | [`hardware-testing.md`](skills/hardware-testing.md) |
| Lab-test a common PR on ghost | [`lab-testing.md`](skills/lab-testing.md) |
| Write or test shell scripts | [`shell-scripts.md`](skills/shell-scripts.md) |
| Work on brew / preinstall packages | [`brew-lifecycle.md`](skills/brew-lifecycle.md) |
| Work on `ujust devmode` | [`devmode.md`](skills/devmode.md) |
| Work with bootc | [`bootc.md`](skills/bootc.md) |
| Work with NVIDIA GPU support | [`nvidia.md`](skills/nvidia.md) |
| Work with OEM first-boot hooks | [`oem-hardware-hooks.md`](skills/oem-hardware-hooks.md) |
| Understand MIME defaults | [`mime-defaults.md`](skills/mime-defaults.md) |
| Understand skill-drift CI check | [`skill-drift.md`](skills/skill-drift.md) |
| Decide whether / how to update a skill | [`skill-improvement.md`](skills/skill-improvement.md) |
| Author a new skill | [`write-a-skill.md`](skills/write-a-skill.md) |
| Understand bonedigger lifecycle | [`bonedigger.md`](skills/bonedigger.md) |
| Use Discord ChatOps / Botkube | [`discord-chatops.md`](skills/discord-chatops.md) |
| Handle secrets / Botkube RBAC | [`secrets-policy.md`](skills/secrets-policy.md) |
| Understand factory topology | [`factory/README.md`](factory/README.md) |

## How to load a skill

Read the skill file's front-matter first. If `description` and `tags` match
your task, read the body. If the topic spans multiple repos, the local skill
links to `projectbluefin/actions` or `docs/factory/` — follow the link rather
than duplicating facts.

## Writing skills

- [`skill-improvement.md`](skills/skill-improvement.md) — when and why to update skills.
- [`write-a-skill.md`](skills/write-a-skill.md) — authoring, front-matter, size budget, and linking rules.
