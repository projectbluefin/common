---
name: bazaar
version: "1.1"
last_updated: "2026-07-01"
id: bazaar
one_line_purpose: Edit Bazaar curated schema, banner conversion, and local preview config.
entry_point: docs/skills/bazaar.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [bazaar, curated, flatpak, apps]
description: >-
  Use when editing Bazaar curated config, systemd service definitions, or hooks
  in common. Covers modern rows schema, native JXL banners, and local ujust preview workflows.
metadata:
  type: procedure
  context7-sources:
    - /flatpak/flatpak-docs
---

# Bazaar — curated config and hook operations

## When to use

- Editing Bazaar config in `system_files/bluefin/etc/bazaar/`
- Porting curated-page structure across Bazaar schema versions
- Changing Bazaar hook behavior for app install interception (JetBrains, VS Code/Codium, Zed)
- Adding or changing banner images (JXL→PNG conversion pipeline)
- Validating Bazaar behavior locally before opening a PR
- Modifying the background `bazaar.service` systemd service definition

## When NOT to use

- Editing general Flatpak preferences or system-wide flatpak overrides unrelated to Bazaar's hooks or configuration.

## Files and ownership

| File | Purpose |
|---|---|
| `system_files/bluefin/etc/bazaar/bazaar.yaml` | Bazaar runtime config, config paths, hook wiring |
| `system_files/bluefin/etc/bazaar/curated.yaml` | Curated Explore content (sections, banners, articles, carousels) |
| `system_files/bluefin/etc/bazaar/blocklist.yaml` | Bluefin blocklist policy |
| `system_files/bluefin/etc/bazaar/hooks.py` | Host-side hook script invoked by Bazaar |
| `system_files/bluefin/usr/libexec/bazaar-hook` | In-image hook script used by Bazaar runtime path |
| `system_files/bluefin/usr/lib/systemd/user/bazaar.service` | Background Bazaar service entrypoint |
| `tests/test_hooks.py` | `hooks.py` state machine tests |
| `tests/test_bazaar_hook.py` | `bazaar-hook` state machine tests |
| `tests/test_curated_config.py` | Curated/Bazaar config shape regression checks |

Both hook scripts must remain synchronized: `hooks.py` (host `/run/host/etc/bazaar/hooks.py`) and `bazaar-hook` (`/usr/libexec/bazaar-hook`) must implement identical hook IDs, stages, and package redirect actions.

## Curated schema specification

Bazaar (`io.github.kolunmi.Bazaar`) uses a typed schema rooted at `rows:`.

Supported row types on `BzRootCuratedConfig`:
- `banner`: Banner image view (`light-uri`, `dark-uri`, `height`, `fit`, `can-shrink`, `alt`). Banners are native `.jxl` images rendered via Flatpak glycin-jxl.
- `section`: App category grid (`title`, optional `subtitle.string`, and `appids.list`).
- `articles`: Curated markdown articles (`list` of articles with `title`, `subtitle`, `image`, `uri`).
- `featured-carousel`: Large featured app carousel (`appids.list`).

```yaml
rows:
  - banner:
      height: 400
      image:
        light-uri: file:///run/host/etc/bazaar/11-bluefin-day.jxl
        dark-uri: file:///run/host/etc/bazaar/11-bluefin-night.jxl
        fit: cover
        can-shrink: true
        alt: "Bluefin desktop screenshot"
      light-color: "#a5897b"
      dark-color: "#0d0e19"
  - section:
      title: "Bluefin Recommends"
      subtitle:
        string: "Our Favorite Applications"
      appids:
        list:
          - app.drey.Damask
          - app.freelens.Freelens
```

Note: Legacy Bazaar releases (`v0.8.2` and older) used a root-level `css:` block and `rows: - sections:`, which is deprecated upstream and rejected by modern Bazaar releases.

## Core Process: Local Preview Workflow

The curated layout references native JXL banners from the `bluefin-branding` submodule. The local preview recipes copy the curated configuration and JXL banners to `/etc/bazaar/` on the host:

### From the checked-out workspace:
```bash
# Copies all config and JXL banner files to /etc/bazaar, and restarts the service
just bazaar-preview
```

### From any terminal on a dev machine (targeting a common checkout directory):
```bash
ujust bazaar-preview /path/to/common
```

## Common Pitfalls & Rationalizations

- Editing curated content without local preview causes UI regressions to slip through.
- Copying Aurora/Bazaar examples directly can leave non-Bluefin branding or links.
- Changing hook dialog/response IDs must be mirrored in tests to avoid silent behavior drift.
- Editing `system_files/bluefin/etc/bazaar/hooks.py` without applying the same hook handler to `system_files/bluefin/usr/libexec/bazaar-hook` leaves the in-image entry point out of sync.

## Red Flags

- Local previews displaying blank/missing banners (indicates JXLs were not copied to `/etc/bazaar`).
- Open PRs modifying `curated.yaml` without matching unit tests in `tests/test_curated_config.py`.

## Verification

Before declaring a Bazaar task complete, ensure:
- [ ] `just check` passes.
- [ ] `pre-commit run --all-files` passes.
- [ ] All python unit tests (`tests/test_curated_config.py`, `tests/test_hooks.py`) are green.
- [ ] Banners in the preview list have `.jxl` extensions.
