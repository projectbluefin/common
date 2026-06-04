# knuckle-release — Release E2E & Tagging Skill

End-to-end release procedure for `projectbluefin/knuckle`. Covers the full
verification chain from unit tests → VM installs → ISO smoke → tag → asset
audit.

Load with: `cat ~/src/skills/knuckle-release/SKILL.md`

## When to Use

- Cutting any knuckle release (`v0.X.Y`)
- Running the full pre-release E2E gate
- Verifying a release has all expected assets
- Diagnosing missing arm64 artifacts

## When NOT to Use

- Per-PR QA review → use `knuckle-qa` skill
- Ghost infra setup → use `ghost-testlab` skill

## Powerlevel

- **Level:** 4

---

## Release Asset Inventory (expected: 16 total)

Each release must ship **8 × amd64 + 8 × arm64**:

| Asset | ×amd64 | ×arm64 |
|---|---|---|
| `knuckle-linux-<arch>` | ✅ | ✅ |
| `knuckle-linux-<arch>.sha256` | ✅ | ✅ |
| `knuckle-linux-<arch>.spdx.json` | ✅ | ✅ |
| `knuckle-linux-<arch>.spdx.json.bundle` | ✅ | ✅ |
| `knuckle-installer-stable-<arch>.iso` | ✅ | ✅ |
| `knuckle-installer-stable-<arch>.iso.sha256` | ✅ | ✅ |
| `knuckle-installer-stable-<arch>.iso.bundle` | ✅ | ✅ |
| `knuckle-linux-<arch>.bundle` | ✅ | ✅ |

```bash
# Audit asset count after release publishes
gh release view vX.Y.Z --repo projectbluefin/knuckle --json assets \
  --jq '.assets | map(.name) | sort | .[]'
# Must be exactly 16 lines.
```

---

## Full E2E Gate (run before every tag)

### Step 1 — Unit + CI gate

```bash
cd ~/src/knuckle
git checkout main && git pull upstream main
just ci
```

All checks must pass. If `cmd/knuckle` TTY tests fail, that's pre-existing
infra issue #512 — does NOT block release. All other failures block.

### Step 2 — Catalog + NVIDIA check

```bash
just release-preflight
```

Runs: `just ci` + sysext catalog coverage check + NVIDIA driver series check.
Must exit 0.

### Step 3 — VM e2e (amd64, ghost)

**Run all 4 automated passes.** Each pass installs Flatcar headlessly via
`knuckle --headless`, boots the installed system, and SSH-verifies assertions.

```bash
# On ghost (required — needs KVM + Flatcar base image):
ssh jorge@192.168.1.102 "cd ~/src/knuckle && just vm-e2e"
```

Or from dev machine with `QA_HOST` set:

```bash
QA_HOST=jorge@192.168.1.102 just vm-e2e
```

| Pass | Config | Key assertion |
|---|---|---|
| DHCP | DHCP + hostname + update groups | hostname, locksmith enabled |
| Static | Static IP 10.0.2.15/24 | `/etc/systemd/network/10-static.network` |
| Sysext | DHCP + docker sysext | `/etc/extensions/docker.raw` present, `docker version` |
| NVIDIA | DHCP + NVIDIA config | `/etc/sysupdate.d/nv-*.conf` present |

All 4 passes must exit 0. Any FAIL blocks the release.

### Step 4 — amd64 ISO smoke (headless)

```bash
just build
just iso   # builds output/knuckle-installer-stable-amd64.iso

# Run headless serial-log smoke test (no display needed):
OVMF=$(ls /usr/share/OVMF/OVMF_CODE*.fd /usr/share/edk2/ovmf/OVMF_CODE*.fd 2>/dev/null | head -1)
just iso-smoke output/knuckle-installer-stable-amd64.iso "$OVMF" 120
```

Pass criteria (checked by `scripts/iso-smoke.sh`):
- `initrd-root-device.target`, `initrd-usr-fs.target`, `getty.target` appear in serial log
- Zero `xd2root` / `x2dauto` / `dracut.*skip` errors
- `systemd.gpt_auto=0` present on both BLS entries

### Step 5 — arm64 ISO smoke (TCG, ghost)

No native KVM on ghost for arm64 — uses TCG (software emulation). Too slow for
CI; run manually before tagging.

```bash
# On ghost:
ssh jorge@192.168.1.102 bash << 'EOF'
cd ~/src/knuckle
# Build arm64 ISO
KNUCKLE_ARCH=arm64 just build
KNUCKLE_ARCH=arm64 just iso

AAVMF=$(ls /usr/share/AAVMF/AAVMF_CODE.fd /usr/share/qemu-efi-aarch64/QEMU_EFI.fd 2>/dev/null | head -1)
if [ -z "$AAVMF" ]; then
  echo "⚠️ No AAVMF found — install qemu-efi-aarch64 or AAVMF package"
  exit 1
fi

# Boot arm64 ISO headlessly (TCG — allow 5 min, systemd-boot+dracut is slow)
timeout 300 qemu-system-aarch64 \
  -M virt -cpu cortex-a57 -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file="$AAVMF" \
  -cdrom output/knuckle-installer-stable-arm64.iso \
  -drive if=virtio,file=/tmp/arm64-smoke-target.img,format=raw \
  -nographic 2>&1 | tee /tmp/arm64-iso-smoke.log || true

echo "=== arm64 ISO smoke results ==="
echo "-- dracut errors (must be 0) --"
grep -c "xd2root\|x2dauto\|dracut.*skip" /tmp/arm64-iso-smoke.log || echo 0
echo "-- boot targets (must appear) --"
grep -E "initrd-root-device|initrd-usr-fs|getty.target" /tmp/arm64-iso-smoke.log || echo "NONE FOUND"
EOF
```

**Pass criteria:** same as amd64. Evidence (quoted log excerpt) must be pasted
into the v0.8.0 epic issue before tagging.

---

## Tag & Publish

```bash
# Final state check
git status   # must be clean
git log --oneline -5

# Tag
git tag v0.X.Y
git push upstream v0.X.Y   # triggers release.yml

# Watch the workflow
gh run watch --repo projectbluefin/knuckle
```

The release.yml pipeline (post-PR-#606) runs:
```
create-release ──┬─→ release-amd64 ──┐
                 └─→ release-arm64 ──┴→ publish
```

Both arch jobs run in parallel. `publish` gates on both.

**Do NOT push the same tag twice.** The `publish` job checks for existing
assets and skips duplicates, but the `create-release` step will fail if a
release already exists for that tag.

---

## Post-Release Verification

```bash
# 1. Asset count (must be 16)
gh release view vX.Y.Z --repo projectbluefin/knuckle --json assets \
  --jq '.assets | length'

# 2. Both arch ISOs present
gh release view vX.Y.Z --repo projectbluefin/knuckle --json assets \
  --jq '.assets | map(.name) | map(select(test("arm64|amd64"))) | sort | .[]'

# 3. Cosign bundles present (one per binary/ISO/SBOM)
gh release view vX.Y.Z --repo projectbluefin/knuckle --json assets \
  --jq '.assets | map(select(.name | endswith(".bundle"))) | length'
# Must be 4 (2 per arch: binary + iso)
```

---

## Release Workflow — Known Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| arm64 assets missing | `release-arm64 needs release-amd64` race (pre-PR-#606) | Ensure PR #606 is merged before tagging |
| `Cannot upload asset … to an immutable release` | Tag pushed twice, first run's `publish` made release immutable | Delete the release + tag, fix, re-tag |
| `arm64 build failed` cross-compile | `CGO_ENABLED` not 0 on the arm64 runner | Check `CGO_ENABLED=0` in all arm64 build steps |
| `iso-smoke` hangs forever | Missing `systemd.gpt_auto=0` on BLS entries | Check `scripts/build-iso.sh` — both `knuckle.conf` and `knuckle-serial.conf` must have it |
| OSSF Scorecard skipped on release | `scorecard` job only runs on push to `main`, not tags | Expected — not a blocker |
| Workflow run blocked (first-time contributor) | GitHub holds workflow runs | Approve via `gh api repos/projectbluefin/knuckle/actions/runs?status=action_required` |

---

## v0.8.0 Checklist

Epic: https://github.com/projectbluefin/knuckle/issues/508

- [x] **N-SEC1** — sysext URL max-length guard — already in `bakery.go` (`maxSysextURLLen = 2048` lines 27-31, 193-196)
- [x] **#505** — coverage gates raised — CLOSED
- [x] **#506** — post-merge BATS smoke job — CLOSED
- [x] **#507** — ignition coverage gate 97% — MERGED
- [ ] **Merge PR #606** — parallel arch builds in release.yml (**Jorge merges via UI** — workflow file, cannot auto-merge)
- [ ] **`just ci`** green on main after PR #606 merges
- [ ] **`just vm-e2e`** all 4 passes green (amd64, ghost)
- [ ] **amd64 ISO smoke** — `just iso-smoke` exits 0, no dracut errors
- [ ] **arm64 ISO smoke** — TCG boot on ghost, quoted serial log evidence in epic #508
- [ ] **`just release-preflight`** exits 0
- [ ] Tag `v0.8.0`, push, watch workflow (`git tag v0.8.0 && git push upstream v0.8.0`)
- [ ] Asset audit: exactly 16 assets, both arch ISOs present
- [ ] Close epic #508

---

## Environment Variables (vm-e2e / iso-smoke)

| Variable | Default | Purpose |
|---|---|---|
| `QA_HOST` | `localhost` | Machine where QEMU runs |
| `QA_FLATCAR_BASE` | `/var/tmp/knuckle-test/flatcar_base.img` | Flatcar QEMU image path on QA_HOST |
| `KNUCKLE_ARCH` | `amd64` | Target architecture (`amd64` or `arm64`) |

---

## Lessons Learned

### v0.7.0 — arm64 artifacts missing

Root cause: `release-arm64` had `needs: release-amd64`. On tag retry, first
run's `publish` made the release immutable before arm64 could upload. Fixed in
PR #606 (parallel `create-release` gate). Never tag before this is merged.

### v0.6.2 — ISO boot failure on bare metal

Root cause: `systemd.gpt_auto=0` missing from BLS entries. Bare metal GPT
disks triggered `systemd-gpt-auto-generator` → dracut `xd2root` hook skipped.
Fixed in v0.7.0. `just iso-smoke` now catches this in CI.

### Always run arm64 ISO smoke manually (TCG)

TCG is too slow (~5× real-time) for CI. Ghost has no native arm64 KVM. The
arm64 ISO cross-compiles fine but must be smoke-tested manually on ghost before
tagging. TCG boots take ~5 minutes. Evidence must be in the release epic.

### `just vm-e2e` does NOT test ISO boot

`vm-e2e` deploys the knuckle binary via SSH to a running Flatcar VM. It does
NOT boot from the installer ISO. Use `just iso-smoke` or `just boot-iso` for
ISO boot validation. Both are required for a complete release gate.
