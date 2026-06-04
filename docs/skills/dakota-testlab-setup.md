---
name: dakota-testlab-setup
description: One-time NUC and ghost provisioning for the dakota hardware test lab — insecure registry, bootc switch, firewall, tmux, and future test-nuc automation. Load this only for initial setup; load dakota-testlab for the active build loop.
---

# Dakota Testlab — One-Time Setup

Load with: `cat ~/src/skills/dakota-testlab-setup/SKILL.md`

Provisioning guide for the ghost + NUC hardware test lab. Read once when setting up.
For the active dev loop (build → publish → bootc upgrade), load `dakota-testlab` instead.

## Powerlevel

- **Level:** 3

## When to Use

- Setting up a fresh NUC disk to pull from ghost's local registry for the first time
- Re-provisioning ghost after a reinstall
- Adding pi agent SSH access to ghost or NUC

## Shared Infra Prerequisites (from ghost-testlab)

Before provisioning with this skill, load `ghost-testlab` and use it as the authority for:
- topology (ghost / exo-dakota hosts and roles)
- SSH key + fingerprint
- port inventory (zot, ghost-lab API, KubeVirt, observability)
- tmux safety and headless constraints

This setup skill intentionally does **not** duplicate those shared facts.


## When NOT to Use

- Active dev loop (build, publish, bootc upgrade, verify) → `dakota-testlab`
- VM testing on local machine → `dakota-local-ota`

---

## NUC Setup (One-Time per Fresh Disk)

### 1. Allow insecure registry from ghost

```bash
ssh jorge@192.168.1.247

sudo tee /etc/containers/registries.conf.d/50-ghost-dev.conf <<EOF
[[registry]]
location = "192.168.1.102:5000"
insecure = true
EOF
```

This drop-in is persistent across reboots. Leave it in place — it is harmless when the NUC points at GHCR.

### 2. Switch from GHCR to ghost's registry

```bash
sudo bootc switch 192.168.1.102:5000/dakota:latest
```

After this, `sudo bootc upgrade` pulls from ghost's zot. The NUC stays pointed here until explicitly switched back.

### 3. Revert to upstream GHCR

```bash
ssh jorge@192.168.1.247
sudo bootc switch ghcr.io/projectbluefin/dakota:latest
sudo systemctl reboot
```

The `50-ghost-dev.conf` drop-in does not need to be removed.

---

## Ghost Setup Notes

### Git remote layout on ghost

```
origin  = projectbluefin/dakota (upstream)
castrojo = castrojo/dakota (fork)
```

Always `git push castrojo` on ghost, never `git push origin`.

### TMux safety

Never terminate existing tmux sessions, windows, or panes without explicit user instruction.
Before any tmux action: `ssh jorge@192.168.1.102 'tmux ls'`

Create agent work in a dedicated window:
```bash
ssh jorge@192.168.1.102 -t \
  'tmux has-session -t copilot 2>/dev/null || tmux new-session -d -s copilot; \
   tmux new-window -t copilot -n <task-name>'
```

### Zot registry on ghost

Start (idempotent):
```bash
just registry-start
```

Manual fallback:
```bash
sudo podman run -d --name egg-registry --replace \
  -p 5000:5000 \
  -v egg-registry-data:/var/lib/registry \
  ghcr.io/project-zot/zot-minimal-linux-amd64:latest
```

The `egg-registry-data` volume persists across reboots.

**Port 5000 conflict (stale pasta process):**
```bash
sudo ss -tlnp | grep 5000   # find PID
sudo kill <PID>
sudo podman start egg-registry
```

**Registry not reachable from NUC:**
- Verify zot is bound to `0.0.0.0:5000`: `podman inspect egg-registry | grep -i hostip`
- Ghost's firewall already permits `1025-65535/tcp` — port 5000 is open.

---

## VM Testing — Full Disk Install Path

> ⚠️ `just boot-vm` uses `-display gtk` and **will fail on ghost** (no monitor attached).
> Use `just boot-fast` (bcvk) for headless VM testing. See `dakota-testlab` for the fast path.

For the full install/composefs validation path when a monitor is available or after `-display none` support lands:

```bash
just generate-bootable-image   # bootc install to-disk --composefs-backend --bootloader systemd --filesystem btrfs
just boot-vm                   # only works with display attached
```

**`bootc install to-disk` must run from inside the container** (via `just bootc install ...`).
Do NOT run `--source-imgref` from outside the container — fails with "No root filesystem specified".
Do NOT use `--bootloader auto` — dakota uses systemd-boot, bootupd is RPM-specific and not present.

Ghost headless workaround (until `-display none` support lands):
```bash
DISK=$(realpath ~/src/dakota/bootable.raw)
qemu-system-x86_64 \
    -enable-kvm -m 4096 -cpu host -smp 2 \
    -drive file="${DISK}",format=raw,if=virtio \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=~/src/dakota/.ovmf-vars.fd \
    -display none \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
    -chardev stdio,id=char0,mux=on,signal=off \
    -serial chardev:char0 -serial chardev:char0 -mon chardev=char0
```

Inside VM (before bootc switch, for registry access):
```bash
mkdir -p /etc/containers/registries.conf.d
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' \
  > /etc/containers/registries.conf.d/local.conf
bootc switch 10.0.2.2:5000/dakota:latest
```

`10.0.2.2` = QEMU user-mode gateway = ghost's localhost from inside the VM.

---

## Future Automation — `just test-nuc`

**Goal:** single command to build → publish → upgrade NUC → reboot → validate.

**Proposed recipe (not yet activated):**
```just
[group('dev')]
test-nuc nuc_ip="192.168.1.247":
    #!/usr/bin/env bash
    set -euo pipefail
    just registry-start
    just publish
    ssh jorge@{{nuc_ip}} "sudo bootc upgrade && sudo systemctl reboot" || true
    echo "==> Waiting 180s for NUC to reboot..."
    sleep 180
    just validate-nuc {{nuc_ip}}
```

**Prerequisites before activating:**
1. Passwordless SSH key auth + NOPASSWD for `bootc` and `systemctl reboot` on NUC
2. `just validate-nuc` must exit non-zero on failure (currently always exits 0)
3. Reboot timeout: 90s warm NUC, 180s typical, 300s large upgrade

`just validate-nuc` is already implemented (PR #132). Activate `test-nuc` once SSH key auth is in place.

---

## Lessons Learned

### Junction patch rebase when upstream bumps a junction ref

When a PR bumps a junction ref (e.g. gnome-build-meta or fdsdk), patches in `patches/<junction>/` may become stale due to hunk offset drift.

**Check first — the module may already be upstreamed:**
```bash
grep -n 'MODULE_NAME_HERE' /tmp/<junction>-work/files/linux/fdsdk-config.sh
# If already present: git rm patches/<junction>/<patch>.patch — don't rebase a no-op
```

**Rebase pattern:**
```bash
# 1. Check out new upstream source from BST cache (no network needed)
git -C ~/.cache/buildstream/sources/git_repo/<junction>.git \
  worktree add /tmp/<junction>-work <NEW_REF>

# 2. Apply with -C1 to tolerate offset drift
cd /tmp/<junction>-work
git apply --ignore-whitespace -C1 ~/src/dakota/patches/<junction>/<patch>.patch

# 3. If -C1 fails, apply manually then diff and save:
git add -A && git diff --cached > /tmp/<patch>-rebased.patch
git checkout -- . && git apply /tmp/<patch>-rebased.patch && echo "VERIFY OK"

# 4. Copy back and commit
cp /tmp/<patch>-rebased.patch ~/src/dakota/patches/<junction>/<patch>.patch
```

BST cache locations on ghost:
- `~/.cache/buildstream/sources/git_repo/gnome_gnome_build_meta.git`
- `~/.cache/buildstream/sources/git_repo/gitlab_freedesktop_sdk_freedesktop_sdk.git`

HTTPS to gitlab.freedesktop.org is broken on ghost (IPv6 unreachable). Always use the BST source cache.

### dconf custom-keybindings list is last-writer-wins

`[org/gnome/settings-daemon/plugins/media-keys] custom-keybindings` is a single dconf value — the last file alphabetically wins and overwrites earlier files.

When adding a new keyfile that sets `custom-keybindings`, include ALL entries from lower-numbered files too.

Verify on NUC:
```bash
dconf read /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
# Must list ALL keybindings from all keyfiles
```

---

## Cross-References

| Skill | When |
|---|---|
| `dakota-testlab` | Active build/publish/bootc upgrade loop |
| `dakota-local-ota` | QEMU VM variant — no physical hardware needed |
| `dakota-ci` | GHCR publish pipeline, what happens after local validation |
