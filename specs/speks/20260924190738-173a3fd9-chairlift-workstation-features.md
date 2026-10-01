---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-173a3fd9-chairlift-workstation-features

## Overview

ChairLift gives people clear ways to discover curated apps, enter Developer Mode and personalize their system without learning how common packages its features. Existing system-level commands remain owned by common; ChairLift is the user-facing surface. Source: [chairlift#195](https://github.com/projectbluefin/chairlift/issues/195).

## Requirements

- [x] **Bundle discovery**
  People can browse curated bundles from system/application locations and distinguish installed, update-available and not-installed states.
- [ ] **Developer Tools**
  People can reach developer access and specialist package controls from task-based Apps details rather than a separate primary Developer page.
- [ ] **Optional AI Tools**
  People can find optional local AI tools without a second conflicting agent runtime or troubleshooting destination.
- [ ] **Wallpaper bundles**
  People can install wallpaper bundles from Appearance/App details while Livery remains independent of Homebrew.
- [ ] **Preserve configured choices**
  Moving actions to five-section destinations retains administrator settings and working existing behavior.

## Constraints

- App-scoped bundle paths are `/usr/share/ublue-os/homebrew`, `/usr/share/chairlift/bundles`, `/etc/chairlift/bundles`, and `/usr/share/snow/bundles`; do not discover arbitrary `$HOME` manifests.
- Do not reinterpret the old nine-page ceiling or standalone `developer_page`/`agents_page` as a new requirement: chairlift#233 coordinates the newer five-section cutover.
- The separate Agent Mode spec chairlift#252 supersedes this epic’s RamaLama assumption; never silently migrate users into another runtime.

## Acceptance Criteria

- [x] **Bundle discovery**
  Closed #196 supplies app-scoped bundle discovery and three-state checks; listings use only the approved system/application paths.
- [ ] **Developer Tools**
  The five-section journey reaches Developer Tools without exposing a duplicate top-level destination.
- [ ] **Optional AI Tools**
  The Apps detail links to the approved Agent Mode contract and does not launch the retired RamaLama workflow.
- [ ] **Wallpaper bundles**
  The wallpaper bundles appear once and Livery operations work without importing Brew into internal/livery.
- [ ] **Preserve configured choices**
  Existing config preserves enabled/disabled groups through migration; old primary pages and duplicated action routes are removed.

## Technical Approach

- The source epic cites a workstation ADR-0013 and CONTEXT.md, but chairlift#233's source audit says that workstation ADR was not present in the audited checkout: the actual ADR-0013 is the capability-floor proposal. Reconcile the current ADRs and five-section design with maintainers before retaining any legacy standalone-page assumption.
- Existing sub-issues #196 and #234 are closed; #197–#202 remain open. Preserve that distinction when updating acceptance.

## Success Metrics

- One task destination owns each transferred user action; no extra primary page is introduced.

## Non-Goals

- Do not replace common’s image-level package integration or implement a second agent runtime.
- Do not parse Homebrew Ruby DSL to infer bundle state.
