---
name: dakota-package-gnome-extensions
description: Use when packaging a GNOME Shell extension for BuildStream in dakota, when adding a new extension to the Bluefin image, or when debugging extension installation paths, UUID discovery, or GSettings schema compilation
---

# Packaging GNOME Shell Extensions (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-package-gnome-extensions/SKILL.md`

## When to Use

- Packaging a GNOME Shell extension for BuildStream in dakota
- Choosing the correct build pattern for an extension (Meson, Make+jq, Make+zip, manual, pure config)
- Debugging extension UUID extraction, schema compilation, or install path issues
- Adding a new extension to `gnome-shell-extensions.bst`

## When NOT to Use

- Adding non-extension packages to the image → use `dakota-add-package` instead
- General BuildStream element reference → use `dakota-buildstream` instead
- Debugging general build failures → use `dakota-debugging` instead

## Overview

GNOME Shell extensions in this project follow one of 6 build patterns depending on what build system the upstream extension uses. All extensions share common traits: `strip-binaries: ""` (extensions are JavaScript, not ELF), UUID-based install paths, and aggregation under `bluefin/gnome-shell-extensions.bst`.

## Pattern Selection

| Condition | Pattern |
|---|---|
| Extension has `meson.build` | **Pattern 1: Meson** |
| Extension has Makefile, no special schemas | **Pattern 2: Make + jq** |
| Extension has Makefile, schemas in system dir | **Pattern 3: Make + schema relocation** |
| Extension has Makefile, produces `.shell-extension.zip` | **Pattern 4: Make + zip** |
| No build system (just source files to copy) | **Pattern 5: Manual + jq** |
| No sources (pure GSettings override) | **Pattern 6: Pure config** |

## Common Elements (All Patterns)

Every extension element shares:

```yaml
variables:
  strip-binaries: ""    # REQUIRED: extensions are JavaScript, not ELF

depends:
  - freedesktop-sdk.bst:components/gettext.bst
  - gnome-build-meta.bst:sdk/glib.bst
  - gnome-build-meta.bst:core/gnome-shell.bst
```

**`strip-binaries: ""`** is mandatory. Without it, BuildStream tries to strip JavaScript files and fails.

The final install command should always be `%{install-extra}`.

## Pattern 1: Meson (Simplest)

```yaml
kind: meson

sources:
  - kind: git_repo
    url: github:<org>/<repo>.git
    track: v*
    ref: <git-describe-ref>

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst

depends:
  - freedesktop-sdk.bst:components/gettext.bst
  - gnome-build-meta.bst:sdk/glib.bst
  - gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
```

No custom `config:` needed — meson installs to the right paths. Examples: gsconnect, app-indicators.

## Pattern 2: Make + jq UUID Extraction

```yaml
kind: make

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
  - freedesktop-sdk.bst:components/jq.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - |
      %{make}
      _uuid="$(jq -r .uuid metadata.json)"
      install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
      cp -R ./* "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/"
    - |
      %{install-extra}
```

**Key:** `%{make}` runs in `install-commands`, not `build-commands`. UUID is extracted dynamically from `metadata.json`. Example: search-light.

## Pattern 3: Make + Schema Relocation

Use when `make install` puts GSettings schemas in system-wide `/usr/share/glib-2.0/schemas/` but extensions need them in their own directory.

```yaml
config:
  install-commands:
    - |
      _uuid="$(jq -r .uuid metadata.json)"
      %{make-install}
      mkdir -p "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
      mv "%{install-root}%{datadir}/glib-2.0/schemas/<schema-name>.gschema.xml" \
         "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
      glib-compile-schemas --strict \
         "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
    - |
      %{install-extra}
```

After `%{make-install}`, move the schema from system dir to extension's `schemas/` subdir, then compile. Example: dash-to-dock.

## Pattern 4: Make + Zip Extraction

Use when `make` produces a `.shell-extension.zip` file.

```yaml
config:
  install-commands:
    - |
      %{make}
      _uuid="$(jq -r .uuid metadata.json)"
      install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
      bsdtar xvf "build/${_uuid}.shell-extension.zip" \
        -C "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/" \
        --no-same-owner
      glib-compile-schemas --strict \
        "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
    - |
      %{install-extra}
```

**Key:** Use `bsdtar` (not `unzip`) — `unzip` not available in sandbox. Example: blur-my-shell.

## Pattern 5: Manual + jq (No Build System)

```yaml
kind: manual

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
  - freedesktop-sdk.bst:components/jq.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - |
      _uuid="$(jq -r .uuid metadata.json)"
      glib-compile-schemas --strict schemas/
      install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
      cp -R ./* "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/"
    - |
      %{install-extra}
```

Still needs `buildsystem-make.bst` for basic tools. Compile schemas in-source before copying. Example: logomenu.

## Pattern 6: Pure Config (No Sources)

```yaml
kind: manual

depends:
  - gnome-build-meta.bst:sdk/glib.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - mkdir -p "%{install-root}%{datadir}/glib-2.0/schemas/"
    - |
      cat <<EOF > "%{install-root}%{datadir}/glib-2.0/schemas/zz-bluefin-<name>.gschema.override"
      [org.gnome.shell]
      some-key=some-value
      EOF
    - "%{install-extra}"
```

No sources, no build-depends. Writes to system schema override directory.

## Adding to the Image

After creating the extension element, add it as a dependency of `elements/bluefin/gnome-shell-extensions.bst`:

```yaml
depends:
  - bluefin/shell-extensions/your-extension.bst
```

Do **not** add extensions to `deps.bst` — they are aggregated through `gnome-shell-extensions.bst`.

## Dependency Tracking

All git-sourced shell extensions are in the `bst source track` workflow's **auto-merge** group. New extensions using `git_repo` sources are automatically eligible — add them to the `elements:` list in `.github/workflows/track-bst-sources.yml` under the auto-merge group.

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Missing `strip-binaries: ""` | Build fails trying to strip JavaScript files | Required for ALL extensions |
| Hardcoding UUID instead of `jq` extraction | Fragile; breaks if UUID changes | Use `_uuid="$(jq -r .uuid metadata.json)"` |
| Installing schemas to system dir | Schemas not found at runtime | Schemas must be inside extension dir at `extensions/<uuid>/schemas/` |
| Using `unzip` instead of `bsdtar` | Command not available in sandbox | Use `bsdtar xvf` with `--no-same-owner` |
| Missing `glib-compile-schemas --strict` | Extension settings don't work | Compile schemas in the extension's schemas dir |
| Putting build in `build-commands` | UUID not available for install path | Put `%{make}` in `install-commands` for Make-based extensions |
| Missing `%{install-extra}` | Downstream hooks don't fire | Always add as last install command |
| Missing `jq.bst` build-dep | `jq` command not found | Add `freedesktop-sdk.bst:components/jq.bst` |
| Adding extension to `deps.bst` | Wrong aggregation hierarchy | Add to `gnome-shell-extensions.bst` instead |
| Using plain SHA ref with `track: v*` | Inconsistent with auto-track output | `track: v*` produces `v<tag>-0-g<40-char-SHA>` format — not a plain SHA. AI reviewers (e.g. Gemini) falsely flag this as invalid; it is correct and required for tag tracking. |
| Missing `install -d "${_dest}"` before `cp` | `cp: cannot create regular file: No such file or directory` at build time | Always `install -d` destination dirs before copying files into them (gradia-capture PR #483, 2026-05-22) |

## UUID Verification

When adding an extension, always verify the UUID in the `.bst` element matches the upstream `metadata.json` exactly:

```bash
# Check upstream metadata.json UUID (e.g. from GitHub)
curl -s https://raw.githubusercontent.com/<org>/<repo>/main/src/metadata.json | jq .uuid
# or
curl -s https://raw.githubusercontent.com/<org>/<repo>/main/metadata.json | jq .uuid
```

The UUID is the install directory name at runtime — a mismatch means the extension silently fails to load. Example: gradia-capture UUID is `gradia-integration@alexandervanhee.github.io` (verified 2026-05-22).
