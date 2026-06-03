---
name: bluefin-variants
description: Bluefin variant and stream matrix reference — use when confused about which image/tag/flavor combination to use, understanding the build matrix, or explaining Bluefin variants to others.
---

# Bluefin Variant Matrix

## Powerlevel

- **Level:** 1


Complete reference for the image × tag × flavor build matrix.

Load with: `cat ~/src/skills/bluefin-variants/SKILL.md`

## When to Use

- Deciding which image/tag/flavor combination to build or reference
- Explaining Bluefin variants to others (users, contributors)
- Understanding which Fedora version maps to which stream tag
- Identifying the correct OCI image path on `ghcr.io/ublue-os`

## When NOT to Use

- Building images (use `cat ~/src/skills/bluefin-build/SKILL.md`)
- Changing stream tag behavior — this is a reference skill only
- LTS-specific questions — use `cat ~/src/skills/bluefin-lts/SKILL.md`
- **NEVER use the VS Code Flatpak for development.** It is on the Bluefin blocklist due to sandbox limitations with devcontainers and SDKs. Install it via Homebrew using `brew install ublue-os/tap/visual-studio-code-linux` instead of layering RPMs.

## How It Works

Bluefin produces images as a matrix of three dimensions. The Justfile encodes this.

## DX / GDX Branding — Critical Distinction

> **⛔ `bluefin-dx` as a separate OCI image is a dead SKU.** The old `ghcr.io/ublue-os/bluefin-dx` image (in the `ublue-os/` org) still exists in the registry but is **not maintained** and must not be recommended to users.

**DX is now a userspace component, not an image.**
- Developer experience features (dev containers, tooling) are installed on top of any standard Bluefin image at the userspace layer — they are **not baked into a separate OCI image**.
- There is no `projectbluefin/bluefin-dx` image in the new project structure.

**GDX = special SKU (not "LTS DX").**
- `ghcr.io/projectbluefin/bluefin-gdx` is a distinct product — Bluefin LTS + NVIDIA driver already included. It is a separate image, not "Bluefin DX on LTS".
- GDX is the only remaining LTS image that ships with NVIDIA drivers pre-installed.
- Do not refer to GDX as "Bluefin LTS DX" — the correct name is **Bluefin GDX**.

## Full Matrix

```
Images:  bluefin
Flavors: main, nvidia-open
Tags:    gts, stable, latest, beta
```

### Tags (Fedora Version)

| Tag | Fedora | Audience | Notes |
|---|---|---|---|
| `gts` | F42 | Most users | "Good Till September" — long support |
| `stable` | F42 | General use | Current stable |
| `latest` | F42/43 | Early adopters | Tracks latest Fedora |
| `beta` | F42/43 | Testers | Upcoming changes |

### Images

| Image | Description |
|---|---|
| `bluefin` | Base GNOME desktop — for general users |
| `bluefin-gdx` (LTS only) | Bluefin GDX — LTS + NVIDIA driver pre-installed. Special SKU, not a DX variant. |

### Flavors

| Flavor | GPU Support |
|---|---|
| `main` | AMD/Intel GPUs, open drivers |
| `nvidia-open` | NVIDIA GPUs using open kernel module |

## OCI Registry

```
ghcr.io/ublue-os/bluefin:TAG-FLAVOR
ghcr.io/ublue-os/bluefin:stable-main
ghcr.io/ublue-os/bluefin:latest-nvidia-open
```

## Related Repos

| Repo | Purpose |
|---|---|
| `~/src/bluefin` | Main image (base + dx) |
| `~/src/bluefin-lts` | LTS variant (CentOS base) |
| `~/src/bluefin-common` | Shared layer for all variants |
| `~/src/aurora` | KDE Plasma variant (parallel project) |

## Learnings

<!-- Background agents append here automatically -->
