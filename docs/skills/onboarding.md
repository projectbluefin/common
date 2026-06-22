---
name: onboarding
description: "Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos. Use when setting up a new development environment or writing contributor documentation."
metadata:
  type: procedure
---

# Onboarding — Correct Setup Commands per Repo

Verified correct setup commands for projectbluefin repos. Use these when writing
contributor docs or guiding new contributors — don't guess from memory.

## documentation (docs.projectbluefin.io)

```bash
npm install --legacy-peer-deps   # bare npm install hits React 19 peer conflicts
npm run start
```

## website (projectbluefin.io)

```bash
npm install --include=dev   # CRITICAL: without this, @vitejs/plugin-vue is missing
npm run dev
```

## bootc-installer

```bash
git submodule update --init --recursive   # fisherman/ is a git submodule — required before any build
# Flatpak (recommended):
flatpak run org.flatpak.Builder --force-clean --user --install _build flatpak/org.bootcinstaller.Installer.json
# Demo/preview loop (no disk, no QEMU):
./run-dev.sh
# PRs target: dev branch (not main)
```

## testsuite (local dev)

```bash
pip install behave qecore dogtail   # NOT qecore-headless — that's the runner binary inside qecore
# Full GUI tests require Wayland + AT-SPI — use the GitHub Action reusable workflow instead
# gnome-ponytail-daemon must be baked into the image under test — not a local pip install
# Source: https://github.com/dogtail/gnome-ponytail-daemon
```

## bluefin / bluefin-lts

```bash
just check                    # Justfile + script syntax
pre-commit run --all-files    # lint/format checks (pip install pre-commit first)
# PRs target: testing branch (bluefin, bluefin-lts, dakota)
# See docs/build.md for full local image build prerequisites
```

## knuckle

```bash
./bin/knuckle --demo   # full TUI wizard with mocked hardware — no QEMU required
just vm-e2e            # full VM e2e test (requires QEMU)
# Troubleshooting: docs/TROUBLESHOOTING.md
```

## Branch targets (not always main)

| Repo | PR target | Notes |
|---|---|---|
| bluefin | `testing` | Never target `main`, `stable`, or `latest` directly |
| bluefin-lts | `testing` | Never target `main` directly |
| bootc-installer | `dev` | `main` is protected by merge queue |
| common | `main` | |
| documentation | `main` | Doc-only changes can push directly |
| website | `main` | |
| testsuite | `main` | Protected; PRs required |
| knuckle | `main` | Protected; requires CI green |
| dakota-iso | `main` | |
| testing-lab | `main` | |
