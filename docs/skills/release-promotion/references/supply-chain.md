# Supply Chain — Current State and Artifact Verification

Part of [release-promotion](../SKILL.md) — Supply chain tooling status, required permissions for `sign-and-publish`, and commands to verify cosign signatures, SBOM, and GitHub attestations.

---

## Supply chain — current state and planned improvements

> **Note:** Supply chain tooling for this repo is being centralized. Do not add inline signing, SBOM, or scanning logic to `build.yml`. All of that belongs in `projectbluefin/actions`.

| Practice | Current state | Tracking |
|---|---|---|
| OCI image signing | ✅ Keyless OIDC — live as of 2026-06-11 ([common#595](https://github.com/projectbluefin/common/issues/595)) | `SIGNING_SECRET` removed — do not reference in new workflows |
| SBOM | ✅ syft — bundled in `sign-and-publish` composite action | — |
| SLSA L2 provenance | ✅ GitHub Actions attestation — bundled in `sign-and-publish` | — |
| CVE scanning | ✅ Trivy gate — bundled in `sign-and-publish` | — |
| Changelog quality | ✅ `git-cliff` — live as of [common#592](https://github.com/projectbluefin/common/pull/592) | — |

### Which job holds which permission

`build.yml` splits the work across two jobs, and their permissions differ. Copying one block onto the other is the usual mistake.

| Job | Permissions | Why |
|---|---|---|
| `build_push` (per-arch matrix) | `contents: read`, `packages: write`, `security-events: write` | `security-events: write` is for the Trivy SARIF upload — it lives here, not on `manifest` |
| `manifest` | `packages: write`, `id-token: write`, `attestations: write` | `id-token` for keyless OIDC, `attestations` for the SBOM + SLSA provenance attestations. No `contents:` entry at all |

`sign-and-publish` runs in `manifest` and needs `packages: write`, `id-token: write`, and `attestations: write`. It does **not** need `security-events: write`.

Do **not** add `SIGNING_SECRET` to new workflows — keyless OIDC has replaced it.

The keyless certificate identity is anchored in `build.yml`:

```
^https://github\.com/projectbluefin/(common|actions)/\.github/workflows/
```

---

## Verifying a published artifact


### Verify GitHub attestation (live — keyless, as of common#595)

```bash
gh attestation verify \
  oci://ghcr.io/projectbluefin/common:latest \
  --repo projectbluefin/common
```

### Verify SBOM attachment

```bash
# List attached referrers (SBOM, signatures, attestations)
oras discover ghcr.io/projectbluefin/common:latest

# Pull the SBOM
cosign verify-attestation \
  --type cyclonedx \
  ghcr.io/projectbluefin/common:latest | jq .payload | base64 -d | jq .
```
