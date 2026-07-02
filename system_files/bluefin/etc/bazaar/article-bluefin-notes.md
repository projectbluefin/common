# Bluefin Release Notes

Welcome to the latest stable release of Project Bluefin. This release delivers a reliable, secure, and auto-updating operating system built directly on top of Fedora Silverblue and Universal Blue.

## Variants Promoted

| Variant | Tag | Digest |
|---|---|---|
| `bluefin` | `:stable` | `sha256:3e31c988e761` |
| `bluefin-nvidia` | `:stable` | `sha256:94f508eddcbf` |

---

## Desktop Screenshot

<img src="https://projectbluefin.github.io/testsuite/screenshots/bluefin-testing-smoke-latest.png" alt="Bluefin desktop — stable-20260701" width="100%">

*Captured from `bluefin:testing` during automated e2e validation — [testsuite](https://github.com/projectbluefin/testsuite)*

---

## Supply Chain & Image Integrity

Your system is fully signed and verified end-to-end. You can programmatically verify the signature of this OCI image with the following command:

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/projectbluefin/(bluefin|actions)/\.github/workflows/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20
```

### 1 — Verify the image signature

[cosign](https://github.com/sigstore/cosign) (Sigstore) verifies the keyless OIDC signature created by GitHub Actions at build time.

### 2 — Fetch and inspect the SBOM

The SBOM ([SPDX 2.3 JSON](https://spdx.dev/)) is attached to the image as an [OCI referrer](https://oras.land) using [ORAS](https://github.com/oras-project/oras) (CNCF graduated project).

```bash
# Discover the attached SBOM referrer
oras discover \
  --artifact-type application/vnd.spdx+json \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20

# Pull the SBOM to disk (replace SBOM_DIGEST with the digest from above)
oras pull \
  --artifact-type application/vnd.spdx+json \
  ghcr.io/projectbluefin/bluefin@<SBOM_DIGEST>
```

### 3 — Verify SLSA Build L2 provenance

[slsa-verifier](https://github.com/slsa-framework/slsa-verifier) (OpenSSF) checks that this image was built by the expected workflow on the expected source repository — not on a developer's laptop or a forked CI runner.

```bash
slsa-verifier verify-image \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20 \
  --source-uri 'github.com/projectbluefin/bluefin' \
  --source-versioned-tag 'stable-20260701'
```

---

Full changelog and verification guide → https://docs.projectbluefin.io/changelogs
