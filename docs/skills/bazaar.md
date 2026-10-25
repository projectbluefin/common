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
- Changing Bazaar hook behavior for app install interception
- Adding or changing banner images (JXL→PNG conversion pipeline)
- Validating Bazaar behavior locally before opening a PR

## When NOT to use

- Editing Aurora-variant Bazaar config — that lives in the Aurora repo, not here
- Upstream Bazaar app bugs — report those in the Bazaar upstream issue tracker (never ublue-os)

## Files and ownership

| File | Purpose |
|---|---|
| `system_files/bluefin/etc/bazaar/bazaar.yaml` | Bazaar runtime config, config paths, hook wiring |
| `system_files/bluefin/etc/bazaar/curated.yaml` | Curated Explore content (sections, banners, carousels) |
| `system_files/bluefin/etc/bazaar/blocklist.yaml` | Bluefin blocklist policy |
| `system_files/bluefin/etc/bazaar/hooks.py` | Host-side hook script invoked by Bazaar (Flatpak host-etc access) |
| `system_files/bluefin/usr/lib/systemd/user/bazaar.service` | Background Bazaar service entrypoint |
| `tests/test_hooks.py` | `hooks.py` state machine tests |
| `tests/test_curated_config.py` | Curated/Bazaar config shape regression checks |

## Remote Precedence and App Store Hierarchy

Bazaar prioritizes Flathub by design:
- `bz-entry.c` hardcodes a +1000 point usefulness bonus for entries originating from a remote named `flathub`.
- Secondary remotes (like `flatpark`) populate complementary applications not present on Flathub without superseding Flathub as the #1 store.
- For multi-remote setups, non-Flathub remotes use Flatpak ref filters (`Filter=/etc/flatpak/remotes.d/<name>.filter`) to exclude conflicting IDs and prevent duplicate catalogue entries.

## Hook architecture and developer experience redirection

Bazaar supports custom transaction hooks configured in `bazaar.yaml` and executed by `hooks.py`.

### 1. In-process regex prefilter (`check-appid-regex`)
Bazaar evaluates `check-appid-regex` in-process against `ts_appid` before spawning any subprocess. Hooks must define this regex to prevent invoking Python for uninvolved Flatpak installs:
- `jetbrains-toolbox`: `^(com\.jetbrains\..*|com\.google\.AndroidStudio)$`
- `vscode`: `^com\.visualstudio\.code$`
- `vscodium`: `^com\.vscodium\.codium$`
- `zed`: `^dev\.zed\.Zed.*$`

### 2. State machine stages
Hooks run through stages:
1. `setup`: Checks `BAZAAR_TS_TYPE == 'install'` and appid match (`ok` or `pass`).
2. `setup-dialog`: Returns `ok` to display the warning dialog.
3. `teardown-dialog`: Evaluates `BAZAAR_HOOK_DIALOG_RESPONSE_ID`. User choices (`download`, `run-ujust`, `run-devmode`) return `ok`; cancelling returns `abort`.
4. `catch`: Catches aborted dialogs; returns `abort` to skip action.
5. `action`: Executes the action (`spawn_ujust('devmode')`, `spawn_ujust('install-jetbrains-toolbox')`, or `spawn_brew(...)`). Terminal spawn uses `flatpak-spawn --host xdg-terminal-exec --app-id=io.github.kolunmi.Bazaar --title=Bazaar -- bash -c ...` with Homebrew shellenv and a pause on finish.
6. `teardown`: Returns `deny` to block Flatpak installation.

### 3. Developer Experience (`run-devmode`)
Every developer IDE dialog provides:
- `cancel`: Aborts without installing Flatpak.
- `run-devmode`: Launches `ujust devmode` to set up Bluefin's full Developer Experience environment.
- An app-specific download button (`download` for Homebrew cask or `run-ujust` for JetBrains Toolbox).

## Curated schema and compatibility notes

The installed release in modern Bluefin is **Bazaar 0.9.x+**, which uses the modern schema structure:
- **No root `css:` block**.
- **`rows`** is a list of typed entries directly (`banner:`, `section:`).
- Banners natively support `.jxl` images via `light-uri` and `dark-uri`.

```yaml
rows:
  - banner:
      height: 400
      image:
        light-uri: file:///run/host/etc/bazaar/06-bluefin-day.jxl
        dark-uri: file:///run/host/etc/bazaar/06-bluefin-night.jxl
        fit: cover
        can-shrink: true
  - section:
      title:
        en: "Desktop Development"
      appids:
        list:
          - dev.zed.Zed
          - com.visualstudio.code
          - com.vscodium.codium
```

### Legacy Schema (v0.8.2 and below — Historical)
Older Bazaar releases wrapped rows under `sections: [category: ...]` and required root `css:`. Modern Bazaar 0.9.x+ rejects the legacy `css:` property.

## Banner image conversion (JXL → PNG)

Banner images in `bluefin-branding/system_files/etc/bazaar/` are stored as
`.jxl`. The `build` stage of the `Containerfile` converts them to `.png` with
`djxl`, forcing an sRGB color space so GTK loaders that ignore embedded ICC
profiles do not render them washed-out or dark.

**Containerfile pattern** (`Containerfile:76-81`):
```dockerfile
COPY bluefin-branding/system_files/etc/bazaar /tmp/bazaar-banners
RUN set -e && mkdir -p /out/bluefin/etc/bazaar && \
    for f in /tmp/bazaar-banners/*.jxl; do \
      name=$(basename "$f" .jxl); \
      djxl "$f" "/out/bluefin/etc/bazaar/${name}.png" --color_space=sRGB; \
    done
```

**Critical rules:**
- The `RUN` step **must** include `set -e` (or `|| exit 1` per iteration). Without it, a `djxl` failure silently exits 0 — the build passes, the PNG is missing, and the curated page breaks at runtime.
- The flag is `--color_space=sRGB`. That is what `Containerfile:80` uses and
  what the build passes with, against the `djxl` from Alpine's `libjxl-tools`
  (`Containerfile:19`). If you change the `build` stage's base image or drop `libjxl-tools`
  for another package, run `djxl --help` in the new stage before assuming either spelling.

## bazaar.service requirements

`bazaar.service` must be `Type=simple`. The `bazaar --no-window` process runs as a persistent background daemon. Setting `Type=oneshot` causes `systemctl` to hang indefinitely waiting for the service to exit.

```ini
[Service]
Type=simple
ExecStart=/usr/bin/flatpak run --no-instance io.github.kolunmi.Bazaar --no-window
```

## Local preview

Two recipes install this checkout's Bazaar config to `/etc/bazaar` and relaunch the flatpak. Both require `sudo` and restart `bazaar.service`:
- `just bazaar-preview`: checkout-local version
- `ujust bazaar-preview <path-to-common>`: in-image version; defaults to invocation directory

Both install `bazaar.yaml`, `curated.yaml`, `blocklist.yaml`, and `hooks.py`.

### Non-root alternative

To test without writing to `/etc`:

1. **Kill background daemon first:** Bazaar runs as a persistent search-provider daemon, so config updates apply only after the running process exits:
   ```bash
   flatpak kill io.github.kolunmi.Bazaar 2>/dev/null || true
   ```
2. **Launch with workspace override:**
   ```bash
   flatpak run --filesystem=host io.github.kolunmi.Bazaar \
     --extra-curated-config=/absolute/path/to/system_files/bluefin/etc/bazaar/curated.yaml
   ```
3. **Schema mismatch errors on stdout/stderr:**
   - `property 'css' doesn't exist on type BzRootCuratedConfig`: legacy config handed to modern Bazaar 0.9.x+
   - `property 'start-on-curated' doesn't exist on type BzMainConfig`: modern options handed to older Bazaar

## Validation
`just test` covers the Bazaar suites: `tests/test_curated_config.py`
(config shape) and `tests/test_hooks.py` (hook state machine).

## Red Flags

- `curated.yaml` contains root `css:` — crashes modern Bazaar 0.9.x+.
- Hook dialog/response IDs changed without mirroring them in the tests or `bazaar.yaml` — silent behavior drift (`test_curated_config.py` enforces `run-devmode` on all dialogs).
- Hook missing `check-appid-regex` in `bazaar.yaml` — causes subprocess overhead on every Flatpak transaction.
- Hook using single-space string in `-x` instead of `-- bash -c ...` vector.
- Curated content edited without a local preview, or copied from Aurora leaving non-Bluefin branding.

## Verification

- [ ] `curated.yaml` uses modern schema with `.jxl` banners
- [ ] `bazaar.service` is `Type=simple`
- [ ] `Containerfile` JXL conversion `RUN` step begins with `set -e`
- [ ] `djxl` invocation uses `--color_space=sRGB`, matching `Containerfile:80`
- [ ] `python3 -m pytest tests/test_curated_config.py tests/test_hooks.py -v` passes
- [ ] `just check && pre-commit run --all-files` passes
