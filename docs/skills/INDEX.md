# docs/skills — Index

Agent skill docs for the `projectbluefin/common` repo.

This is the **canonical skills hub** for the entire OS factory. All agent skills for
bluefin, bluefin-lts, common, dakota, and knuckle live here.

## Factory docs

| File | What it covers |
|---|---|
| [../factory/README.md](../factory/README.md) | Org brain landing page — what common is, factory structure, data flow, org board |
| [../factory/agentic-model.md](../factory/agentic-model.md) | Agent operating guide — rules, issue lifecycle, label taxonomy, PR policy, branch targets |
| [../factory/migration-status.md](../factory/migration-status.md) | Live parity matrix — current state of factory infra migration across all 5 repos |

## Org and process skills

| File | What it covers |
|---|---|
| [governance.md](governance.md) | Triagers role, CODEOWNERS sentinel pattern, sync workflow, branch protection matrix |
| [hive.md](hive.md) | Hive label taxonomy, sync workflow schedule, org board fields, finding work |
| [qa.md](qa.md) | QA model, test coverage matrix, promotion gates by repo, hardware gap, running tests |
| [bonedigger.md](bonedigger.md) | bonedigger integration guide, current status per repo, template sync, known issues |
| [hive-review.md](hive-review.md) | `~/src/hive-status` — session start, P0/P1 triage, hive label taxonomy |
| [queue-dashboard.md](queue-dashboard.md) | queue.projectbluefin.io — PR tiers, merge ruleset (2 approvals), refresh cadence |
| [e2e-ci.md](e2e-ci.md) | Post-merge E2E CI architecture — common suite, brew tools masked in CI, MOTD fix, known quarantined scenarios |

## Bluefin image skills

| File | What it covers |
|---|---|
| [bluefin-variants.md](bluefin-variants.md) | Variant and stream matrix — image × tag × flavor build matrix, OCI paths, Fedora version mapping |
| [bluefin-build.md](bluefin-build.md) | Build, validation, and PR workflow — anti-legacy tenets, local build, container push |
| [bluefin-ci.md](bluefin-ci.md) | GitHub Actions CI — workflow inventory, failure triage, retry patterns, artifact handling |
| [bluefin-packages.md](bluefin-packages.md) | Package management — Flatpak, Homebrew, RPM layering, Brewfile, COPR rules |
| [bluefin-security.md](bluefin-security.md) | Security model — cosign verification, COPR vetting, secureboot kernel module signing |
| [bluefin-release.md](bluefin-release.md) | Release process — stream tags, changelog generation, promotion cadence |
| [bluefin-renovate.md](bluefin-renovate.md) | Renovate dependency updates — PR review, merge rules, config location |
| [bluefin-lts.md](bluefin-lts.md) | LTS variant — CentOS base, lts branch model, critical production warnings, ISOs |
| [bluefin-iso.md](bluefin-iso.md) | ISO building and promotion — CloudFlare R2, testing→production pipeline |

## Dakota skills

| File | What it covers |
|---|---|
| [dakota-overview.md](dakota-overview.md) | What dakota is, how it differs from Bluefin, unique features, known package gaps |
| [dakota-buildstream.md](dakota-buildstream.md) | Writing .bst element files — variable names, element kinds, source kinds, command hooks |
| [dakota-oci-layers.md](dakota-oci-layers.md) | How packages flow into the final OCI image — layer assembly, file presence/absence |
| [dakota-ci.md](dakota-ci.md) | CI/CD — GitHub Actions workflow, remote CAS, local vs CI build differences |
| [dakota-debugging.md](dakota-debugging.md) | Build failure diagnosis — element errors, CI log reading, common failure patterns |
| [dakota-add-package.md](dakota-add-package.md) | Adding a new package — new .bst element, wiring into the build |
| [dakota-remove-package.md](dakota-remove-package.md) | Removing a package — deleting .bst element, unwiring from build |
| [dakota-update-refs.md](dakota-update-refs.md) | Updating package versions — bumping upstream refs, dependency tracking |
| [dakota-bst-overrides.md](dakota-bst-overrides.md) | Junction element overrides — upstream-first principle, recognizable patterns |
| [dakota-patch-junctions.md](dakota-patch-junctions.md) | Patching upstream freedesktop-sdk or gnome-build-meta elements |
| [dakota-package-go.md](dakota-package-go.md) | Packaging Go projects — go_module sources, GOPATH vendoring, offline builds |
| [dakota-package-rust.md](dakota-package-rust.md) | Packaging Rust/Cargo projects — cargo2 sources, offline builds, dependency lists |
| [dakota-package-zig.md](dakota-package-zig.md) | Packaging Zig projects — zig fetch/build, offline dependency caching |
| [dakota-package-binaries.md](dakota-package-binaries.md) | Packaging pre-built static binaries — when source build is impractical |
| [dakota-package-gnome-extensions.md](dakota-package-gnome-extensions.md) | Packaging GNOME Shell extensions — UUID discovery, GSettings schema compilation |
| [dakota-local-ota.md](dakota-local-ota.md) | Local OTA testing — zot registry on host, QEMU VM pointing at local registry |
| [dakota-testlab.md](dakota-testlab.md) | Ghost + exo-dakota active hardware loop — build, publish, test, gate PR on lab evidence |
| [dakota-testlab-setup.md](dakota-testlab-setup.md) | One-time NUC and ghost provisioning — insecure registry, bootc switch, firewall |
| [dakota-installer.md](dakota-installer.md) | Dakota installer — tuna-installer fork, dev setup, build loop, ISO integration |
| [dakota-agent-quickstart.md](dakota-agent-quickstart.md) | Zero-context entry point for routine dakota maintenance — routing table |

## Knuckle skills

| File | What it covers |
|---|---|
| [knuckle-qa.md](knuckle-qa.md) | QA workflow — test harness, scenario coverage, hardware matrix, gating criteria |
| [knuckle-release.md](knuckle-release.md) | Release process — version bumps, changelog, ISO integration, promotion steps |
| [knuckle-testlab.md](knuckle-testlab.md) | Hardware test lab — physical device setup, test execution, result reporting |
