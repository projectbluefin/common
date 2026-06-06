# docs/skills — Index

Agent-agnostic skill docs for the `projectbluefin/common` repo. These apply to any agent (Copilot, Claude, etc.) working in this repository.

## What belongs here

Workflow knowledge, architectural context, and operational runbooks that any agent needs to work effectively in this repo.

## What does NOT belong here

Agent-specific instruction files (`.github/copilot-instructions.md`, `AGENTS.md`, `.cursorrules`, etc.) are loaded separately by their respective tools and must not be listed here.

## Factory docs

| File | What it covers |
|---|---|
| [../factory/README.md](../factory/README.md) | Org brain landing page — factory structure, data flow, infrastructure state, open gaps, branch targets, sensitive paths, parity matrix |
| [../factory/IMPROVEMENTS.md](../factory/IMPROVEMENTS.md) | **Why we rewrote Bluefin** — narrative by area (build, CI, lifecycle, agentic model, QA, security). Living doc; agents append as improvements land. |
| [../factory/agentic-model.md](../factory/agentic-model.md) | Cross-repo agent rules — hard rules, smallest-change principle, branch targets, sensitive paths, doc-only push exception, ublue-os prohibition |

## QA and promotion docs

| File | What it covers |
|---|---|
| [../qa/PROMOTION_GATES.md](../qa/PROMOTION_GATES.md) | Current promotion pipeline — what gates exist vs. are still planned; today's real pre-promotion checklist |
| [../qa/HARDWARE_CANARY.md](../qa/HARDWARE_CANARY.md) | Hardware canary program design intent and current manual process |
| [../hardware-testing.md](../hardware-testing.md) | Hardware test report format, 7 hardware-only bug categories, promotion policy for hardware blockers |

## Skill docs

| File | What it covers |
|---|---|
| [bluefin-ci.md](bluefin-ci.md) | Bluefin CI/CD troubleshooting — workflow failures, build status, common issues |
| [bluefin-build.md](bluefin-build.md) | Bluefin build, validation, and PR workflow — working in bluefin, bluefin-lts, common, or dakota |
| [bluefin-iso.md](bluefin-iso.md) | ISO building and promotion — CloudFlare R2, testing→production, LTS warnings |
| [bluefin-lts.md](bluefin-lts.md) | LTS variant — critical production warnings about disabled ISOs; always load before LTS work |
| [bluefin-packages.md](bluefin-packages.md) | Package management — brew formulas, flatpaks, RPM/DNF packages, COPR repos |
| [bluefin-release.md](bluefin-release.md) | Release process — changelogs, stream tags (gts/stable/latest/beta), release cadence |
| [release-promotion.md](release-promotion.md) | **common** release and promotion — criteria, monthly cadence, hotfix process, artifact verification, supply chain gaps |
| [bluefin-renovate.md](bluefin-renovate.md) | Renovate dependency update handling — reviewing/merging Renovate PRs, configuring behavior |
| [bluefin-security.md](bluefin-security.md) | Security model — COPR repos, cosign verification, secureboot, sensitive package decisions |
| [bluefin-variants.md](bluefin-variants.md) | Variant and stream matrix — which image/tag/flavor to use, build matrix, explaining variants |
| [label-workflow.md](label-workflow.md) | Label taxonomy, issue lifecycle, and workflow guidelines for humans and agents across all factory repos |
| [governance.md](governance.md) | Triagers role, CODEOWNERS sentinel pattern, sync workflow, branch protection matrix |
| [qa.md](qa.md) | QA model, test coverage matrix, promotion gates by repo, hardware gap, running tests |
| [hive-review.md](hive-review.md) | `~/src/hive-status` — session start, P0/P1 triage, hive label taxonomy |
| [queue-dashboard.md](queue-dashboard.md) | PR review and merge queue workflow — ruleset (1 approval, squash, ALLGREEN queue), triage tiers, rebase patterns, submodule boundary policy |
| [workflow-map.md](workflow-map.md) | What each `common` GitHub workflow is for — validation, E2E, release, and factory-policy boundaries |
| [e2e-ci.md](e2e-ci.md) | Pre/post-merge and promotion-candidate E2E CI for common — composed PR gate, testing-stream smoke/common checks, masked brew setup, quarantined scenarios |
| [ci-tooling.md](ci-tooling.md) | Pre-commit floating-tag guard, live skill-drift workflow, Renovate OCI digest tracking |
| [onboarding.md](onboarding.md) | Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos |
| [submodule-boundary.md](submodule-boundary.md) | What is/isn't editable in this repo — `system_files/shared/` is directly tracked here (edit freely), `system_files/bluefin/` is Bluefin-specific |
| [dconf-consistency.md](dconf-consistency.md) | GSettings override ↔ dconf lock file parity rules — must edit both files together for locked settings |
| [image-registry.md](image-registry.md) | ublue-os vs projectbluefin org split for OCI publishing — production images still at `ghcr.io/ublue-os/` |
| [rollback-helper.md](rollback-helper.md) | `ublue-rollback-helper` TUI state machine — three-way coordinated arrays, LTS/non-LTS branches, registry path derivation, testing guidance |
| [skill-drift.md](skill-drift.md) | How the skill-drift CI check works — path mapping, what counts as a satisfying update, waiver process |
| [human-gates.md](human-gates.md) | The 4 decision gates (Design/Security/Breakage/Merge) — when to stop, how to signal, verification evidence requirement |
| [skill-improvement.md](skill-improvement.md) | The skill-improvement mandate — checklist, what counts as a learning, cross-repo routing |
| [bonedigger.md](bonedigger.md) | bonedigger + kubestellar-bot — the full self-improvement loop, ujust report, priority escalation, template sync |
| [hive.md](hive.md) | Hive system architecture — bonedigger/kubestellar-bot/hive triangle, label taxonomy, sync schedule, finding work |
| [acmm-audit-level2.md](acmm-audit-level2.md) | ACMM Level 2 audit (2026-06-05) — confirms L2 maturity, maps feedback mechanisms, defines Level 3 bridge requirements |
| [factory-improvement.md](factory-improvement.md) | Self-improving factory loop — gap audit protocol, pipeline uniformity checklist, human gates, known gaps, and priority order for full automation |
| [dakota-add-package.md](dakota-add-package.md) | Adding a new software package to the dakota/Bluefin BuildStream build |
| [dakota-agent-quickstart.md](dakota-agent-quickstart.md) | Zero-context entry point for routine dakota maintenance — routing table for add/remove/update |
| [dakota-bst-overrides.md](dakota-bst-overrides.md) | BuildStream junction element overrides in dakota — upstream-first principle and patterns |
| [dakota-buildstream.md](dakota-buildstream.md) | Writing/editing BuildStream .bst elements — variable names, element kinds, source kinds, hooks |
| [dakota-ci.md](dakota-ci.md) | dakota CI failures, build pipeline, GHA workflow, remote CAS, local-vs-CI debugging |
| [dakota-debugging.md](dakota-debugging.md) | BuildStream build failures in dakota — diagnosing element errors and CI build logs |
| [dakota-installer.md](dakota-installer.md) | Dakota installer (tuna-os fork) — dev setup, build loop, CI/release, ISO integration |
| [dakota-local-ota.md](dakota-local-ota.md) | Local OTA update registry workflow — zot registry, publishing images, QEMU VM testing |
| [dakota-oci-layers.md](dakota-oci-layers.md) | How packages flow into the final OCI image — layer assembly, debugging missing files |
| [dakota-overview.md](dakota-overview.md) | What dakota/egg is, how it differs from production Bluefin, package gaps, planning additions |
| [dakota-package-binaries.md](dakota-package-binaries.md) | Packaging pre-built static binaries in dakota — when building from source is impractical |
| [dakota-package-gnome-extensions.md](dakota-package-gnome-extensions.md) | Packaging GNOME Shell extensions for BuildStream — paths, UUID discovery, GSettings schemas |
| [dakota-package-go.md](dakota-package-go.md) | Packaging Go projects for BuildStream — go_module sources, offline builds, GOPATH vendoring |
| [dakota-package-rust.md](dakota-package-rust.md) | Packaging Rust/Cargo projects for BuildStream — cargo2 sources, offline builds |
| [dakota-package-zig.md](dakota-package-zig.md) | Packaging Zig build system projects — offline dependency caching, zig fetch/build |
| [dakota-patch-junctions.md](dakota-patch-junctions.md) | Modifying upstream freedesktop-sdk/gnome-build-meta elements — patch vs replace decisions |
| [dakota-remove-package.md](dakota-remove-package.md) | Removing a software package from the Bluefin image in dakota — delete .bst, unwire from build |
| [dakota-testlab-setup.md](dakota-testlab-setup.md) | One-time NUC/ghost provisioning for the dakota hardware test lab |
| [dakota-testlab.md](dakota-testlab.md) | Ghost + exo-dakota active hardware loop — build, publish to zot, test, gate PR on lab evidence |
| [dakota-testlab-lessons.md](dakota-testlab-lessons.md) | Archived dakota testlab lessons learned (May 2026) |
| [dakota-update-refs.md](dakota-update-refs.md) | Updating package versions in dakota — bumping upstream refs, dependency tracking |
| [knuckle-qa.md](knuckle-qa.md) | PR review + VM e2e workflow for knuckle — complexity gate, code review, GHA vm-e2e, merge queue |
| [knuckle-qa-lessons.md](knuckle-qa-lessons.md) | Archived knuckle QA lessons learned (May 2026) |
| [knuckle-release.md](knuckle-release.md) | End-to-end release procedure for knuckle — unit tests, VM installs, ISO smoke, tagging |
| [knuckle-testlab.md](knuckle-testlab.md) | knuckle in Flatcar QEMU VM on ghost — manual testing, TUI behavior, UI iteration |
| [../../.github/copilot-instructions.md](../../.github/copilot-instructions.md) | Copilot agent instructions — session start ritual, PR checklist, scope discipline, CODEOWNERS sentinel |
| [../factory/README.md](../factory/README.md) | Factory operating model entry point for org-level agent and maintainer workflow |
