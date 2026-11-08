# Build and Push — ci-pitfalls

Part of [ci-pitfalls](../SKILL.md) — rootless buildah vs root podman storage namespace separation, and GHCR login required before cosign signing.

---

## build.yml — rootless buildah vs root podman storage

`build.yml` uses `redhat-actions/buildah-build` which stores images in **rootless user storage** (`~/.local/share/containers`). The `push-image` composite action uses `sudo podman push` which reads **root storage** (`/var/lib/containers`). These are different namespaces — the push will fail with `image not known` if the image is not in root storage.

**Fix already in place:** After `Export image for scanning`, a `sudo skopeo copy` step promotes the docker-archive into root `containers-storage` so `push-image` finds it.

```yaml
- name: Promote image to root storage for push
  if: github.event_name != 'pull_request'
  shell: bash
  run: |
    sudo skopeo copy \
      "docker-archive:/tmp/scan-image.tar:${{ env.IMAGE_NAME }}:${{ steps.generate-tags.outputs.local_tag }}" \
      "containers-storage:${{ env.IMAGE_NAME }}:${{ steps.generate-tags.outputs.local_tag }}"
```

Do not remove this step. Without it every push-to-GHCR fails silently until the next build.

---

## build.yml — GHCR login required before cosign signing

The `sign-and-publish` composite action's internal step order is: cosign sign (step 5) → ORAS registry login (step 12). Cosign has no GHCR credentials at step 5 and fails UNAUTHORIZED when pushing the signature blob.

**Fix already in place:** A `docker/login-action` step runs immediately before `sign-and-publish` in the manifest job.

Do not remove this step or reorder it after sign-and-publish.
