# Automation Audit — Project Bluefin Factory

> Generated: 2026-06-09 | Author: Copilot (autoresearch loop, 15 iterations)

## Executive Summary

The projectbluefin factory is **91% automated** across 97 workflows in 6 repos. This audit identifies the remaining gaps and provides ready-to-deploy artifacts to reach **97% automation** with only 4 intentional human gates remaining.

**Key findings:**
- ISO builds are the weakest link (25% automation — fully manual dispatch)
- Supply chain tooling (SBOM, SLSA, keyless signing) is designed but not deployed
- Self-healing patterns (retry, token health) don't exist yet
- 4 of 7 non-deterministic steps are already mitigated

**Total effort to implement all recommendations:** 9 working days

---

## Audit Artifacts

| # | File | Purpose |
|---|---|---|
| 1 | [`pipeline-map.md`](pipeline-map.md) | Complete mapping of 97 workflows across 6 repos |
| 2 | [`manual-touchpoints.md`](manual-touchpoints.md) | 11 manual touchpoints classified and prioritized |
| 3 | [`non-deterministic-steps.md`](non-deterministic-steps.md) | 7 ND steps audited, 3 actionable fixes |
| 4 | [`failure-modes.md`](failure-modes.md) | 7 failure modes with YAML hardening patterns |
| 5 | [`publish-loop-spec.md`](publish-loop-spec.md) | Target architecture for fully automated pipeline |
| 6 | [`implementation-roadmap.md`](implementation-roadmap.md) | 7-phase prioritized roadmap with dependency graph |

## Implementation Artifacts (Ready to Deploy)

| # | File | Deploy to | Addresses |
|---|---|---|---|
| 7 | [`iso-auto-rebuild.yml`](iso-auto-rebuild.yml) | `iso/.github/workflows/` | T2: Manual ISO builds |
| 8 | [`iso-dispatch-snippet.yml`](iso-dispatch-snippet.yml) | Image repo `execute-release.yml` | T2: Dispatch trigger |
| 9 | [`actions-v1-tag-update.yml`](actions-v1-tag-update.yml) | `actions/.github/workflows/` | T6: Manual tag push |
| 10 | [`build-upgraded.yml`](build-upgraded.yml) | `common/.github/workflows/build.yml` | T8: Key-based signing |
| 11 | [`cliff.toml`](cliff.toml) | `common/` root | T9: Raw changelog |
| 12 | [`release-with-cliff.yml`](release-with-cliff.yml) | `common/.github/workflows/release.yml` | T9: + E2E gate |
| 13 | [`retry-action.yml`](retry-action.yml) | `actions/actions/retry/` | FM1, FM2: No retry |
| 14 | [`check-token-health-action.yml`](check-token-health-action.yml) | `actions/actions/check-token-health/` | FM3: Token expiry |
| 15 | [`dakota-cache-warm.yml`](dakota-cache-warm.yml) | `dakota/.github/workflows/` | ND1: Cold-start timeout |

---

## Remaining Human Gates (Intentional — Do Not Automate)

| Gate | Rationale |
|---|---|
| 2 maintainer reviews on promotion PR | Accountability for production changes |
| Human merge on `actions` repo | Supply chain security (reusable actions = high blast radius) |
| P0/P1 priority assignment | Release impact requires judgment |
| `/unclaim` on stale PRs | Context on abandoned vs. in-progress work |

---

## How to Use This Audit

1. **Start with the roadmap** ([`implementation-roadmap.md`](implementation-roadmap.md)) — it has the priority order and dependency graph
2. **Pick a phase** — Phases 1-4 and 7 have no dependencies and can start immediately
3. **Deploy the artifact** — Each YAML file has deployment instructions in its header comments
4. **Validate** — Each phase in the roadmap has specific validation steps
5. **Track** — File GitHub issues per the tracking section in the roadmap

---

## Design Decisions Required From Maintainers

| Decision | Context | Recommendation |
|---|---|---|
| Keyless signing migration (#513) | Eliminates SIGNING_SECRET rotation + enables SLSA | Approve — standard practice for OIDC-capable repos |
| ISO dispatch token type | App vs. PAT for cross-repo dispatch | GitHub App (more secure, auditable) |
| MERGERAPTOR secrets (#511) | One-time admin provisioning for label sync | Provision — 5 minute task, high cumulative value |

---

## Iteration Log

See [`results.tsv`](results.tsv) for the full iteration history.
