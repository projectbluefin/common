# Upstream contributions

When Bluefin users report hardware issues, the root cause is sometimes a missing
kernel quirk, firmware fix, or driver patch — something that belongs upstream, not
in our image. This document collects those findings so they can be tracked, submitted
upstream, and optionally applied locally by affected users while waiting for the fix
to land in a shipped Fedora kernel.

**We do not ship these fixes by default.** Shipping device-specific workarounds for
hardware we cannot test causes regressions on machines that don't need them. Instead,
we document the fix here, submit it upstream, and link the tracking issue. Once the
fix lands in a Fedora kernel, the entry is removed.

## How to use this

If you are affected by one of the issues below, apply the workaround manually and
report back in the linked issue so we can track real-world confirmation.

When an upstream patch ships in a Fedora kernel update, open a PR removing the entry
from this file and closing the linked issue.

---

## AMD s2idle — atkbd wakeup prevents PC10/S0i3

**Affects:** AMD laptops where the PS/2 keyboard controller (`i8042`/`atkbd`) is
registered as a wakeup source, preventing the SoC from entering its deepest sleep
state. Symptom on every resume:

```
amd_pmc AMDI000B:00: Last suspend didn't reach deepest state
```

**Upstream fix:** Add the board to `fwbug_list` in
`drivers/platform/x86/amd/pmc/pmc-quirks.c` with `quirk_s2idle_spurious_8042`.
Submit to `platform-driver-x86@vger.kernel.org`, cc `Shyam-sundar.S-k@amd.com`.

**Local workaround:** Create `/etc/udev/rules.d/60-amd-s2idle-fix.rules` containing:

```
ACTION=="add", SUBSYSTEM=="serio", DRIVERS=="atkbd", ATTR{power/wakeup}="disabled"
```

This is safe on all laptops — PS/2 keyboard wakeup is never used on laptop hardware
(wakeup occurs via lid sensor or power button).

### Affected hardware

| Machine | Board (`DMI_BOARD_NAME`) | Tracking issue | Upstream patch | Status |
|---|---|---|---|---|
| HP ZBook Ultra G1a 14 | `8D01` | [bluefin#383](https://github.com/projectbluefin/bluefin/issues/383) | [gist](https://gist.github.com/castrojo/647c8e1c99e54bc146021901b1aebaa8) | awaiting upstream |
