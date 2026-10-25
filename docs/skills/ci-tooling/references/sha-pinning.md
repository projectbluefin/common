# SHA Pinning Policy and Floating-Tag Guard

Part of [ci-tooling](../SKILL.md) — Full SHA pinning rules, how to look up and update SHAs, internal `projectbluefin/` ref policy, and the floating-tag guard pre-commit hook.

---

## SHA pinning policy

**Every `uses:` reference in `.github/workflows/` is pinned to a full 40-character commit SHA with a version comment — external and internal alike.** Floating tags (`@v4`, `@main`, `@latest`) are rejected by the `no-floating-action-tags` pre-commit hook for external refs, and are not used for internal refs either.

### Why

Floating tags are a supply chain attack vector. Any upstream action can be compromised and inject malicious code on the next workflow run without any change to your workflow file. SHA pins guarantee bit-for-bit reproducibility.

### The pattern

```yaml
# correct — full SHA + human-readable version comment
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
uses: projectbluefin/actions/bootc-build/scan-image@e2ccd51b41d9bb3abd9caeac626fb15c95589c3c # v1

# rejected by pre-commit
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
```

The trailing comment names the tag the SHA came from. It is documentation, not the ref — `# v1` and `# main` after a SHA do not mean the workflow floats.

### How to find the SHA for an action

```bash
# look up the tag's SHA
gh api repos/{owner}/{action}/git/ref/tags/{version} --jq '.object.sha'

# example
gh api repos/actions/checkout/git/ref/tags/v4.2.2 --jq '.object.sha'
```

### How to update a pinned SHA

1. Look up the new tag's SHA (command above)
2. Update the `uses:` line: `@<new-sha> # <new-version>`
3. Renovate handles most updates automatically — root `renovate.json` automerges `digest` updates, which is how `projectbluefin/actions` bumps land

---

## Internal `projectbluefin/` refs are SHA-pinned too

Both internal refs in this repo are full SHA pins, and Renovate digest-tracks them:

| Caller file | Ref | Comment |
|---|---|---|
| `build.yml` (5 steps) | `projectbluefin/actions/bootc-build/{setup-runner,scan-image,push-image,create-manifest,sign-and-publish}@e2ccd51b41d9bb3abd9caeac626fb15c95589c3c` | `# v1` |
| `run-testsuite.yml` | `projectbluefin/testsuite/.github/workflows/e2e.yml@8d9ca0b35a25a9c2072067fcdc145268f7e08be5` | `# main` |

`run-testsuite.yml` is the only place the testsuite pin appears; `e2e.yml`, `pr-e2e.yml`, and `promotion-candidate-e2e.yml` all call it through the local `./.github/workflows/run-testsuite.yml` path.

### The outstanding inconsistency

Two artifacts still describe the old managed-floating-tag model, and neither is enforced:

1. The `no-floating-action-tags` hook **exempts** `projectbluefin/*` via a negative lookahead — but **no ref in this repo relies on that exemption.** The exemption is dead permission: removing it would not fail a single line here.
2. `projectbluefin/actions`'s own `README.md` still tells adopters "Pin to `@v1` for stability. Renovate manages updates in consuming repos," and its examples use `@v1`. That is the opposite of what its largest consumer does.

Do not resolve this by loosening `common`. If you touch either artifact, tighten toward SHA pins.

### Why SHA-pinning internal refs used to be discouraged

A stale internal pin fails obscurely: when the pinned commit predates the called file's existence, GitHub emits `startup_failure: This run likely failed because of a workflow file issue` and nothing else (June 2026, [bonedigger#27](https://github.com/projectbluefin/bonedigger/issues/27)). The mitigation is not floating tags — it is Renovate keeping the digest current, which is what root `renovate.json` does. See [`ci-pitfalls`](../../ci-pitfalls/SKILL.md) for the incident.

**Trap: bad semver tags.** The `v1.1.0` tag in `projectbluefin/actions` was cut from commit `95dc404b` (May 31 2026), which predates `lifecycle.yml` being added to that repo (June 10). Anyone who pinned to `v1.1.0` got a broken caller. Verify a tag's commit actually contains the file you are calling before taking its SHA.

---

## Floating-tag guard

**Hook:** `no-floating-action-tags`, defined locally in `.pre-commit-config.yaml`.

**Regex:** `uses:(?!.*projectbluefin/).*@(main|master|latest|v[0-9])`

**Scope:** `types: [yaml]`, `files: '\.github/workflows/'` — it is a pygrep hook, so it only ever sees this repo's workflow files. Any claim about it being "active in bluefin, bluefin-lts, dakota, actions" is a claim about *those* repos' own `.pre-commit-config.yaml`, not about anything in this one.

Current state in `common`: zero violations, and zero refs depend on the `projectbluefin/` exemption.

### Renovate vs pre-commit

These two protections do different jobs:

- **The pre-commit hook** prevents new floating tags from entering the codebase
- **Renovate** updates existing SHA pins automatically once they are tracked — see [renovate-and-tools.md](renovate-and-tools.md) for which config file actually governs

Use both. The hook enforces that refs are pinned at commit time. Renovate keeps them fresh.

### Known pin inconsistency inside this repo

`copilot-setup-steps.yml` pins `actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7`; every other workflow pins `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7`. Both carry the same `# v7` comment. Align `copilot-setup-steps.yml` the next time you touch it.
