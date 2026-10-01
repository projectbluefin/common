# SHA Pinning Policy and Floating-Tag Guard

Part of [ci-tooling](../SKILL.md) and [`ACTIONS-SECURITY.md`](../../../../ACTIONS-SECURITY.md) — Full SHA pinning rules, how to look up and update SHAs, internal `projectbluefin/` ref policy, and the floating-tag guard pre-commit hook.

---

## SHA pinning policy

**All third-party `uses:` references must be pinned to a full commit SHA with a version comment.** Floating tags (`@v4`, `@main`, `@latest`) are rejected by the pre-commit hook.

### Why

Floating tags are a supply chain attack vector. Any upstream action can be compromised and inject malicious code on the next workflow run without any change to your workflow file. SHA pins guarantee bit-for-bit reproducibility.

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

### How to update a pinned SHA

1. Look up the new tag's SHA (command above)
2. Update the `uses:` line: `@<new-sha> # <new-version>`
3. Renovate handles most updates automatically once pins are tracked

### Internal `projectbluefin/` refs — managed tags, not SHA pins

**`projectbluefin/` internal workflow refs use managed floating tags (`@main` or `@v1`), not SHA pins — with one documented exception: the `bonedigger.yml` lifecycle retention pins described below.**

The `no-floating-action-tags` pre-commit hook exempts all `projectbluefin/` refs via a negative lookahead. External refs (`actions/`, `docker/`, `taiki-e/`, etc.) are still required to be SHA-pinned.

SHA-pinning internal `projectbluefin/` workflow refs causes a factory cascade: every commit to `projectbluefin/actions` requires manual SHA bumps in all consumers (common, bluefin, bluefin-lts, dakota). Worse, a stale pin silently broke when the pinned commit predated the called file's existence, emitting only `startup_failure: This run likely failed because of a workflow file issue` with no further diagnosis (June 2026, bonedigger#27). The failure mode is worse than the risk of managed-tag drift. See [`ci-pitfalls.md`](../../ci-pitfalls/SKILL.md) for the full incident.

**Current state (post June 2026 cleanup):**

| Caller file | Repo(s) | Calls | Ref |
|---|---|---|---|
| `bonedigger.yml` | bluefin, bluefin-lts, dakota, knuckle | `projectbluefin/bonedigger/.github/workflows/lifecycle.yml` | full SHA retention pin (`d530767`, tag `v1`; dakota `9c5faf6`) — file removed from `main` in `bonedigger#40` (2026-09-29), so the pins still resolve and run but cannot be bumped forward |
| `run-testsuite.yml` | bluefin, bluefin-lts, dakota | `projectbluefin/testsuite/.github/workflows/e2e.yml` | `@main` |

**Note:** the `bonedigger.yml` callers are the one internal ref that is a full
SHA pin rather than a managed floating tag. `lifecycle.yml` was removed from
`projectbluefin/bonedigger`'s `main` (`bonedigger#40`, 2026-09-29; issue
lifecycle is now Hive-managed), so each consumer pins the full SHA at which the
workflow is retained — a retention pin, not a normal managed-tag call. This is
distinct from the anti-pattern below: the pinned SHAs resolve to a file that
still exists, so they do not hit the `startup_failure` cascade.

**Anti-pattern to avoid:** SHA-pinning `projectbluefin/actions` workflow refs, or SHA-pinning `projectbluefin/bonedigger` refs for any reason other than the lifecycle retention pins noted above. When a SHA predates the file's existence in the repo, GitHub emits `startup_failure: This run likely failed because of a workflow file issue` with no further diagnosis. See [bonedigger#27](https://github.com/projectbluefin/bonedigger/issues/27).

**Trap: refs that do not contain the called file.** A valid tag or SHA does not guarantee that the requested workflow exists at that ref. Verify the exact repository, workflow path, and ref before using it. `projectbluefin/actions` does not currently contain a lifecycle workflow; the historical lifecycle callers target `projectbluefin/bonedigger`, as documented in [label-workflow.md](../../label-workflow.md). For managed-tag consumers, use the repository's supported floating tag rather than an old semver tag.

---

## Floating-tag guard

**Scope:** shared pre-commit hook active in `common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`. Parity work pending in other repos.

**Regex:** `uses:(?!.*projectbluefin/).*@(main|master|latest|v[0-9])`

The `no-floating-action-tags` hook blocks commits of workflow files containing floating `uses:` refs. It scans `.github/workflows/` YAML files. All `projectbluefin/` refs are exempted via negative lookahead — they use managed floating tags by design. All external refs are subject to the hook.

### If you narrow the exemption, include reusable-workflow subpaths

If the exemption is narrowed from `projectbluefin/.*` to specific internal repos (for example `actions|bonedigger`), the negative lookahead must allow an optional subpath before `@`:

```regex
uses:(?!.*projectbluefin\/(?:actions|bonedigger)(?:\/[^@]*)?@).*@(main|master|latest|v[0-9]+)\b
```

The key fragment is `(?:\/[^@]*)?`. Without it, reusable workflow refs such as `projectbluefin/bonedigger/.github/workflows/sync-templates.yml@main` or `projectbluefin/testsuite/.github/workflows/e2e.yml@main` can be falsely matched as forbidden floating tags.

### What the floating-tag hook blocks

Third-party actions must be pinned to a full commit SHA with a human-readable version comment. These floating refs are rejected:

```yaml
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
uses: projectbluefin/testsuite/.github/workflows/e2e.yml@main  # CORRECT — internal ref, exempt from the hook
```

### Repos with managed tags (exempt)

All `projectbluefin/` internal refs are exempt from the hook. Current usage:
- `projectbluefin/actions` — `@v1` (common, bluefin, bluefin-lts, dakota build workflows)
- `projectbluefin/bonedigger` — the `lifecycle.yml` ref is a full SHA retention pin (the file was removed from `main` in `bonedigger#40`), not a managed floating tag
- `projectbluefin/testsuite` — `@main` (managed floating tag, same policy as all internal refs)

External actions (everything outside `projectbluefin/`) must use full SHA pins.

### Renovate vs pre-commit

These two protections do different jobs:

- **The pre-commit hook** prevents new floating tags from entering the codebase
- **Renovate** updates existing SHA pins automatically once they are tracked

Use both. The hook enforces that refs are pinned at commit time. Renovate keeps them fresh.
