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

### Keyless signing — required permissions

`sign-and-publish` composite action requires these permissions on the calling job:

```yaml
permissions:
  id-token: write        # OIDC token for keyless signing
  attestations: write    # GitHub SLSA L2 attestation
  packages: write        # push to GHCR
  security-events: write # Trivy CVE gate upload
```

Do **not** add `SIGNING_SECRET` to new workflows — keyless OIDC has replaced it.

---

## Verifying a published artifact

### Verify cosign signature (legacy — key-based, pre-2026-06-11)

```bash
cosign verify \
  --key https://raw.githubusercontent.com/projectbluefin/common/main/cosign.pub \
  ghcr.io/projectbluefin/common:latest
```

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
