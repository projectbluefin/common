---
name: scanner-fixture
version: "1.0"
last_updated: "2026-09-25"
id: scanner-fixture
one_line_purpose: Test driverless scanning in CI without a physical scanner.
entry_point: docs/skills/scanner-fixture/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [testing, scanner, escl, airscan, container]
description: >-
  Hardware-free eSCL scanner fixture for common. Use when testing
  driverless scanning, sane-airscan, or eSCL/DNS-SD discovery without a
  physical scanner.
metadata:
  type: reference
---

# Scanner Fixture

## When to Use

Use when you need to exercise driverless scanning — eSCL/AirScan, the
`sane-airscan` backend, or `_uscan._tcp` DNS-SD discovery — without physical
hardware, or when a change touches scanner configuration and you want a
deterministic client-visible check.

## When Not to Use

Do not use this skill for hardware validation: the fixture says nothing about
real device behaviour. Physical scanner results go through
[`../hardware-testing.md`](../hardware-testing.md) and are reported as
unverified here. For general shell-script testing conventions, see
[`../shell-scripts/SKILL.md`](../shell-scripts/SKILL.md).

## What It Is

`tests/fixtures/escl-scanner/` is a container image pairing two upstream
projects:

| Piece | Role |
|---|---|
| [OpenPrinting/go-mfp](https://github.com/OpenPrinting/go-mfp) `cmd/mfp-virtual` | Virtual MFP simulator: serves eSCL over HTTP, can advertise over DNS-SD |
| `sane-airscan` + `sane-utils` | The real client: the `airscan` SANE backend and the `scanimage` frontend |

Nothing emulates the client. `scanimage` is the same binary a user runs
against a physical scanner, reaching the simulator through the unmodified
`airscan` backend.

## Running It

```bash
docker build --tag escl-fixture tests/fixtures/escl-scanner
docker run --rm escl-fixture --mode capture   # acceptance gate
docker run --rm escl-fixture --mode dnssd     # discovery
```

Both modes exit non-zero with a diagnosis on failure; the simulator's log is
dumped automatically when a step fails.

## Modes

**`--mode capture`** is the gate. It asserts:

1. `scanimage -L` lists the virtual scanner — the "detects it" half.
2. Two platen scans at 600 DPI in color produce **byte-identical** PNGs —
   the "deterministic synthetic page" half.
3. Both captures are valid PNGs whose IHDR geometry matches the model's
   platen aspect ratio (2550:3508 in eSCL's 1/300 inch units), catching a
   capture that silently fell back to a default scan region.
4. The capture is above a small size floor, catching truncation.

**`--mode dnssd`** asserts `airscan-discover` finds the scanner by DNS-SD
alone. `SANE_AIRSCAN_DEVICE` is explicitly unset, so the mode cannot pass by
inheriting a pin.

## Gotchas

**Geometry is asserted by aspect ratio, not exact pixels.** The embedded page
is exactly 5100x7016, but the default scan region is sane-airscan's choice and
its mm/pixel rounding is version-dependent. Pinning an exact pixel count would
fail the fixture on a client upgrade that changed nothing about the simulator.

**The capture gate pins the device URL.** `run-fixture.sh` sets
`SANE_AIRSCAN_DEVICE=escl:<name>:<url>`, a documented sane-airscan feature and
the same mechanism `mfp-virtual` uses for child commands. This keeps the gate
off multicast networking; real discovery is covered by `--mode dnssd`.

**600 DPI is a 1:1 copy.** The virtual scanner reports 600x600 DPI and holds a
5100x7016 page, so a full-platen 600 DPI scan is the embedded page without
resampling.

**Liveness needs `jobs -r`, not `kill -0`.** An exited child stays a zombie
until reaped, and the PID remains signalable, so `kill -0` reports a crashed
simulator as alive and the readiness loop spins to its timeout. `server_running()`
uses `jobs -rp`; keep it that way when editing the script.

**Teardown escalates SIGTERM to SIGKILL.** A simulator that ignores SIGTERM
would otherwise hang teardown and leave the CI job waiting on it.

## Pinned Versions

The Containerfile pins both base images by digest and the go-mfp checkout by
commit SHA. `.github/renovate.json5` does not manage this file, so bumps are
manual. When bumping `GO_MFP_SHA`, re-check the model file against
`modeling/escl.py` and `modeling/keyword.go` upstream: the model's field names
are matched case-insensitively against the Go struct fields.

## Scope and Limits

- **No hardware.** Nothing here has run against a physical scanner; nothing
  here is evidence about real device behaviour.
- **Not a scanner application.** A test fixture only — not published as an
  image, not part of the `common` OCI layer, not wired into any `ujust`
  recipe.
- **DNS-SD is non-gating in CI.** `escl-fixture.yml` runs the DNS-SD step with
  `continue-on-error: true` because in-container dbus/avahi is the one part
  not validated outside CI. Remove it once a green run confirms it.

## Tests

`tests/test_escl_fixture.bats` covers the orchestration logic in
`run-fixture.sh` — readiness probing, device-name parsing, and every
assertion path — with the simulator, `curl`, and `scanimage` replaced by
stubs, so it runs anywhere with no container runtime. The container build
itself is covered by `.github/workflows/escl-fixture.yml`, not by bats.

Every external command is overridable through the environment
(`MFP_VIRTUAL`, `SCANIMAGE`, `CURL`, `AIRSCAN_DISCOVER`, `DBUS_DAEMON`,
`AVAHI_DAEMON`). Keep that property: it is what makes the script testable
without the image.
