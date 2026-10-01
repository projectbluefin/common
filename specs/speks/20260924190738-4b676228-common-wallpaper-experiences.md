---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-4b676228-common-wallpaper-experiences

## Overview

Bluefin users can opt into slideshow and looping-video wallpaper experiences through ChairLift bundles while retaining the desktop’s native timed wallpaper behavior until they choose rotation. Four existing sub-issues own artwork, bundle surfacing, Damask integration and first-run configuration. Source: [common#1157](https://github.com/projectbluefin/common/issues/1157).

## Requirements

- [ ] **Offer two optional bundles**
  People can install Wallpaper Slideshow (Damask) and Video Wallpaper (Hidamari) from ChairLift without installing both.
- [ ] **Make Damask access safe**
  The slideshow can read only packaged and user wallpaper folders and runs its background service only when installed.
- [ ] **Preserve native wallpaper defaults**
  First use seeds a 24-hour slideshow interval but leaves active-source none until the user opts in.
- [ ] **Ship a working video sample**
  Hidamari includes one project-owned looping movie selectable through the optional video bundle.
- [ ] **Explain platform limitations**
  Users learn when XWayland fullscreen pausing or NVIDIA Wayland decoding is unsupported before relying on it.

## Constraints

- Bundles belong to /usr/share/ublue-os/homebrew and to ChairLift’s brew_bundles_group; no forced wallpaper replacement or automatic uninstall path.
- Damask sandbox access is read-only for /usr/share/backgrounds and xdg-data/backgrounds; systemd user service must avoid failed restart loops when absent.
- Video playback on XWayland/Wayland must report real limits rather than promising fullscreen pause or GPU decode.

## Acceptance Criteria

- [ ] **Offer two optional bundles**
  Both Brewfile bundles appear as distinct Install actions; removing them uses ChairLift Flatpak management.
- [ ] **Make Damask access safe**
  The Flatpak has read-only wallpaper folder access and damask.service remains inactive when Damask is absent.
- [ ] **Preserve native wallpaper defaults**
  On a fresh session GNOME day/night wallpaper remains unchanged until rotation is explicitly enabled.
- [ ] **Ship a working video sample**
  The movie is packaged, can loop in Hidamari and does not start playback without user choice.
- [ ] **Explain platform limitations**
  Documentation states X11-dependent pause behavior, software decode fallback and Damask timer reset on relogin.

## Technical Approach

- Work map: #1158 movie, #1159 bundles, #1160 sandbox and user service, #1161 non-destructive first-run hook. Keep those four links intact.
- The current source proposal uses ConditionPathExists=| for the user service, interval 86400 and active-source=none; verify those exact interactions when designing the implementation.

## Success Metrics

- Neither wallpaper engine runs before selection; both can be installed from the ordinary UI and the stock day/night cycle remains intact.

## Non-Goals

- Do not build a second wallpaper manager inside ChairLift or replace desktop wallpaper settings.
