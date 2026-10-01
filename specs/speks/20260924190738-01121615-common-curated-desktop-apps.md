---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-01121615-common-curated-desktop-apps

## Overview

Bluefin users can install a curated, non-duplicative desktop application collection suited to ordinary tasks and creative work. The proposal remains discussion-stage; the final roster must be verified before an image changes. Source: [common#1087](https://github.com/projectbluefin/common/issues/1087).

## Requirements

- [ ] **Curate one app per everyday task**
  The full-desktop application set covers documents, media, creative work and utilities without carrying obsolete duplicates.
- [ ] **Keep Flatpak and shell-extension ownership separate**
  Flatpak selection lives in common’s Brewfile while GNOME Shell extensions and settings remain image-owned.
- [ ] **Support published architectures**
  Selected app IDs are available for x86_64 and aarch64 where the image variants promise both.
- [ ] **Preserve portal safety**
  Apps requiring filesystem, camera, audio or background access receive only reviewed permissions.
- [ ] **Validate package manifests**
  The curated Brewfile passes the repo’s existing validation and can be installed.

## Constraints

- Keep `system_files/bluefin/usr/share/ublue-os/homebrew/full-desktop.Brewfile` the owner; do not edit shared or NVIDIA overlays for this curation.
- Proposal excludes Cawbird, Teleport, LibreOffice, KeePassXC, VLC, Filezilla, Boatswain, HandBrake, Rnote, Fragments, PikaBackup, Remmina, Collision, Tuba, Cartridges and Commit until maintainer review changes that list.

## Acceptance Criteria

- [ ] **Curate one app per everyday task**
  The chosen roster gives each documented task a maintained app, and excluded/pruned entries do not remain in full-desktop.Brewfile.
- [ ] **Keep Flatpak and shell-extension ownership separate**
  The Brewfile contains only intended Flatpak apps; image-level extension changes are reviewed in their own owner repo.
- [ ] **Support published architectures**
  Each selected Flathub ID is verified for both target arches or has an approved explicit exception.
- [ ] **Preserve portal safety**
  A permissions audit documents actual portals and no app acquires broader access by default.
- [ ] **Validate package manifests**
  common/scripts/validate-brewfiles.sh passes and a smoke install resolves every selected app ID.

## Technical Approach

- Issue roster names Collabora Office, Apostrophe, Whisp, Planify, Minder, PDF Arranger, Foliate, Komikku, Amberol, Shortwave, EarTag, Blanket, Mousai, OBS, Kdenlive, Blender, Inkscape, GIMP, VideoTrimmer, Kooha, Curtail, Eyedropper, Warp, LocalSend, Raider, Authenticator, Decoder, Dialect, Solanum and NewsFlash; verify all IDs from the current issue before implementation.
- GNOME extension candidates (Bluetooth Battery Meter, Copyous, audio-device tools, Syncthing Toggle, Tiling Assistant) are a separate bluefin image decision, not part of this Brewfile change.
- Proposed office/docs IDs: `com.collaboraoffice.Office`, `org.gnome.gitlab.somas.Apostrophe`, `io.github.tanaybhomia.Whisp`, `io.github.alainm23.planify`, `com.github.phase1geo.minder`, `com.github.jeromerobert.pdfarranger`, `com.github.johnfactotum.Foliate`, `info.febvre.Komikku`.
- Proposed media IDs: `io.bassi.Amberol`, `de.haeckerfelix.Shortwave`, `app.drey.EarTag`, `com.rafaelmardojai.Blanket`, `io.github.seadve.Mousai`.
- Proposed creative IDs: `com.obsproject.Studio`, `org.kde.kdenlive`, `org.blender.Blender`, `org.inkscape.Inkscape`, `org.gimp.GIMP`, `org.gnome.gitlab.YaLTeR.VideoTrimmer`, `io.github.seadve.Kooha`, `com.github.huluti.Curtail`, `com.github.finefindus.eyedropper`.
- Proposed utility IDs: `app.drey.Warp`, `org.localsend.localsend_app`, `com.github.ADBeveridge.Raider`, `com.belmoussaoui.Authenticator`, `com.belmoussaoui.Decoder`, `app.drey.Dialect`, `org.gnome.Solanum`, `io.gitlab.news_flash.NewsFlash`. These remain proposals until arch/portal checks pass.

## Success Metrics

- Every chosen application resolves and installs on its intended architecture; no excluded duplicate remains.

## Non-Goals

- Do not change GNOME Shell extension ownership, image defaults or third-party package sources through a Brewfile edit.
