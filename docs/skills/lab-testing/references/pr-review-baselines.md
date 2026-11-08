# Lab Testing — Baseline vs Delta PR Review Methodology

Detailed worked examples referenced from [`../SKILL.md`](../SKILL.md). Use this when reviewing a PR that touches systemd units, timers, or other system state and you need to distinguish pre-existing behavior from the PR's actual delta.

## Contents

- [Baseline vs delta methodology for PR review](#baseline-vs-delta-methodology-for-pr-review)

---

## Baseline vs delta methodology for PR review

> Moved from `pr-review.md` on 2026-06-24. The baseline-vs-delta methodology and worked examples live here because they require lab infrastructure context.

**Always establish a baseline before the PR merges.** Boot the current testing image, record the state of the units/files the PR touches, then re-verify after rebuild. This catches unintended regressions and confirms all new artifacts landed.

**Step 1 — collect baseline** (pre-merge, on current testing image):

```bash
# For a systemd unit PR — capture current state of every touched unit/file
systemctl cat uupd.timer 2>/dev/null || echo "MISSING"
systemctl cat uupd.service 2>/dev/null || echo "MISSING"
cat /usr/lib/systemd/system/uupd.service.d/10-bluefin.conf 2>/dev/null || echo "MISSING"
cat /usr/lib/udev/rules.d/99-uupd-on-ac.rules 2>/dev/null || echo "MISSING"
systemctl cat uupd-on-ac.service 2>/dev/null || echo "MISSING"
```

**Step 2 — merge PR, wait for rebuild** (`bluefin:testing` rebuilds automatically on push to main)

**Step 3 — verify delta** (post-merge, on new testing image):

```bash
# Confirm every expected artifact is present and has the right content
systemctl cat uupd.timer          # check OnCalendar value
systemctl cat uupd.service        # should still be static (no [Install])
systemctl is-enabled uupd.timer   # should still be enabled
cat /usr/lib/systemd/system/uupd.service.d/10-bluefin.conf  # new drop-in
cat /usr/lib/udev/rules.d/99-uupd-on-ac.rules               # new udev rule
systemctl cat uupd-on-ac.service                             # new unit
```

### Worked example — PR #768 (uupd AC-aware scheduling)

**Baseline state** (bluefin:testing before PR, workflow `pr768-uupd-baseline-lxknq`):

| Artifact | Baseline state |
|---|---|
| `uupd.timer` | **Exists** — daily at 04:00, `Persistent=true`, `RandomizedDelaySec=15m` |
| `uupd.service` | Exists, static (no `[Install]`), timer-driven — correct |
| `uupd.service.d/10-bluefin.conf` | **MISSING** — PR adds it |
| `99-uupd-on-ac.rules` | **MISSING** — PR adds it |
| `uupd-on-ac.service` | **MISSING** — PR adds it |
| `uupd-manual.service` | Exists, untouched by PR |
| `ConditionACPower=` on uupd.service | **Absent** — drop-in adds it |

PR #768 **replaces** the existing daily timer with a 6h schedule — this is a deliberate behavior change, not an error. Knowing the baseline prevents false-alarming on "timer changed".

**Post-merge verification checklist for PR #768:**

```bash
# 1. Timer fires every 6h
systemctl cat uupd.timer | grep OnCalendar
# expected: OnCalendar=*-*-* 00,06,12,18:00

# 2. Drop-in adds ConditionACPower
cat /usr/lib/systemd/system/uupd.service.d/10-bluefin.conf | grep ConditionACPower
# expected: ConditionACPower=true

# 3. udev rule present
ls -la /usr/lib/udev/rules.d/99-uupd-on-ac.rules

# 4. AC-triggered unit present
systemctl cat uupd-on-ac.service

# 5. Timer still enabled, uupd.service still static
systemctl is-enabled uupd.timer       # enabled
systemctl cat uupd.service | grep '\[Install\]'  # should be absent (timer-driven)
```

### Worked example — PR #767 (flatpak appstream every-boot)

**Baseline state** (bluefin:testing, 3 workflows, all Succeeded):

| Artifact | Baseline state |
|---|---|
| `flatpak-appstream-firstboot.service` | Exists, unit file matches pre-PR content |
| `systemctl is-enabled flatpak-appstream-firstboot.service` | **`disabled`** — no want symlink anywhere |
| Journal for the service | `-- No entries --` — never ran at boot |
| `ConditionPathExists=!/var/lib/flatpak/.appstream-refreshed` | Present (firstboot guard, PR removes it) |
| `ExecStartPost=/bin/touch ...` | Present (flag file creator, PR removes it) |
| `StartLimitBurst=3` location | In `[Service]` — misplaced (PR correctly moves to `[Unit]`) |
| `/var/lib/flatpak/.appstream-refreshed` flag file | Absent (fresh VM — correct) |
| Preset `02-flatpak-appstream-firstboot.preset` | In repo source, but **not yet active** in this image build |

**Critical finding:** The service is **disabled** in the current testing image. The preset file exists in the repo but the image was built before it merged — so neither the old firstboot-only behavior nor the new every-boot behavior is active or verifiable yet. A clean lab boot here produces no journal output and no failures, but it is entirely a no-op — not a green signal.

**Open question for PR author:** Is the preset landing in the same PR? If not, the every-boot behavior won't activate until a subsequent build includes the preset.

**Post-merge verification checklist for PR #767** (requires a rebuilt image that includes the preset):

```bash
# 1. Service is now enabled
systemctl is-enabled flatpak-appstream-firstboot.service
# expected: enabled

# 2. Firstboot guard removed — no ConditionPathExists line
systemctl cat flatpak-appstream-firstboot.service | grep ConditionPathExists
# expected: no output

# 3. StartLimitBurst in [Unit] not [Service]
systemctl cat flatpak-appstream-firstboot.service
# expected: StartLimitBurst=3 appears after [Unit] header, not after [Service] header

# 4. WantedBy target confirmed (verify graphical.target issue was addressed)
systemctl cat flatpak-appstream-firstboot.service | grep WantedBy
# expected: WantedBy=multi-user.target

# 5. Service ran this boot
journalctl -u flatpak-appstream-firstboot.service -b
# expected: entries showing appstream refresh

# 6. No flag file created (every-boot, not one-shot)
ls /var/lib/flatpak/.appstream-refreshed 2>/dev/null && echo "EXISTS" || echo "absent (correct)"
# expected: absent (correct)
```

---
