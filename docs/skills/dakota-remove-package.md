---
name: dakota-remove-package
description: Use when removing a software package from the Bluefin image in dakota, deleting a .bst element, or unwiring a package from the build
---

# Removing a Package (dakota)

## Powerlevel

- **Level:** 1


## Overview

Systematic checklist for safely removing a package from the Bluefin image. The reverse of `dakota-add-package`.

Load with: `cat ~/src/skills/dakota-remove-package/SKILL.md`

## Agent Quick-Start

```bash
# Run this first — it prints a preflight checklist with live grep output
just remove-package <name>
```

Read every section of the output before touching any files. The command tells you exactly what to delete and edit. After following the printed steps, run `just validate oci/bluefin.bst && just build` to verify.

The manual checklist below is the same content the command prints, kept here as reference.

## When to Use

- Removing a `bluefin/` or `core/` element from the build
- Replacing a package with an alternative (remove old, then add new)
- Cleaning up abandoned packages

## When NOT to Use

- Adding a new package to the image → use `dakota-add-package` instead
- Updating a package to a newer version → use `dakota-update-refs` instead
- Debugging build failures left behind after a removal → use `dakota-debugging`

## The Removal Checklist

Work through every step. Some steps will be no-ops — the verification command tells you.

### 1. Identify all element files

```bash
# Find the element and any arch-specific variants
ls elements/bluefin/<name>*.bst elements/core/<name>*.bst 2>/dev/null
```

Multi-arch packages have a stack (e.g., `tailscale.bst`) plus per-arch elements (`tailscale-x86_64.bst`, `tailscale-aarch64.bst`). Remove all of them.

### 2. Check reverse dependencies

```bash
grep -r "<name>.bst" elements/
```

If other elements depend on this package, you must update or remove them too. **Do not proceed until all reverse dependencies are resolved.**

### 3. Remove from deps stack

Edit `elements/bluefin/deps.bst` — remove the `bluefin/<name>.bst` line from `depends:`.

For `core/` override elements, this step is different — see Special Cases below.

### 4. Delete element files

```bash
rm elements/bluefin/<name>.bst        # main element
rm elements/bluefin/<name>-*.bst      # arch variants (if any)
```

### 5. Check source aliases

```bash
grep -rl "<alias_name>" elements/bluefin/ elements/core/ include/
```

Look at the element's `url:` fields to find which aliases it used. If an alias in `include/aliases.yml` is used **only** by the removed element, remove that alias.

### 6. Check tracking workflow

```bash
grep "<name>" .github/workflows/track-bst-sources.yml
```

Remove the element path from `auto-merge` or `manual-merge` groups. Also check the `track-tarballs` job for tarball-sourced elements (brew-tarball, wallpapers, 1password-cli, 1password desktop).

### 7. Check Renovate config

```bash
grep -i "<name>" .github/renovate.json5
```

Remove any `customManagers` entries or `packageRules` that reference the element or its upstream dependency.

### 8. Clean up static files

```bash
grep -r "<name>" files/
ls files/<name>/ 2>/dev/null
```

Remove directories/files in `files/` that were only used by this element (e.g., `files/plymouth/` for the plymouth theme).

### 9. Clean up patches

```bash
ls patches/freedesktop-sdk/*<name>* patches/gnome-build-meta/*<name>* 2>/dev/null
```

Remove patches that only existed for this element. Check patch filenames and content.

### 10. Validate the build

```bash
just bst show oci/bluefin.bst    # dependency graph resolves
just build                        # full image builds
```

## Special Cases

### Core override elements (`elements/core/`)

Core elements are referenced from `elements/gnome-build-meta.bst` via `config.overrides`, not from `deps.bst`. To remove:

1. Delete the element file from `elements/core/`
2. Remove the corresponding `overrides:` entry in `elements/gnome-build-meta.bst`
3. The upstream gnome-build-meta element will be used instead

### Multi-arch packages

A multi-arch package typically has 3 files: a stack element plus per-arch elements. The stack is listed in `deps.bst`; the arch elements are dependencies of the stack. Remove all files.

### GNOME Shell extensions

Extensions live in `elements/bluefin/shell-extensions/`. Also remove from the `elements/bluefin/gnome-shell-extensions.bst` stack (not `deps.bst`).

## Common Mistakes

| Mistake | Consequence |
|---|---|
| Skip reverse dependency check | Other elements fail to build |
| Leave element in tracking workflow | Cron job fails daily |
| Remove alias still used by other elements | Other elements lose their source URL |
| Forget junction override entry | gnome-build-meta override points to missing file |
| Only delete main element, miss arch variants | Orphaned arch elements in tree |

## Cross-References

- `dakota-add-package` — reverse workflow
- `dakota-patch-junctions` — for junction patch cleanup
- `dakota-buildstream` — element kinds and structure
