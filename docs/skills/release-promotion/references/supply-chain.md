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

## Enforcing signatures at pull time — containers policy.json

Signing only matters if the pull path rejects unsigned images. The base image
pull is enforced by
`system_files/shared/etc/containers/policy.json`, consumed by the
`containers/image` library at `bootc switch` / `bootc install` time.

- The `"default"` scope is `reject`, so any registry without an explicit entry
  falls through to the `""` docker catch-all.
- `quay.io/toolbx-images` and `ghcr.io/ublue-os` are enforced with
  `sigstoreSigned` (`keyPath`/`keyPaths` + `matchRepository`).
- `ghcr.io/projectbluefin` (the base image every consumer pulls) is enforced
  with a keyless `sigstoreSigned` entry: Fulcio CA (`fulcio_v1.crt.pem`),
  Rekor public key (`rekor.pub`), and `subjectRegExp` scoped to
  `^https://github\.com/projectbluefin/[^/]+/\.github/workflows/` — the same
  certificate identity the `sign-and-publish` action emits
  (`.github/workflows/build.yml`).

The `fulcio` block uses `oidcIssuer` + `subjectRegExp` (or `subjectEmail`),
**not** a top-level `fulcioIssuer`: `containers/image` policy parsing only
recognises those fields inside the `fulcio` object, so a `fulcioIssuer`
key is silently ignored and the scope falls back to the catch-all.

> The `insecureAcceptAnything` catch-all on the `""` docker scope is left in
> place on purpose. Removing it would reject every registry without an explicit
> entry (Fedora base, rpm-ostree layers, third-party COPRs) and requires
> validating the entire consumed-registry surface before it is safe. Narrowing
> it is a follow-up, not this change.

### Verifying the policy

```bash
# The projectbluefin entry references these trust roots — they must exist:
ls -1 system_files/shared/usr/lib/pki/containers/fulcio_v1.crt.pem \
      system_files/shared/usr/lib/pki/containers/rekor.pub

# The policy must be valid JSON:
python3 -c "import json;json.load(open('system_files/shared/etc/containers/policy.json'))"
```

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
