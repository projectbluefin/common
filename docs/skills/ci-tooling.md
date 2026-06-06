---
name: ci-tooling
description: "Pre-commit floating-tag guard, SHA pinning policy, skill-drift workflow, consumer-contract validation, and Renovate OCI digest tracking for projectbluefin repos."
---

# CI tooling

## SHA pinning policy

**All third-party `uses:` references must be pinned to a full commit SHA with a version comment.** Floating tags (`@v4`, `@main`, `@latest`) are rejected by the pre-commit hook.

### Why

Floating tags are a supply chain attack vector. Any upstream action can be compromised and inject malicious code on the next workflow run without any change to your workflow file. SHA pins guarantee bit-for-bit reproducibility — the action you pinned is the action that runs, forever.

### The pattern

```yaml
# correct — full SHA + human-readable version comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4
uses: taiki-e/install-action@be26d15a6e9c3a1e0696f6f1f5e56b4e46d08c29 # v2.47.0

# rejected by pre-commit
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
```

### How to find the SHA for an action

```bash
# look up the tag's SHA
gh api repos/{owner}/{action}/git/ref/tags/{version} --jq '.object.sha'

# example
gh api repos/actions/checkout/git/ref/tags/v4.2.2 --jq '.object.sha'
```

Or browse the action's releases on GitHub and copy the full commit SHA from the tag.

### How to update a pinned SHA

When an action releases a new version:
1. Look up the new tag's SHA (command above)
2. Update the `uses:` line: `@<new-sha> # <new-version>`
3. Renovate handles most updates automatically once pins are tracked — see "Renovate vs pre-commit" below

### Internal `projectbluefin/` refs — different policy

Internal reusable workflow refs use a coordinated policy, not blanket SHA pinning:

- `lifecycle-caller.yml` files pin `projectbluefin/common/.github/workflows/lifecycle.yml@<SHA>` — Renovate manages those SHA updates
- Other internal `projectbluefin/` refs follow repo-local policy comments — read the comment in the workflow file before converting to a SHA
- Coordinate with maintainers before changing an internal ref policy

---

## Floating-tag guard

**Scope:** shared pre-commit hook active in `common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`. Parity work pending in other repos.

**Regex:** `uses:.*@(main|master|latest|v[0-9])`

The `no-floating-action-tags` hook blocks commits of workflow files containing floating `uses:` refs. It scans `.github/workflows/` YAML files.

### Renovate vs pre-commit

These two protections do different jobs:

- **The pre-commit hook** prevents new floating tags from entering the codebase
- **Renovate** updates existing SHA pins automatically once they are tracked

Use both. The hook enforces that refs are pinned at commit time. Renovate keeps them fresh.

---

## Skill drift detection

**Workflow:** `.github/workflows/skill-drift.yml`

`skill-drift.yml` is a PR gate used across projectbluefin repos. In `common`, it calls the reusable workflow `projectbluefin/actions/.github/workflows/skill-drift-check.yml` at a pinned commit SHA (so the local floating-tag guard does not reject the workflow).

Path mapping and failure handling: [`skill-drift.md`](./skill-drift.md)

---

## Renovate OCI digest tracking

`Containerfile` has two OCI image pins tracked by Renovate:

1. `docker.io/library/alpine:latest@sha256:...` via Renovate's built-in `dockerfile` manager
2. `ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:...` via a custom regex manager in `.github/renovate.json5`

### Why both managers exist

- `FROM docker.io/library/alpine:latest@sha256:...` is a standard Dockerfile dependency — the built-in `dockerfile` manager handles it
- `COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:...` is not covered by the default parser — a custom regex manager tracks it

### Rule when adding OCI pins

If you add new OCI image pins to `Containerfile`, also update `.github/renovate.json5` so Renovate can keep them current. Applies to both `FROM` and `COPY --from=` references. An untracked pin silently goes stale.

---

## Renovate versioned-binary tracking

`.github/renovate.json5` tracks versioned binaries downloaded in the build stage via custom regex managers:

| Binary | Source | Renovate pattern |
|---|---|---|
| `bonedigger` | `projectbluefin/bonedigger` GitHub releases | `BONEDIGGER_VERSION` in `system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` |

When adding a new binary pinned to a specific version in a script or just file, add a corresponding regex manager entry in `renovate.json5`.

**Scope:** shared pre-commit hook pattern for `projectbluefin` repos. It is currently live in `common`, `bluefin`, `bluefin-lts`, and `actions`; parity work remains in other repos.

The `no-floating-action-tags` hook blocks GitHub Actions from being committed with floating refs in workflow files.

**Regex:** `uses:.*@(main|master|latest|v[0-9])`

### What it blocks

Third-party actions must be pinned to a full commit SHA, with a human-readable version comment:

```yaml
uses: actions/checkout@abc123def456 # v4
uses: taiki-e/install-action@abc123def456 # v2
```

These floating refs are rejected:

```yaml
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
```

### Coverage

The hook scans `.github/workflows/` YAML files.

Any workflow `uses:` line pointing at `@main`, `@master`, `@latest`, or a floating major tag like `@v4` is rejected.

### Managed `projectbluefin/` refs

The ACMM audit treats some internal reusable workflows as a documented policy exception, not a lint cleanup target.

- Third-party actions should still be SHA-pinned.
- `projectbluefin/` internal reusable workflows should follow the repo-local policy comments rather than blanket float-to-`@main` cleanup.
- The old `projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main` exemption was retired when lifecycle ownership moved into `common`.
- Downstream `lifecycle-caller.yml` files now pin `projectbluefin/common/.github/workflows/lifecycle.yml@<SHA>`, and Renovate manages those SHA updates.
- If you are changing an internal `projectbluefin/` ref, follow the repo-local comment and coordinate with maintainers before converting it to a SHA.

### Renovate vs pre-commit

These two protections do different jobs:

- **Renovate** updates existing SHA pins automatically once they are already tracked
- **The pre-commit hook** prevents new floating tags from being introduced in the first place

Use both. Renovate keeps pinned refs fresh; the hook enforces that refs are pinned at commit time.

## Skill drift detection

**Workflow:** `.github/workflows/skill-drift.yml`

`skill-drift.yml` is a PR gate used across projectbluefin repos. In `common`, it calls the reusable workflow `projectbluefin/actions/.github/workflows/skill-drift-check.yml` at a pinned commit SHA so the local floating-tag guard does not reject the workflow.

### Repo path mapping

| Repo | code-paths | skill-paths |
|---|---|---|
| common | `.github/workflows/**`, `system_files/**`, `Containerfile`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin | `.github/workflows/**`, `build_files/**`, `Justfile`, `recipes/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin-lts | `.github/workflows/**`, `build_files/**`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| dakota | `.github/workflows/**`, `build_files/**`, `Justfile`, `elements/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| knuckle | `.github/workflows/**`, `cmd/**`, `internal/**`, `Justfile`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| testsuite | `.github/workflows/**`, `.github/actions/**`, `tests/**`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |

### When it fires

A PR that touches any repo's `code-paths` without also touching one of its `skill-paths` triggers the check.

This is advisory, not a hard merge block, but it should be treated as a prompt to update documentation while the implementation context is still fresh.

For `common`, the workflow now lives at `.github/workflows/skill-drift.yml` and uses the exact path mapping shown above.

## Renovate OCI digest tracking

`Containerfile` now has two OCI image pins tracked by Renovate:

1. `docker.io/library/alpine:latest@sha256:...` via Renovate's built-in `dockerfile` manager
2. `ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:...` via a custom regex manager in `.github/renovate.json5`

### Why both managers exist

- `FROM docker.io/library/alpine:latest@sha256:...` is a standard Dockerfile dependency, so the built-in `dockerfile` manager handles it
- `COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:...` is not covered by the default Dockerfile parser, so a custom regex manager tracks that digest

### Rule when adding more OCI pins

If you add new OCI image pins to `Containerfile`, also update `.github/renovate.json5` so Renovate can keep them current.

That applies to both:

- `FROM` instructions
- `COPY --from=` image references

If a pinned image is not represented in Renovate config, the digest will silently go stale.

## Renovate versioned-binary tracking

`.github/renovate.json5` also tracks versioned binaries downloaded in the `Containerfile` build stage via custom regex managers:

| Binary | Source | Renovate pattern |
|---|---|---|
| `bonedigger` | `projectbluefin/bonedigger` GitHub releases | `BONEDIGGER_VERSION` in `system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` |

When adding a new binary that is pinned to a specific version in a script or just file, add a corresponding regex manager entry in `renovate.json5` so the version stays current automatically.
