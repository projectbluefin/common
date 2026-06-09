# Manual Touchpoints Audit

> Every step in the factory that currently requires a human to be present, monitoring, or acting.

## Classification

- **INTENTIONAL** — Design decision; human judgment is required and should remain
- **AUTOMATABLE** — Can be fully automated with existing tooling
- **BLOCKED** — Requires prerequisite work before automation is possible

---

## Touchpoint Inventory

### T1: PR Review for Promotion (INTENTIONAL)

| Field | Value |
|---|---|
| Location | All image repos: `promote-testing-to-main.yml` |
| Current behavior | 2 maintainer approvals required before merge queue |
| Purpose | Accountability gate — human eyes on production promotions |
| Blocker | None — this is by design |
| Closest automation | Auto-approve after 7-day soak + zero crash signal (requires Gate 3) |
| Recommendation | **Keep as-is.** This is the R3 human gate (see `human-gates.md`). Once bonedigger crash signal (#424) is wired, consider reducing to 1 reviewer for promotions with >7 day soak + zero crashes. |

### T2: ISO Builds (AUTOMATABLE)

| Field | Value |
|---|---|
| Location | `projectbluefin/iso` — all `build-iso-*.yml` workflows |
| Current behavior | `workflow_dispatch` only — someone must manually trigger |
| Purpose | Build installation media after a stable promotion |
| Blocker | None — all build logic is already in `reusable-build-iso-anaconda.yml` |
| Closest automation | `repository_dispatch` from `execute-release.yml` after stable promotion |
| Recommendation | **Automate.** Wire `execute-release.yml` → `repository_dispatch` to `iso` repo with variant+digest payload. See artifact: `iso-auto-rebuild.yml`. |
| Impact | HIGH — eliminates the longest manual step in the release pipeline |

### T3: ISO Promotion to CDN (AUTOMATABLE)

| Field | Value |
|---|---|
| Location | `projectbluefin/iso/.github/workflows/promote-iso.yml` |
| Current behavior | Manual dispatch — someone copies ISOs from testing to production in CloudFlare R2 |
| Purpose | Make ISOs available on download page |
| Blocker | Currently no automated quality gate for ISOs |
| Closest automation | Auto-promote after ISO build succeeds + checksum verification |
| Recommendation | **Automate with gate.** Add checksum + size verification step, then auto-promote. Manual override remains via dispatch. |
| Impact | MEDIUM — removes human from the ISO publish path |

### T4: Dakota Build Machine (BLOCKED)

| Field | Value |
|---|---|
| Location | Dakota CI — `build.yml` needs self-hosted runner |
| Current behavior | Build depends on a local machine that is currently broken |
| Purpose | BuildStream requires specific tooling not available on GHA runners |
| Blocker | #497 — hardware needs repair/replacement |
| Closest automation | Move BuildStream to a cloud-hosted runner with BuildStream pre-installed |
| Recommendation | **Blocked on #497.** Long-term: containerize BuildStream build environment so it runs on standard GHA runners or a dedicated cloud VM. |
| Impact | HIGH — unblocks Dakota E2E and full pipeline parity |

### T5: actions Repo Merge (INTENTIONAL)

| Field | Value |
|---|---|
| Location | `projectbluefin/actions` — branch protection |
| Current behavior | Non-admin cannot merge; PRs always need human merge |
| Purpose | Supply chain protection — reusable actions are high blast radius |
| Blocker | None — security design decision |
| Closest automation | N/A — this is a security gate |
| Recommendation | **Keep as-is.** Actions are consumed by all repos. Human oversight is correct. |

### T6: v1 Tag Force-Push After actions Merge (AUTOMATABLE)

| Field | Value |
|---|---|
| Location | `projectbluefin/actions` — post-merge step |
| Current behavior | After merge, someone must `git tag -f v1 HEAD && git push --force origin v1` |
| Purpose | Update the `@v1` floating tag that consumers reference |
| Blocker | Requires `contents: write` with a token that has tag force-push permission |
| Closest automation | Post-merge workflow that auto-updates the tag |
| Recommendation | **Automate.** Add `.github/workflows/update-v1-tag.yml` triggered on push to `main`. See artifact: `actions-v1-tag-update.yml`. |
| Impact | MEDIUM — eliminates a common "forgot to update tag" failure mode |

### T7: MERGERAPTOR Secret Provisioning (BLOCKED)

| Field | Value |
|---|---|
| Location | `common/.github/workflows/sync-labels.yml` |
| Current behavior | Workflow requires `MERGERAPTOR_APP_ID` + `MERGERAPTOR_PRIVATE_KEY` secrets |
| Purpose | GitHub App token for cross-repo label sync |
| Blocker | #511 — secrets not yet provisioned |
| Closest automation | One-time setup: add secrets to org, then sync-labels runs fully auto |
| Recommendation | **Unblock #511.** This is a 5-minute admin task. Once done, label sync is fully automated across all repos. |
| Impact | LOW (one-time) but HIGH cumulative (label drift causes confusion) |

### T8: Key Rotation for Cosign Signing (AUTOMATABLE)

| Field | Value |
|---|---|
| Location | All repos using `SIGNING_SECRET` |
| Current behavior | Key-based signing with manual secret rotation |
| Purpose | Image integrity verification |
| Blocker | #513 — migration to keyless signing via OIDC |
| Closest automation | Keyless cosign via GitHub OIDC (Fulcio + Rekor) |
| Recommendation | **Migrate to keyless (tracked in #513).** Eliminates rotation entirely. Shared `sign-and-publish` action in `projectbluefin/actions` already designed for this. |
| Impact | HIGH — eliminates rotation risk + enables SLSA L2 provenance |

### T9: Release Changelog Quality (AUTOMATABLE)

| Field | Value |
|---|---|
| Location | `common/.github/workflows/release.yml` — heredoc `git log` |
| Current behavior | Raw git log output as release notes |
| Purpose | Inform users what changed |
| Blocker | None — git-cliff is a drop-in replacement |
| Closest automation | `git-cliff` with conventional commits classification |
| Recommendation | **Automate.** Install `git-cliff`, add `cliff.toml` config. See artifact: `cliff.toml`. |
| Impact | LOW — cosmetic improvement but signals maturity |

### T10: Stale PR Cleanup / Unclaim (INTENTIONAL)

| Field | Value |
|---|---|
| Location | All repos — stale agent PRs |
| Current behavior | Human runs `/unclaim` to release abandoned work |
| Purpose | Judgment on whether PR is truly abandoned vs. slow |
| Blocker | None — this requires context |
| Closest automation | Auto-close after N days with warning comment |
| Recommendation | **Keep as human-initiated.** The `release-reminder.yml` already alerts on stale promotions. For agent PRs, stale-bot with long grace period (14 days) could supplement but not replace human judgment. |

### T11: Hotfix Cherry-Pick Decision (INTENTIONAL)

| Field | Value |
|---|---|
| Location | `bluefin/.github/workflows/cherry-pick-to-stable.yml` |
| Current behavior | Label-triggered but human must decide what to label |
| Purpose | Judgment on which fixes are urgent enough for hotfix |
| Blocker | None |
| Closest automation | Auto-label P0 fixes, but human still decides severity |
| Recommendation | **Keep.** The workflow itself is automated; the decision to apply the label is correctly human. |

---

## Summary Matrix

| ID | Touchpoint | Class | Impact | Effort | Priority |
|---|---|---|---|---|---|
| T2 | ISO auto-rebuild | AUTOMATABLE | HIGH | LOW | **P1** |
| T6 | v1 tag auto-update | AUTOMATABLE | MEDIUM | LOW | **P1** |
| T8 | Keyless signing | AUTOMATABLE | HIGH | MEDIUM | **P2** |
| T3 | ISO auto-promote | AUTOMATABLE | MEDIUM | MEDIUM | **P2** |
| T9 | git-cliff changelog | AUTOMATABLE | LOW | LOW | **P3** |
| T7 | MERGERAPTOR secrets | BLOCKED | LOW | LOW | **Unblock** |
| T4 | Dakota build machine | BLOCKED | HIGH | HIGH | **Unblock** |
| T1 | Promotion review | INTENTIONAL | — | — | Keep |
| T5 | actions merge | INTENTIONAL | — | — | Keep |
| T10 | Stale PR unclaim | INTENTIONAL | — | — | Keep |
| T11 | Hotfix decision | INTENTIONAL | — | — | Keep |

## Automation Impact

- **Currently automated:** 88/97 workflows (91%)
- **Automatable with artifacts in this audit:** +3 touchpoints → 94%
- **Blocked (requires external action):** 2 touchpoints
- **Intentional human gates (keep):** 4 touchpoints
- **Target after implementation:** 93/97 workflows automated, 4 intentional human gates
