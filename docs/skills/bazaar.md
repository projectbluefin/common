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
  Use when editing Bazaar config or hooks in common. Covers curated schema
  migration, JXL→PNG banner conversion, Bluefin-owned files, and local
  preview workflow.
metadata:
  type: reference
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

## When NOT to use

- Editing Aurora-variant Bazaar config — that lives in the Aurora repo, not here
- Upstream Bazaar app bugs — report those in the Bazaar upstream issue tracker (never ublue-os)

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

## Banner image conversion (JXL → PNG)

Banner images in `bluefin-branding/system_files/etc/bazaar/` are stored as `.jxl`. They are converted to `.png` at build time in the `Containerfile`. The conversion uses `djxl` with the `-C sRGB` flag to force sRGB color space translation (prevents washed-out or dark images on standard GTK loaders that ignore embedded ICC profiles).

**Containerfile pattern:**
```dockerfile
RUN set -e && mkdir -p /out/bluefin/etc/bazaar && \
    for f in /tmp/bazaar-banners/*.jxl; do \
      name=$(basename "$f" .jxl); \
      djxl "$f" "/out/bluefin/etc/bazaar/${name}.png" -C sRGB; \
    done
```

**Critical rules:**
- `curated.yaml` must reference `.png` paths, never `.jxl` — stable Bazaar v0.8.2 crashes on JXL due to a libdex regression on modern GNOME runtimes.
- The `RUN` step **must** include `set -e` (or `|| exit 1` per iteration). Without it, a `djxl` failure silently exits 0 — the build passes, the PNG is missing, and the curated page breaks at runtime.
- Do not change `-C sRGB` to `--color_space=sRGB` — only `-C` is supported by the version of `djxl` used in the build stage. Verify against the actual binary before changing.

## bazaar.service requirements

`bazaar.service` must be `Type=simple`. The `bazaar --no-window` process runs as a persistent background daemon. Setting `Type=oneshot` causes `systemctl` to hang indefinitely waiting for the service to exit.

```ini
[Service]
Type=simple
ExecStart=/usr/bin/flatpak run --no-instance io.github.kolunmi.Bazaar --no-window
```



Instead of installing files to `/etc/bazaar` (which requires `sudo`), you can launch the Bazaar flatpak directly against files in your local workspace using command-line arguments. This is the preferred non-root preview workflow.

1. **Kill any lingering background Bazaar processes first.** Since Bazaar runs as a search provider daemon, starting it with a new config requires killing existing background processes:
   ```bash
   # List active bazaar/bwrap processes and locate their PIDs
   ps -ef | grep -E 'bazaar|Bazaar' | grep -v grep

   # Kill the exact PIDs (never use pkill/killall)
   kill <PID1> <PID2>
   ```

2. **Launch with workspace overrides:**
   To load the custom curated config directly from your workspace without copying it to `/etc`:
   ```bash
   flatpak run --filesystem=host io.github.kolunmi.Bazaar \
     --extra-curated-config=/absolute/path/to/system_files/bluefin/etc/bazaar/curated.yaml
   ```

3. **Verify the logs:**
   If there are validation or schema errors, Bazaar will output them directly to stdout/stderr:
   - `property 'banner' doesn't exist on type BzCuratedRow` indicates that the old version of Bazaar is trying to parse the modern schema format.
   - `property 'start-on-curated' doesn't exist on type BzMainConfig` indicates that the old version of Bazaar is trying to parse modern options in `bazaar.yaml`.


## Validation

```bash
# Curated/Bazaar config shape regression
python3 -m pytest tests/test_curated_config.py -v

# Hook behavior
python3 -m pytest tests/test_hooks.py tests/test_bazaar_hook.py -v

# Repo standard validation
just check
pre-commit run --all-files
just test
```

## Common pitfalls

- Editing curated content without local preview causes UI regressions to slip through.
- Copying Aurora/Bazaar examples directly can leave non-Bluefin branding or links.
- Changing hook dialog/response IDs must be mirrored in tests to avoid silent behavior drift.
- Editing `system_files/bluefin/etc/bazaar/hooks.py` without applying the same hook handler to `system_files/bluefin/usr/libexec/bazaar-hook` leaves the in-image entry point out of sync.
- Dropping `set -e` from the JXL conversion RUN step lets silent build failures through.
- Using `--color_space=sRGB` instead of `-C sRGB` breaks the conversion with "Unknown argument" error.

## Red Flags

- `curated.yaml` contains `banner:`, `articles:`, `featured-carousel:`, or `start-on-curated:` keys — these crash stable Bazaar v0.8.2.
- Banner entries reference `.jxl` paths instead of `.png`.
- `bazaar.service` has `Type=oneshot` — will hang `systemctl` indefinitely.
- `Containerfile` JXL conversion loop is missing `set -e` — silent build failures silently produce no PNG.
- A curated section has a `subtitle` but no `title` — stops the curated page from loading.
- djxl flag changed from `-C sRGB` to `--color_space=sRGB` without verifying the installed binary supports the long form.

## Verification

- [ ] `curated.yaml` uses legacy schema only: `css`/`rows`/`sections`/`category` — no `banner`/`carousel`/`articles` keys
- [ ] All `light-banner` and `dark-banner` entries end in `.png`
- [ ] All curated `sections` have a `title` key under `category`
- [ ] `bazaar.service` is `Type=simple`
- [ ] `Containerfile` JXL conversion `RUN` step begins with `set -e`
- [ ] `djxl` invocation uses `-C sRGB`
- [ ] `python3 -m pytest tests/test_curated_config.py -v` passes
- [ ] `just check && pre-commit run --all-files` passes
