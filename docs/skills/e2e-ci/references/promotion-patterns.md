# E2E CI — Promotion Pipeline Gate Patterns

Part of [e2e-ci](../SKILL.md) — patterns for wiring E2E as a gate before publishing stream tags across any image repo.

## Promotion pipeline e2e gate patterns

These patterns apply when wiring e2e as a gate before publishing stream tags across any image repo.

### Never publish :testing at build time

The `reusable-build.yml` action supports `publish_stream_tag: "false"` to withhold the `:testing` tag from the initial push. The build publishes `:<sha>` and version alias tags only. A separate `promote-to-testing` job in `post-testing-e2e.yml` does `skopeo copy @digest → :testing` only after all e2e jobs succeed.

This ensures `:testing` always points to a digest that passed gate e2e — never a freshly-built untested image.

### promote-to-testing job pattern

```yaml
promote-to-testing:
  needs: [e2e, run-e2e, run-upgrade-test]
  if: >-
    needs.run-e2e.result == 'success' &&
    needs.run-upgrade-test.result == 'success'
  runs-on: ubuntu-latest
  timeout-minutes: 15
  permissions:
    packages: write
  steps:
    - name: Download all testing image digests
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        gh run download "${{ github.event.workflow_run.id }}" \
          --repo "${{ github.repository }}" \
          --pattern "image-digest-testing-*" \
          --dir /tmp/all-digests
    - name: Promote verified digests to :testing
      run: |
        REGISTRY="ghcr.io/${{ github.repository_owner }}"
        while IFS= read -r -d '' f; do
          while IFS='=' read -r image_name digest; do
            [[ -z "${image_name}" || -z "${digest}" || "${image_name}" == *"|"* ]] && continue
            skopeo copy --all "docker://${REGISTRY}/${image_name}@${digest}" \
                              "docker://${REGISTRY}/${image_name}:testing"
          done < "$f"
        done < <(find /tmp/all-digests -name "*.txt" -print0)
```

Use `--pattern "image-digest-testing-*"` (not `--name`) to download all flavor artifacts in one step. Parse the `=` format lines (skip `|` multi-arch lines with the `*"|"*` guard).

### TOCTOU guard — lock the tested SHA, not the live HEAD

The `lock-sha` step in a promotion workflow must use the source SHA from the `verify` step output (the SHA the tested image was built from), compare it to the current live branch HEAD, and fail early if they differ:

```bash
CURRENT_SHA=$(gh api repos/${{ github.repository }}/git/ref/heads/main --jq '.object.sha')
if [[ "${CURRENT_SHA}" != "${SOURCE_SHA}" ]]; then
  echo "::error::main has advanced since :testing was built — aborting"
  exit 1
fi
echo "locked_sha=${SOURCE_SHA}" >> "$GITHUB_OUTPUT"
```

Locking the live HEAD after testing is a race: `main` may advance between the e2e run and the lock step.

### cosign verify — anchor the certificate identity regexp

Always anchor with `^...$` and restrict to the specific publishing workflow and allowed ref patterns:

```
--certificate-identity-regexp "^https://github.com/<repo>/.github/workflows/publish\.yml@refs/heads/(main|gh-readonly-queue/main/.+)$"
```

An unanchored wildcard (e.g. `"https://github.com/<repo>/.github/workflows/"`) accepts signatures from any workflow file in the repo.

### cosign install on GHA runners

Never write directly to `/usr/local/bin`. Use `$RUNNER_TEMP` + `sudo install`:

```bash
curl -fsSL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
  -o "$RUNNER_TEMP/cosign"
sudo install -m 0755 "$RUNNER_TEMP/cosign" /usr/local/bin/cosign
```
