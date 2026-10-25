---
name: bazaar
version: "1.1"
last_updated: "2026-10-24"
id: bazaar
one_line_purpose: Edit Bazaar config, blocklists, curated content, banner conversion, hooks, and previews.
entry_point: docs/skills/bazaar.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [bazaar, curated, flatpak, apps]
description: >-
  Documents Bazaar config, curated content, app blocklists, banner conversion, systemd service definitions,
  and hooks. Use when editing Bazaar settings in common. Covers modern rows schema, native JXL banners,
  and local ujust preview workflows.
metadata:
  type: procedure
  context7-sources:
    - /flatpak/flatpak-docs
---

# Bazaar — config, blocklists, and hook operations

## When to use

- Editing Bazaar config in `system_files/bluefin/etc/bazaar/`
- Porting curated-page structure across Bazaar schema versions
- Changing Bazaar hook behavior for app install interception (JetBrains, VS Code/Codium, Zed, Cursor, Antigravity)
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
| `system_files/bluefin/usr/lib/systemd/user/bazaar.service` | Background Bazaar service entrypoint |
| `tests/test_hooks.py` | `hooks.py` state machine tests |
| `tests/test_curated_config.py` | Curated/Bazaar config shape and app policy regression checks |
| `system_files/shared/usr/share/flatpak/remotes.d/flatpark.flatpakrepo` | FlatPark system remote descriptor |
| `system_files/shared/usr/share/flatpak/flatpark.filter` | FlatPark ref filter excluding Flathub duplicate IDs |
| `tests/test_flatpark_remote.py` | Remote descriptor and deduplication filter integrity test |
| `system_files/shared/usr/lib/systemd/system/flatpark-filter-copy.{path,service}` | Once `/var/lib/flatpak/repo/config` exists, copies `flatpark.filter` into `/var/lib/flatpak/repo/` so sandboxed Bazaar can read it (libflatpak fallback path) |

## Remote Precedence and App Store Hierarchy

Bazaar prioritizes Flathub by design:
- `bz-entry.c` awards a +1000 point usefulness bonus to entries originating from a remote named `flathub`.
- Secondary remotes (such as `flatpark`) provide complementary applications not present on Flathub without superseding Flathub as the #1 store.
- Non-Flathub remotes use Flatpak ref filters (`Filter=/usr/share/flatpak/flatpark.filter`) to disallow exact application IDs that overlap with Flathub (`com.calibre_ebook.calibre`, `com.google.Chrome`, `com.jianguoyun.Nutstore`, `com.longbridgeapp.LongbridgePro`, `com.tencent.wemeet`, `com.tradingview.tradingview`, `io.enpass.Enpass`, `me.hyliu.fluentreader`, `org.openshot.OpenShot`, `social.whalebird.WhalebirdDesktop`).
- Note: Ref filters match exact IDs (`deny app/<id>/*`). Repackaged upstream vendor apps under non-standard IDs (such as `com.tencent.weixin` vs Flathub's `com.tencent.WeChat`) are not excluded by exact-ID filtering and require explicit filter lines or Bazaar blocklist entries if duplication is undesired.
- Curated sections in `curated.yaml` may reference apps provided by secondary remotes (such as FlatPark); each application ID must exist in the target remote and must not be denied by its ref filter.

`bazaar.yaml` invokes `hooks.py` via `/run/host/etc/bazaar/hooks.py`.
When adding an editor interception, update both the YAML dialog and `IDE_HOOKS`
and extend `IDE_CASES` in `tests/test_hooks.py` to cover the wiring and actions.
Use the cask and tap from the shared Homebrew manifests: Cursor uses
`ublue-os/experimental-tap/cursor-linux` from `experimental-ide.Brewfile`;
Antigravity uses `ublue-os/tap/antigravity-linux` from `ide.Brewfile`.
Pass Cursor's experimental tap to the handler so it taps and trusts the same
source that supplies the cask. Keep Cancel as the default and intercept only
installs; updates and removals must pass through.

### Developer Experience redirection (`run-devmode`)

Intercepted IDE transaction dialogs (`jetbrains-toolbox`, `vscode`, `vscodium`, `zed`) present a `run-devmode` option. Choosing this executes `spawn_chairlift_dx_mode()`, launching ChairLift directly to its Developer Mode toggle screen via `flatpak-spawn --host /home/linuxbrew/.linuxbrew/bin/chairlift-wrapper --dx-mode`. Note that launching `--dx-mode` requires a ChairLift release containing the `--dx-mode` launch intent.

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
- Adding a YAML hook without a matching `IDE_HOOKS` entry silently passes through instead of redirecting the install.
- Bazaar denylist entries go in `blocklist.yaml` under `blocklists[].block`,
  using the exact Flatpak app ID; remove matching curated entries too.

## Red Flags

- Local previews displaying blank/missing banners (indicates JXLs were not copied to `/etc/bazaar`).
- Open PRs modifying `curated.yaml` without matching unit tests in `tests/test_curated_config.py`.

## Verification

Before declaring a Bazaar task complete, ensure:
- [ ] `just check` passes.
- [ ] `pre-commit run --all-files` passes.
- [ ] All python unit tests (`tests/test_curated_config.py`, `tests/test_hooks.py`) are green.
- [ ] Banners in the preview list have `.jxl` extensions.
