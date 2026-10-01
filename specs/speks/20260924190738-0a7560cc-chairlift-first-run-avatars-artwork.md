---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-0a7560cc-chairlift-first-run-avatars-artwork

## Overview

New Bluefin users can complete or skip a short first-run introduction, choose a profile avatar, and discover wallpaper customization without growing Control Center’s primary navigation. Existing users keep their preferences and ordinary launches remain stable. Source: [chairlift#222](https://github.com/projectbluefin/chairlift/issues/222).

## Requirements

- [ ] **Choose or skip setup**
  A first-run assistant offers skippable steps, persists completed or explicitly skipped state, and can be reopened on request.
- [ ] **Reuse existing actions**
  Setup uses existing capability-filtered action handlers and refreshes main-window state when dismissed.
- [x] **Deliver safe dinosaur avatars**
  Users can select project-owned dinosaur art and apply a bounded PNG avatar to AccountsService without elevated execution.
- [ ] **Integrate avatar choice**
  Users can see and choose the dinosaur catalog in Appearance profile details.
- [ ] **Delegate wallpaper experiences**
  Appearance exposes supported Damask wallpaper controls and Hanabi video controls only when available.
- [ ] **Verify first-run journey**
  Documentation and tests exercise packaging parity, persistence, dry-run and the real GUI.

## Constraints

- The assistant is a transient AdwDialog, not a sidebar mode; suppress auto-presentation during --dry-run/screenshots.
- Preserve the session-immutable capability floor proposed in ADR-0013 and the pure-Go avatar constraints in ADR-0015. The proposed ADR-0014 transient assistant conflicts with chairlift#233 on nine-page navigation and repeat prompting; review and revise that design before treating it as binding.
- The nine-page statement in the old issue is superseded for planning by chairlift#233’s proposed five-section contract; do not create a tenth or revive nine pages.

## Acceptance Criteria

- [ ] **Choose or skip setup**
  A fresh user completes or skips each step once; later launches and the --setup path reflect the saved choice.
- [ ] **Reuse existing actions**
  Running setup does not duplicate widgets, leak pointers, bypass capability checks or leave stale Home state.
- [x] **Deliver safe dinosaur avatars**
  Closed #226–#228 provide the catalog, pure-Go WebP transcoding to 512x512 under 1 MiB, and unprivileged AccountsService dispatch.
- [ ] **Integrate avatar choice**
  Selection appears on the supported desktop and can be changed without adding a primary sidebar destination.
- [ ] **Delegate wallpaper experiences**
  Damask launches its own rotation service; Hanabi controls are absent without extension support and do not silently install software.
- [ ] **Verify first-run journey**
  A fresh install, configured install, skip and re-entry flow pass alongside screenshots and docs #232.

## Technical Approach

- Reuse existing account, livery and wallpaper handlers rather than a parallel settings system; #226–#228 and #265 are closed, while #223–#225 and #229–#232 remain open.
- Pinned art source in the issue is projectbluefin/website at commit 92b81281649c0795f16f266f712c9a2798af54c4; no new external artwork source is implied.

## Success Metrics

- Setup remains absent after an explicit skip; avatar and wallpaper changes are visible in the ordinary app without a new destination.

## Non-Goals

- No independent setup navigation mode or unconditional optional software install.
- Do not mutate AccountsService through an in-process D-Bus binding or introduce CGO for avatar decoding.
