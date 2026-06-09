# Non-Deterministic Steps — Audit and Elimination Plan

> Every step that can produce different results on re-run without code changes.

## Classification

- **ND** — Non-deterministic (different results each run)
- **FLAKY** — Usually succeeds but fails intermittently
- **ENV** — Depends on specific machine/environment state
- **TIMING** — Race condition or timing-dependent

---

## Inventory

### ND1: Dakota BuildStream Cold-Start Timeout

| Aspect | Detail |
|---|---|
| Type | ENV + TIMING |
| Location | `dakota/.github/workflows/build.yml` — 360min timeout |
| Symptom | Cold builds (no cache) exceed 6h and timeout |
| Root cause | BST must rebuild entire GNOME stack from gnome-build-meta when cache misses |
| Current mitigation | BST cache on `cache.projectbluefin.io` + GHA actions/cache for `bst show` |
| Determinism fix | **Pre-warm cache** — scheduled job that keeps the cache hot even when no PRs merge |

**Proposed fix:**
```yaml
# dakota/.github/workflows/cache-warm.yml
name: Warm BuildStream cache
on:
  schedule:
    - cron: '0 6 * * 1,4'  # Monday and Thursday mornings
  workflow_dispatch:
jobs:
  warm:
    runs-on: ubuntu-24.04
    timeout-minutes: 360
    steps:
      - uses: actions/checkout@<sha> # v6
      - name: Setup runner
        uses: projectbluefin/actions/bootc-build/setup-runner@<sha> # v1
        with:
          storage-backend: btrfs
          update-podman: true
          install-tools: '["just"]'
      - name: Build (cache priming only)
        run: just bst build oci/bluefin.bst
```

### ND2: GHA Runner Image Updates (All Repos)

| Aspect | Detail |
|---|---|
| Type | ENV |
| Location | Every workflow using `ubuntu-latest` or `ubuntu-24.04` |
| Symptom | Builds pass Monday, fail Tuesday with same code (runner image updated) |
| Root cause | GitHub updates runner images weekly with new package versions |
| Current mitigation | Critical tools pinned via `taiki-e/install-action`, `setup-runner` |
| Determinism fix | Already mitigated in key workflows |

**Status:** Acceptable. BuildStream runs inside its own container (`bst2`), isolating from runner changes. Other workflows pin their tools.

### ND3: Renovate Auto-Merge Race Condition

| Aspect | Detail |
|---|---|
| Type | TIMING |
| Location | `renovate-automerge.yml` — `workflow_run` trigger |
| Symptom | Two Renovate PRs merge simultaneously, second fails conflict check |
| Root cause | `workflow_run` fires for each completed CI run independently |
| Current mitigation | `reusable-renovate-automerge.yml` checks mergeability before merge |
| Determinism fix | Already fixed — eventual consistency via retry-on-next-run |

### ND4: Testsuite Boot Timing

| Aspect | Detail |
|---|---|
| Type | FLAKY |
| Location | `testsuite/e2e.yml` — VM boot + GNOME session start |
| Symptom | Tests fail with "GNOME Shell not responding" on slow runners |
| Root cause | VM boot time varies with runner load |
| Current mitigation | qecore retries (3 per scenario) + wait-for-session logic |
| Determinism fix | Already mitigated — quarantined flaky tests don't block promotion |

### ND5: GHCR Registry Propagation Delay

| Aspect | Detail |
|---|---|
| Type | TIMING |
| Location | `execute-release.yml` → cosign verify after skopeo copy |
| Symptom | Cosign verify fails because tag hasn't propagated |
| Root cause | GHCR is eventually consistent |
| Current mitigation | Small sleep in `reusable-execute-release.yml` |
| Determinism fix | **Poll-until-available** pattern |

**Proposed fix:**
```yaml
- name: Wait for tag propagation
  run: |
    for i in $(seq 1 12); do
      if skopeo inspect "docker://$REGISTRY/$IMAGE:$TAG" &>/dev/null; then
        echo "Tag available after $((i * 5))s"
        exit 0
      fi
      echo "Waiting for tag propagation ($i/12)..."
      sleep 5
    done
    echo "::error::Tag not available after 60s"
    exit 1
```

### ND6: ISO Build Non-Reproducibility

| Aspect | Detail |
|---|---|
| Type | ND (inherent) |
| Location | `iso/reusable-build-iso-anaconda.yml` |
| Symptom | ISOs built from same source image produce different checksums |
| Root cause | Anaconda embeds timestamps, UUIDs in filesystem |
| Current mitigation | None needed |
| Determinism fix | **Accept** — integrity comes from signed OCI image, not ISO checksum |

### ND7: Promotion-Candidate E2E Flakiness

| Aspect | Detail |
|---|---|
| Type | FLAKY |
| Location | `common/.github/workflows/promotion-candidate-e2e.yml` |
| Symptom | Weekly test flakes file false-positive blocker issues |
| Root cause | Tests run against :testing which may be mid-update |
| Current mitigation | Auto-close issue when next run succeeds |
| Determinism fix | **Resolve digest before test** — pin the exact digest to test |

**Proposed fix:**
```yaml
- name: Resolve testing digest
  id: resolve
  run: |
    DIGEST=$(skopeo inspect --format '{{.Digest}}' "docker://ghcr.io/projectbluefin/bluefin:testing")
    echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"
    echo "Testing exact digest: ${DIGEST}"
# Then pass digest to testsuite dispatch to ensure the exact image is tested
```

---

## Summary

| ID | Type | Severity | Status | Action |
|---|---|---|---|---|
| ND1 | ENV+TIMING | HIGH | Propose cache-warm | New workflow artifact |
| ND2 | ENV | LOW | Already mitigated | None needed |
| ND3 | TIMING | LOW | Already fixed | None needed |
| ND4 | FLAKY | MEDIUM | Already mitigated | None needed |
| ND5 | TIMING | MEDIUM | Partially mitigated | Propose poll pattern |
| ND6 | ND | LOW | Accepted by design | None needed |
| ND7 | FLAKY | MEDIUM | Partially mitigated | Propose digest pinning |

## Net Assessment

The factory is **remarkably deterministic** for a bootc image build system. 4 of 7 ND concerns are already fully mitigated. The 3 actionable items:

1. **ND1** — Dakota cache-warm workflow (prevents 6h cold builds)
2. **ND5** — Registry propagation polling (prevents verify failures)
3. **ND7** — Digest pinning for weekly tests (prevents false-positive blocker issues)
