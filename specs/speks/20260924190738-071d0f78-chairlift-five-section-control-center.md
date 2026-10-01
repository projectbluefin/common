---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-071d0f78-chairlift-five-section-control-center

## Overview

Control Center must help people update, install apps, personalize, free space and get support without exposing package-manager or image internals in its ordinary paths. A coordinated five-section cutover replaces the nine-page taxonomy without deleting specialist capabilities or safety disclosures. Source: [chairlift#233](https://github.com/projectbluefin/chairlift/issues/233).

## Requirements

- [ ] **Provide task destinations**
  The app exposes at most Updates, Apps, Appearance, System and Help as primary destinations, with focused detail views for specialist actions.
- [ ] **Keep core tasks close**
  A person can reach updates, browsing apps, personalization, storage cleanup and help in at most two navigation selections.
- [ ] **Give updates one truthful owner**
  The displayed updater distinguishes current, unknown, missing, disabled, failed and partial states while retaining automatic updates, trust, restart, change details and recovery.
- [ ] **Offer one safe cleanup action**
  Storage provides a single routine Free Up Space action; recovery and factory reset remain separate opt-in tasks.
- [ ] **Respect app installation identity**
  Apps can manage user/system installations without losing scope or administrator policy on migration.
- [ ] **Keep optional setup and appearance safe**
  Users can skip setup, choose avatars/wallpapers/icons and see only desktop-supported controls without unexpected installs or cloud activation.
- [ ] **Keep power features discoverable**
  Developer Tools, AI Tools, Recovery and technical diagnostics remain accessible through named details and truthful consequence explanations.
- [ ] **Verify full interaction quality**
  Keyboard, screen reader, narrow/large-text, light/dark, unavailable, failure, cancellation and dry-run paths all work in the real GTK app.

## Constraints

- Architecture and UX review must approve the five-section prototype before changing navigation or conflicting older ADRs.
- Configuration migration preserves explicit false values, administrator precedence, user preferences and fail-closed behavior.
- Reuse existing update coordinator, typed cleanup runner, authenticated privileged helpers and back behavior; no new arbitrary privileged command path.
- Availability is absent rather than an inert UI; failed checks remain errors and workers never mutate detached widgets.

## Acceptance Criteria

- [ ] **Provide task destinations**
  A navigation audit finds five or fewer primary entries and every existing action has a destination or an explicit handoff.
- [ ] **Keep core tasks close**
  Three people unfamiliar with Linux complete the five tasks without coaching; wrong turns and blockers are recorded.
- [ ] **Give updates one truthful owner**
  No old page fetches or mutates a competing update state; an unchecked host is never described as current.
- [ ] **Offer one safe cleanup action**
  The action omits installed apps, user data, containers, boot history and configured scripts; partial failure and cancelled auth are not success.
- [ ] **Respect app installation identity**
  An app installed in both scopes appears with distinct identities and removal targets only the selected installation.
- [ ] **Keep optional setup and appearance safe**
  Skip persists, setup has at most three decisions, GNOME/Plasma apply and revert visibly work, and the sidebar remains stable.
- [ ] **Keep power features discoverable**
  No ordinary route requires unexplained Brewfile/tap/deployment choices; privileged and destructive actions still disclose their effects.
- [ ] **Verify full interaction quality**
  Focused tests and make ci pass; real GTK E2E/screenshots and the novice walkthrough cover all five destinations.

## Technical Approach

- Proposed map: Updates (status and decisions), Apps (store, bundles, Developer and AI details), Appearance (profile, wallpapers, icons), System (overview, Storage, Recovery), Help (support and diagnostics). Detail views are not sidebar entries.
- The source audit is anchored in internal/navigation/navigation.go, internal/window/window.go, internal/views/views.go, internal/views/update_shell.go, internal/views/updatepresent/updatepresent.go, internal/updateproviders/maintenance.go, internal/powerwash/powerwash.go and docs/walkthrough.md; preserve these sources when reviewing the cutover.
- Delivery slices from the source: approve product prototype; unify Updates; separate Storage/Recovery; Apps/specialist views; Appearance/Help/setup; real cross-product verification. Native sub-issues #241–#251 and nested epics #195/#203/#211/#222/#235 retain ownership; closed #245 is the recovery separation, not evidence that the whole cutover shipped.
- Source audit and exact code anchors preserved below.

### Audit: current interface → revision

Evidence: inspected all seven committed page screenshots, the corresponding builders and companion dialogs, the actual window composition, Preferences/shortcuts, and all four new epic bodies plus affected child contracts. Source checkout HEAD: `20974ce70bc4f85ce8b88a81796404fa9569f460`; local proposed ADR/spec documents were also read. This is a source-and-screenshot audit, **not** a live usability study or a screen-reader certification.

| Surface | Finding | Revision / disposition |
|---|---|---|
| Navigation and startup | Seven current destinations begin with Applications; the expansion plan grows to nine. Maintenance, Features, Livery and Agents ask people to translate project terminology. | Reduce to the five task destinations below; open on Updates when available, otherwise the first supported destination. Preserve an always-reachable Help fallback. |
| Updates | The window already mounts the status-first `UpdateShell`, but `UserHome` still constructs the legacy Updates page. The committed Updates screenshot shows the legacy page, not the mounted shell. | **Keep and finish the existing unified flow**, do not build a third updater. Migrate still-needed actions, then remove the superseded page, duplicate workers and competing badge updates. |
| Update status and settings | Provider/source rows remain prominent; update preferences live in a separate generic Preferences dialog. The ready presentation can say “System Is Up to Date” while its description says no sources are available. | Show the overall result first; put source/item detail behind “Details” and source selection under “Update Settings”. Distinguish unavailable, excluded, checking, partial failure, current, and restart-needed states. Never imply the entire computer was checked when it was not. |
| Update extras | Automatic updates, restart, rollback, on-demand changes/SBOM comparison, individual package actions and tap-trust handling exist in the old surface. | Inventory and migrate intentionally before removing it: automatic updates/settings stay in Updates; changes stay on demand; rollback moves to Recovery; granular actions live in detail views or an explicit existing-manager handoff; trust remains an explicit contextual decision. |
| Applications | “Manage Flatpaks”, separate User/System Flatpak lists, Formulae/Casks, raw package search, pin/unpin, and “Brew Bundle Dump” expose the package taxonomy. | **Apps** leads with “Browse Apps” (the configured store) and a combined installed-app view. Preserve backend identity and scope internally; disclose “Only for you” / “All users” where it affects removal. Technical packages, search, version pinning and export move to Developer Tools details, not into the trash. Do not equate every cask with a desktop app or every system-scope app with an immutable OS component. |
| App collections / bundles | A manifest and its filename are treated as a user concept; upcoming bundles introduce multiple specialist sets. | Present named app/tool collections with purpose, contents and Installed / Updates Available / Not Installed states. Keep manifest discovery and execution from the workstation epic; avoid duplicate listings on multiple pages. |
| Routine maintenance | Separate Homebrew and Flatpak cleanup actions, configurable script runners, and a “System Optimization — Coming soon” placeholder. | Replace the ordinary Maintenance page with **System → Storage → Free Up Space**, one supported cleanup action. Delete the placeholder. Keep administrator-provided maintenance separate in a clearly named specialist detail view when configured; never fold unknown scripts into routine cleanup. |
| Reset and recovery | Powerwash and Factory Reset share Maintenance with cleanup. “Remove Everything I Installed” overstates a runner that removes user Flatpaks and Distrobox containers, not every installation technology. | Move to **System → Recovery**. Describe each operation's actual scope; preserve opt-in defaults, confirmation, experimental disclosure, and existing authentication. They are never cleanup steps. |
| System information | Raw OS-release fields, deployment references and digests dominate details; “System Health” is a monitor launcher. | Lead with a concise About This Computer summary using known data. Put diagnostics/build identifiers behind Details. Label the launcher “Open System Monitor”; do not invent a health score. |
| Channels and graphics | Testing channel and graphics-driver switching share a Release Channel group. | Early-release selection belongs under Update Settings; supported graphics choices under System → Graphics. Explain restart and system replacement effects before confirmation; do not promise a performance improvement. |
| Features | Developer access, gaming setup, Local AI, diagnostic assistance and distribution features share one grab-bag page, including unavailable states. | Remove Features as a primary destination. Gaming setup and developer/AI tools get named Apps detail views; diagnostic assistance belongs in Help; distribution-specific system features belong in System details. Preserve their separate lifecycles and security models. |
| Livery and choosers | “App Grid Livery”, “Foundational Livery”, and “Dock Livery” require insider knowledge; controls expose extensions/catalog mechanics. | Rename the destination **Appearance**. Add the planned avatar/wallpaper work there. Under Icons, name the actual surfaces: app launcher, top-bar icon where supported, Files/Dolphin icon. Show previews and a clear restore-default action; rotation and custom SVG are secondary choices. Clarify that the Files icon changes across the desktop, not just the dock. |
| Help | Primarily external website/issues/discussion links with raw URLs; diagnostic assistance is elsewhere. | Task-oriented help and troubleshooting first, then support/reporting links. Retain configured destinations. Explain unavailable features in a collapsed diagnostic section, not another error catalog. AI assistance remains optional and names its provider and data disclosure before setup. |
| Menus, dialogs, states | Preferences is predominantly update settings; repeated headings/subtitles, implementation errors, confirmation flows and small-window/keyboard states need the same treatment as pages. | One app menu and consistent commands. Contextual settings instead of duplicate ownership. Plain-language errors with a next action and expandable/copyable technical detail; visible status for long operations, retained state on failure, no unnecessary confirmations for harmless navigation. |
| Visual evidence | Published screenshots contain missing-icon glyphs and omit some enabled/optional surfaces; the Updates capture is stale relative to source. | Capture the real revised surfaces and dialogs, including optional configurations. Verify icon availability on supported desktops rather than relying on a screenshot fixture to imply the feature works. Focus and accessibility require runtime verification; a screenshot alone cannot establish a focus bug. |

#### Source anchors for the findings

- [Canonical page inventory](https://github.com/projectbluefin/chairlift/blob/main/internal/navigation/navigation.go), [window composition](https://github.com/projectbluefin/chairlift/blob/main/internal/window/window.go) (`buildContentArea`), and [view construction](https://github.com/projectbluefin/chairlift/blob/main/internal/views/views.go).
- [Unified update shell](https://github.com/projectbluefin/chairlift/blob/main/internal/views/update_shell.go), [status presentation](https://github.com/projectbluefin/chairlift/blob/main/internal/views/updatepresent/updatepresent.go), [update preferences](https://github.com/projectbluefin/chairlift/blob/main/internal/window/preferences.go).
- [Application controls](https://github.com/projectbluefin/chairlift/blob/main/internal/views/applications_page.go), [maintenance controls](https://github.com/projectbluefin/chairlift/blob/main/internal/views/maintenance_page.go), [existing typed cleanup runner](https://github.com/projectbluefin/chairlift/blob/main/internal/updateproviders/maintenance.go), [Powerwash scope](https://github.com/projectbluefin/chairlift/blob/main/internal/powerwash/powerwash.go).
- [System](https://github.com/projectbluefin/chairlift/blob/main/internal/views/system_page.go), [Features](https://github.com/projectbluefin/chairlift/blob/main/internal/views/features_page.go), [Livery](https://github.com/projectbluefin/chairlift/blob/main/internal/views/livery_page.go), [Help](https://github.com/projectbluefin/chairlift/blob/main/internal/views/help_page.go), and [walkthrough/screenshots](https://github.com/projectbluefin/chairlift/blob/main/docs/walkthrough.md).
- [chairlift#195](https://github.com/projectbluefin/chairlift/issues/195) keeps bundle and workstation ownership; Developer/AI actions become Apps details, not new primary pages.
- [chairlift#203](https://github.com/projectbluefin/chairlift/issues/203) supplies the configured-and-available floor for task routes, onboarding, preferences and updates.
- [chairlift#211](https://github.com/projectbluefin/chairlift/issues/211) keeps Plasma apply/revert while Appearance uses one desktop-appropriate vocabulary.
- [chairlift#222](https://github.com/projectbluefin/chairlift/issues/222) owns optional setup/avatar/artwork; a skip persists and the assistant does not become a permanent destination.



## Success Metrics

- Five ordinary tasks take at most two navigation choices and five-or-fewer primary destinations remain.
- Users unfamiliar with Linux complete five tasks without coaching; failures cause copy or layout revision, not a completion claim.

## Non-Goals

- Do not reskin the app as macOS/Android, replace GTK, Bazaar or desktop settings, create a backend/plugin framework, or delete specialist capabilities to reduce page count.
- Do not bundle recovery/reset into Free Up Space, promise passwordless cleanup, or invent reclaimed byte estimates.
