---
name: bootc
version: "1.2"
last_updated: "2026-10-01"
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

### Kernel arguments

bootc supports declarative kernel arguments via TOML files in `/usr/lib/bootc/kargs.d/`.
When adding or modifying kernel arguments for the OS image, **always use declarative TOML files** instead of runtime `grubby` commands in setup scripts.

```toml
# /usr/lib/bootc/kargs.d/my-feature.toml
kargs = ["module_blacklist=my_module", "my_arg=1"]
```

This ensures arguments are baked into the image, reproducible, and applied reliably without requiring runtime modification of the bootloader config.
Source: bootc docs → "Kernel arguments" (resolve via Context7).

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

### Known bug: `bootc upgrade` fails with `readlink /var/lib/containers/storage/overlay/diff`

**Reported in `projectbluefin/common#1332`** (booted
`ostree-image-signed:docker://ghcr.io/projectbluefin/utah:testing-20260928-ce09ef7`,
bootc 1.12.1, Fedora 44). Symptom:

```
error: Switching: Switching (ostree): Pulling: Importing:
  failed to invoke method GetBlob: creating file-getter:
  readlink /var/lib/containers/storage/overlay/diff: no such file or directory
```

**Root cause (read from bootc v1.12.1 source, not memory):**
`crates/lib/src/cli.rs::upgrade` auto-detects whether the booted image already
lives in bootc-owned unified storage via
`crate::deploy::image_exists_in_unified_storage(storage, imgref)`; when true,
it dispatches to `pull_unified`, which re-imports through the
`containers-storage:` transport. The overlay driver's
`Driver.DiffGetter → getDiffPath → redirectDiffIfAdditionalLayer` then calls
`os.Readlink("/var/lib/containers/storage/overlay/diff")` against a path
that has no `id` segment and no `diff` symlink, so the readlink fails with
`ENOENT`. The error string is propagated verbatim by
`layerStore.newFileGetter` ("creating file-getter: %w") and surfaces as the
"Importing: failed to invoke method GetBlob" chain above.

`bootc switch <booted-image>:<new-tag>` side-steps the bug because
`image_exists_in_unified_storage(storage, &target)` checks the *target* ref
— the new tag is not yet in bootc storage, so the auto-detect returns
`false`, regular `pull` is used, and the upgrade imports cleanly via skopeo.

**Action by repo:** none. The fix belongs to bootc-dev/bootc (the auto-detect
should not pull through `containers-storage:` when the underlying overlay
path is missing, or should not assume `diff` is a real symlink in
`redirectDiffIfAdditionalLayer`). Not yet reported upstream as of this
revision; this skill records the workaround and the first-party-fork can
file the upstream bug from the description above. Do not duplicate the
workaround in `bootc-update-stage` or `update.just` — those callers already
invoke plain `bootc upgrade` (the contract tested by
`tests/test_chairlift_config.py::test_bootc_stage_script_is_executable_and_stages_only`),
which is the upstream-recommended verb. `ujust toggle-testing` is not in that
list — it already runs `pkexec bootc switch --enforce-container-sigpolicy`
(`system_files/bluefin/usr/share/ublue-os/just/system.just`), which takes the
working `pull` path.

**User-side workaround (for end-user reports):**

```bash
# Find the booted image ref. `.status.booted.image` is an ImageStatus, whose
# `.image` is an ImageReference struct — the ref string is one level deeper
# (bootc v1.12.1 crates/lib/src/spec.rs: ImageStatus.image: ImageReference,
# ImageReference.image: String).
bootc status --json | jq -r '.status.booted.image.image.image'
# → e.g. ostree-image-signed:docker://ghcr.io/projectbluefin/utah:testing-20260928-ce09ef7

# Switch to the floating channel tag to bypass the unified auto-detect.
# Strip the transport prefix and replace the dated tag with the channel tag.
sudo bootc switch ghcr.io/projectbluefin/<image>:testing
```

Switch to the **floating** tag (`:testing`), not a dated one
(`:testing-20260928-ce09ef7`). A dated tag pins the system to that exact
build: `bootc upgrade` then resolves the same immutable digest forever and
reports no update, so the machine silently stops receiving images.

`bootc upgrade` only works again while the booted ref is absent from bootc's
unified storage. If the readlink error returns on a later `bootc upgrade`,
re-run the `bootc switch` above against the same floating ref — that is the
workaround until bootc-dev/bootc fixes the auto-detect.

**Verification:**

```bash
# Confirm the jq path: ImageStatus.image is an ImageReference whose .image is
# the ref String, so the status ref is .status.booted.image.image.image
curl -s https://raw.githubusercontent.com/bootc-dev/bootc/v1.12.1/crates/lib/src/spec.rs \
  | grep -n "pub struct ImageReference" -A 4

# Confirm bootc v1.12.1 still routes through pull_unified on auto-detect
curl -s https://raw.githubusercontent.com/bootc-dev/bootc/v1.12.1/crates/lib/src/cli.rs \
  | grep -n "image_exists_in_unified_storage\|use_unified" | head -5

# Confirm the broken path is in containers/storage overlay driver
curl -s https://raw.githubusercontent.com/containers/storage/main/drivers/overlay/overlay.go \
  | grep -n "redirectDiffIfAdditionalLayer\|DiffGetter" | head -5
```

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
