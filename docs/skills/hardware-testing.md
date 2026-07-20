---
name: hardware-testing
version: "1.0"
last_updated: "2026-07-20"
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

File a **Hardware test report** issue in `projectbluefin/common` using `.github/ISSUE_TEMPLATE/hardware-test-report.yml`.
Include:

- exact image digest or tag tested
- hardware make/model/generation
- test date
- pass/fail/untested status for all 7 categories
- pstore/kdump evidence, pasted inline or linked
- severity: `all-clear`, `degraded`, or `blocker`

The template adds `hardware/test-report` and `source:manual` automatically. Maintainers can add `hardware/all-clear` or `hardware/blocker` after triage.

## Promotion policy

A candidate should **not** be promoted while there is an open `hardware/blocker` issue for that candidate digest or tag.
A degraded report is signal, but not an automatic stop unless triage upgrades it to a blocker.
An all-clear report should be labeled `hardware/all-clear` so the candidate has explicit real-hardware evidence in the queue.

Find open blockers with:

```bash
gh search issues --label "hardware/blocker" --owner projectbluefin --state open
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
- Lifecycle workflow: [`.github/workflows/lifecycle.yml`](../.github/workflows/lifecycle.yml)
- Lifecycle background: [`docs/skills/governance.md`](./governance.md)

Real hardware testing does not replace CI. It closes the visibility gap for bug classes that CI running in VMs cannot see.
