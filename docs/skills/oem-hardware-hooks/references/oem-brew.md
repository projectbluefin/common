# OEM Hardware Hooks — OEM Brew Hook and WirePlumber

Part of [oem-hardware-hooks](../SKILL.md) — OEM brew hook data-driven pattern; adding a new OEM vendor; OEM directories table; WirePlumber rules; known gaps.

---

## OEM brew hook — data-driven pattern

`20-oem-brew.sh` is a single generic hook. It detects the vendor, looks up
`/usr/share/ublue-os/oem/<Vendor>/`, installs packages, and sets the logo.
The logo in the top-left menu reflects that HWE brew packages are installed
and active — a plain `u` means stock, a vendor logo means the OEM stack is running.

### Adding a new OEM

1. Add a `case` arm in `20-oem-brew.sh` mapping the DMI vendor string → canonical name:
   ```bash
   *:LENOVO*) VENDOR="Lenovo" ;;
   ```
   (`CHASSIS_VENDOR:SYS_VENDOR` — use whichever field is reliable for that hardware.)

2. Create the data directory:
   ```
   system_files/shared/usr/share/ublue-os/oem/<Vendor>/
     packages.Brewfile   # tap + cask declarations (trusted: true required)
     logo                # icon name, e.g. "lenovo-logo-symbolic"
   ```

3. Add the vendor logo SVG to:
   `system_files/shared/usr/share/icons/hicolor/scalable/actions/<name>-symbolic.svg`

4. If the OEM also needs user-session config files (for example a WirePlumber
   snippet), place them in the same `oem/<Vendor>/` directory and have
   `20-oem-brew.sh` install them into the user's home directory.

No new hook file is needed. Bump the hook version only when existing machines
must re-run the hook to pick up a new payload.

### OEM directories

| Vendor | Packages | Logo |
|---|---|---|
| `Framework` | `framework_tool`, `framework-wallpapers` | `framework-logo-symbolic` |
| `ASUS` | `asusctl-linux`, `rog-control-center-linux` | `asus-rog-symbolic` |

### Version stamp

The stamp slug is `oem-<Vendor> user 2`. This is intentionally separate from
the old `asus user 1` stamp — existing ASUS machines that already ran the old
`11-asus.sh` will pick up the new generic hook and get the logo set on next login.
The brew installs are idempotent (already-installed casks are skipped by brew).

**WirePlumber rules for Framework Desktop (AMD Ryzen AI Max 300):**
ship the snippet as OEM data in
`system_files/shared/usr/share/ublue-os/oem/Framework/51-framework-desktop.conf`
and let `20-oem-brew.sh` install it to
`~/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf`
on Framework Desktop machines only (`product_name == "Framework Desktop"`).

---

## WirePlumber rules — use wireplumber.conf.d/, not hardware-profiles/

Bazzite ships WirePlumber rules in a `hardware-profiles/<product-name>/wireplumber.conf.d/`
subdirectory structure. **This is a bazzite-specific extension — it does NOT work in stock
Fedora/bluefin WirePlumber.**

Bazzite swaps wireplumber from their own COPR (`ublue-os/bazzite`) and enables
`wireplumber-sysconf.service` in deck builds to process those directories. Stock
WirePlumber 0.5.x (what bluefin ships) has no `hardware-profiles/` loader.

**For common:** do not drop OEM-specific WirePlumber snippets into
`system_files/shared/usr/share/wireplumber/wireplumber.conf.d/` — that ships
globally to every machine. If the rule only applies to one OEM family, store it in
that vendor's `oem/<Vendor>/` directory and have the OEM user hook copy it into the
user's WirePlumber fragment directory:

```bash
install -d "${HOME}/.config/wireplumber/wireplumber.conf.d"
install -m 0644 "${OEM_DIR}/${VENDOR}/51-framework-desktop.conf" \
  "${HOME}/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf"
```

WirePlumber's documented user fragment path is
`~/.config/wireplumber/wireplumber.conf.d/`. The `node.name` match (PCI address or
pattern) still scopes the rule to the target hardware — no hardware-profiles
directory structure needed:

```conf
monitor.alsa.rules = [
  {
    matches = [{ node.name = "~alsa_output.pci-0000_c3_00.1.*" }]
    actions = {
      update-props = {
        priority.driver = 1100
        priority.session = 1100
      }
    }
  }
]
```

Use `~` prefix for regex matching to avoid PCI minor-revision fragility.

If you add a new OEM payload to an existing versioned setup hook and want current
users to receive it, bump that hook's `version-script` version. Otherwise existing
machines skip the new logic forever because the old stamp already exists.

If an OEM payload only applies to one model within a vendor family, gate the copy
on DMI `product_name` as well as vendor. `Framework` alone is too broad — it would
also match Framework laptops.

If the OEM payload is a user-level config file that should survive failed setup
retries, run its copy step **after** the versioned work block and make it
idempotent (`install -d` + `install`). That way existing stamped systems still get
the file and repeated logins safely refresh it.

## Sources

- WirePlumber config fragments and user override path: Context7 `/websites/pipewire_pages_freedesktop_wireplumber`

---

## Known gaps (tracking issues)

- `20-framework.sh` in `projectbluefin/bluefin` is superseded by `20-oem-brew.sh` in common — file a cleanup issue in bluefin to delete it after common ships.
- `apps.just` ASUS recipe calls `brew install --cask` directly after `brew tap` + `brew trust`; consider moving to a Brewfile with `trusted: true` instead.
