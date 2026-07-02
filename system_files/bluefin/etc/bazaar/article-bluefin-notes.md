## Variants promoted

| Variant | Tag | Digest |
|---|---|---|
| `bluefin` | `:stable` | `sha256:b0276d98a256` |
| `bluefin-nvidia` | `:stable` | `sha256:3a52047ed338` |

---
## Variants promoted

| Variant | Tag | Digest |
|---|---|---|
| `bluefin` | `:stable` | `sha256:a1cd03bc324a` |
| `bluefin-nvidia` | `:stable` | `sha256:e1785056efb5` |

---
## Variants promoted

| Variant | Tag | Digest |
|---|---|---|
| `bluefin` | `:stable` | `sha256:3e31c988e761` |
| `bluefin-nvidia` | `:stable` | `sha256:94f508eddcbf` |

---
![Release card](https://github.com/projectbluefin/bluefin/releases/download/stable-20260701/release-card.png)






> no package changes since the previous release. **0 packages** total.








## Desktop Screenshot

<img src="https://projectbluefin.github.io/testsuite/screenshots/bluefin-testing-smoke-latest.png" alt="Bluefin desktop — stable-20260701" width="100%">

*Captured from `bluefin:testing` during automated e2e validation — [testsuite](https://github.com/projectbluefin/testsuite)*


<details>
<summary>Supply chain verification</summary>

## Supply chain

This image is signed, attested, and ships a full SPDX-JSON SBOM.
Every artifact below is verifiable without trusting this release page.

**Tools required** — install via Homebrew or see links in each section:

```bash
brew install cosign oras slsa-verifier
```

---

### 1 — Verify the image signature

[cosign](https://github.com/sigstore/cosign) (Sigstore) verifies the keyless
OIDC signature created by GitHub Actions at build time.

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/projectbluefin/(bluefin|actions)/\.github/workflows/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20
```

A valid response lists the certificate subject and OIDC issuer. Any tampered
image will produce a verification error.

---

### 2 — Fetch and inspect the SBOM

The SBOM ([SPDX 2.3 JSON](https://spdx.dev/)) is attached to the image as an
[OCI referrer](https://oras.land) using
[ORAS](https://github.com/oras-project/oras) (CNCF graduated project).

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

The SBOM is also attached to this release as
[`bluefin.spdx.json`](https://github.com/projectbluefin/bluefin/releases/download/stable-20260701/bluefin.spdx.json).

---

### 3 — Verify the SBOM attestation

The SBOM is also stored as a signed
[GitHub SBOM attestation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)
in the Sigstore transparency log.

```bash
cosign verify-attestation \
  --type https://spdx.dev/Document \
  --certificate-identity-regexp '^https://github\.com/projectbluefin/(bluefin|actions)/\.github/workflows/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20 \
  | jq -r '.payload | @base64d | fromjson | .predicate.name'
```

---

### 4 — Verify SLSA Build L2 provenance

[slsa-verifier](https://github.com/slsa-framework/slsa-verifier) (OpenSSF)
checks that this image was built by the expected workflow on the expected
source repository — not on a developer's laptop or a forked CI runner.

```bash
slsa-verifier verify-image \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20 \
  --source-uri 'github.com/projectbluefin/bluefin' \
  --source-versioned-tag 'stable-20260701'
```

You can also inspect the raw provenance:

```bash
cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/projectbluefin/(bluefin|actions)/\.github/workflows/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/projectbluefin/bluefin@sha256:3e31c988e761c3541ee8842b8c658a04de067c920e8c58981834d6f97e867e20 \
  | jq -r '.payload | @base64d | fromjson | .predicate'
```

---

Full changelog and verification guide → https://docs.projectbluefin.io/changelogs

</details>


Full changelog → https://docs.projectbluefin.io/changelogs
