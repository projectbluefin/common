---
title: "Post-Merge E2E CI: Regression Testing Architecture"
load_when: "Debugging E2E test failures, adding new regression tests, or understanding CI pipeline"
categories: ["ci", "testing", "qa"]
---

# Post-Merge E2E CI — Regression Testing Architecture

Load when: Debugging E2E CI failures, adding regression tests, or understanding the testing pipeline.

## Quick start

```
Every merge to main in common:
  ├─ Trigger: GitHub webhook
  ├─ Target: testing-lab Argo Workflow
  ├─ Suites:
  │  ├─ smoke (GNOME Shell, Activities)
  │  ├─ developer (toolbox, podman, brew)
  │  └─ system (atomic OS contract)
  ├─ Platforms: Bluefin latest + LTS
  └─ Result: Pass/fail comment on commit + issue closure if fixed
```

## Architecture Overview

```
projectbluefin/common (PR merged to main)
        │
        ├─ GitHub webhook triggers
        ├─ testing-lab Argo Workflow captured
        │
        └─→ argo/bluefin-test-matrix.yaml (two-platform test)
            ├─ Platform 1: Latest Fedora (dakotastream)
            ├─ Platform 2: CentOS Stream 10 (LTS)
            │
            ├─ Phase 1: Golden Path Smoke (GNOME Shell, Activities)
            ├─ Phase 2: Developer Tooling (terminal, brew, podman)
            └─ Phase 3: Software Management (Flatpak, GNOME Software)
            
Results:
  ├─ Comment on commit in common
  ├─ Dashboard updated (queue.projectbluefin.io)
  └─ If fixes bonedigger issue → auto-close + verify
```

## Test Phases

The common E2E suite runs in three phases:

### Phase 1: Golden Path Smoke (Every merge)

**What it tests**: GNOME Shell basics — can the desktop boot and respond?

```
Golden path smoke:
├─ Boot from bootc image (Fedora latest + LTS)
├─ Desktop session starts (GNOME Shell)
├─ Activities overview opens
├─ Activities search works
├─ Application launcher functional
└─ Wallpaper loads correctly
```

**Where**: `tests/common/features/smoke/`

**Typical duration**: 3–5 minutes per platform (6–10 min total)

**Failures**: If smoke fails, subsequent phases don't run (stop fast).

### Phase 2: Developer Tooling (Merge + targeted validation)

**What it tests**: CLI developer experience

```
Developer tooling:
├─ toolbox create + list
├─ podman run (hello-world)
├─ brew install (small package)
├─ ujust list (recipes accessible)
├─ Terminal emulator launches
└─ Text editor (micro) works
```

**Where**: `tests/common/features/developer/`

**Typical duration**: 8–12 minutes per platform

**Triggered on**: Merge to main OR PR with `[test-developer]` tag

### Phase 3: Software Management (Targeted validation)

**What it tests**: Flatpak and application installation

```
Software management:
├─ Flatpak system repo initialized
├─ Install from Flathub (e.g., GNOME Circle apps)
├─ Flatpak permissions model
├─ GNOME Software app functional
├─ Application launcher integration
└─ Flatpak data directory cleanup
```

**Where**: `tests/common/features/software/`

**Triggered on**: PR with `[test-software]` tag or merge affecting Flatpak configs

## Platforms Under Test

### Latest (Cutting Edge)

```
Base: Latest Fedora (rawhide or latest released)
Builder: BIB (Fedora Container Initiative)
Image: ghcr.io/projectbluefin/bluefin:latest

Coverage: Latest dependency versions
         Latest GNOME Shell
         Experimental features
```

### LTS (Long-Term Support)

```
Base: CentOS Stream 10 (RHEL-based)
Builder: BIB (bootc native)
Image: ghcr.io/projectbluefin/bluefin:lts

Coverage: Stable dependency versions
         GNOME version compatible with RHEL
         Extended support scenario
```

## Browser Tools Masking in CI

**Problem**: `brew` and `flatpak` download tools (browser cache, store CDN) can fail in CI environments, causing false negatives.

**Solution**: Common masks these tools during E2E to avoid flaky failures:

```yaml
# During E2E on common suite:
- brew install ...   # mocked or timeout-tolerant
- flatpak install    # retried with backoff
- curl/wget          # requests blocked; use local mirrors
```

**How to work around it locally**:

```bash
# If E2E passes in lab but fails in CI:
# 1. Ensure offline mode in CI workflows
# 2. Use local package mirrors
# 3. Mock external tools

# See: testing-lab/docs/lab-operations.md for details
```

## MOTD Fix & Known Issues

### MOTD (Message of the Day) Failures

The MOTD script sometimes fails in E2E because:

1. **Dynamic content**: MOTD fetches live data (network in sandbox)
2. **Locale issues**: Test VM locale may differ from expected

**Workaround**:

```bash
# In your feature file, skip MOTD validation:
When I do not check the MOTD (it may contain dynamic content)
```

### Quarantined Scenarios

Some tests are known-failing and temporarily quarantined:

| Scenario | Status | Reason | Issue |
|----------|--------|--------|-------|
| Wayland on NVIDIA | 🟡 Skipped | Driver interaction | upstream-tracking |
| TPM unlock | 🟡 Skipped | Requires hardware | #512 |
| iCloud syncing | 🟡 Skipped | Needs macOS server | feature-request |

**Check the mark**: Before adding a new test, see `.skipped_scenarios.yml` in testing-lab.

## CI Failure Troubleshooting

### "smoke phase failed: Activities overlay didn't open"

**Likely cause**: Dogtail (AT-SPI) can't access the desktop accessibility tree.

**Fix**:
```bash
# 1. Check if Wayland is causing issues
grep "GDK_BACKEND" test-output.log

# 2. Force X11 or Wayland specifically in Argo Workflow:
env:
  - name: GDK_BACKEND
    value: "x11"  # or "wayland"

# 3. If still failing, check testing-lab/docs/dogtail-testing.md
```

### "developer phase timeout: podman run took >5min"

**Likely cause**: Container image pull stalled or runner overloaded.

**Fix**:
```bash
# 1. Check if testing-lab runner is healthy
gh workflow list -R projectbluefin/testing-lab | grep runner-status

# 2. Add timeout tolerance:
Given a timeout of 10 minutes
When I run podman run hello-world
Then it should complete within the timeout

# 3. If podman itself is slow, update test expectations:
# See: testing-lab/tests/common/features/developer/podman.feature
```

### "software phase failed: Flatpak install rate-limited"

**Likely cause**: Flathub CDN rate limiting or network saturation.

**Fix**:
```bash
# 1. Use offline/mocked Flatpak repo
# See: testing-lab/containers/registry-mirrors.yaml

# 2. If changing Flatpak config in common, note in PR:
# "Flatpak tests may timeout in CI due to CDN; locally passing."

# 3. Maintainers can force-merge with:
# /lgtm override-ci-flatpak-timeout
```

## Integration with bonedigger

When bonedigger issues are fixed:

```
Issue #999 filed via ujust report (e.g., "GNOME crashes")
    ↓
P1 triage (3+ confirms)
    ↓
Developer fixes + PR #1234
    ↓
PR merges to main
    ↓
E2E smoke tests run (golden path)
    ↓
If smoke passes AND issue is in smoke suite → bonedigger notices
    ↓
bonedigger checks if new image digest differs from issue's digest
    ↓
If fixed → auto-close issue, ask users to ujust verify
```

See [hive-review](./hive-review.md) for the full loop.

## Integration with Regression Contract

The E2E suite validates the [REGRESSION_CONTRACT](../qa/REGRESSION_CONTRACT.md):

- **Tier 1 tests** (golden path smoke) validate bootc composition
- **Tier 2 tests** (developer tooling) validate Tier 2 contract items
- **Tier 3+ tests** (platform-specific) validate stream-specific feature parity

If a feature is added to the regression contract, a corresponding test must be added to one of these phases.

## Adding New Tests

### Step 1: Choose the right phase

```
New test?
├─ GNOME Shell, Activities, basic desktop?
│  └─ Add to Phase 1 (smoke)
├─ Dev tool (podman, toolbox, brew)?
│  └─ Add to Phase 2 (developer)
└─ Flatpak, app installation, software?
   └─ Add to Phase 3 (software)
```

### Step 2: Write the feature file

```gherkin
# tests/common/features/developer/my-new-test.feature
Feature: My new developer tool

  Scenario: Tool installs and runs
    Given I have a terminal
    When I run "my-tool --version"
    Then it should return successfully
```

### Step 3: Implement step definitions

```python
# tests/common/steps/my_new_tool.py
@when('I run "{cmd}"')
def step_run_cmd(context, cmd):
    context.result = subprocess.run(cmd, shell=True, capture_output=True)
```

### Step 4: Submit PR with `[test-<phase>]` tag

```
PR title: feat(tooling): add my-new-tool
          [test-developer]
```

This triggers the developer phase during PR validation.

### Step 5: Wait for E2E + merge

Once both platforms pass, merge.

## Integration with Trail of Bits CI

The skill-drift CI validates that this documentation stays in sync with CI changes:

- **Code changes**: When CI workflows or test definitions change, this guide must update
- **Trigger**: On every PR, `skill-drift-check.yml` compares code changes to skill updates
- **Enforcement**: If CI changes without skill updates, the check fails
- **Waiver**: Note in PR if no skill update is needed

See [skill-drift documentation](./SKILL_DRIFT_CI.md) for handling failures.

## Key files

```
projectbluefin/common
├─ .github/workflows/
│  └─ (no E2E workflows here; testing-lab owns them)

projectbluefin/testing-lab
├─ argo/bluefin-test-matrix.yaml        Two-platform E2E orchestration
├─ tests/common/features/                Shared feature definitions
│  ├─ smoke/
│  ├─ developer/
│  └─ software/
├─ tests/common/steps/                   Step implementations
└─ docs/dogtail-testing.md               GUI test authoring guide
```

## See also

- [hive-review](./hive-review.md) — Issue prioritization; triage feeds test selection
- [queue-dashboard](./queue-dashboard.md) — PR merge gating on CI status
- [REGRESSION_CONTRACT](../qa/REGRESSION_CONTRACT.md) — Test scope by stream
- [testing-lab RUNBOOK](https://github.com/projectbluefin/testing-lab/blob/main/RUNBOOK.md) — Complete CI/lab architecture
