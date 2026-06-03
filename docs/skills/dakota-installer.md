---
name: dakota-installer
description: Project Bluefin Dakota installer — fork of tuna-os/tuna-installer. Dev setup, build loop, CI/release, dakota-iso integration, demo mode. Load when working on the installer or debugging the ISO installer integration.
---

# Skill: dakota-installer

## What It Is

A soft fork of `tuna-os/tuna-installer` (which itself forks `Vanilla-OS/vanilla-installer`). Produces a GTK4/Adwaita Flatpak installer specialized for Project Bluefin Dakota (GNOME OS / bootc / composefs).

- **Canonical repo:** `projectbluefin/bootc-installer` ← **transferred 2026-05-27** (was `castrojo/tuna-installer`)
- **Upstream:** `tuna-os/tuna-installer` (read-only, pull upstream fixes)
- **Local clone:** `~/src/tuna-installer` (clone path unchanged; remote updated to projectbluefin)
- **Remotes:** `origin = git@github.com:projectbluefin/bootc-installer.git`, `upstream = https://github.com/tuna-os/tuna-installer`
- **Default branch:** `dev` (active work); `prod` (stable, triggers Flatpak release CI)
- **App ID:** `org.bootcinstaller.Installer`

## Architecture

```
tuna-installer/
├── bootc_installer/         # Python GTK4/Adwaita GUI
│   ├── defaults/            # Wizard step widgets (disk, encryption, user, welcome)
│   ├── views/               # Progress, done, confirm screens
│   ├── windows/             # Main window + dialogs
│   ├── gtk/                 # Blueprint UI files (.blp)
│   └── utils/               # Builder, Processor, RecipeLoader
├── fisherman/               # Git submodule → tuna-os/fisherman (Go backend)
│   ├── fisherman/cmd/       # main.go — 9-step install pipeline
│   └── data/images.json     # Image catalog (bundled in GResource)
├── flatpak/                 # Flatpak manifests
├── recipe.json              # Dakota-specific recipe (distro_name, steps, imgref)
└── run-dev.sh               # Local dev launcher (dakota-lab toolbox)
```

**Two-component model:** Python GUI collects wizard finals → Processor builds fisherman recipe JSON → fisherman (Go) runs as root via pkexec and does the actual disk install.

**Key customizations from upstream:**
- Image picker step removed (Dakota only, imgref in recipe.json)
- `welcome_title: "Welcome to Bluefin"`, `welcome_subtitle` from recipe
- Default hostname: `dakota`
- Encryption copy: plain-language ("Encrypt this disk", "Use hardware-backed encryption")
- Passphrase strength feedback (weak/fair/strong)
- Done screen: `"{name} is installed"` + `"Restart now to complete the installation."`
- `BOOTC_DEMO=1` demo mode — full UI walkthrough, no disk touched

## Dev Setup (First Time)

```bash
# Prereq: dakota-lab toolbox running
toolbox list  # should show dakota-lab

# Init fisherman submodule
cd ~/src/tuna-installer
git submodule update --init --recursive

# Build fisherman
mkdir -p /var/tmp/gobuild
cd fisherman/fisherman && go build -o /var/tmp/fisherman-test ./cmd/fisherman/

# Install build deps in toolbox (one-time)
toolbox run --container dakota-lab sudo dnf install -y \
  meson ninja-build python3-gobject python3-devel \
  blueprint-compiler libadwaita-devel desktop-file-utils mutter

# Build + install to /tmp/bootc-installer-dev
cd ~/src/tuna-installer
toolbox run --container dakota-lab meson setup build \
  --prefix=/tmp/bootc-installer-dev -Dvariant=gnome -Dbuild-fisherman=false
toolbox run --container dakota-lab ninja -C build
toolbox run --container dakota-lab meson install -C build
```

## Dev Loop

```bash
cd ~/src/tuna-installer
./run-dev.sh          # build if changed, launch in BOOTC_DEMO mode
./run-dev.sh --rebuild  # force full rebuild
./run-dev.sh --logs   # tail debug log only
```

**`BOOTC_DEMO=1`** — clicking Install runs a 5-second fake progress sequence (9 steps). No fisherman launched, no disk touched. Set by default in `run-dev.sh`.

**Debug log:** `~/.cache/tuna-installer/installer-debug.log`  
**Run log:** `/tmp/bootc-installer-run.log`

**After editing `.py` files:** `./run-dev.sh` detects changes and rebuilds automatically.  
**After editing `.blp` files:** same — blueprint-compiler reruns via ninja.  
**After editing fisherman Go:** `cd fisherman/fisherman && go build -o /var/tmp/fisherman-test ./cmd/fisherman/`

## Background Launch (pi limitation)

`toolbox run` must be in foreground. The working pattern:

```bash
# Write a launcher script, then:
toolbox run --container dakota-lab bash /tmp/launch-installer.sh &
sleep 4
# Window appears on Wayland display
```

Do NOT use `nohup toolbox run ... &` or `setsid toolbox run ... &` — these silently fail to produce output/window. The `&` job control pattern with `kill %1` works for timed testing.

## CI / Releases

| Branch/tag | Trigger | Output |
|---|---|---|
| `dev` push | `devel` job | `org.bootcinstaller.Installer.Devel.flatpak` → `continuous-dev` release |
| `prod` push | `production` job | `org.bootcinstaller.Installer.flatpak` → `continuous` release |
| `v*` tag | both jobs | attach Flatpak to tagged release |

**Permissions fix required:** `.github/workflows/flatpak.yml` needs `permissions: contents: write` on release jobs — without it CI builds the Flatpak but fails to publish. File: `flatpak.yml` → add under each release job:
```yaml
permissions:
  contents: write
```

## Integration with dakota-iso

`dakota-iso/dakota/src/install-flatpaks.sh` fetches the installer:
```bash
RELEASE_TAG="continuous"   # stable channel
RELEASE_TAG="continuous-dev" # dev channel
curl "https://github.com/castrojo/dakota-installer/releases/download/${RELEASE_TAG}/..."
```

The ISO overrides all branding via `/etc/bootc-installer/images.json` + `recipe.json` — these override the bundled GResource versions at runtime.

## Key Files

| File | Purpose |
|---|---|
| `recipe.json` | Dakota recipe: distro_name, welcome_title, imgref, images metadata, steps |
| `bootc_installer/defaults/welcome.py` | Welcome screen — reads welcome_title/subtitle from recipe |
| `bootc_installer/defaults/disk.py` | Disk selection + hostname |
| `bootc_installer/defaults/encryption.py` | Encryption step + passphrase strength |
| `bootc_installer/defaults/user.py` | User creation (skipped for Dakota via needs_user_creation:false) |
| `bootc_installer/utils/processor.py` | Assembles fisherman recipe JSON from all finals |
| `bootc_installer/views/progress.py` | Install progress + `start_demo()` for BOOTC_DEMO mode |
| `bootc_installer/windows/main_window.py` | Wizard carousel, on_installation_confirmed() |
| `fisherman/data/images.json` | Image catalog (full multi-distro; overridden on ISO) |

## Known Issues / Deferred

1. **CI permissions:** flatpak.yml needs `permissions: contents: write` — release publishing fails without it
2. **Bundled catalog:** `fisherman/data/images.json` still has full Aurora/Bazzite/etc catalog — needs `castrojo/fisherman` fork to strip to Bluefin-only
3. **TPM2 enrollment:** `systemd-cryptenroll --unlock-key-file=-` fails with "Reading keyfile /var/roothome/- failed" — non-fatal, password fallback works
4. **Version string:** shows `2.4.0` in About dialog, should read from `VERSION` file
5. **Recovery key screen:** ✅ Implemented — fisherman emits `{"type":"recovery_key","key":"..."}` for `tpm2-luks` installs; GUI shows the key with copy button.
6. **Install video:** ✅ Implemented — VP9 WebM, deferred to `map` signal to avoid GStreamer CRITICAL (#33 fixed)
7. **Battery warning:** ✅ Implemented — `disk.py:786-815` reads `/sys/class/power_supply`, reveals `Adw.Banner` when on battery
8. **Confirm screen labels:** encryption type shown as raw key ("tpm2-luks-passphrase") not plain text
9. **Repo rename:** ✅ Done — transferred to `projectbluefin/bootc-installer` (2026-05-27)
10. **OEM menu icon:** ASUS ROG eye logo should replace ublue-logo-symbolic when on ASUS hardware (needs dconf override)
11. **TUXEDO packages:** Vendor detected but no brew casks in ublue-os/homebrew-tap yet

## fisherman Post-Install Features (1.0)

These run during installation (steps 7-9 in main.go) for "instant first boot":

| Feature | Go file | What it does |
|---|---|---|
| WiFi persistence | `post/post.go` | Copies NM `.nmconnection` files so WiFi reconnects on first boot |
| Bluetooth persistence | `post/post.go` | Copies `/var/lib/bluetooth` so paired devices reconnect |
| Audio config | `post/audio.go` | WirePlumber rules: friendly device names, hide S/PDIF/Pro Audio |
| OEM detection | `post/oem.go` | Detects ASUS/Framework, queues first-boot brew packages |
| Cache warming | `post/caches.go` | Pre-generates 8 system caches (font, icon, pixbuf, GIO, ldconfig, etc.) |
| Wallpaper slurp | `slurp/wallpaper.go` | Extracts Windows wallpapers + pre-generates GNOME thumbnails |
| Data migration | `slurp/data.go` | Migrates docs/photos/music/bookmarks/fonts from Windows |
| Install video | progress.py | AV1/VP9 video plays during install (Gtk.Video widget) |

## fisherman Submodule

- **Version pinned:** `v0.2.0-17-g7379574` (includes fix for #38: OCI cache mount on composefs/btrfs)
- **Source:** `tuna-os/fisherman`, branch `dev`
- **Key fix:** mount OCI cache at `/run/fisherman/oci-cache` instead of `/var/tmp` — fixes composefs overlay storage on btrfs targets
- **Build:** `cd fisherman/fisherman && go build -o /var/tmp/fisherman-test ./cmd/fisherman/`

## Lessons Learned (2026-05-27 session)

- `toolbox run` in background (`&`) works with `kill %1` for timed tests; `nohup`/`setsid` patterns silently fail to connect Wayland
- Blueprint files (`.blp`) compile via `ninja -C build` — no separate step needed
- GResource icon paths (`resource:///org/bootcinstaller/Installer/images/dakota.png`) must match the compiled bundle; the ISO's `images.json` can reference them because the Flatpak bundle is installed
- `skip_screen` on user step needed a three-way fallback: image_step → sys_recipe["images"] → /etc/bootc-installer/images.json
- Processor fallback for removed image step: check `sys_recipe["images"]` before `/etc/` path
- Issues disabled by default on GitHub forks — enable via `gh api --method PATCH /repos/owner/repo -f has_issues=true`
- For BOOTC_DEMO: intercept at `on_installation_confirmed()` in main_window.py and call `progress.start_demo()` — no fisherman changes needed

## Lessons Learned (2026-05-28 session)

- Flatpak builder sandbox enforces `safe.bareRepository=explicit` — git module sources fail silently. Always use `"type": "archive"` with SHA256 instead of `"type": "git"` in manifests.
- Windows data slurp must happen BEFORE partitioning (source disk IS target disk). RAM scratch at `/run/fisherman-slurp/` (Statfs("/run") - 2GB reserve).
- `fisherman scan <disk>` CLI outputs JSON for GUI enumeration — the GUI step should shell out to this and parse the ScanResult.
- Offline install detection: check `local_imgref` in recipe OR live ISO indicators (`/run/initramfs/live`, `/run/ostree-booted`). Processor passes `additionalImageStores` to fisherman recipe for ISO-baked OCI stores.
- NTFS mounting: try kernel `ntfs3` (in-kernel since 5.15, faster) then fallback to `ntfs-3g` FUSE.
- Freedesktop thumbnail spec: filename = `MD5("file:///path").png` in `~/.cache/thumbnails/large/` (256×256). Thumbnailer chain: gdk-pixbuf-thumbnailer > ffmpeg > ImageMagick convert.
- fisherman submodule must be committed/pushed separately before parent repo pointer update — CI checks out recursively.

## Lessons Learned (2026-05-29 session)

- OEM hardware detection: read `/sys/devices/virtual/dmi/id/sys_vendor`, normalize casing, map to brew packages. Service uses `ConditionPathExists=!%h/.config/dakota/oem-setup-done` for one-shot.
- WiFi persistence: NetworkManager stores passwords in `/etc/NetworkManager/system-connections/*.nmconnection` (mode 0600). Copy pattern follows the Bluetooth pairing approach.
- Audio config for WirePlumber: write `monitor.alsa.rules` JSON files to `/etc/wireplumber/wireplumber.conf.d/`. Both `live` (applied immediately) and `persist` (target filesystem) modes needed.
- Cache warming runs 8 commands: fc-cache, gtk-update-icon-cache, gdk-pixbuf-query-loaders, gio-querymodules, ldconfig, locale-gen, man-db, and flatpak repair. All non-fatal on failure.
- ASUS ROG hardware: homebrew-tap provides `asusctl-linux` + `rog-control-center-linux` casks. `asusd.service` needs explicit enable. Framework has `framework-tool`.
- Install video plays via Gtk.Video widget in progress.py — replaces the old log-tail UX. Uses AV1 (libsvtav1) for compression, VP9 fallback.
- Python unit tests (`tests/unit/`) run without GTK/display. UI tests need Xvfb. pytest must be installed via `--break-system-packages` on Fedora Atomic.
- Open GitHub issues: #25 (QR companion epic), #24 (video install), #23 (printer auto-detection), #22 (Windows data slurp GUI), #20, #18, #2.

## Lessons Learned (2026-05-27 triage session)

- `gh issue close` via GraphQL can fail with HTTP 401 even when `gh auth status` shows logged in. Use REST API instead: `gh api repos/owner/repo/issues/N --method PATCH -f state=closed`
- pytest is installed at `~/.local/bin/pytest` on this machine — `python3 -m pytest` fails because it's not in the system PATH. Use the full path.
- `TunaPageHeader page_header` declared in a `.blp` file is automatically accessible as `Gtk.Template.Child()` in Python — no need to redeclare it in the blp. If it has a name in the template, it's a child.
- Locale-specific easter eggs pattern: detect language code in `update(finals)` loop (e.g. `selected_language.startswith("pt_BR")`), then set `page_header.subtitle` accordingly. Use `random.choice()` for variety.
- Slurp scan race condition pattern: always check staleness (`if disk != self.__scan_disk: return False`) BEFORE clearing the inflight flag, not after. Code review caught this.
- Issues #18 (encryption ON by default), #22 (slurp GUI), #26 (Senna), #30 (dinosaur), #31 (soundtrack) are now implemented and closed on castrojo/tuna-installer.
- Issues #tpm2-fix (TPM2 enrolment for `tpm2-luks`) and recovery key screen now fixed — fisherman emits `recovery_key` event, GUI shows key with copy button + ack checkbox.
- Issues remaining open (deferred): #2 (repo rename), #20 (TPM2 validation), #23 (printer), #25 (QR epic), #27 (phone auth), #28 (pre-stage), #29 (libpastry).

## Lessons Learned (2026-05-27 feature-completion session)

- **Repo transfer:** `gh api repos/<owner>/<repo>/transfer -f new_owner=<org>` is the correct way to transfer via gh CLI (no `gh repo transfer` subcommand exists). Rename first with `gh repo rename <newname> --repo owner/repo --yes`, then transfer.
- **Repository state:** `castrojo/tuna-installer` → renamed to `castrojo/bootc-installer` → transferred to `projectbluefin/bootc-installer`. GitHub redirect active. Local remote updated.
- **GStreamer init race pattern:** `Gtk.Video` + `GstMediaFile` backend triggers `GStreamer-Player-CRITICAL` if you call `set_muted()` or `play()` before `GstPlayer` is constructed. Fix: defer `__configure_install_video()` to the `map` signal of the widget (fires when page is first shown). Then use `notify::prepared` on the MediaStream, and guard all media ops with `media_stream.is_prepared()`.
- **Credits discoverability:** Any feature accessible only from page 1 of a wizard is effectively invisible. Add important dialogs (credits, about, help) to the main window header bar so they persist throughout the flow.
- **Feature audit pattern:** When the user says "nothing works," the real issue is often a runtime/packaging/wiring problem rather than missing code. Audit in layers: (1) does the code exist? (2) is it wired up? (3) does it fail at runtime? (4) is it discoverable?
- **Gap analysis lifecycle coverage:** A complete gap analysis must cover ALL six layers: code → unit tests → UI tests → Flatpak build → hardware lab install → post-reboot verification. Missing layer 5-6 means "works in demo, broken on hardware" ships undetected.
- **Rubber-duck critique value:** The rubber-duck agent caught 6 critical gaps that weren't in the initial plan: hardware lab procedure, CI migration audit, failure path tests, encryption matrix, offline ISO parity, post-reboot verification. Always run rubber-duck on gap analyses before filing issues.
- **Soundtrack QR pattern:** When depending on a Python library (`segno`) for runtime asset generation, add a dev-path filesystem fallback AND pre-generate the assets at build time for production. Never let a missing optional library silently degrade a primary feature.
- **Issue filing for parallel automation:** Each issue filed for parallel automated sessions should include: (1) exact files to touch, (2) acceptance criteria, (3) code examples, (4) explicit "no file conflicts with sessions A/B/C." This allows multiple agents to work simultaneously without merge conflicts.
- **testsuite repo:** `castrojo/bluefin-test-suite` was also transferred → `projectbluefin/testsuite` in this session.

## Lessons Learned (2026-06-01 session)

- **gi stub cross-contamination:** When multiple unit test files each call `_build_gi_stubs()` at module level (overwriting `sys.modules["gi.repository.Gio"]` etc.), pytest's alphabetical collection order determines the "winning" stub. The last-alphabetically-loaded file's stub is what all later tests see. Files after `test_branding_parity.py` and `test_done.py` clobber their stubs with minimal `types.ModuleType` objects lacking needed attrs (`ResourceLookupFlags`, `bus_get_sync`, `BusType`, `DBusCallFlags`, `GLib.Variant`, `Adw.Window`).
- **Stale module reference pattern:** Importing `from some_module import func` at module level creates a binding to the *first-ever* module object. If another test file later deletes `some_module` from `sys.modules` and re-imports it (creating a NEW module object), `patch("some_module.Gio.bus_get_sync")` targets the NEW object while `func` still uses the OLD one — the patch has no effect. Fix: use a `_fresh_module()` helper that re-imports and re-patches before every test method.
- **Minimal fix strategy for stub contamination:** Rather than restructuring all test files (the proper long-term fix is a `tests/unit/conftest.py` with canonical stubs), augment the affected `_import_xxx()` functions to patch missing attrs onto existing live stub objects *before* re-importing. This is surgical and doesn't require touching all 17 test files.
- **Merge queue unblock procedure:** When all open PRs fail the same CI check, the fix must land on `dev` first. Create a PR from a feature branch → `dev`, enable auto-merge (`gh pr merge N --auto --squash`), and the merge queue handles the rest. All queued PRs can then rebase and pass once the fix is in.
