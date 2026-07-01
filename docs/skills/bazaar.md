---
name: bazaar
version: "1.1"
last_updated: 2026-07-01
tags: [bazaar, curated, flatpak, apps]
description: "Use when editing Bazaar curated config, systemd service definitions, or hooks in common. Covers sRGB JXL-to-PNG image conversions, Type=simple requirements, and local ujust preview workflows."
metadata:
  type: procedure
  context7-sources:
    - /flatpak/flatpak-docs
---

# Bazaar — curated config and hook operations

## When to use

- Editing Bazaar config in `system_files/bluefin/etc/bazaar/`
- Porting curated-page structure across Bazaar schema versions
- Changing Bazaar hook behavior for app install interception
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

## Curated schema and compatibility notes

Bazaar supports two distinct configuration schemas depending on the installed Flatpak version. Because stable releases may lag behind upstream GitHub commits, agents must verify the local version's expected format before editing.

### 1. Legacy Schema (Stable `v0.8.2` and below)
The currently installed stable release (`v0.8.2`) expects the legacy schema structure:
- Root-level **`css:`** block containing raw GTK CSS strings.
- **`rows`** is a list where each row maps to a map containing **`sections`**:
  ```yaml
  css: |
    .global-section { margin: 15px; }
  rows:
    - sections:
        - expand-horizontally: true
          classes:
            - global-section
          category:
            title:
              en: "Bluefin Recommends"
            light-banner: file:///run/host/etc/bazaar/11-bluefin-day.png
            appids:
              - org.gnome.Calculator
  ```
- **Limitations in `v0.8.2`**:
  - Direct row types like `banner`, `articles`, `featured-carousel`, or `section` do NOT exist.
  - The `start-on-curated: true` option in `bazaar.yaml` does NOT exist and will fail main config validation.

### 2. Modern Schema (Upstream `master` / Post-`v0.8.2` tags)
Newer unreleased or upstream commits use a simplified schema where `rows` contains typed entries directly, and does not support the root-level `css:` block:
```yaml
rows:
  - banner:
      height: 250
      image:
        light-uri: https://getaurora.dev/aurora-text-logo.svg
  - section:
      title: "Welcome to Bazaar"
      appids:
        list:
          - org.gnome.Calculator
```

When porting content between repos/variants, **always check the active schema shape** to avoid rendering failures or parser errors.

## Core Process: Local Preview Workflow

Since the curated layout references PNG banners (converted from JXL files inside the branding submodule), the local environment needs those PNGs to exist in `/etc/bazaar` on the host to avoid rendering blank/empty spaces.

Always use the automated preview recipes which handle JXL conversion via a non-root `podman` container and reload the systemd service:

### From the checked-out workspace:
```bash
# Formats, builds/converts JXL banners to PNG, copies all config files to /etc/bazaar, and restarts the service
just bazaar-preview
```

### From any terminal on a dev machine (targeting a common checkout directory):
```bash
ujust bazaar-preview /path/to/common
```

## Common Pitfalls & Rationalizations

- **"I can just run djxl locally."** -> This fails in CI and on many developer machines because `djxl` is not installed on the host. Always use the automated `podman` JXL-to-PNG loop.
- **"I'll use the legacy -C sRGB flag."** -> Newer versions of `djxl` throw `Unknown argument: -C` and abort the build. Always use `--color_space=sRGB` to preserve full sRGB pixel colors.
- **"Using Type=oneshot on bazaar.service is fine."** -> If the systemd service is `oneshot`, and the command `bazaar --no-window` runs as a persistent daemon, systemd will block forever waiting for the service to start, hanging the user's terminal. Always use `Type=simple`.

## Red Flags

- `bazaar.service` containing `Type=oneshot` or `RemainAfterExit=yes` for the background daemon.
- `Containerfile` or preview scripts referencing the deprecated `-C` flag for `djxl`.
- Local previews displaying blank/missing banners (indicates PNGs were not successfully compiled or copied to `/etc/bazaar`).
- Open PRs modifying `curated.yaml` without matching unit tests in `tests/test_curated_config.py`.

## Verification

Before declaring a Bazaar task complete, ensure:
- [ ] `just check` passes.
- [ ] `pre-commit run --all-files` passes.
- [ ] All python unit tests (`tests/test_curated_config.py`, `tests/test_hooks.py`) are green.
- [ ] Banners in the preview list have `.png` extensions (not `.jxl`).
- [ ] Converted PNG banners are non-empty and show correct color matching on standard GTK loaders.
