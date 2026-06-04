---
name: onboarding
description: "Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos."
---

# Onboarding — Correct Setup Commands per Repo

Verified correct setup commands for projectbluefin repos. Use these when writing
contributor docs or guiding new contributors — don't guess from memory.

## ⚠️ CRITICAL: ublue-os vs projectbluefin image registry

**`ghcr.io/ublue-os/bluefin` is still the active production image registry.**

The `projectbluefin` GitHub org exists and holds source repos, but **OCI images
are still published under `ghcr.io/ublue-os/`**. The migration to
`ghcr.io/projectbluefin/` has NOT happened yet.

**Consequences for agents:**
- Do NOT replace `ghcr.io/ublue-os/bluefin` with `ghcr.io/projectbluefin/bluefin` in any docs or scripts — the projectbluefin image path does not serve production images.
- Do NOT change `bootc switch ghcr.io/ublue-os/...` commands — users running them would pull from a non-existent or wrong registry.
- Do NOT flag `ghcr.io/ublue-os/bluefin` refs as "stale" in docs or READMEs — they are correct.
- The hive guide/scanner agents may flag these as stale org refs. **They are not.** Verify against this skill before acting on such advisories.
- Do NOT touch `projectbluefin/documentation` (docs.projectbluefin.io) for ublue-os image ref "fixes" — that site is production and its refs are intentionally `ublue-os` until migration completes.

**What IS legitimately `projectbluefin` org (GitHub repos, not registry):**
- `github.com/projectbluefin/bluefin`, `github.com/projectbluefin/common`, etc.
- Source code lives in `projectbluefin`; published images still live in `ublue-os`.

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
# PRs target: testing branch (bluefin), main branch (bluefin-lts)
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
| bluefin-lts | `main` | |
| bootc-installer | `dev` | `main` is protected by merge queue |
| common | `main` | |
| documentation | `main` | Doc-only changes can push directly |
| website | `main` | |
| testsuite | `main` | Protected; PRs required |
| knuckle | `main` | Protected; requires CI green |
| dakota-iso | `main` | |
| testing-lab | `main` | |
