# DX-Next (system files)

Experimental developer environment for Bluefin / uBlue **DX** images. End users run **`ujust dx-next`**; implementation lives here and in sibling paths under `usr/share/ublue-os/`.

Full guide: [docs/dx-next.md](../../../../../../docs/dx-next.md) (repo root).

## Architecture

```text
ujust dx-next
    └── just/apps.just  (recipe dx-next — menus, one bash shell)
            ├── dx-ui-lib.sh      sudo, messages, spinners
            ├── dx-install-lib.sh install steps
            └── dx-remove-lib.sh  removal steps (remove path only)

ujust dx-docker | dx-virt | …
    └── just/dx.just → sources dx-install-lib.sh (per-component)

/usr/bin/dx-remove     CLI: dx_remove_main "$@"
/usr/bin/dx-sudo-ensure  used by dx.just _ensure-sudo
```

Install/remove run in **one shell** so Fedora sudo TTY tickets are not lost between steps. Do not `exec dx-remove` from `apps.just`; **source** `dx-remove-lib.sh` instead.

## Directory layout

| Path | Purpose |
|------|---------|
| `dx-install-lib.sh` | `dx_run_*` install functions; sourced by `dx-next` and `dx.just` |
| `dx-remove-lib.sh` | `dx_remove_*` removal functions |
| `dx-ui-lib.sh` | `dx_msg_*`, `dx_acquire_sudo`, `dx_spin_run`, `dx_sudo_run` |
| `quadlets/*.container` | Podman quadlets → `libvirt-dx`, `incus-dx`, `cockpit-dx` |
| `units/system/dockerd-dx.service` | Rootfull Docker (Homebrew dockerd) |
| `units/user/dockerd-rootless-dx.service` | Reference unit (rootless uses setuptool user unit) |
| `../homebrew/dx-next.Brewfile` | DX-Tools bundle (**no** `incus` — see `dx_run_incus`) |

## Environment variables (dev / overrides)

| Variable | Default | When to set |
|----------|---------|-------------|
| `DX_SHARE` | `/usr/share/ublue-os/dx` | Git checkout testing (`run-dx-next-dev.sh` sets this) |
| `DX_UBLUE_ROOT` | `/usr/share/ublue-os` | Brewfile and shared assets root |
| `DX_LIB` | `$DX_SHARE/dx-install-lib.sh` | Override install lib path |
| `DX_REMOVE_LIB` | `$DX_SHARE/dx-remove-lib.sh` | Override remove lib path |
| `DX_SUDO_READY` | unset | Set internally after first `dx_acquire_sudo` |
| `DX_NONINTERACTIVE` | unset | `1` to skip gum menus |
| `DX_NEXT_CHOICES` | `Virt Docker` | Components for non-interactive install |
| `DX_NEXT_ACTION` | `install` | `remove` for non-interactive removal |
| `DX_SPIN_INLINE` | `1` | `0` to use gum spin subprocess (legacy) |

## Dev testing (immutable `/usr`)

Production paths above are read-only on Silverblue. From the repo:

```bash
./scripts/dx-next-dev.sh
```

See [scripts/README.md](../../../../../../scripts/README.md).
