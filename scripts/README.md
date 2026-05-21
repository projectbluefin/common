# DX-Next scripts (dev only)

**Production (PR #288):** `ujust dx-next` — recipes in `system_files/shared/usr/share/ublue-os/just/`, libs in `dx/`, helpers in `usr/bin/dx-remove` and `usr/bin/dx-sudo-ensure`.

User and architecture docs: [docs/dx-next.md](../docs/dx-next.md) · [dx/README.md](../system_files/shared/usr/share/ublue-os/dx/README.md).

**This folder** is only for testing from a git checkout on immutable `/usr` (Silverblue/Bluefin). One entry script:

```bash
./scripts/dx-next-dev.sh              # interactive (same as ujust dx-next)
./scripts/dx-next-dev.sh debug install Virt Docker
./scripts/dx-next-dev.sh deploy dev
./scripts/dx-next-dev.sh link         # ~/.local/bin/ujust-dx-next
```

| File | Role |
|------|------|
| `dx-next-dev.sh` | **Main** dev entry (`run` / `deploy` / `debug` / `link`) |
| `lib/dx-paths.sh` | Shared `DX_SHARE`, `DX_LIB`, validation (sourced only) |
| `run-dx-next-dev.sh` | Thin wrapper → `dx-next-dev.sh run` |
| `deploy-dx-next-fix.sh` | Thin wrapper → `dx-next-dev.sh deploy` |
| `debug-dx-next.sh` | Thin wrapper → `dx-next-dev.sh debug` |
| `install-ujust-dx-next-local.sh` | Thin wrapper → `dx-next-dev.sh link` |

Wrappers keep old paths working for docs and habits; new work should call `dx-next-dev.sh` only.
