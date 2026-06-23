---
name: bootc
description: >-
  bootc is the foundational tool for this entire project. Every OCI image built
  here is a bootc image. Use this skill when working on Containerfiles, image
  build workflows, update mechanics, image switching, or anything touching how
  the OS image is structured or delivered.
metadata:
  type: reference
  context7-sources:
    - /bootc-dev/bootc
---

# bootc

## MANDATORY: Read the docs first

This project is built on bootc. Before writing any Containerfile instruction,
workflow step, or configuration that affects how images are built, delivered,
or updated — look up the current bootc docs via Context7:

```
resolve-library-id: bootc
→ get-library-docs: /bootc-dev/bootc
→ implement from docs
→ cite the section
```

Do not rely on training data for bootc behavior, flags, labels, or config
options. The bootc project evolves; training data is a snapshot. The docs are
the source of truth.

---

## What bootc is

bootc is an OCI-native transactional OS update system. An image built here is
a standard OCI container image with a Linux root filesystem. bootc on the
installed system pulls that image and applies it as the next boot entry.

The Containerfile in `projectbluefin/common` produces the shared base layer.
Downstream repos (`bluefin`, `bluefin-lts`, `dakota`) extend it. The result is
a bootc-compatible OCI image published to `ghcr.io/projectbluefin/`.

---

## Factory-relevant bootc patterns (read from source, not memory)

### Image labels

bootc images require specific OCI labels. The authoritative source for required
labels is the bootc docs (resolve via Context7). Do not guess label names.

To verify what labels the factory currently sets:

```bash
grep -r "LABEL\|org.opencontainers" common/Containerfile bluefin/Containerfile
```

### How the factory builds bootc images

The reusable build workflow is the source of truth:

```bash
gh api repos/projectbluefin/actions/contents/.github/workflows/reusable-build.yml \
  --jq '.content' | base64 -d
```

Do not describe the build process from memory. Read that file.

### Image structure rules

bootc images have constraints on what goes where in the filesystem. Before
adding files to `system_files/`, check the bootc docs for filesystem layout
requirements. The wrong path can break the update applier silently.

The three directories that matter most:
- `/usr/` — read-only on the running system; bootc-managed
- `/etc/` — mutable, overlaid; changes here survive updates
- `/var/` — persistent user data; never reset by bootc

Source: bootc docs → "Filesystem layout" (resolve via Context7).

### Update and switch mechanics

If a task involves `bootc update`, `bootc switch`, or how users move between
image streams, read the bootc docs for the current flag set and behavior.
These change between releases. Training data will be wrong.

---

## What NOT to do

- Do not copy bootc CLI flags from memory or another doc — verify via Context7
- Do not describe bootc behavior without citing the docs section
- Do not add Containerfile instructions that conflict with bootc's filesystem
  layout without first checking the layout docs
- Do not write image labels from memory — look them up

---

## Where to find authoritative bootc information

1. **Context7** — `resolve-library-id: bootc` → `get-library-docs: /bootc-dev/bootc`
2. **Source code** — `gh api repos/bootc-dev/bootc/contents/docs` for the upstream doc tree
3. **Existing Containerfiles** — read what the factory actually does before changing it

The bootc project docs are comprehensive, well-maintained, and open source.
There is no reason to guess.
