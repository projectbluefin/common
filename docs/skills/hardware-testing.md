---
name: hardware-testing
version: "1.1"
last_updated: "2026-09-25"
id: hardware-testing
one_line_purpose: File hardware test reports and apply promotion policy.
entry_point: docs/skills/hardware-testing.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [hardware, testing, promotion]
description: >-
  Hardware test report format and promotion policy. Use when filing a hardware
  test report, triaging hardware blockers, or deciding whether a candidate is
  safe to promote.
metadata:
  type: runbook
---

# Hardware testing in the factory loop

VM gates are necessary, but they cannot validate several bug classes that only show up on physical devices. The factory loop now treats community hardware reports as promotion input, not anecdote.

## The 7 hardware-only categories

1. **Suspend / resume** — sleep, wake, resume panics, lost devices, wake failures
2. **USB-C / docks / alt-mode** — dock enumeration, display output, power delivery, device reconnects
3. **GPU power management / display hotplug** — panel wake, external monitor attach/detach, power-state bugs
4. **Wi-Fi / Bluetooth / firmware** — `iwlwifi`, `btusb`, firmware load, reconnect, radio regressions
5. **TPM / Secure Boot / disk unlock edge cases** — measured boot, unlock prompts, firmware-specific paths
6. **Audio / webcam / microphone** — codec, mic routing, webcam enumeration, mute state, capture/playback
7. **Battery / thermals / ACPI platform behavior** — charge state, thermals, fan behavior, ACPI quirks

These are poor fits for KubeVirt and other VM-only gates because they depend on real firmware, buses, power states, radios, sensors, docks, and platform ACPI behavior.

## Report path

File an issue in `projectbluefin/common` using the repository issue form and
select **Hardware test result**. Include:

- exact image digest or tag tested
- hardware make/model/generation
- test date
- pass/fail/untested status for all 7 categories
- pstore/kdump evidence, pasted inline or linked
- severity: `all-clear`, `degraded`, or `blocker`

The form applies `1-triage`. Maintainers record the outcome — all-clear, degraded,
or blocker — in the issue itself during triage.

## Promotion policy

A candidate should **not** be promoted while there is an open hardware blocker
report for that candidate digest or tag. A degraded report is signal, but not an
automatic stop unless triage upgrades it to a blocker.

Find open hardware reports with:

```bash
gh search issues --owner projectbluefin --state open "hardware test result"
```

When possible, include the candidate digest in the issue title or body so blocker searches and promotion review stay unambiguous.

## Evidence guidance

If the system panics, hangs, or hard-resets during hardware testing, attach crash evidence instead of summarizing from memory:

- Fedora kdump quick docs: <https://docs.fedoraproject.org/en-US/quick-docs/kernel-crash-dump-kdump/>
- Linux kernel pstore guide: <https://www.kernel.org/doc/html/latest/admin-guide/pstore.html>

A short pstore snippet, kdump backtrace, or gist link is enough to connect a report to a real kernel failure.

## Factory integration

Hardware test reports enter the factory lifecycle queue and become promotion input once triaged.

- Lifecycle: [`docs/skills/label-workflow.md`](./label-workflow.md)
- Lifecycle background: [`docs/skills/governance.md`](./governance.md)

Real hardware testing does not replace CI. It closes the visibility gap for bug classes that CI running in VMs cannot see.

## Printer and scanner inventory evidence

Before proposing driver images, consult the
[printer and scanner source inventory](../printer-scanner-inventory.md). Record
the inspected release or commit, upstream owner, source license, and whether
the code is a driver, bridge, framework, demo, or virtual fixture. A maintained
wrapper does not establish maintenance of every bundled legacy driver.

Keep source readiness, container smoke tests, synthetic protocol tests, and
physical device results separate. In particular, a print application or a
successful virtual scan does not establish scanner hardware support. Mark
untested USB ownership, hotplug, platen, ADF and duplex behavior explicitly;
record the backend, model, transport and firmware/plugin requirements when
hardware becomes available. Recheck open upstream scanning work before changing
its status from experimental to supported.
