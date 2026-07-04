---
name: bazaar
version: "2.1"
last_updated: 2026-07-02
tags: [bazaar, curated, flatpak, apps]
description: "Use when editing Bazaar config or hooks in common. Covers new curated schema (post-0.8.3), JXL→PNG banner conversion, Bluefin-owned files, and sandboxed hot-reloading local preview workflow."
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

## Curated schema — current format (post-0.8.3 / PR #1655)

Bazaar upstream merged **PR #1655 "Rework Curated System"** on 2026-06-23. This is a **breaking schema change**. Bluefin `curated.yaml` has been migrated to the new format.

**Current schema uses typed row entries:**
```yaml
rows:
  - banner:
      height: 400
      image:
        light-uri: file:///run/host/etc/bazaar/11-bluefin-day.png
        dark-uri: file:///run/host/etc/bazaar/11-bluefin-night.png
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
          - org.gnome.Calculator
```

**Key schema rules:**
- Root `css:` block does NOT exist in the new schema — remove it entirely.
- `rows` is a list of typed entries: `banner`, `section`, `articles`, `featured-carousel`.
- Each entry has exactly one key (`banner:`, `section:`, etc.).
- `section.subtitle` is a markdown object: `subtitle: string: "..."` (not a plain string).
- `section.appids` is `appids: list: [...]` (not a bare list).
- `banner` and `section` are separate rows — one banner per section, both as siblings in `rows`.
- `section.overflow-count` enables a "Show More" button for sections with many apps.

## Non-Flathub Icon Resolution (Homebrew & System .desktop Files)

Non-Flathub applications included in curation pages (such as Homebrew apps or developer CLI tools like OpenLens or Tavern) must have high-fidelity app tiles just like Flathub flatpaks.

Because Flathub appstream paths are not predictable on the CDN, we query the official Flathub v2 API first:
`https://flathub.org/api/v2/appstream/{appid}`

For non-Flathub applications:
1. The nightly assembly action check-runs local/Homebrew paths for `.desktop` launcher files.
2. It parses the launcher to find the specified `Icon=name`.
3. It locates the referenced icon file (PNG or SVG) in standard Linux icon themes and Homebrew paths (`/home/linuxbrew/.linuxbrew/share/icons/`, `/usr/share/icons/`, etc.).
4. It encodes the located asset as an inline, self-contained base64 Data URI directly into the final compiled markdown article:
   `data:image/svg+xml;base64,...` or `data:image/png;base64,...`

This prevents downstream broken image links and eliminates filesystem sandboxing issues.

## Banner image conversion (JXL → PNG)

Banner images in `bluefin-branding/system_files/etc/bazaar/` are stored as `.jxl`. They are converted to `.png` at build time in the `Containerfile` using `djxl` with `--color_space=sRGB`.

**Containerfile pattern:**
```dockerfile
RUN set -e && mkdir -p /out/bluefin/etc/bazaar && \
    for f in /tmp/bazaar-banners/*.jxl; do \
      name=$(basename "$f" .jxl); \
      djxl "$f" "/out/bluefin/etc/bazaar/${name}.png" --color_space=sRGB; \
    done
```

**Critical rules:**
- `curated.yaml` must reference `.png` paths, never `.jxl` — Bazaar crashes on JXL due to a libdex fiber scheduling regression on modern GNOME runtimes (issue #497).
- The correct djxl flag is `--color_space=sRGB` (long form). The short form `-C sRGB` is not supported by some build-stage alpine djxl binaries.
- The `RUN` step **must** include `set -e`. Without it, a `djxl` failure silently exits 0 — the build passes, the PNG is missing, and the curated page breaks at runtime.

## bazaar.service requirements

`bazaar.service` must be `Type=simple` with `Restart=on-failure`. The `bazaar --no-window` process runs as a persistent background daemon.

```ini
[Service]
Type=simple
ExecStart=flatpak run --command=bazaar io.github.kolunmi.Bazaar --no-window
StandardOutput=journal
Restart=on-failure
RestartSec=5
```

`Type=oneshot` causes `systemctl` to hang indefinitely waiting for the service to exit.

## Local preview workflow

### Userspace prototype (no root needed)

**Never write to `/etc` for prototype work.** Use `--extra-content-config` directly — Bazaar hot-reloads on every save.

1. **Install v0.9.0+ from CI** if not yet on Flathub stable:
   ```bash
   # Find latest successful CI build artifact ID
   RUN_ID=$(gh api 'repos/kolunmi/bazaar/actions/runs?per_page=1&branch=main&status=success' \
     --jq '.workflow_runs[0].id')
   ARTIFACT_ID=$(gh api "repos/kolunmi/bazaar/actions/runs/${RUN_ID}/artifacts" \
     --jq '.artifacts[] | select(.name | test("x86_64")) | .id')
   curl -sL -H "Authorization: token $(gh auth token)" \
     "https://api.github.com/repos/kolunmi/bazaar/actions/artifacts/${ARTIFACT_ID}/zip" \
     -o /tmp/bazaar-head.zip
   unzip -o /tmp/bazaar-head.zip -d /tmp/bazaar-head/
   flatpak install --bundle --user --assumeyes /tmp/bazaar-head/Bazaar.flatpak
   ```

2. **Kill any running Bazaar processes** (exact PIDs only, never pkill):
   ```bash
   ps -ef | grep -E 'bazaar|Bazaar' | grep -v grep
   kill <PID1> <PID2>
   ```

3. **Block Built-in Fallbacks & Launch isolated Bazaar** — hot-reload is automatic on file save:
   ```bash
   # Block the development-mode example.yaml fallback copy by creating it as a directory:
   rm -rf ~/.var/app/io.github.kolunmi.Bazaar/data/example.yaml || true
   mkdir -p ~/.var/app/io.github.kolunmi.Bazaar/data/example.yaml || true

   setsid flatpak run --nofilesystem=host --filesystem=home io.github.kolunmi.Bazaar \
     --extra-content-config=/var/home/jorge/src/common/system_files/bluefin/etc/bazaar/curated-dev.yaml \
     > /tmp/bazaar-proto.log 2>&1 &
   disown
   ```
   v0.9.0 development builds of Bazaar copy and load the built-in development `example.yaml` page when no host `/etc` configs are accessible, resulting in layout duplication (example rows + your custom rows). Hiding the host filesystem with `--nofilesystem=host` and blocking `example.yaml` with a directory forces Bazaar to only load your custom `--extra-content-config` file.

4. **Article markdown files** for `uri: file:///` paths in articles rows:
   ```bash
   mkdir -p /tmp/bazaar-proto
   cat > /tmp/bazaar-proto/article.md << 'EOF'
   # Article Title
   Body in **markdown**. Links and *formatting* work.
   EOF
   ```

### Menu Launcher and Shortcut Integration

The `just bazaar-preview` command automatically overrides the personal GNOME Shell application launcher at `~/.local/share/applications/io.github.kolunmi.Bazaar.desktop`. It configures the launcher to use our isolated sandbox arguments (`--nofilesystem=host --filesystem=home`) and points it to the checkout's hot-reloaded `curated-dev.yaml`.

This means **clicking on the Bazaar icon in the desktop, dock, or GNOME application menu instantly loads your repository configurations and updates on save!**

To run it:
```bash
just bazaar-preview
```

### System install (requires root)

Use the `ujust bazaar-preview` recipe which automates JXL→PNG conversion and writes to `/etc/bazaar`:

```bash
ujust bazaar-preview
```

## Article Markdown authoring — avoid raw HTML card layouts

Bazaar's article view uses a Markdown renderer that does **not** reliably render
raw HTML `<div>`/flexbox card-wall layouts. `article-devtools.md` shipped with a
large inline-styled HTML grid (flex containers, `<div style="...">` cards,
button-styled `<a>` tags) that rendered broken/blank in Bazaar even though the
YAML wiring was valid.

**Use plain Markdown instead — proven patterns from working articles:**
- Tables for app/tool listings: `| Tool | Description | Install |`
- `**[Install](appstream://<appid>)**` for a Flatpak deep-link in a table cell
  (see `article-ai.md` history, `article-games.md` history)
- A single bare `<img src="..." alt="..." width="100%">` is fine (e.g.
  `article-bluefin-notes.md` screenshot) — the regression is specifically
  `<div>`-based layout containers and inline `style="..."` attributes, not any
  HTML tag at all.
- External links (`https://formulae.brew.sh/...`) for Homebrew-only CLI tools
  that have no Flatpak/appstream ID.

`tests/test_curated_config.py::test_article_markdown_avoids_raw_html_card_layouts`
guards against this regression by scanning every `article-*.md` for `<div` and
`style="` fragments.

### Real "Click to Install" links only work for hooked appids

An `appstream://<appid>` link only produces a genuine click-to-install action
if a hook in `hooks.py`/`bazaar-hook` intercepts that exact appid. Bazaar only
fires a hook when the user attempts a real Flatpak transaction — so the appid
must correspond to an actual (even if unofficial/abandoned) app listing on
Flathub, otherwise there's no Install button to click at all.

Hooked appids today (redirect to `brew install` instead of the Flatpak):
`com.jetbrains.*` / `com.google.AndroidStudio` (jetbrains-toolbox hook),
`com.visualstudio.code` (code hook), `com.vscodium.codium` (code hook),
`dev.zed.Zed` (zed hook), `io.neovim.nvim` (neovim hook),
`com.helix_editor.Helix` (helix hook), `org.vim.Vim` (vim hook),
`io.github.zyedidia.micro` (micro hook).

Pure CLI/daemon tools with no Flatpak identity at all (Docker, Lima, incus)
and tools with no Flathub listing (Antigravity) can **never** get a real
click-to-install link — don't label their table rows "Install" with a fake
`appstream://` link; use the actual `ujust`/`brew` command as plain text
instead. Verify an appid is real before wiring a new hook:

```bash
curl -s "https://flathub.org/api/v2/search" -X POST \
  -H "Content-Type: application/json" -d '{"query":"<tool name>"}'
```

Adding a new hook requires three matching edits: `hooks.py` (source of
truth), `usr/libexec/bazaar-hook` (in-image copy — keep byte-identical except
the shebang line), and a new `hooks:` entry + confirmation dialog in
`bazaar.yaml`. Add matching state-machine tests to both `tests/test_hooks.py`
and `tests/test_bazaar_hook.py`.

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
- Wiring a fake `appstream://<appid>` "Click to Install" link for an appid with no real Flathub listing — the button never appears in Bazaar because there's no transaction to intercept.
- Adding a hook in `hooks.py` but forgetting to mirror it in `usr/libexec/bazaar-hook` and `bazaar.yaml` — the in-image copy is what actually runs on real Bluefin installs.
- Dropping `set -e` from the JXL conversion RUN step lets silent build failures through.
- Writing article Markdown as raw HTML `<div>` card grids — Bazaar's renderer does not reliably display these; use Markdown tables instead (see "Article Markdown authoring" above).

## Red Flags

- `curated.yaml` contains root `css:` key — this is the old schema; migrate to `rows` with `banner`/`section` types.
- `curated.yaml` uses `rows[].sections[].category` structure — old schema; migrate to new typed rows.
- Banner entries reference `.jxl` paths instead of `.png`.
- `bazaar.service` has `Type=oneshot` — will hang `systemctl` indefinitely.
- `Containerfile` JXL conversion loop is missing `set -e` — silent build failures produce no PNG.
- `djxl` invocation uses `-C sRGB` — some build-stage alpine binaries do not support the short flag; use `--color_space=sRGB`.
- `section.subtitle` is a bare string — must be `subtitle: string: "..."`.
- `section.appids` is a bare list — must be `appids: list: [...]`.

## Verification

- [ ] `curated.yaml` uses new schema: `rows[]` with `banner`/`section` row types, no root `css`
- [ ] All banner `uri`/`light-uri`/`dark-uri` entries end in `.png`
- [ ] All `section` entries have `title` and `appids.list`
- [ ] `bazaar.service` is `Type=simple` with `Restart=on-failure`
- [ ] `Containerfile` JXL conversion `RUN` step begins with `set -e`
- [ ] `djxl` invocation uses `--color_space=sRGB` (not `-C sRGB`)
- [ ] Non-Flathub app icons resolve statically during the assembly script step using local/Homebrew .desktop icon retrieval and base64 SVG/PNG encoding.
- [ ] `python3 -m pytest tests/test_curated_config.py -v` passes
- [ ] `just check && pre-commit run --all-files` passes
