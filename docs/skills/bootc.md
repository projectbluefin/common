---
name: bootc
version: "1.1"
last_updated: "2026-09-13"
id: bootc
one_line_purpose: Work with bootc image build, update, and Containerfile mechanics.
entry_point: docs/skills/bootc.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [bootc, containers, ostree]
description: >-
  bootc — foundational OS image tool. Use when working on Containerfiles,
  image build workflows, update mechanics, or OS image structure.
metadata:
  type: reference
  context7-sources:
    - /bootc-dev/bootc
---

# bootc

## Read the docs, not your training data

bootc's flags, labels, and config options change between releases. Before
writing any Containerfile instruction, workflow step, or config that affects how
images are built, delivered, or updated, look them up:

```
resolve-library-id: bootc
→ get-library-docs: /bootc-dev/bootc
→ implement from docs
→ cite the section
```

This skill is the worked example of the rule in
[`context7.md`](context7.md): it deliberately holds only facts about *this
repo*, and defers every general bootc question to upstream.

## What `common` actually produces

`common` does **not** build a bootc image. Its `Containerfile` ends in a
`FROM scratch AS ctx` stage that assembles `system_files/` plus generated
artifacts into an OCI layer. `bluefin` and `bluefin-lts` consume that layer and
produce the bootable images; `iso` git-clones this repo at build time for the
Brewfiles.

Consequences for anything you change here:

- **There are no image labels to set.** `grep LABEL Containerfile` returns
  nothing, by design — the scratch context image carries none. Label
  requirements belong to the downstream repos.
- **`bootc upgrade`/`switch` semantics are out of scope**, with one exception:
  `shared/usr/libexec/bootc-update-stage` runs a bare `bootc upgrade` behind a
  polkit action. Its flag prohibitions are documented in
  [`brew-lifecycle/SKILL.md`](brew-lifecycle/SKILL.md).
- **The build is owned elsewhere.** The reusable workflow is authoritative:
  ```bash
  gh api repos/projectbluefin/actions/contents/.github/workflows/reusable-build.yml \
    --jq '.content' | base64 -d
  ```

## Kernel arguments — the declarative rule, and where this repo breaks it

bootc supports declarative kargs via TOML in `/usr/lib/bootc/kargs.d/`:

```toml
# /usr/lib/bootc/kargs.d/my-feature.toml
kargs = ["module_blacklist=my_module", "my_arg=1"]
```

Baked into the image, reproducible, applied without touching the bootloader at
runtime. Use this for any new kernel argument.

**`common` ships no `kargs.d/` at all.** Its one karg manipulation is runtime
and imperative: `system_files/shared/usr/share/ublue-os/system-setup.hooks.d/10-framework.sh`
reads `rpm-ostree kargs` and calls
`rpm-ostree kargs --delete-if-present=module_blacklist=hid_sensor_hub`. That is
a *removal* of a karg an older image set, on matching Framework hardware only,
which a static TOML cannot express — so it is a deliberate exception, not an
oversight. Do not copy the pattern for *adding* a karg.

## Filesystem layout

`/usr/` is read-only and bootc-managed, `/etc/` is mutable and overlaid, `/var/`
is persistent and never reset. Where files in `system_files/` may go is
constrained by that; the wrong path breaks the update applier silently. Check
the bootc docs → "Filesystem layout" before adding a new top-level path, and see
[`submodule-boundary.md`](submodule-boundary.md) for which overlay layer a file
belongs in.
