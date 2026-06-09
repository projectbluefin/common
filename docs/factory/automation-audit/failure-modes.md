# Failure Mode Hardening — Agentic Image Factory

> Systematic defense against the failure modes that break autonomous CI/CD loops.

## Failure Mode Catalog

### FM1: GitHub API Rate Limiting

| Aspect | Detail |
|---|---|
| Symptom | `gh` CLI fails with 403 / "API rate limit exceeded" |
| Where it hits | Label sync, lifecycle automation, cross-repo dispatches |
| Current mitigation | None |
| Impact | Silent failures — labels drift, lifecycle stalls |
| Frequency | Weekly during high-automation periods |

**Hardening:**
```yaml
# Add to any step making multiple API calls
- name: API call with rate-limit awareness
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    # Check remaining rate limit before proceeding
    REMAINING=$(gh api rate_limit --jq '.rate.remaining')
    if [ "$REMAINING" -lt 100 ]; then
      RESET=$(gh api rate_limit --jq '.rate.reset')
      WAIT=$((RESET - $(date +%s) + 5))
      echo "::warning::Rate limit low (${REMAINING} remaining). Waiting ${WAIT}s."
      sleep "$WAIT"
    fi
    # Proceed with API calls
```

**Recommended pattern:** Wrap all multi-call workflows in a rate-limit-aware shell function:
```bash
gh_api_safe() {
  local retries=3
  for i in $(seq 1 $retries); do
    if gh api "$@" 2>/tmp/gh-err; then
      return 0
    fi
    if grep -q "rate limit" /tmp/gh-err; then
      local wait=$((60 * i))
      echo "Rate limited, waiting ${wait}s (attempt $i/$retries)"
      sleep "$wait"
    else
      cat /tmp/gh-err >&2
      return 1
    fi
  done
  return 1
}
```

### FM2: Registry Push Rate Limits (GHCR)

| Aspect | Detail |
|---|---|
| Symptom | `push-to-registry` fails with 429 or timeout |
| Where it hits | `build.yml`, `reusable-build.yml` on multi-arch pushes |
| Current mitigation | None |
| Impact | Build succeeds but image not published — silent |
| Frequency | Rare but catastrophic when it happens |

**Hardening:**
```yaml
- name: Push with retry
  uses: nick-fields/retry@<sha> # v3
  with:
    timeout_minutes: 10
    max_attempts: 3
    retry_wait_seconds: 60
    command: |
      buildah push \
        --compression-format=zstd:chunked \
        "$IMAGE" "docker://$REGISTRY/$IMAGE:$TAG"
```

### FM3: Auth Token Expiry

| Aspect | Detail |
|---|---|
| Symptom | Cosign sign fails, registry push 401, dispatch rejected |
| Where it hits | Any workflow using `SIGNING_SECRET`, `RENOVATE_TOKEN`, or App tokens |
| Current mitigation | `check-cosign-key-rotation.yml` (bluefin only) |
| Impact | Entire release pipeline stops |
| Frequency | Every 90 days (GitHub App tokens), yearly (signing keys) |

**Hardening:**
1. **Keyless signing** (tracked #513) — eliminates signing key rotation entirely
2. **Token health check composite action:**
```yaml
# projectbluefin/actions/actions/check-token-health/action.yml
name: Check Token Health
inputs:
  token:
    required: true
  token_name:
    required: true
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        # Verify token can authenticate
        if ! gh auth status 2>/dev/null; then
          echo "::error::Token '${INPUT_TOKEN_NAME}' is expired or invalid"
          exit 1
        fi
      env:
        GH_TOKEN: ${{ inputs.token }}
        INPUT_TOKEN_NAME: ${{ inputs.token_name }}
```

### FM4: Build Cache Invalidation

| Aspect | Detail |
|---|---|
| Symptom | Builds suddenly take 3x longer; cache miss on everything |
| Where it hits | `reusable-build.yml`, `cache-maintenance.yml` |
| Current mitigation | `cache-maintenance.yml` cleans old caches on schedule |
| Impact | Slow builds → timeout → failed release windows |
| Frequency | After major dependency bumps or GHA runner image updates |

**Hardening:**
- Current mitigation is adequate. The `cache-maintenance.yml` already handles this.
- **Enhancement:** Add cache hit rate metric to build summary annotations:
```yaml
- name: Report cache stats
  if: always()
  run: |
    echo "::notice::Cache hit rate: ${CACHE_HITS}/${CACHE_TOTAL} (${HIT_RATE}%)"
```

### FM5: Partial Publish (Split-Brain)

| Aspect | Detail |
|---|---|
| Symptom | Image pushed but not signed; or signed but release notes not created |
| Where it hits | `execute-release.yml` — multi-step release process |
| Current mitigation | `reusable-execute-release.yml` verifies cosign before skopeo copy |
| Impact | Users pull unsigned images or miss release notes |
| Frequency | Rare — only on mid-workflow failures |

**Hardening:**
```yaml
# Already partially addressed by the verify-before-promote pattern.
# Additional defense: make release-notes job retry-safe
release-notes:
  needs: [execute]
  if: always() && needs.execute.result == 'success'
  # ↑ This is correct — release notes only run if promotion succeeded.
  # The ncipollo/release-action with allowUpdates: true is already idempotent.
```

**Additional guard:** Add a "release verification" job that runs last:
```yaml
verify-release:
  needs: [execute, release-notes]
  if: always() && needs.execute.result == 'success'
  runs-on: ubuntu-latest
  steps:
    - name: Verify promoted image is signed
      run: |
        cosign verify \
          --certificate-identity-regexp "${{ inputs.cosign_identity_regexp }}" \
          --certificate-oidc-issuer https://token.actions.githubusercontent.com \
          "$REGISTRY/$IMAGE:$TARGET_TAG"
    - name: Verify GitHub Release exists
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        TAG=$(gh release list --repo "${{ github.repository }}" --limit 1 --json tagName --jq '.[0].tagName')
        echo "Latest release: ${TAG}"
```

### FM6: Merge Queue Races

| Aspect | Detail |
|---|---|
| Symptom | `enqueuePullRequest` fails with "Required status check is expected" |
| Where it hits | `promote-testing-to-main.yml` — enqueue step |
| Current mitigation | Mergeability poll loop (12 attempts, 15s each) |
| Impact | Promotion PR sits unqueued until next daily run |
| Frequency | Common — every time squash branch is freshly pushed |

**Hardening:** Current mitigation (poll loop) is adequate. The `release-reminder.yml` provides a secondary alert if a promotion PR goes stale. No additional hardening needed.

### FM7: Concurrent Promotion Conflicts

| Aspect | Detail |
|---|---|
| Symptom | Two promotion workflows run simultaneously, one fails |
| Where it hits | `promote-testing-to-main.yml` when push + cron trigger overlap |
| Current mitigation | `concurrency: group: promote-testing-to-main, cancel-in-progress: false` |
| Impact | One run fails but the other succeeds — eventual consistency |
| Frequency | Rare — only when push and cron coincide |

**Hardening:** Current concurrency group with `cancel-in-progress: false` is correct — it queues rather than cancels. No change needed.

---

## Self-Healing Patterns

### Pattern 1: Retry with exponential backoff (composite action)

```yaml
# projectbluefin/actions/actions/retry/action.yml
name: Retry with backoff
description: Retry a command with exponential backoff
inputs:
  command:
    required: true
  max_attempts:
    default: "3"
  initial_wait:
    default: "10"
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        ATTEMPT=1
        WAIT="${{ inputs.initial_wait }}"
        while [ $ATTEMPT -le ${{ inputs.max_attempts }} ]; do
          echo "Attempt $ATTEMPT/${{ inputs.max_attempts }}..."
          if eval "${{ inputs.command }}"; then
            echo "Success on attempt $ATTEMPT"
            exit 0
          fi
          if [ $ATTEMPT -eq ${{ inputs.max_attempts }} ]; then
            echo "::error::All ${{ inputs.max_attempts }} attempts failed"
            exit 1
          fi
          echo "Failed, waiting ${WAIT}s before retry..."
          sleep "$WAIT"
          WAIT=$((WAIT * 2))
          ATTEMPT=$((ATTEMPT + 1))
        done
```

### Pattern 2: Automatic issue filing on repeated failures

```yaml
# Add to any critical workflow's failure path
report-repeated-failure:
  if: failure()
  runs-on: ubuntu-latest
  steps:
    - name: Check failure streak
      id: streak
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        # Count consecutive failures
        FAILURES=$(gh run list \
          --repo "${{ github.repository }}" \
          --workflow "${{ github.workflow }}" \
          --limit 5 \
          --json conclusion \
          --jq '[.[] | select(.conclusion == "failure")] | length')
        echo "consecutive_failures=${FAILURES}" >> "$GITHUB_OUTPUT"

    - name: File issue on 3+ consecutive failures
      if: steps.streak.outputs.consecutive_failures >= 3
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        TITLE="ci: ${{ github.workflow }} has failed 3+ consecutive times"
        EXISTING=$(gh issue list --label "area/ci,kind/bug" --state open --search "$TITLE" --json number --jq 'length')
        if [ "$EXISTING" -eq 0 ]; then
          gh issue create \
            --title "$TITLE" \
            --label "area/ci,kind/bug,priority/p1" \
            --body "Workflow \`${{ github.workflow }}\` has failed ${{ steps.streak.outputs.consecutive_failures }} consecutive times.\n\nLatest run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
        fi
```

### Pattern 3: Idempotent operations (design principle)

Every publish step must be safe to re-run:
- `skopeo copy` — overwrites existing tag (idempotent)
- `ncipollo/release-action` with `allowUpdates: true` — updates existing release (idempotent)
- `cosign sign` — re-signing is safe (adds to transparency log)
- `git push --force` on promotion branch — always rebuilds from scratch (idempotent)

**Anti-pattern to avoid:** Creating objects conditionally without checking for existence first. Always check-then-create or use upsert semantics.

---

## Priority Implementation Order

| # | Hardening | Effort | Impact | Status |
|---|---|---|---|---|
| 1 | Keyless signing (#513) | Medium | Eliminates FM3 for signing | Tracked |
| 2 | Retry composite action | Low | Addresses FM1, FM2 | **New** |
| 3 | Repeated-failure auto-issue | Low | Addresses all FMs | **New** |
| 4 | Rate-limit awareness | Low | Addresses FM1 | **New** |
| 5 | Release verification job | Low | Addresses FM5 | **New** |
| 6 | Token health check action | Low | Addresses FM3 | **New** |
