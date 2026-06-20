---
name: udev-rules
description: |
  Convention and prefix taxonomy for udev rules in common.
  Use when: adding a new udev rule, reviewing a PR that touches rules.d/, debugging device access failures, or asking "what prefix should this rule use?"
metadata:
  context7-sources:
    - /bootc-dev/bootc
---

# udev Rules — Prefix Taxonomy and Conventions

## Prefix Allocation

| Range | Purpose | Examples |
|---|---|---|
| `10–19` | Generic catch-all / hard-to-classify | `10-switch.rules` |
| `50–59` | OEM/hardware quirks (device-specific patches) | `50-framework16.rules`, `50-zsa.rules`, `50-steam-horipad-controller.rules` |
| `60–69` | Platform workarounds (kernel/driver patches) | `60-amd-s2idle-fixes.rules`, `60-arduino-mbed.rules` |
| `70–79` | Security / authentication devices | `70-titan-key.rules`, `70-wooting.rules`, `70-u2f.rules` (build-injected) |
| `71–` | **Reserved for build-injected game-devices-udev** — do not use statically |
| `80–89` | Audio / media peripherals | `88-neutron_hifi_dac.rules` |
| `90–99` | Exotic / legacy peripherals | `90-apple-superdrive.rules`, `92-viia.rules` |

## Build-Injected Rules

Two rule sets are fetched and injected by the Containerfile build stage — they are **not** in this source tree:

- `70-u2f.rules` — Yubico U2F rules, downloaded from the Yubico release page (SHA256-verified)
- `71-*.rules` — game-devices-udev rules, downloaded from Codeberg and prefixed `71-` synthetically

**Important:** The `71-` prefix band is occupied by game-devices-udev. Do not add static rules with `71-` prefixes — they will appear to work but may have non-obvious sort-order interactions with the game device rules.

The `70-` band already has static files (`70-titan-key.rules`, `70-wooting.rules`). The build-injected `70-u2f.rules` sorts between them alphabetically. This is currently safe but the `70-` band is full — new security/auth rules should use `72-` or higher within the `70–79` range.

## Access Grant Pattern

All rules in this repo grant per-session device access using:
```
TAG+="uaccess"
```

**Do NOT use `MODE="0666"`** — this grants world-readable/writable access to all users, not just the session user. `TAG+="uaccess"` is the correct mechanism for granting a logged-in user access to a device.

**Do NOT use `GROUP="<groupname>"`** unless the group is guaranteed to exist via a `sysusers.d` entry. Groups that don't exist cause udev to silently fail the assignment.

## Adding a New Rule

1. Choose the appropriate prefix range from the table above
2. Name the file: `<prefix>-<descriptive-name>.rules`
3. Scope rules to specific VID/PID whenever possible — never match on `KERNEL=="hidraw*"` or `SUBSYSTEM=="usb"` alone
4. Use `TAG+="uaccess"` for session-user access grants
5. Add a comment with the upstream reference (PR, issue, or spec URL)

## OEM Hardware Rules

OEM-specific udev rules (Framework, ASUS, etc.) should use the `50-` range. Rules that are written dynamically at runtime by OEM hooks (e.g., the Framework 13 suspend workaround) go to `/etc/udev/rules.d/` on the running system — they are not shipped in this source tree.

---

## When to Use

- Adding a new udev rule file to `system_files/shared/usr/lib/udev/rules.d/`
- Reviewing a PR that adds or modifies rules in that directory
- Choosing a prefix number for a new rule
- Debugging why device access doesn't work for a user
- Auditing rules for security regressions

## When NOT to Use

- Runtime udev rules written by OEM hooks (those go to `/etc/udev/rules.d/` on the deployed system, not here)
- NVIDIA-specific udev rules (those belong in `system_files/nvidia/usr/lib/udev/rules.d/`)
- Questions about udev rule syntax beyond access grants — consult the upstream udev documentation

## Core Process

1. **Choose prefix** — pick the range from the allocation table that matches the device category
2. **Scope the match** — always use `ATTRS{idVendor}` and/or `ATTRS{idProduct}` to limit to specific hardware; never match on `KERNEL=="hidraw*"` alone
3. **Grant access** — use `TAG+="uaccess"` for per-session user access; never `MODE="0666"` or `GROUP=<nonexistent>`
4. **Add provenance comment** — first line: `# <description>`, second line: `# Ref: <upstream URL or PR>`
5. **Check build-injected bands** — confirm your prefix doesn't land in `71-` (reserved for game-devices-udev)
6. **Verify** — run `udevadm test /sys/class/<subsystem>/<device>` on target hardware

## Red Flags

- `MODE="0666"` on any `hidraw*` or `usb` match — grants world-readable/writable access to ALL matching devices, not just the target hardware (shipped as a security regression in `92-viia.rules` before being fixed in this repo)
- `GROUP="<name>"` without a corresponding `sysusers.d` entry — group silently doesn't exist, rule has no effect (was the bug in `10-switch.rules` for the Nintendo Switch jig)
- Rule with no `ATTRS{idVendor}` constraint matching a broad subsystem (`hidraw*`, `usb`) — overly broad, affects unintended devices
- Static file with a `71-` prefix — conflicts with the build-injected game-devices-udev synthetic band
- Rule copied from a StackOverflow answer or debugging session without VID/PID scoping

## Verification

- [ ] Rule is scoped to specific VID/PID (`ATTRS{idVendor}==` present)
- [ ] No `MODE="0666"` — uses `TAG+="uaccess"` instead
- [ ] No `GROUP=` assignment unless `sysusers.d` entry guarantees group exists
- [ ] Prefix falls in the correct range per allocation table; not in `71-`
- [ ] Provenance comment present with upstream reference
- [ ] `udevadm test` verified on target hardware (or noted as untested with reason)
