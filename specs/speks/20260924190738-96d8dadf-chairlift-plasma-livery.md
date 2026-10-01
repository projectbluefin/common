---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-96d8dadf-chairlift-plasma-livery

## Overview

ChairLift users on Plasma can apply and revert supported desktop marks and see the result immediately instead of receiving false success from GNOME-only writes. GNOME behavior remains unchanged, and unsupported Plasma controls do not appear. Source: [chairlift#211](https://github.com/projectbluefin/chairlift/issues/211).

## Requirements

- [x] **Detect desktop environment**
  The app distinguishes GNOME, Plasma and unsupported sessions before showing livery groups.
- [x] **Use desktop-appropriate Files mark**
  On Plasma, Files customization targets Dolphin through hicolor using existing icon-shadowing behavior.
- [ ] **Apply visible Plasma marks**
  People can set a Kickoff app-grid mark on Plasma and see it update without logging out.
- [ ] **Revert without data loss**
  Reverting Plasma marks restores a user value if one existed or removes the override if not.
- [ ] **Hide unsupported surfaces**
  Plasma never presents a GNOME-only panel mark; unsupported desktops hide livery groups.
- [ ] **Document two-desktop results**
  Walkthroughs and screenshots demonstrate apply/revert on actual GNOME and Plasma sessions.

## Constraints

- Blocked by capability-driven visibility in chairlift#203.
- Image identity and desktop environment are independent; do not special-case Bazzite as a desktop.
- All mutating paths respect `dryrun.Enabled()`; allowed command classification includes KDE binaries.

## Acceptance Criteria

- [x] **Detect desktop environment**
  Closed #213 tests GNOME, Plasma and unknown XDG_CURRENT_DESKTOP values against the desktop capability selection.
- [x] **Use desktop-appropriate Files mark**
  The closed #216 path applies the Files mark to Dolphin; GNOME Nautilus output remains unchanged.
- [ ] **Apply visible Plasma marks**
  On a Plasma session, apply updates Kickoff and its icon cache; #212 proves the mechanism and #215/#218 implement it.
- [ ] **Revert without data loss**
  Both pre-existing and absent user-value cases return to their original desktop appearance after revert.
- [ ] **Hide unsupported surfaces**
  The Plasma panel group and unknown-session groups are absent, not disabled success-looking controls.
- [ ] **Document two-desktop results**
  Real-session evidence and docs #220 show immediate apply/revert and GNOME parity.

## Technical Approach

- Use a per-desktop livery surface table: icon-theme shadowing for Files and desktop-setting writes for the app-grid. Limit environment-specific cache invalidation to a narrow seam.
- Source: #212–#220; #213 detection and #216 Dolphin path closed. Keep existing GNOME paths and dry-run screenshot behavior.
- Source mapping: Kickoff uses the `icon` key in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` via `kwriteconfig6`, instead of GNOME's Adwaita `view-app-grid-symbolic` (`internal/livery/apply.go:55-63`). Dolphin uses `org.kde.dolphin` in `hicolor` instead of `org.gnome.Nautilus` (`apply.go:70-73`). Plasma has no equivalent of GNOME's `menuicon-setting` panel mark (`apply.go:64-69`).
- Refresh Plasma icons via `org.kde.KIconLoader.iconChanged` and validated applet reload rather than GNOME `GAppInfoMonitor` mtime touch. Revert tests must distinguish a pre-existing user-layer INI override from no override before `kwriteconfig6 --delete`; #212 still validates these paths.
- `XDG_CURRENT_DESKTOP`/`DESKTOP_SESSION` is the cheap detection seam. Keep image identity separate: the gaming-image default from `livery.DefaultFoundationID` still flows through the KDE backend without a Bazzite special case.

## Success Metrics

- Both supported marks visibly change and revert in Plasma without relogin; GNOME behavior remains unchanged.

## Non-Goals

- No Plasma panel mark, global theme/color scheme, image channel mapping or rebase behavior.
