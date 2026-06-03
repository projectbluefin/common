---
name: dakota-bst-overrides
description: Use when creating, evaluating, or removing BuildStream junction element overrides in projectbluefin/dakota — ensures agents follow GNOME OS upstream-first principle and maintain recognizable patterns
---

# Managing BuildStream Junction Overrides (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-bst-overrides/SKILL.md`

## When to Use

- Creating a junction override to replace an upstream element with a Bluefin-specific local version
- Evaluating whether an existing override is still justified (quarterly hygiene audit)
- Removing an override that has become identical to or superseded by upstream
- Deciding between patching an element vs. replacing it entirely

## When NOT to Use

- Making small, targeted tweaks to upstream elements → use `dakota-patch-junctions` (patch_queue) instead
- Version-only ref bumps → handle via patch or `dakota-update-refs`
- Debugging build failures caused by an override → use `dakota-debugging`
- General BuildStream element authoring → use `dakota-buildstream`

## Overview

Dakota extends **gnome-build-meta** via junction. By default, all gnome-build-meta elements (and its freedesktop-sdk transitive dependency) are used as-is from upstream. **Overrides** replace specific upstream elements with local versions. Overrides should be **rare** and **justified** - the upstream-first principle means we align with GNOME OS patterns unless there's a compelling Bluefin-specific reason.

**Guiding principle:** A GNOME OS maintainer should recognize this as a standard GNOME-based image. Overrides break that recognition and create maintenance burden.

## Override Mechanism

Overrides are declared in the junction element using `config.overrides`:

```yaml
# elements/gnome-build-meta.bst
kind: junction
sources:
- kind: git_repo
  url: gnome:gnome-build-meta.git
  ref: <pinned-ref>
- kind: patch_queue
  path: patches/gnome-build-meta
config:
  overrides:
    oci/os-release.bst: oci/os-release.bst
    core/meta-gnome-core-apps.bst: core/meta-gnome-core-apps.bst
```

**What this does:**
- When BuildStream sees `gnome-build-meta.bst:oci/os-release.bst`, it loads `elements/oci/os-release.bst` (local) instead of the upstream version
- The local element **completely replaces** the upstream element - no merging, no inheritance
- Dependencies, sources, variables - everything comes from the local file

## When to Create an Override

Valid reasons:
- **Bluefin branding**: os-release, Plymouth theme, desktop background
- **Significant behavioral changes**: Package selection (meta-gnome-core-apps excludes unwanted GNOME apps)
- **Impossible to patch**: Completely replacing a source, a build system, or the entire element structure

Invalid reasons (use patching instead):
- **Build flag changes**: Patch the upstream element via patch_queue
- **Version bumps**: Patch the upstream element to update the ref
- **Bug fixes**: Patch upstream, then submit upstream so the patch can eventually be dropped
- **"Just easier"**: Short-term convenience creates long-term divergence

### Decision Matrix

| Goal | Mechanism | Why |
|---|---|---|
| Change os-release to say "Bluefin" | Override | Bluefin-specific branding |
| Enable a compiler flag on openssh | Patch | Behavioral tweak, stays aligned |
| Remove GNOME Maps from core apps | Override | Significant app selection change |
| Bump bootc to v1.2.0 | Patch | Version bump, aligns with upstream workflow |
| Fix bootc build failure | Patch | Bug fix, upstream can adopt |
| Replace bootc with identical copy | **NEVER** | Pointless divergence, pure maintenance burden |

## Creating an Override

### 1. Create the local element

```bash
# Copy from upstream as starting point (optional but recommended):
just bst source checkout gnome-build-meta.bst --directory /tmp/gbm-checkout
cp /tmp/gbm-checkout/elements/path/to/element.bst elements/path/to/element.bst
```

Edit the local file to make Bluefin-specific changes. Add a comment at the top documenting **why** this is an override:

```yaml
# Override: Bluefin branding - replaces GNOME OS release info with Bluefin identity
kind: manual
```

### 2. Declare the override in the junction

Edit `elements/gnome-build-meta.bst`:

```yaml
config:
  overrides:
    path/to/element.bst: path/to/element.bst
```

The syntax is `upstream-path: local-path` (usually identical).

### 3. Verify the override works

```bash
just bst show oci/bluefin.bst | grep 'path/to/element.bst'
# Should show elements/path/to/element.bst NOT gnome-build-meta.bst:path/to/element.bst
```

### 4. Update tracking (if needed)

If the element tracks upstream sources, add it to `.github/workflows/track-bst-sources.yml`.

## Removing an Override

**Checklist** (mandatory - follow every step):

### 1. Verify upstream provides equivalent functionality

```bash
just bst source checkout gnome-build-meta.bst --directory /tmp/gbm-checkout
cat /tmp/gbm-checkout/elements/path/to/element.bst
```

**Compare carefully:**
- Do we need any customizations from the local version?
- If yes → convert to a patch via `dakota-patch-junctions` skill
- If no → proceed with removal

### 2. Remove override declaration

Edit `elements/gnome-build-meta.bst`, delete the line from `config.overrides:`.

### 3. Update references to use junction path

```bash
rg --type=bst 'path/to/element.bst'
```

For each non-junction reference, update to the junction path:

```yaml
# Before:
build-depends:
- core/bootc.bst

# After:
build-depends:
- gnome-build-meta.bst:gnomeos-deps/bootc.bst
```

### 4. Remove tracking entries

Search `.github/workflows/track-bst-sources.yml` for the element name and remove it.

### 5. Update skill documentation

Search for the element filename across skill files and update references.

### 6. Delete the local element file

```bash
rm elements/path/to/element.bst
```

### 7. Verify the build

```bash
just bst show oci/bluefin.bst
just build
```

## Override Hygiene Audit

Periodically (quarterly or when bumping upstream refs), audit existing overrides:

### 1. List all current overrides

```bash
yq '.config.overrides' elements/gnome-build-meta.bst
```

### 2. For each override, check if it's still justified

```bash
just bst source checkout gnome-build-meta.bst --directory /tmp/gbm-checkout
diff -u /tmp/gbm-checkout/elements/path/to/element.bst elements/path/to/element.bst
```

**Ask:**
- Is the diff Bluefin-specific branding/customization? → Keep override
- Is the diff a version bump or bug fix? → Convert to patch, remove override
- Is the diff empty or trivial? → **Remove override immediately** (identical overrides are bugs)

## Current Overrides (2026-02-16)

| Override | Justification | Status |
|---|---|---|
| `oci/os-release.bst` | Bluefin branding (NAME, ID, PRETTY_NAME, etc.) | Justified |
| `core/meta-gnome-core-apps.bst` | Custom GNOME app selection (removes unwanted apps) | Justified |
| `bluefin/plymouth-bluefin-theme.bst` | Replaces `gnomeos-deps/plymouth-gnome-theme.bst` | Justified (branding) |

**Removed overrides:**
- `core/bootc.bst` (2026-02-16): Identical to upstream - removed
- `oci/gnomeos.bst` (2026-02-16): Defensive /usr/etc merge was redundant - removed

## Red Flags

- **Identical override**: Local element is byte-for-byte identical to upstream → remove immediately
- **Version-only override**: Only difference is a newer `ref:` → convert to patch
- **Override without comment**: No explanation of why it exists → add comment
- **Override of freedesktop-sdk element**: Almost never justified → patch instead
- **Override that could be a patch**: Diff only changes build flags or configure options → convert to patch

## Integration with Other Skills

- **Before creating override:** Read `dakota-patch-junctions` to see if a patch suffices
- **When removing package:** Check `dakota-remove-package` for dependency cleanup
- **After override changes:** Run a local build to verify
- **When updating upstream refs:** Read `dakota-update-refs` for junction ref bumps
