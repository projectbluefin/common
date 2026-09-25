# eSCL scanner fixture

A hardware-free eSCL scanner that CI can start, scan from, and tear down.

The fixture is a container image that pairs two upstream projects:

| Piece | Role |
|---|---|
| [OpenPrinting/go-mfp](https://github.com/OpenPrinting/go-mfp) `cmd/mfp-virtual` | The virtual MFP simulator: serves eSCL over HTTP and can advertise over DNS-SD |
| [sane-airscan](https://github.com/alexpevzner/sane-airscan) + `sane-utils` | The real client: the `airscan` SANE backend and the `scanimage` frontend |

Nothing here emulates a client. `scanimage` is the same binary a user runs
against a physical scanner, and it reaches the simulator through the
unmodified `airscan` backend.

## Why

`projectbluefin/common` ships scanner-adjacent configuration but has no way to
exercise driverless scanning without physical hardware. This fixture gives CI
a deterministic eSCL endpoint so scanner changes can be tested before they
reach an image.

## Running it

```bash
docker build -f tests/fixtures/escl-scanner/Containerfile --tag escl-fixture tests/fixtures/escl-scanner

# Acceptance gate: detect the scanner, capture the page twice, compare.
docker run --rm escl-fixture --mode capture

# Discovery: find the scanner over DNS-SD with no pinned device URL.
docker run --rm escl-fixture --mode dnssd
```

Both modes exit non-zero with a diagnosis on failure; the simulator's log is
dumped automatically when a step fails.

## What `--mode capture` asserts

1. `scanimage -L` — the real SANE frontend, through the `airscan` backend,
   lists the virtual scanner. This is the "detects it" half.
2. Two platen scans at 600 DPI in color produce **byte-identical** PNGs. This
   is the "deterministic synthetic page" half.
3. Both captures are valid PNGs whose IHDR geometry matches the model's
   platen aspect ratio (2550:3508 in eSCL's 1/300 inch units), so a capture
   that silently fell back to a default scan region is caught.
4. The capture is above a small size floor, which catches truncation.

## What `--mode dnssd` asserts

`airscan-discover` finds the scanner by DNS-SD alone. The simulator publishes
a `_uscan._tcp` record and the client resolves it through avahi; no device URL
is passed in, and `SANE_AIRSCAN_DEVICE` is explicitly unset so the mode cannot
pass by accident.

## Design notes

**The capture gate pins the device URL.** `run-fixture.sh` sets
`SANE_AIRSCAN_DEVICE=escl:<name>:<url>` for the capture mode. That is a
documented sane-airscan feature — the same mechanism `mfp-virtual` itself
uses when it runs a child command — and it keeps the acceptance gate off
multicast networking. Real discovery is covered separately by `--mode dnssd`.

**Geometry is checked by aspect ratio, not by exact pixel count.** The page
go-mfp embeds is exactly 5100x7016, but the scan region `scanimage` requests
by default is sane-airscan's choice, and its millimetre/pixel rounding is an
implementation detail of the installed version. Pinning an exact pixel count
would make the fixture fail on a client upgrade that changed nothing about
the simulator, so the assertion is on the platen's aspect ratio instead.

**Scanning at 600 DPI is a 1:1 copy.** The simulator's virtual scanner reports
600x600 DPI and holds a 5100x7016 page, so a 600 DPI full-platen scan is the
embedded page without resampling.

## Pinned versions

The Containerfile pins both base images by digest and the go-mfp checkout by
commit SHA. `.github/renovate.json5` does not manage this file, so these are
manual bumps. When bumping `GO_MFP_SHA`, re-check the model file against
`modeling/escl.py` and `modeling/keyword.go` upstream — the model's field
names are matched case-insensitively against the Go struct fields.

## Scope and limits

- **No hardware.** Nothing here has been run against a physical scanner, and
  nothing here should be read as evidence about real device behaviour.
- **Not a scanner application.** This is a test fixture only. It is not
  published as an image, not part of the `common` OCI layer, and not wired
  into any `ujust` recipe.
- **DNS-SD is exercised but non-gating.** See the comment on the DNS-SD step
  in `.github/workflows/escl-fixture.yml`.

## Tests

`tests/test_escl_fixture.bats` covers the orchestration logic in
`run-fixture.sh` — readiness probing, device-name parsing, and each assertion
path — with the simulator, `curl`, and `scanimage` replaced by stubs. The
container build itself is covered by the workflow, not by bats.
