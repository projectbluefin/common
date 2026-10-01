---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924185705-b85790e7-chairlift-capability-driven-visibility

## Overview

ChairLift must show only controls backed by capabilities available on the current machine, so users do not encounter inert update, application, AI or appearance surfaces. This spec translates [chairlift#203](https://github.com/projectbluefin/chairlift/issues/203) into consistent, truthful availability across navigation, view construction and Help without changing privileged actions.

## Requirements

- [x] **Resolve host capabilities independently of the UI**
  The application can classify whether each backing tool or service is available without a GTK dependency; tracked by #204.
- [x] **Apply one capability floor across surfaces**
  Navigation, constructed groups, update sources and user preferences all use configured AND available as their visibility floor; tracked by #205.
- [x] **Use one Homebrew path for visibility and execution**
  A configured Brew group is visible only when the same resolved Brew executable can run its action; tracked by #207.
- [ ] **Hide unavailable groups instead of leaving inert controls**
  When flatpak, brew, podman, bootc/stage, uupd.timer or the extension schema is absent, its unsupported group or row is omitted, while supported siblings remain usable; tracked by #206.
- [ ] **Keep navigation stable during capability resolution**
  Cheap page checks complete during construction; slower group checks reveal a hidden group only after availability is confirmed and do not cause session-long sidebar reordering.
- [ ] **Explain unavailable functionality without false success**
  Help presents authoritative reasons for missing capabilities on demand and failures remain errors rather than absence; tracked by #209.
- [ ] **Verify and document the same policy**
  Headless capability tests, CHAIRLIFT_CAPABILITIES E2E coverage, screenshots and product guidance describe the same five-section visibility contract; tracked by #208 and #210.

## Constraints

- A user-disabled group stays disabled even when the host supports it; preserve the shipped disabled defaults for reset_group and maintenance_cleanup_group.
- Configuration load failures remain fail-closed and never re-enable hidden groups.
- Page-level checks on the GTK thread must remain cheap; group-level async checks start hidden and resolve once without visible flapping.
- The capability model stays pure and headless-testable; do not import puregotk directly or transitively.

## Acceptance Criteria

- [x] **Pure host resolution**
  The tests for #204 resolve present and missing backing tools without GTK.
- [x] **Shared policy floor**
  The tests for #205 show that config can subtract availability but cannot add unsupported groups.
- [x] **Homebrew consistency**
  The completed #207 path uses the same executable lookup for visibility and action.
- [ ] **No unsupported inert controls**
  On hosts lacking each relevant tool/service in the source matrix, no corresponding inert group/subtitle is constructed; the old `flatpak`, `brew` and `podman` inert-subtitle paths are deleted rather than kept as an alternate behavior.
- [ ] **Stable session navigation**
  After initial resolution, Alt+N destinations and sidebar items stay fixed; async group reveal does not flash unsupported controls.
- [ ] **Truthful Help and errors**
  Missing capability reasons are available in Help, while a failed availability check remains an error.
- [ ] **Visual and automated gates**
  make ci (including internal/installcheck) and make screenshots pass with the capability matrix exercised; #208/#210 guidance agrees with behavior.

## Technical Approach

- Retain the existing `internal/navigation.VisibleItems(enabled func(page, group string) bool)` and `anyGroupEnabled`; compose `capability.Compose(w.config.IsGroupEnabled, set)` through `views.New` and updateflow rather than adding a new navigation subsystem.
- Existing `internal/updateflow` uses `SourceState{Configured, Available, Enabled}` (`model.go:52-64`), `Provider.Available()` (`model.go:105`) and `Enabled = configured[id] && available && preferenceEnabled(preferences, id)` (`coordinator.go:337`). Extend that vocabulary to page and group visibility; `internal/autoupdate/autoupdate.go:43-46` already states the intended hidden-when-unavailable rule.
- Sub-issues (source text): #204 pure package; #205 common predicate; #206 remove inert subtitles; #207 Brew path; #208 E2E; #209 Help; #210 docs and acceptance of ADR-0013.

| Missing prerequisite | Current behavior to reconcile | Source anchor |
|---|---|---|
| `uupd.timer` | Row omitted | `internal/views/update_all.go:152-154` |
| `bootc` / stage script | Group hidden | `internal/views/updates_page.go:596-597` |
| `flatpak` | Pane shows zero badge and inert subtitle | `internal/views/updates_page.go:469-481` |
| `brew` | Pane shows inert expander subtitles | `internal/views/applications_page.go:278-290` |
| `podman` | Switch insensitive with subtitle | `internal/views/aistack.go:61-62` |
| GNOME extension schema | `ErrExtensionMissing`, disabled row | `internal/livery/apply.go:502-511`, `:537-539`; `internal/views/livery_page.go:289-301` |
| `distrobox` | Action-side step skipped with `OutcomeSkipped`; do not change powerwash behavior | `internal/powerwash/powerwash.go:104-107` |

- `internal/navigation/navigation.go:151` is called at `internal/window/window.go:118`; `anyGroupEnabled` (`:217`) already collapses pages with no groups and `Item.AlwaysShow` (`:22`) keeps Help. The configured map and `views.New` at `window.go:121-131` must use the same capability predicate. `config.go:101-135` supplies the fail-closed behavior; `navigation.go:229-239` fixes Alt+N destinations for the session.

## Success Metrics

- Every item in the seven-case source availability matrix has one truthful visible/hidden outcome instead of an inert subtitle.
- Screenshots capture every navigable page on the CI runner without unsupported controls.

## Non-Goals

- Do not infer AI capability from GPU presence: missing GPU can slow inference without making the action impossible.
- Do not repeatedly probe or reorder the session sidebar after the initial resolution.
- Do not change pkexec, helpers, privileged policy, or action-side behavior.
