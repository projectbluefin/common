# Common Skill Router

Agent entry point for `projectbluefin/common`. Find the skill that matches
your task, load only that skill, then act.

For agents entering another factory repository, use
[`skills/factory-onboarding.md`](skills/factory-onboarding.md) to verify local
authority, attach common as a shared-contract sidecar, and run the
self-repair/self-improvement loop on every task.

## Read order

1. [`AGENTS.md`](../AGENTS.md) — repo contract, build commands, boundaries.
2. This file — task→skill mapping.
3. The skill file named in the table below.
4. [`docs/factory/agentic-model.md`](factory/agentic-model.md) for cross-repo rules.

For routed Hive work, verify the target repository first, then load that
repository's local catalog with `docs/skills/hive.md` as the preflight guard.

## Skill index

| I need to... | Load |
|---|---|
| Set up a dev environment or clone a factory repo | [`onboarding.md`](skills/onboarding.md) |
| Understand CODEOWNERS, triagers, or branch protection | [`governance.md`](skills/governance.md) |
| Run hive priority review at session start | [`hive-review.md`](skills/hive-review.md) |
| Understand cross-repo agent rules | [`factory/agentic-model.md`](factory/agentic-model.md) |
| Know when to stop and ask a human | [`human-gates.md`](skills/human-gates.md) |
| Understand issue lifecycle / labels | [`label-workflow.md`](skills/label-workflow.md) |
| Review the PR / issue backlog (human-decides, agent-lands) | [`pr-review/SKILL.md`](skills/pr-review/SKILL.md) |
| Queue a reviewed PR for Hive auto-merge-on-green | [`hive-automerge.md`](skills/hive-automerge.md) |
| Read the static pull-request queue feed | [`queue-feed.md`](skills/queue-feed.md) |
| Understand the hive / kubestellar-bot loop | [`hive.md`](skills/hive.md) |
| Manage the canonical hosted Project Bluefin Hive | [`hosted-hive.md`](skills/hosted-hive.md) |
| Receive work through the Clankers relay | [`hosted-hive-clankers.md`](skills/hosted-hive-clankers.md) |
| Improve factory automation or audit gaps | [`factory-improvement.md`](skills/factory-improvement/SKILL.md) |
| Onboard a new repo into the factory | [`factory-onboarding.md`](skills/factory-onboarding.md) |
| Change a GNOME setting or dconf key | [`dconf-consistency.md`](skills/dconf-consistency.md) |
| Work on Bazaar config or hooks | [`bazaar.md`](skills/bazaar.md) |
| Edit `system_files/shared/`, `bluefin/`, or `nvidia/` | [`submodule-boundary.md`](skills/submodule-boundary.md) |
| Touch any image reference or registry path | [`image-registry.md`](skills/image-registry.md) |
| Modify the `Containerfile` or add a binary | [`containerfile.md`](skills/containerfile/SKILL.md) |
| Use Context7 to look up external tools | [`context7.md`](skills/context7.md) |
| Change `.github/workflows/` | [`ci-tooling.md`](skills/ci-tooling/SKILL.md) + [`workflow-map.md`](skills/workflow-map.md) |
| Debug a CI failure | [`ci-pitfalls.md`](skills/ci-pitfalls/SKILL.md) |
| Work on E2E test changes | [`e2e-ci.md`](skills/e2e-ci/SKILL.md) |
| Understand release / promotion | [`release-promotion.md`](skills/release-promotion/SKILL.md) |
| Understand QA coverage or run tests | [`qa.md`](skills/qa.md) |
| Submit a hardware test report | [`hardware-testing.md`](skills/hardware-testing.md) |
| Lab-test a common PR on ghost | [`lab-testing/SKILL.md`](skills/lab-testing/SKILL.md) |
| Write or test shell scripts | [`shell-scripts.md`](skills/shell-scripts/SKILL.md) |
| Work on brew / preinstall packages | [`brew-lifecycle.md`](skills/brew-lifecycle/SKILL.md) |
| Work on `ujust devmode` | [`devmode.md`](skills/devmode.md) |
| Work with bootc | [`bootc.md`](skills/bootc.md) |
| Work with NVIDIA GPU support | [`nvidia.md`](skills/nvidia/SKILL.md) |
| Add or gate a GPU vendor toolkit (AMD, Intel) | [`gpu-toolkit-interface.md`](skills/gpu-toolkit-interface.md) |
| Work with OEM first-boot hooks | [`oem-hardware-hooks.md`](skills/oem-hardware-hooks/SKILL.md) |
| Understand MIME defaults | [`mime-defaults.md`](skills/mime-defaults.md) |
| Understand why skill-drift was retired | [`skill-drift.md`](skills/skill-drift.md) |
| Decide whether / how to update a skill | [`skill-improvement.md`](skills/skill-improvement.md) |
| Author a new skill | [`write-a-skill.md`](skills/write-a-skill.md) |
| Understand bonedigger lifecycle | [`bonedigger.md`](skills/bonedigger/SKILL.md) |
| Use Discord ChatOps / Botkube | [`discord-chatops.md`](skills/discord-chatops.md) |
| Handle secrets / Botkube RBAC | [`secrets-policy.md`](skills/secrets-policy.md) |
| Understand factory topology | [`factory/README.md`](factory/README.md) |

This table is curated by hand for quick scanning. The full, generated catalog
— every skill's `id`, `category`, `status`, and one-line purpose — lives in
[`skills/index.json`](skills/index.json) (machine-readable) and
[`skills/index.md`](skills/index.md) (human-readable mirror). Both are
produced by `scripts/generate_skill_index.py`; see
[`write-a-skill.md`](skills/write-a-skill.md) for the required front-matter
fields and regeneration step.

## How to load a skill

Read the skill file's front-matter first. If `description` and `tags` match
your task, read the body. If the topic spans multiple repos, the local skill
links to `projectbluefin/actions` or `docs/factory/` — follow the link rather
than duplicating facts.

## Writing skills

- [`skill-improvement.md`](skills/skill-improvement.md) — when and why to update skills.
- [`write-a-skill.md`](skills/write-a-skill.md) — authoring, front-matter, size budget, and linking rules.
