---
name: image-identity
version: "1.0"
last_updated: "2026-09-23"
id: image-identity
one_line_purpose: Decide who owns image-identity and variant metadata across the org.
entry_point: docs/skills/image-identity.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [identity, variants, image-info, ownership]
description: >-
  Ownership map for image-identity and variant metadata across the factory:
  which layer common owns, which each repo owns, and the field drift between
  them. Use when adding a variant or writing image-info.json.
metadata:
  type: reference
---

# Image Identity & Variant Metadata

> **This file records an ownership decision, not a schema you may invent.**
> Read the layer table before adding an identity field or a variant. If your
> change does not fit an existing layer, that is a signal to amend this file
> first — in the same PR.

`image-registry.md` owns *where images live* (registry paths, tags). This file
owns *what an image calls itself* (identity fields, variant declarations) and
**who is allowed to define each one**.

## When to Use

- Adding or renaming an image variant (nvidia, dx, gaming, a new arch).
- Writing or reading `/usr/share/ublue-os/image-info.json`.
- Tempted to add a `projectbluefin/schema` repo or a shared identity library.
- Reviewing a PR that declares variant membership in CI.

## The decision

Issue [#1056](https://github.com/projectbluefin/common/issues/1056) observed
that nine repos each "single-sourced" image identity independently and asked
whether common should be canonical **(a)** or per-repo ownership should be
accepted with a consistency check **(b)**. The answer is neither, wholesale —
the domain is not one thing. It splits into three layers with different owners:

| Layer | What it is | Owner | Why |
|---|---|---|---|
| 1. Runtime identity vocabulary | Field names, meanings, and the readers that consume them | **common** | Every image, every repo, one consumer set. Divergence here breaks user-facing tools. |
| 2. Build-time variant declaration | Which variants a repo builds and which pipeline roles each participates in | **per-repo** | Variant sets are build-pipeline-shaped, not runtime-shaped. |
| 3. Presentation | Rendering identity into release notes, PR bodies, gates | **actions** | Already single-sourced and drift-guarded. |

So: **(a) for layer 1, (b) for layer 2.** The rest of this file says what is
already true, and what is not.

## Layer 1 — runtime identity vocabulary (common owns)

The canonical surface is `/usr/share/ublue-os/image-info.json`. These five keys
are genuinely cross-repo and are what common's readers consume:

| Key | Meaning |
|---|---|
| `image-name` | Image name, e.g. `bluefin`, `bluefin-nvidia`, `dakota` |
| `image-flavor` | Variant within the image, e.g. `main`, `nvidia`, `gaming` |
| `image-vendor` | GHCR org segment; prefixes `image-ref` |
| `image-ref` | Full bootc source ref |
| `image-tag` | Published stream tag |

**What common already owns** (`system_files/shared/`):

- `usr/libexec/ublue-image-repo` — the name/tag → upstream repo resolver. Its
  header states it is the single source of truth for "which repository owns
  this booted image"; every consumer must route through it.
- `usr/bin/ublue-image-info.sh` — the reader.
- Consumers: `changelog.just`, `system.just`, `bonedigger-report`.

**What common does *not* own, and cannot:** the *writers*. Each repo generates
`image-info.json` during its own build, in its own build system, so the write
must stay local. That is the residual gap — there is no shared schema for the
writers to conform to, and they have already drifted.

### Field drift between the writers (verified 2026-09-23)

| Key | bluefin | bluefin-lts | dakota |
|---|---|---|---|
| `image-name` | yes | yes | yes |
| `image-flavor` | derived from `IMAGE_NAME =~ nvidia` | literal `main`, later rewritten | literal `main`, `gaming` under a variant |
| `image-vendor` | yes | yes | yes |
| `image-ref` | yes | yes | yes |
| `image-tag` | from `$UBLUE_IMAGE_TAG` | **literal `"stable/testing"`** | **literal `"latest"`** |
| base version | `fedora-version` | `centos-version` | *(absent)* |
| other | `base-image-name` | — | — |

Four findings worth acting on, in rough priority order:

1. **`image-tag` is a hardcoded literal in two repos.** bluefin-lts writes the
   string `stable/testing`; dakota writes `latest` into images that are also
   published as `testing`, `stable` and `next`. Any consumer that trusts
   `image-tag` is wrong for those images. This is the highest-value fix.
2. **The base-version key has no agreed name** (`fedora-version` vs
   `centos-version` vs absent). A consumer cannot read the base version
   portably, so today none do.
3. **`image-ref` is hand-reconstructed in all three writers**, duplicating the
   `ostree-image-signed:docker://ghcr.io/<vendor>/<name>` grammar that
   `ublue-image-repo` exists to centralize.
4. **dakota mirrors identity into `os-release` as well** (`IMAGE_NAME`,
   `IMAGE_VENDOR`, `IMAGE_REF`, `IMAGE_FLAVOR`, `IMAGE_TAG`), creating a second
   surface of the same data that the other repos do not have.

Do not "fix" these by editing the writers from common — see Red Flags.

## Layer 2 — build-time variant declaration (per-repo owns)

Each repo declares variants locally, in the shape its build system needs, and
each already has a fail-closed gate. That redundancy is accepted; what follows
is the inventory to check against.

| Repo | Declaration | Gate |
|---|---|---|
| dakota | `.github/image-variants.json` | `.github/scripts/image_variants.py` projects roles into matrices; `check-publish-workflow` fails closed if `publish.yml` drifted |
| server | `include/arch.yml` | `options.arch.values` in `project.conf` constrains the axis to mapped architectures |
| fsdk-containers | `elements/targets.json` | `tests/test_catalog_conformance.py` — every published image has a record and vice versa |
| bluefin-lts | `build_scripts/build.sh` `run_buildscripts_for()` + `overrides/<variant>/` | filename ordering (`*-*.sh`, human-numeric sort) |
| dakota-iso | `scripts/variant-config.sh` | *(PR #146, open)* |
| finpilot | `Containerfile` + `iso/iso.toml` | build-time only |

dakota's `image-variants.json` is the mature model: every variant must declare a
membership decision for *every* role — either a participation object or
`{"excluded": "<reason>"}` — so a forgotten variant fails the gate closed rather
than silently shrinking pipeline coverage.

**The consistency rule:** a repo may name variants however its build system
requires, but the `image-flavor` value it writes into `image-info.json` at
build time must be one of the flavors `image-registry.md` documents for that
image. Flavor strings are layer-1 vocabulary; variant names are layer-2.

## Layer 3 — presentation (actions owns)

`projectbluefin/actions` renders identity into release cards, PR bodies and gate
sections. `tests/test_render_single_source.py` asserts the composite actions
execute the `.github/actions` copies rather than the `scripts/` copies, so the
duplication that motivated this skill cannot be reintroduced silently. Nothing
to do here — cite it as the pattern the other layers should reach.

## Red Flags

- **Writing an identity field from memory.** Derive it. See Verification.
- **Adding a new `image-info.json` key in one repo only.** Layer 1 is shared;
  a new key is an org-level change. Amend this file in the same PR.
- **Reading `image-tag` and trusting it.** Two of three writers hardcode it.
- **Editing another repo's identity writer from a common PR.** common is an OCI
  layer, not a code generator; its writers are not ours to change. File the
  finding against the owning repo.
- **Adding a shared identity schema library or a new `schema` repo.** Rolled
  into #1056 and rejected: common already ships the readers, and a library
  would add a build-time dependency to repos with unrelated build systems.
- **Creating `ADR.md`, `PLAN.md`, or a `specs/` entry for this decision.** This
  skill *is* the decision record — AGENTS.md bans committed planning docs.

## Verification

Re-derive every claim above before trusting it.

```bash
# The five shared keys, as common's readers consume them
grep -rn 'image-info\.json' system_files/ docs/

# bluefin writer — image_flavor derivation and the key set
gh api repos/projectbluefin/bluefin/contents/build_files/base/00-image-info.sh \
  --jq '.content' | base64 -d

# bluefin-lts writers — note the literal image-tag and the separate rewrite step
gh api repos/projectbluefin/bluefin-lts/contents/build_scripts/90-image-info.sh \
  --jq '.content' | base64 -d
gh api repos/projectbluefin/bluefin-lts/contents/build_scripts/scripts/image-info-set \
  --jq '.content' | base64 -d

# dakota writer — IMAGE_FLAVOR / IMAGE_TAG defaults and the os-release mirror
gh api repos/projectbluefin/dakota/contents/include/os-release.yml \
  --jq '.content' | base64 -d

# Layer 2 declarations
gh api repos/projectbluefin/dakota/contents/.github/image-variants.json \
  --jq '.content' | base64 -d
gh api repos/projectbluefin/server/contents/include/arch.yml \
  --jq '.content' | base64 -d

# Registry paths and flavor tables are owned by the sibling skill — do not
# restate them here; read docs/skills/image-registry.md instead.
```

### Incident log

| Date | What happened |
|---|---|
| 2026-09-23 | Six writers across three repos, no shared schema. `image-tag` hardcoded in two; base-version key named three different ways. Recorded here after nine per-repo "SSOT" PRs merged without converging. |
