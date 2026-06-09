# Automation Audit — Implementation Roadmap

> Prioritized by impact. Highest automation gain first.

## Quick Reference

| Phase | Artifact(s) | Deploy to | Effort | Blocks |
|---|---|---|---|---|
| **1** | `actions-v1-tag-update.yml` | `actions/.github/workflows/` | 30 min | Nothing |
| **2** | `cliff.toml` + `release-with-cliff.yml` | `common/` root + workflows | 1h | Nothing |
| **3** | `retry-action.yml` | `actions/actions/retry/` | 1h | Nothing |
| **4** | `check-token-health-action.yml` | `actions/actions/check-token-health/` | 1h | Nothing |
| **5** | `iso-auto-rebuild.yml` + `iso-dispatch-snippet.yml` | `iso/.github/workflows/` + image repos | 2h | Dispatch token |
| **6** | `build-upgraded.yml` | `common/.github/workflows/build.yml` | 4h | Maintainer decision on #513 |
| **7** | `dakota-cache-warm.yml` | `dakota/.github/workflows/` | 30 min | Nothing |

---

## Phase 1: v1 Tag Auto-Update (30 min)

**What:** After every merge to `main` in `projectbluefin/actions`, auto-update the `v1` tag.

**Steps:**
1. Copy `actions-v1-tag-update.yml` to `actions/.github/workflows/`
2. Pin the `actions/checkout` SHA (already done in artifact)
3. PR to `actions` → human merges (actions merge is intentional human gate)
4. After merge: the workflow will self-update v1 going forward

**Validation:** After first merge, check `git log v1 --oneline -1` matches latest main.

**Risk:** None. Worst case: tag points to main anyway (which is the desired state).

---

## Phase 2: git-cliff Changelog (1 hour)

**What:** Replace raw `git log` in `common/release.yml` with structured git-cliff output.

**Steps:**
1. Copy `cliff.toml` to `common/` root
2. Replace `common/.github/workflows/release.yml` with `release-with-cliff.yml`
3. Test: `git cliff --latest` locally to verify output
4. Push directly to main (doc-adjacent: the release workflow is a factory improvement)

**Validation:** Run `git cliff --latest` and verify it produces categorized output.

**Risk:** Low. `git-cliff` binary must be available at runtime — handled by `taiki-e/install-action`.

---

## Phase 3: Retry Composite Action (1 hour)

**What:** Add a reusable retry-with-backoff action to `projectbluefin/actions`.

**Steps:**
1. Create `actions/actions/retry/action.yml` from `retry-action.yml` artifact
2. PR to `actions` → human merges
3. After merge + v1 tag update: available to all repos

**Validation:** Test with intentional failure: `command: "false"` should retry 3 times then fail.

**Risk:** None. Opt-in — no existing workflow changes until repos adopt it.

---

## Phase 4: Token Health Check (1 hour)

**What:** Composite action that validates token auth/scopes/rate-limit at workflow start.

**Steps:**
1. Create `actions/actions/check-token-health/action.yml` from artifact
2. PR to `actions` → human merges
3. Add to `reusable-renovate.yml` as first step (validates RENOVATE_TOKEN)

**Validation:** Test with expired/revoked token → should fail with clear error message.

**Risk:** None. Fails fast with actionable error instead of cryptic downstream failure.

---

## Phase 5: ISO Auto-Rebuild (2 hours)

**What:** Automatically rebuild ISOs when :stable is promoted.

**Steps:**
1. Create dispatch token (GitHub App or PAT with `repo` scope on `iso` repo)
2. Store as org secret: `ISO_DISPATCH_APP_ID` + `ISO_DISPATCH_PRIVATE_KEY` (or `ISO_DISPATCH_TOKEN`)
3. Add `iso-auto-rebuild.yml` to `iso/.github/workflows/`
4. Add dispatch job from `iso-dispatch-snippet.yml` to:
   - `bluefin/.github/workflows/execute-release.yml`
   - `bluefin-lts/.github/workflows/execute-release.yml`
5. Test with `workflow_dispatch` → verify ISO build triggers

**Validation:** Trigger a test promotion → verify ISO workflow fires within 5 minutes.

**Design decision required:** Token type (App vs. PAT). App is more secure but more setup.

**Risk:** Medium. Cross-repo dispatch requires correct token permissions. Test in staging first.

---

## Phase 6: Supply Chain Upgrade (4 hours)

**What:** Keyless signing + SBOM + SLSA L2 + CVE scan for `common/build.yml`.

**Steps:**
1. **Get maintainer approval on #513** — this changes signing infrastructure
2. Verify `id-token: write` is available (it is — already in current permissions)
3. Replace `build.yml` with `build-upgraded.yml`:
   - Remove `SIGNING_SECRET` usage → keyless cosign
   - Add Trivy scan step
   - Add SBOM generation + attach
   - Add provenance attestation
4. Update `docs/skills/release-promotion.md` verification commands
5. After shipping: remove `SIGNING_SECRET` from org secrets (or keep as backup)
6. Update cosign.pub → document new keyless verification command

**Validation:**
```bash
# Verify keyless signature
cosign verify \
  --certificate-identity-regexp "https://github.com/projectbluefin/common/" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/projectbluefin/common:latest

# Verify SBOM attached
oras discover ghcr.io/projectbluefin/common:latest

# Verify attestation
gh attestation verify oci://ghcr.io/projectbluefin/common:latest --repo projectbluefin/common
```

**Design decision required:** Maintainer must approve removing key-based signing. Recommend keeping `cosign.pub` for signature verification of historical images.

**Risk:** High. Wrong OIDC config = unsigned images in production. Implement on a branch, test with `pr-` tag first.

---

## Phase 7: Dakota Cache Warm (30 min)

**What:** Scheduled builds to keep BST remote cache hot.

**Steps:**
1. Copy `dakota-cache-warm.yml` to `dakota/.github/workflows/`
2. PR to `dakota` → merge
3. Wait for first scheduled run Monday morning

**Validation:** After first run, check if subsequent `build.yml` runs complete faster.

**Risk:** None. Cache warming is additive — worst case, it fails and logs a warning.

---

## Dependency Graph

```
Phase 1 (v1 tag)        ── no deps ──→ immediate
Phase 2 (git-cliff)     ── no deps ──→ immediate
Phase 3 (retry action)  ── no deps ──→ immediate
Phase 4 (token health)  ── no deps ──→ immediate
Phase 5 (ISO dispatch)  ── needs dispatch token (admin setup) ──→ after admin action
Phase 6 (supply chain)  ── needs maintainer approval (#513) ──→ after design gate
Phase 7 (cache warm)    ── no deps ──→ immediate
```

**Critical path:** Phases 1-4 and 7 can all be done in parallel (1 day total). Phase 5 needs an admin to create a token. Phase 6 needs a maintainer to approve the signing change.

---

## Success Metrics

| Before Audit | After Phase 1-4,7 | After All Phases |
|---|---|---|
| 91% automated | 93% automated | 97% automated |
| 11 manual touchpoints | 7 manual touchpoints | 4 intentional human gates |
| Key-based signing | Key-based signing | Keyless OIDC signing |
| No SBOM/provenance | No SBOM/provenance | SBOM + SLSA L2 |
| Manual ISO builds | Manual ISO builds | Event-driven ISO builds |
| Raw git log changelog | Structured changelog | Structured changelog |
| No retry/self-heal | Retry + token health | Full self-healing |

---

## Tracking Issues to File

After review, file these as GitHub issues in `projectbluefin/common`:

1. `feat(ci): auto-update v1 tag in actions repo` — kind/improvement, area/ci
2. `feat(ci): integrate git-cliff for structured changelogs` — kind/improvement, area/ci
3. `feat(ci): add retry composite action to actions` — kind/improvement, area/ci
4. `feat(ci): add token health check action` — kind/improvement, area/ci
5. `feat(ci): automate ISO rebuilds on stable promotion` — kind/improvement, area/ci, priority/p1
6. `feat(ci): dakota BST cache-warm workflow` — kind/improvement, area/ci
