# Hardware Canary Program — Post-Promotion Testing

This document defines the hardware canary program for Project Bluefin, a distributed testing effort that validates LTS releases across diverse hardware configurations before general availability.

## Program Overview

The hardware canary program uses a fleet of volunteer-contributed devices to stress-test images in real hardware environments before wider rollout. This catches hardware-specific failures (suspend/resume, USB-C, GPU, Wi-Fi, TPM, audio, battery) that QEMU-based testing cannot simulate.

### Timeline

```
lts-stable candidate (post gate 1-3)
    ↓
[distribute to canary fleet — 3-5 days]
    ↓
[concurrent testing across 7 hardware classes]
    ↓
[automated and manual issue reporting]
    ↓
[triage and hotfix cycle]
    ↓
lts-stable release → general availability
    OR
[rollback if critical hardware bug found]
```

## Hardware Bug Classes (7 Categories)

The program focuses on these seven hardware-specific failure modes:

### 1. Suspend/Resume (S3/S4)

**Symptoms:**
- System fails to enter S3/S4 state
- Fails to wake from suspend via keyboard/mouse/network
- Resume corrupts memory or rootfs
- Wake timing inconsistent (>5min, random)

**Canary Tests:**
- Automated: 10x suspend/resume cycles with monitoring
- Log check: `journalctl -b 0 | grep -i "suspend\|resume\|acpi"`
- Hardware-specific: ACPI table validation
- Kernel params: systemd.suspend_state validation

**Automated Script:**
```bash
#!/bin/bash
# Canary test: suspend/resume cycles
for i in {1..10}; do
  rtcwake -m mem -s 30 &
  sleep 2
  if ! systemctl suspend; then
    echo "FAIL: suspend cycle $i"
    journalctl --no-pager -b0 -n 50 >> suspend-issues.log
    exit 1
  fi
  sleep 5
done
echo "PASS: 10 suspend/resume cycles successful"
```

### 2. USB-C / Type-C (Power, DP, Data)

**Symptoms:**
- USB-C port not detected by kernel
- Power delivery negotiation fails
- USB device connectivity intermittent
- DisplayPort alternate mode fails

**Canary Tests:**
- Automated: Monitor `/sys/kernel/debug/usb/` for device enumeration
- Manual: Plug/unplug 5x with different USB-C peripherals
- Power: Query battery info during USB-C power delivery
- DP: Test external monitor detection (if applicable)

**Manual Test Procedure:**
```
1. Cold plug: USB-C hub with mixed peripherals
2. Verify kernel detects devices: `lsusb`, `dmesg`
3. Hot unplug and re-plug 5x
4. Validate device persistence and re-enumeration
5. If DP-capable: test monitor detection and mode switching
6. Log any errors to USB_C_issues.log
```

**Automated Monitoring:**
```bash
#!/bin/bash
# Monitor USB-C device enumeration
udevadm monitor --property --udev | while read -r line; do
  if grep -q "TYPE_C\|usb-c\|USB-C" <<< "$line"; then
    echo "[$(date)] USB-C event: $line" >> usb-c-events.log
  fi
done
```

### 3. GPU / Graphics (dGPU, iGPU, eGPU)

**Symptoms:**
- GPU not detected by kernel or driver
- X11/Wayland fails to initialize with GPU
- Rendering artifacts (visual glitches)
- Hardware acceleration unavailable

**Canary Tests:**
- Automated: `glxinfo` and `vulkaninfo` pass without crash
- GNOME: 5min of interactive GNOME usage (window animation, scaling)
- GPU monitoring: `nvidia-smi` or `radeontop` (for supported GPUs)
- Regression: Compare prior image performance

**GPU Detection Script:**
```bash
#!/bin/bash
# Validate GPU initialization
glxinfo | grep -q "OpenGL vendor\|OpenGL renderer" || exit 1
vulkaninfo 2>&1 | grep -q "NVIDIA\|AMD\|Intel\|Vulkan" || exit 1

# Monitor thermal
if command -v nvidia-smi; then
  nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
fi

# Test rendering
glmark2-es2 --run-forever &
sleep 60
pkill -TERM glmark2-es2
echo "PASS: GPU rendering functional"
```

### 4. Wi-Fi / 802.11 (Connectivity)

**Symptoms:**
- Wi-Fi adapter not detected
- Network connection drops after N minutes
- Slow or inconsistent throughput
- Power management issues (disconnect on idle)

**Canary Tests:**
- Automated: Connect to AP, sustained ping 100x, measure latency
- Manual: Switch between 2.4GHz and 5GHz networks
- Sleep-wake: Does Wi-Fi reconnect after suspend?
- Range: Test signal at varying distances from AP

**Wi-Fi Validation Script:**
```bash
#!/bin/bash
# Test Wi-Fi connectivity
nmcli device wifi rescan
SSID="Canary-Test-Network"
nmcli device wifi connect "$SSID" password "test-password" || exit 1

# Ping test
ping -c 100 8.8.8.8 | tee wifi-ping.log

# Extract stats
LOSS=$(grep -oP '\d+(?=% packet loss)' wifi-ping.log)
AVG_LATENCY=$(grep -oP 'avg = \K[\d.]+' wifi-ping.log)

if [[ ${LOSS} -gt 5 ]]; then
  echo "FAIL: Packet loss ${LOSS}% (threshold 5%)"
  exit 1
fi

if (( $(echo "$AVG_LATENCY > 100" | bc -l) )); then
  echo "WARN: High latency ${AVG_LATENCY}ms"
fi

echo "PASS: Wi-Fi connectivity validated"
```

### 5. TPM / Secure Boot (Firmware Security)

**Symptoms:**
- TPM chip not detected
- PCR (Platform Configuration Register) readings unstable
- Secure Boot enforcement fails
- FDE (Full Disk Encryption) cannot initialize

**Canary Tests:**
- Automated: Query TPM 2.0 via `tpm2` tools, verify PCR values
- Measurement: Re-measure PCR consistently (should be deterministic)
- Secure Boot: Verify EFI secure boot status and keys

**TPM Validation Script:**
```bash
#!/bin/bash
# Test TPM 2.0 availability and PCR consistency
tpm2_getcap properties-fixed | grep -q "TPM2_PT_FIRMWARE_VERSION" || {
  echo "WARN: TPM 2.0 not detected"
  exit 0
}

# Measure PCR 0 three times (should be identical)
PCR_VALUES=()
for i in {1..3}; do
  PCR=$(tpm2_pcrread -o /tmp/pcr.dat 0 2>&1 | grep "0x" | awk '{print $2}')
  PCR_VALUES+=("$PCR")
done

if [[ ${PCR_VALUES[0]} == ${PCR_VALUES[1]} ]] && [[ ${PCR_VALUES[1]} == ${PCR_VALUES[2]} ]]; then
  echo "PASS: TPM PCR values consistent"
else
  echo "FAIL: TPM PCR values inconsistent: ${PCR_VALUES[@]}"
  exit 1
fi

# Verify secure boot
efibootmgr 2>&1 | grep -q "Secure Boot.*enabled" && echo "INFO: Secure Boot enabled"
```

### 6. Audio / ALSA / PulseAudio (Sound)

**Symptoms:**
- No audio output detected
- Audio latency too high (noticeable delay)
- Crackling or distortion
- Microphone/input not working

**Canary Tests:**
- Automated: Play test sound, verify PCM levels
- ALSA: List devices with `arecord -L`, `aplay -L`
- Pulseaudio: Validate source/sink enumeration
- Hotplug: Unplug/replug audio device 3x

**Audio Validation Script:**
```bash
#!/bin/bash
# Test audio output availability
aplay -l | grep -q "^card" || exit 1
pactl list short sinks | grep -q "RUNNING\|IDLE" || exit 1

# Play test tone (1 second)
paplay --rate=44100 --channels=1 --format=u8 /dev/zero &
PLAY_PID=$!
sleep 1
kill $PLAY_PID 2>/dev/null || true

# Record test (1 second)
parecord --rate=44100 --channels=1 --format=u8 /tmp/audio-test.raw &
REC_PID=$!
sleep 1
kill $REC_PID 2>/dev/null || true

[[ -s /tmp/audio-test.raw ]] && echo "PASS: Audio I/O functional" || exit 1
```

### 7. Battery / Power Management (Laptop)

**Symptoms:**
- Battery not detected or capacity unknown
- Charging doesn't work or is slow
- Thermal throttling too aggressive
- Power profiles not switching correctly

**Canary Tests:**
- Automated: Query battery state via `acpi -b`, monitor charge rate
- Charging: Plug/unplug 3x, verify state changes
- Stress: 30-minute stress test while unplugged, track battery drain
- Thermal: `sensors` output, verify fan control

**Battery Validation Script:**
```bash
#!/bin/bash
# Test battery management
acpi -b | grep -qE "Battery [0-9]+: (Discharging|Charging)" || exit 1

# Get initial charge
CHARGE_START=$(acpi -b | grep -oP '\d+(?=%)')
echo "Initial charge: ${CHARGE_START}%"

# Run 30-minute test unplugged
timeout 30m bash -c 'while true; do stress-ng --cpu 1 --io 1 --vm 1 2>/dev/null; done' &
STRESS_PID=$!

sleep 1800  # 30 minutes

kill $STRESS_PID 2>/dev/null || true

CHARGE_END=$(acpi -b | grep -oP '\d+(?=%)')
DRAIN=$((CHARGE_START - CHARGE_END))

echo "Charge after 30m stress: ${CHARGE_END}%"
echo "Drain rate: ${DRAIN}% per 30m"

if [[ $DRAIN -lt 10 ]]; then
  echo "WARN: Unusually low battery drain (possible test issue)"
fi

echo "PASS: Battery management validated"
```

## Canary Device Selection Criteria

### Device Profile Requirements

Each canary device MUST have:

```
1. Diverse CPU architecture
   - Intel 9th gen or newer (2019+)
   - AMD Ryzen 3000 or newer (2019+)
   - ARM-based (e.g., Framework 5, MacBook Pro M3 via asahi)

2. At least 3 of the 7 bug classes to test:
   - e.g., ThinkPad: suspend, USB-C, Wi-Fi, battery
   - e.g., Desktop: GPU, USB-C, audio
   - e.g., Gaming laptop: GPU, Wi-Fi, battery

3. Recent enough to detect regressions (within 5 years)

4. Reliable network/logging infrastructure
```

### Device Inventory Example

| Device | CPU | GPU | Suspend | USB-C | Wi-Fi | TPM | Audio | Battery | Owner |
|--------|-----|-----|---------|-------|-------|-----|-------|---------|-------|
| Framework 13 | Intel 13th | Intel Iris Xe | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Alice |
| ThinkPad X1 | Intel 11th | Intel UHD | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Bob |
| ASUS ROG | Intel 12th | RTX 3060 | ✓ | ✗ | ✓ | ✓ | ✓ | ✗ | Charlie |
| Desktop | AMD R9 | RTX 4070 | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | Diana |
| MacBook M3 | Apple M3 | Apple M3 GPU | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | Eve |

### Onboarding Canary Device Owner

1. Owner volunteers device and contacts release team
2. Device profile documented in DEVICE_INVENTORY.md
3. Test scripts installed: `bluefin-canary-tests` package
4. Logging/reporting configured: automatic report generation to bonedigger
5. Release team validates connectivity and baseline

## Test Automation and Reporting

### Automated Test Suite

**Package:** `bluefin-canary-tests` (installed on canary devices)

**Contents:**
```
/usr/bin/bluefin-canary-test
  ├── suspend-test         (run 10x suspend/resume)
  ├── usb-c-test           (device enumeration)
  ├── gpu-test             (glxinfo, vulkaninfo, glmark2)
  ├── wifi-test            (connectivity, latency, reconnect)
  ├── tpm-test             (PCR consistency, secure boot)
  ├── audio-test           (playback, recording, hotplug)
  └── battery-test         (charge rate, drain measurement)
```

**Hourly Cron Job:**
```bash
# /etc/cron.d/bluefin-canary
0 * * * * bluefin /usr/bin/bluefin-canary-test run-all --report-to bonedigger
```

### Manual Test Procedure (Canary Owner)

Device owner receives pre-release image and:

1. **Installation & First Boot** (1 hour)
   - Install using standard procedure
   - Verify GNOME starts, basic functionality
   - File any issues to bonedigger with `canary-manual` label

2. **Stress Testing** (2-3 hours)
   - Run `bluefin-canary-test run-all --interactive`
   - Perform category-specific manual tests (unplug USB-C, toggle Wi-Fi, etc.)
   - Test suspend/resume cycling (10x)

3. **Daily Use** (3-7 days)
   - Use system as normal (work, browsing, gaming)
   - Watch for crashes, hangs, unusual behavior
   - Report any issues found

### Issue Reporting Format

Canary owners file issues with this template:

```markdown
Title: [CANARY] GPU flickering on external monitor disconnect

Category: GPU
Device: Framework 13 (Intel 13th)
Image: ghcr.io/projectbluefin/bluefin:lts-candidate-20260603

Steps to Reproduce:
1. Connect external USB-C DP monitor
2. Open GNOME Settings
3. Disconnect monitor

Expected:
- Desktop redraws cleanly to internal display

Actual:
- Display flickers, artifacts visible for ~2 seconds
- GPU fan spins up momentarily

Frequency: 8/10 occurrences

Logs:
journalctl --boot 0 | grep -E "gpu|drm|nouveau" >> gpu-issue.log
```

Labels applied automatically:
- `canary-report` — from canary device
- `type:gpu` / `type:wifi` / etc. — category
- `blocking-promotion` — if critical
- `hardware:${DEVICE}` — device type

### Automated Reporting

Canary devices report hourly via:

```bash
bluefin-canary-report --image ghcr.io/projectbluefin/bluefin:lts-candidate \
  --device "Framework 13 (Alice)" \
  --test-results /var/log/bluefin-canary/results.json \
  --api-token ${BONEDIGGER_API_TOKEN}
```

Creates issues in bonedigger automatically if tests fail:
- Red: Failure (test exit code != 0)
- Yellow: Warning (latency high, temp high, etc.)
- Green: Pass

## Gate Integration

### Pre-Promotion Workflow

Promotion workflow waits for canary results:

```bash
# In scheduled-lts-release.yml or manual promotion workflow
- name: Collect canary results
  run: |
    # Wait up to 7 days for canary fleet to report
    for day in {1..7}; do
      RESULTS=$(gh api repos/projectbluefin/bonedigger/issues \
        -f labels='canary-report' \
        -f created='>='$(date -d "$day days ago" +%Y-%m-%d) \
        --jq '.[] | select(.state=="open" and .labels[].name | contains("blocking"))' \
      )
      
      if [[ -n "$RESULTS" ]]; then
        echo "Blocking canary issues found:"
        echo "$RESULTS" | jq -r '.[].title'
        exit 1
      fi
      
      sleep 86400
    done
    
    echo "✅ Canary fleet passed — safe to promote to stable"
```

### Blocking Canary Criteria

Promotion is **blocked** if:

```
1. Any "FAIL" test results from 3+ devices in same category
2. Critical issue marked blocking-promotion from any canary owner
3. Reproducible system hang (>1 device, same hardware class)
4. Data corruption or filesystem damage reported
5. Unable to collect results from >50% of canary fleet for 72+ hours
```

### Canary Owner Expectations

- **Availability:** Available to run tests and manual procedures during 3-5 day test window
- **Communication:** Respond to release team questions about device state
- **Reporting:** File issues promptly with reproduction steps
- **Hardware:** Maintain device in working state (no major firmware updates during test window)

## Workflow and Timeline

### Image Candidate Release (Day 0)

```
1. lts-testing built, post-merge tests pass, installability passes
2. Bonedigger crash signal check passes
3. Image tagged: ghcr.io/projectbluefin/bluefin:lts-candidate-20260603
4. Release team announces: "Canary testing starting — [link to issues]"
```

### Canary Testing (Days 1-5)

```
Day 1:   Canary owners receive image, begin installation + first tests
Day 2-4: Concurrent testing across fleet, issues filed as discovered
Day 5:   Final results collected, triage decisions made
```

### Triage & Hotfix (Days 5-6)

```
Critical issues:
- Assess: Is fix quick or defer to next release?
- If quick: Patch image, restart canary testing
- If defer: Add "deferred-to-20260610" label, proceed with caveat

Non-critical issues:
- File in tracking, backlog for next cycle
- Proceed with promotion if no blockers
```

### Promotion Decision (Day 7)

```
If clear:
  gh release create lts-stable
  Announce to users

If issues:
  rollback lts-testing or defer release date
```

## Observability Metrics

**Canary Program KPIs:**

- **Detection rate:** Issues found by canary vs. issues found post-stable (should be 0 critical post-stable)
- **MTTR:** Time from issue report to hotfix or deferral decision
- **Device participation:** % of devices reporting per cycle
- **False negative rate:** Critical bugs that slip through canary

**Per-Category Metrics:**

| Category | Failure Rate (%) | MTTR (hours) | Notes |
|----------|------------------|--------------|-------|
| Suspend/Resume | <1% | <24 | Most reliable |
| USB-C | 2-5% | 24-48 | Firmware/EC dependent |
| GPU | 1-3% | <24 | Driver-dependent |
| Wi-Fi | 3-7% | 24-72 | Upstream kernel delays |
| TPM | <1% | 48-72 | Rare firmware issues |
| Audio | 1-2% | 24-48 | Usually userspace fixes |
| Battery | 0.5% | <24 | ACPI dependent |

## Related Docs

- [PROMOTION_GATES.md](PROMOTION_GATES.md) — Full promotion pipeline
- `bluefin-lts/.github/workflows/post-merge-e2e.yml` — E2E gate
- `bluefin-lts/.github/workflows/installability-gate.yml` — Install gate
- DEVICE_INVENTORY.md (to be created) — Canary device registry

## Future Enhancements

- [ ] Mobile hardware support (e.g., Framework Laptop + Stylus)
- [ ] Cloud instance canary testing (AWS, Azure, GCP)
- [ ] Thermal imaging integration for thermal validation
- [ ] Audio quality validation (frequency response, SNR)
- [ ] Battery wear trending (multi-cycle testing)
- [ ] Machine learning-based issue prediction and triage
