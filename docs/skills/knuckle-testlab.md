---
name: knuckle-testlab
description: Launch knuckle in a Flatcar QEMU VM on ghost for interactive manual testing. Load when demoing, verifying TUI behavior, or iterating on UI changes.
---

# knuckle-testlab

Run knuckle interactively inside a real Flatcar Container Linux VM. Enables rapid build→deploy→test iteration.

Load with: `cat ~/src/skills/knuckle-testlab/SKILL.md`

## When to Use
- Running knuckle interactively for manual testing or demos
- Verifying TUI behavior after code changes
- Running a live install (writes to disk)
- Booting the installed system to verify Ignition config
- Testing the installer ISO end-to-end

## When NOT to Use
- Unit tests — run `just test` locally
- Quick headless validation — run `just headless-test`

---

## Quick Start — Justfile Recipes

```bash
cd ~/src/knuckle

# Interactive TUI (SCP deploy over SSH, real install)
just vm          # real install in QEMU → auto-boots installed system after

# Automated end-to-end (4 passes: DHCP, static network, sysext/docker, NVIDIA)
just vm-e2e      # fully automated, no user interaction required

# ISO-based (full bare-metal simulation)
just iso         # build UEFI installer ISO
just e2e         # build ISO + launch interactive VM in Ghostty
just boot-iso    # boot ISO on serial console (Ctrl-a x to quit)

# Utilities
just stop        # kill running VM
just clean       # kill VM + remove all artifacts
just headless-test  # no VM needed, exercises config generation (CI gate)
```

## How `just vm` Works

1. Builds binary (`linux/amd64`, CGO_ENABLED=0)
2. Creates qcow2 overlay on cached Flatcar base image (instant, no 3GB copy)
3. Creates 20G target disk
4. Boots QEMU daemonized with port-forward (2222→22)
5. Waits for SSH (~6s with KVM)
6. SCPs binary to `/tmp/knuckle`
7. SSHes into the VM to run knuckle interactively (real install, writes to /dev/vdb)
8. After install completes: kills installer VM and boots the installed target disk automatically

**Antipattern:** Never embed the binary into Ignition via base64 (19MB → 26MB JSON, breaks fw_cfg).

## How `just vm-e2e` Works

Runs four automated passes back-to-back inside QEMU. No user interaction required.

| Pass   | What it tests                              | Timeout |
| ------ | ------------------------------------------ | ------- |
| DHCP   | Hostname, update strategy, locksmith       | 15m     |
| Static | `/etc/systemd/network/10-static.network`   | 15m     |
| Sysext | docker.raw present, `docker version` exits | 25m     |
| NVIDIA | NVIDIA driver sysext config, enabled-sysext.conf | 15m |

Each pass builds a fresh qcow2 overlay so passes are independent.

## How `just e2e` Works

1. Builds ISO (if not already present in `output/`)
2. Opens Ghostty window with QEMU UEFI VM booting from ISO
3. GRUB menu appears (3s timeout), boots Flatcar
4. knuckle auto-launches on tty1 via systemd unit
5. User completes install interactively
6. After install: `just boot-target` to verify

## ISO Architecture

- **Kernel:** `flatcar_production_pxe.vmlinuz` from Flatcar CDN
- **Initrd:** `flatcar_production_pxe_image.cpio.gz` + knuckle overlay cpio (appended)
- **Boot:** GRUB standalone EFI (`grub-mkstandalone` with fat/part_gpt/search/linux modules)
- **Assembly:** xorriso with El Torito EFI boot image
- **Overlay:** `/opt/knuckle` binary + `knuckle-installer.service` systemd unit
- **UEFI only** (no BIOS/legacy boot)

Build deps: `x86_64-elf-grub-mkstandalone`, `xorriso`, `mtools` (mformat/mcopy), `cpio`

## Agent Workflow — Launch Terminal for User

```bash
cd ~/src/knuckle

# Option A: Quick TUI test (SCP deploy)
ghostty --gtk-single-instance=false -e bash -c "cd ~/src/knuckle && just vm ''" &

# Option B: Full ISO experience
ghostty --gtk-single-instance=false -e bash -c "cd ~/src/knuckle && just boot-iso" &

# Option C: E2E (builds ISO if needed, then launches)
just e2e
```

## Post-Install Verification

`just vm` boots the installed system automatically after knuckle exits. To
verify manually after the installed VM is up:

```bash
# `just vm` handles the reboot automatically.
# For vm-e2e, the pass output shows SSH verification results.
# For ISO installs, reboot the VM from inside knuckle's done screen.
ssh -p 2222 core@127.0.0.1 -o StrictHostKeyChecking=no \
  "hostname && uname -r && cat /etc/flatcar/update.conf"
```

## ⛔ Agent Verification Limitations

**The agent CANNOT verify TUI interactive behavior.**

| Can verify | Cannot verify |
|---|---|
| Binary builds (`go build`) | Forms render correctly |
| Unit tests pass (`go test`) | User can navigate steps |
| Process launches (`pgrep`) | Fields accept input |
| VM boots (SSH works) | Install progress animates |
| Installed system config | TUI doesn't crash mid-flow |
| Headless mode output | Interactive experience |

**Correct protocol:**
1. Launch terminal for user (Ghostty)
2. Say "launched — awaiting your feedback"
3. WAIT. Never claim "verified" for TUI behavior.

## Fork / Remote Setup (2026-05-22)

The upstream repo is `projectbluefin/knuckle`. The fork is `castrojo/knuckle-1`
(GitHub auto-suffixed because `castrojo/knuckle` was already taken).

Local remote layout in `~/src/knuckle`:
```
upstream  git@github.com:projectbluefin/knuckle.git
castrojo  git@github.com:castrojo/knuckle-1.git
```

Branch workflow:
```bash
git checkout -b fix/slug upstream/main   # always base on upstream/main
git push castrojo fix/slug               # push to fork, never to upstream
```

Compare URL base:
```
https://github.com/projectbluefin/knuckle/compare/main...castrojo:knuckle-1:<branch>
```

---

## Key Facts

| Item | Value |
|---|---|
| Local VM SSH | `ssh -p 2222 core@127.0.0.1` |
| Target disk in VM | `/dev/vdb` (20G virtio) |
| Image format | qcow2 overlay (backing: .vm/flatcar_base.img) |
| Boot time (KVM) | ~6s to SSH |
| QEMU binary | `/home/linuxbrew/.linuxbrew/bin/qemu-system-x86_64` |
| OVMF firmware | `/home/linuxbrew/.linuxbrew/Cellar/qemu/11.0.0/share/qemu/edk2-x86_64-code.fd` |
| GRUB standalone | `x86_64-elf-grub-mkstandalone` (Homebrew) |
| Ghostty flag | `--gtk-single-instance=false` (REQUIRED) |
| SSH options | `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR` |

## Gotchas

| Problem | Fix |
|---|---|
| Ghostty window invisible | `--gtk-single-instance=false` |
| ISO doesn't boot (EFI shell) | Need OVMF firmware (`-drive if=pflash,format=raw,readonly=on,file=$OVMF`) |
| GRUB "file not found" | Needs `search --file /vmlinuz --set=root` in grub.cfg |
| SSH after ISO boot fails | Live ISO has no SSH key — use `just vm` for SSH testing |
| VM port 2222 in use | `just stop` |
| Base image missing | First `just vm` downloads ~470MB Flatcar image (cached in .vm/) |
| `just e2e` / `just boot-iso` fail on ghost | These recipes use `-display gtk` / Ghostty — **local display required, never run on ghost** |
| SSH to ghost:2222 connects to host sshd | `hostfwd=tcp::2222-:22` binds `127.0.0.1` — SSH to the VM must run FROM ghost (`ssh jorge@ghost` then `ssh -p 2222 core@127.0.0.1`), never through it |
| Flatcar VM SSH permission denied on ghost | Ghost SSH key is `~/.ssh/id_ed25519.pub` on ghost, not on your dev machine — the `_write-ignition` recipe reads the key from the machine running QEMU |

---

## Remote Testing on Ghost

**Two separate systems — do not confuse them:**

| System | Approach | SSH |
|---|---|---|
| `just vm` / `just vm-e2e` (Justfile) | QEMU with port-forward (`hostfwd`) | `ssh -p 2222 core@127.0.0.1` FROM the machine running QEMU |
| `qa-test-pr.sh` (PR review) | KubeVirt VMs via kubectl in `knuckle-test` namespace | KubeVirt pod IP, `kv_ssh` helper in `vm-kubevirt.sh` |

**QEMU port-forward constraint (Justfile recipes):**
```
-net user,hostfwd=tcp::2222-:22  → binds 127.0.0.1:2222 on the machine running QEMU

If QEMU runs on ghost:
  ✅ ssh jorge@ghost → ssh -p 2222 core@127.0.0.1   (from ghost)
  ❌ ssh -p 2222 jorge@ghost                         (reaches host sshd, not VM)
```

**Ghost-safe Justfile recipes** (headless, no display):
- `just vm-e2e` — fully automated 4-pass
- `just headless-test` — no VM, runs anywhere
- `just hardware-repro` — ISO-based headless

**Local-only Justfile recipes** (require display/Ghostty):
- `just vm` — opens interactive TUI over SSH
- `just e2e` / `just boot-iso` — use `-display gtk`, will fail on ghost

**Ghost Flatcar base image:**
```
/var/tmp/knuckle-test/flatcar_base.img  (qcow2, Flatcar 4593.2.1)
```

For PR testing, load `knuckle-qa` skill — it uses KubeVirt, not the Justfile.
