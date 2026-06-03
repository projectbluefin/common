# Promotion Gates — Testing→Stable Release Pipeline

This document defines the automated gates and integration points that control promotion from `testing` to `stable` release channels in Project Bluefin.

## Overview

The Bluefin-LTS release pipeline follows a staged promotion model:

```
main branch
    ↓
[nightly builds on lts branch]
    ↓
lts-testing tag (weekly scheduled release)
    ↓
[post-merge e2e + upgrade tests]
    ↓
[installability gate]
    ↓
lts-stable tag (production promotion)
    ↓
[bonedigger crash signal validation]
    ↓
general availability
```

Each gate is independently verifiable and must pass before promotion proceeds.

## Gate 1: Post-Merge E2E and Upgrade Tests

**Location:** `.github/workflows/post-merge-e2e.yml` (bluefin-lts repo)

**Trigger:** After merge to `main` branch in bluefin-lts

**Tests:**

1. **E2E Smoke Tests**
   - Runs testsuite against `:lts` tag
   - Uses GNOME QEMU runner for desktop validation
   - Verifies basic functionality (boot, desktop, apps)

2. **Upgrade Path Validation**
   - Boots previous stable LTS (`lts-stable` tag)
   - Stages new LTS image via bootc switch
   - Verifies successful boot and system integrity
   - Ensures users can upgrade without breaking their system

**Pass Criteria:**
- All testsuite smoke tests pass (100% pass rate)
- Previous→new upgrade staging succeeds
- New image boots successfully post-upgrade

**Failure Behavior:**
- Workflow fails, blocking release generation
- Issue filed automatically (via bonedigger integration, future)
- Release team notified for manual investigation

## Gate 2: Installability Gate

**Location:** `.github/workflows/installability-gate.yml` (bluefin-lts repo)

**Trigger:** Manual dispatch before stable promotion (required in promotion SOP)

**Test:**
- Spins up VM with 50GB disk
- Runs full anaconda/knuckle installation from OCI image
- Extracts kernel from installed system
- Boots installed system
- Validates GNOME and systemd health

**Pass Criteria:**
- Installation completes without errors
- Installed system boots successfully
- Basic services (systemd, SSH) functional
- GNOME packages installable (variant-dependent)

**Failure Behavior:**
- Promotion workflow fails, blocking stable release
- Logs uploaded as artifacts for root cause analysis
- Release team must resolve before retry

## Gate 3: Bonedigger Crash Signal Integration

**Status:** DESIGN - awaiting bonedigger API exposure

This gate queries the bonedigger issue tracking system for crash and panic reports associated with the candidate image digest, blocking promotion if unresolved critical issues are found.

### Design

**API Integration:**
```bash
# Query bonedigger for issues associated with image digest
GET /api/v1/issues?labels=crash&labels=panic&image_digest=${DIGEST}&status=open

# Expected response:
{
  "issues": [
    {
      "id": "BUG-1234",
      "title": "kernel panic in nvme driver",
      "severity": "critical",
      "status": "open",
      "first_seen": "2026-05-28T14:32:00Z",
      "occurrences": 47,
      "pstore_available": true,
      "kdump_available": true
    }
  ]
}
```

**Gate Logic:**

```bash
# In promotion workflow, after installability passes:
DIGEST=$(skopeo inspect --format='{{.Digest}}' \
  docker://ghcr.io/projectbluefin/bluefin:lts)

RESPONSE=$(curl -s https://bonedigger.project.bluefin/api/v1/issues \
  -d "image_digest=${DIGEST}&status=open&severity=critical")

CRITICAL_ISSUES=$(echo $RESPONSE | jq '.issues | length')

if [[ ${CRITICAL_ISSUES} -gt 0 ]]; then
  echo "❌ Promotion blocked by unresolved crash reports"
  echo "$RESPONSE" | jq '.issues[] | "- \(.id): \(.title) (\(.severity))"'
  exit 1
fi

echo "✅ No critical crash signals — proceeding to stable promotion"
```

### Signal Sources

1. **Panic/Crash Reports**
   - Kernel oops captured via kdump
   - Systemd crash handler invocations
   - User-reported application crashes with stack traces

2. **Persistent Storage Evidence**
   - `/dev/pstore/` contents (if available in hardware)
   - UEFI variables indicating system failures
   - Hardware watchdog resets

3. **Issue Labels for Blocking**
   - `type:panic` — kernel panic
   - `type:crash` — application crash
   - `type:hang` — system hang (non-responsive)
   - `type:oops` — kernel oops
   - `severity:critical` or `severity:blocker`

### Blocking Criteria

Promotion is **blocked** if any of these conditions are met:

```
1. 5+ panics in same component (e.g., GPU driver) in last 14 days
2. Any reported pstore/kdump evidence within 7 days of image build
3. System hang (5+ reports) with no upstream fix confirmed
4. Hardware watchdog resets (>3 in 48 hours)
5. Critical SELinux denials causing boot failure
```

### Unblocking Procedure

Release team workflow for unblocking:

1. Verify root cause analysis is underway or complete
2. Confirm upstream bug report filed if applicable
3. Triage: is this blocker or known-issue deferral?
4. Add `accepted-risk` or `deferred-to-[next-release]` label to clear gate
5. Document rationale in issue comment

### Integration Points

**Bonedigger Lifecycle Workflow:**
- New crash report filed → triggers triage automation
- Bonedigger marks report with `blocking-promotion` label automatically if matches criteria
- Release team reviews at promotion time
- Approved deferrals clear gate

**Metrics:**
- **Gate pass rate:** % of promotions passing without crash-signal blocks
- **MTTR:** Time from critical report to resolution/deferral
- **False positive rate:** Crash signals that don't recur after fix

## Gate 4: Hardware Canary Program (Future)

**Status:** DESIGN - see [HARDWARE_CANARY.md](HARDWARE_CANARY.md)

This gate distributes test images to canary devices (diverse hardware) before general availability, capturing real-world hardware-specific failures before promotion.

## Promotion Workflow Integration

### Scheduled Release (Weekly)

**File:** `.github/workflows/scheduled-lts-release.yml`

```yaml
on:
  schedule:
    - cron: '0 6 * * 2'  # Weekly Tuesday 6 AM UTC

jobs:
  build-lts:
    # ...
  
  post-merge-tests:  # Gate 1
    needs: build-lts
    uses: ./.github/workflows/post-merge-e2e.yml
  
  stability-gate:
    needs: post-merge-tests
    # Runs human review + bonedigger API check
    runs-on: ubuntu-latest
    steps:
      - name: Query bonedigger for open crashes
        env:
          BONEDIGGER_API: https://bonedigger.project.bluefin/api/v1
          IMAGE_DIGEST: ...
        run: |
          # Gate 3 implementation
          ./scripts/check-bonedigger-gates.sh

  manual-installability-approval:
    # Gate 2: Manual dispatch required
    runs-on: ubuntu-latest
    steps:
      - name: Run installability test
        run: |
          gh workflow run installability-gate.yml \
            -f image=ghcr.io/projectbluefin/bluefin:lts
```

### Release Generation

Only proceeds if all gates pass:

```bash
if [[ gate1_pass && gate2_pass && gate3_pass ]]; then
  git tag lts-stable
  gh release create lts-stable
fi
```

## Testing Gates in Development

### Local Testing

Developers can test gates locally before merging:

```bash
# Test e2e gate locally
./scripts/test-e2e.sh ghcr.io/projectbluefin/bluefin:lts smoke

# Test installability gate locally
gh workflow run installability-gate.yml \
  -f image=ghcr.io/projectbluefin/bluefin:lts-testing
```

### CI Integration

- **PR validation:** Smoke tests run on every PR (in `pr-testsuite.yml`)
- **Post-merge:** Full gates run after merge to `main`
- **Pre-promotion:** Manual approval gates before `lts-stable` tag

## Observability and Metrics

### Promotion Dashboard

Key metrics tracked:

- **Gate pass rate (%)** per gate per month
- **Time from lts-testing to lts-stable** (median days)
- **Blocker frequency** (blockers/month by type)
- **MTTR to resolution** for blocking issues
- **Regression rate** (critical issues found in stable vs. testing)

### Alert Conditions

- Gate 1 failing consecutively (>2 runs)
- Gate 2 timeout or persistent failures
- Gate 3 unresolved critical signals (>5 per image)

### Feedback Loop

If gates consistently fail:

1. Post-merge test failures → assign to responsible team
2. Installability failures → trigger image rebuild investigation
3. Crash signals → escalate to maintainers for triage

## Related Documents

- [HARDWARE_CANARY.md](HARDWARE_CANARY.md) — Hardware testing program design
- `bluefin-lts/.github/workflows/post-merge-e2e.yml` — E2E test implementation
- `bluefin-lts/.github/workflows/installability-gate.yml` — Install test implementation
- bonedigger API docs (in bonedigger repo) — Crash signal querying

## Future Enhancements

- [ ] bonedigger API exposure and authentication
- [ ] Automated crash report triage and severity scoring
- [ ] Hardware canary device fleet management
- [ ] Release notes auto-generation from closed issues
- [ ] Rollback automation if critical regression detected post-stable
