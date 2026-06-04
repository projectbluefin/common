# E2E CI

## Post-merge E2E

**File:** `.github/workflows/e2e.yml`

- Runs after merges to `main`
- Calls the reusable `projectbluefin/testsuite` E2E workflow with `suites: common`
- Validates the common layer against three downstream images:
  - `ghcr.io/ublue-os/bluefin:latest`
  - `ghcr.io/ublue-os/bluefin:lts`
  - `ghcr.io/projectbluefin/dakota:latest`
- Uses SSH-mode tests from the runner, so the common suite does not require a full GNOME session

## Pre-merge gate

**File:** `.github/workflows/pr-e2e.yml`

- Runs on PRs to `main` and on `merge_group`
- Builds the PR's `common` layer candidate first
- Composes a downstream test image from `ghcr.io/ublue-os/bluefin:latest` by overlaying `/system_files/shared` and `/system_files/bluefin`
- Recompiles GSettings schemas in the composed image
- Pushes the composed image to GHCR and runs the reusable `projectbluefin/testsuite` workflow with `suites: common`

This is the pre-merge gate for common-layer changes, so regressions can fail before merge instead of waiting for post-merge E2E.

## Known CI caveats and quarantines

- `brew-setup.service` is masked in CI, so Homebrew-installed CLI tools are not present unless explicitly provisioned during the job
- `testsuite#210` tracks the `bash -lc` PATH mismatch affecting `zsh`/`fish` checks in the CI user environment
- GNOME Software scenarios are intentionally `@quarantine` after `testsuite#258`; they should not be treated as active software-store coverage
- Bazaar coverage is currently a `@pending` placeholder tied to the same gap
- `ujust report --confirm` scenario (`system_health.feature`) is `@quarantine` — the `--confirm` mode is not implemented in any current image variant; the step skip-detection used the wrong error string. See testsuite PR #259. Re-enable when `report --confirm` lands in the image Justfile.

## Testsuite SHA pin

`run-testsuite.yml` in `projectbluefin/bluefin` pins the testsuite SHA. When the pin lags behind `main`, quarantined scenarios may run and cause spurious failures. Renovate manages the pin automatically once it's set to a SHA (not `@main`). After any testsuite fix merges, approve the Renovate bump PR promptly.
