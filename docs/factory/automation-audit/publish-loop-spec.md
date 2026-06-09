# Fully Automated Publish Loop — Target Architecture

> Source trigger → build → test → sign/attest → publish → notify
> with zero human intervention on the happy path.

## Design Principles

1. **Event-driven, not cron-driven** — every action fires in response to a real state change
2. **Build once, promote the artifact** — never rebuild for production what was tested in staging
3. **Idempotent operations** — every step is safe to re-run
4. **Self-healing** — transient failures retry; persistent failures auto-file issues
5. **Human gates are explicit** — only where accountability requires judgment

---

## Target Pipeline (After Audit Recommendations)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FULLY AUTOMATED PUBLISH LOOP                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ SOURCE TRIGGER ────────────────────────────────────────────────────┐    │
│  │  Renovate PR auto-merged → push to testing branch                   │    │
│  │  Feature PR merged by maintainer → push to testing branch           │    │
│  │  Common layer updated → downstream rebase (Renovate digest bump)    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─ BUILD PHASE ──────────────────────────────────────────────────────┐    │
│  │  reusable-build.yml                                                 │    │
│  │  ├── Multi-arch OCI build (buildah + zstd:chunked)                  │    │
│  │  ├── Trivy CVE scan (CRITICAL = fail)                               │    │
│  │  ├── Push to ghcr.io/projectbluefin/<image>:testing                 │    │
│  │  ├── Keyless cosign sign (GitHub OIDC → Fulcio)                     │    │
│  │  ├── SBOM attach (CycloneDX via anchore/sbom-action)                │    │
│  │  └── SLSA L2 provenance (actions/attest-build-provenance)           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─ TEST PHASE ───────────────────────────────────────────────────────┐    │
│  │  post-testing-e2e.yml (fires on :testing push)                      │    │
│  │  ├── Resolve exact digest (deterministic target)                    │    │
│  │  ├── Run smoke + common suites in KubeVirt VM                       │    │
│  │  ├── [FUTURE] Installability gate (#423)                            │    │
│  │  └── Report pass/fail as commit status                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─ GATE PHASE ───────────────────────────────────────────────────────┐    │
│  │  promote-testing-to-main.yml (push to testing + daily heartbeat)    │    │
│  │  ├── Compare testing/main trees → create/update squash PR           │    │
│  │  ├── reusable-release-gate.yml:                                     │    │
│  │  │   ├── Cosign verify :testing signature                           │    │
│  │  │   ├── Dispatch E2E (smoke,common) → wait for result             │    │
│  │  │   ├── Check freshness (image age < 7 days for LTS)              │    │
│  │  │   └── Verify no open P0/P1 blockers                             │    │
│  │  ├── ┌──────────────────────────────────────────────┐               │    │
│  │  │   │ 👤 HUMAN GATE: 2 maintainer approvals        │               │    │
│  │  │   │    (R3 accountability — intentional)         │               │    │
│  │  │   └──────────────────────────────────────────────┘               │    │
│  │  └── Merge queue enqueue → auto-merge on approval                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─ RELEASE PHASE ────────────────────────────────────────────────────┐    │
│  │  execute-release.yml (fires on merged promotion PR)                 │    │
│  │  ├── reusable-execute-release.yml:                                  │    │
│  │  │   ├── Cosign verify :testing digest (pre-promote check)          │    │
│  │  │   ├── Poll-until-available (GHCR propagation)                    │    │
│  │  │   ├── skopeo copy :testing → :stable (digest promotion)          │    │
│  │  │   └── Cosign verify :stable (post-promote check)                 │    │
│  │  ├── reusable-release.yml:                                          │    │
│  │  │   ├── Generate SBOM (inline mode for promotion path)             │    │
│  │  │   ├── git-cliff changelog                                        │    │
│  │  │   ├── Release card (badge, notable packages, docs link)           │    │
│  │  │   └── Create/update GitHub Release                                │    │
│  │  ├── verify-release job:                                             │    │
│  │  │   ├── Verify :stable is signed                                    │    │
│  │  │   └── Verify GitHub Release exists                                │    │
│  │  └── dispatch-iso-rebuild job:                                       │    │
│  │      └── repository_dispatch → projectbluefin/iso                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─ ISO PHASE (NEW — currently manual) ───────────────────────────────┐    │
│  │  iso-auto-rebuild.yml (fires on repository_dispatch)                │    │
│  │  ├── Validate dispatch payload                                      │    │
│  │  ├── Build variant ISO (reusable-build-iso-anaconda.yml)            │    │
│  │  ├── Upload to CloudFlare R2                                        │    │
│  │  └── [FUTURE] Auto-promote after checksum verify                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─ NOTIFICATION PHASE ───────────────────────────────────────────────┐    │
│  │  ├── GitHub Release published (triggers watchers/subscribers)       │    │
│  │  ├── release-reminder.yml (alerts if promotion PR goes stale)       │    │
│  │  └── [FUTURE] Status dashboard update / Mastodon post               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Artifact Types Produced

| Artifact | Registry/Location | Trigger | Automated |
|---|---|---|---|
| OCI container image (:testing) | ghcr.io/projectbluefin/bluefin:testing | Push to testing | ✅ |
| OCI container image (:stable) | ghcr.io/projectbluefin/bluefin:stable | Promotion PR merge | ✅ |
| Cosign signature | Rekor transparency log | With image push | ✅ |
| SBOM (CycloneDX) | OCI referrer on image | With image push | ✅ (after #513) |
| SLSA L2 provenance | GitHub attestation API | With image push | ✅ (after actions#86) |
| GitHub Release | github.com releases | After promotion | ✅ |
| ISO (bootable media) | CloudFlare R2 | After stable promotion | ✅ (after iso-auto-rebuild) |
| Changelog (git-cliff) | In GitHub Release body | With release | ✅ (after cliff.toml) |

---

## Version Bumping and Tagging Strategy

| Component | Version scheme | Bump trigger | Human input needed |
|---|---|---|---|
| common | `v<YEAR>.<MONTH>` | Monthly cron | No (auto) |
| bluefin | `v<YEAR>.<MONTH>.<DAY>` | Each promotion merge | No (auto) |
| bluefin-lts | `v<YEAR>.<MONTH>.<DAY>-lts` | Each promotion merge (7-day floor) | No (auto) |
| dakota | `v<YEAR>.<MONTH>.<DAY>-dakota` | Each promotion merge | No (auto) |
| ISO | No version (latest overwrites) | After stable promotion | No (auto, after T2) |

**Idempotency guarantees:**
- `ncipollo/release-action` with `allowUpdates: true` — safe to re-run
- `skopeo copy` by digest — overwrites tag atomically
- ISO upload with checksum suffix — same content = same filename = idempotent

---

## Remaining Human-Required Decisions

After implementing all artifacts in this audit, exactly **4 decisions** remain human-only:

| # | Decision | Why human-only | Frequency |
|---|---|---|---|
| 1 | Approve promotion PR (2 reviews) | Accountability for production changes | Weekly |
| 2 | Approve actions repo PRs | Supply chain security | Ad-hoc |
| 3 | Assign priority (P0/P1) labels | Release impact judgment | Ad-hoc |
| 4 | `/unclaim` stale PRs | Context on abandoned vs. slow | Rare |

Everything else in the pipeline is fully automated or will be after implementing the artifacts in this audit.

---

## Implementation Order

| Phase | Artifacts | Effort | Impact | Dependencies |
|---|---|---|---|---|
| **Phase 1** (Quick wins) | `actions-v1-tag-update.yml`, `cliff.toml` | 1 day | Medium | None |
| **Phase 2** (ISO automation) | `iso-auto-rebuild.yml`, `iso-dispatch-snippet.yml` | 2 days | HIGH | ISO repo dispatch token |
| **Phase 3** (Supply chain) | `build-upgraded.yml` (keyless + SBOM + scan) | 3 days | HIGH | #513 decision from maintainers |
| **Phase 4** (Self-healing) | `retry-action.yml`, propagation polling | 1 day | Medium | None |
| **Phase 5** (Reliability) | Dakota cache-warm, digest pinning | 2 days | Medium | None |

**Total estimated effort:** 9 working days to reach 94% automation with 4 intentional human gates.
