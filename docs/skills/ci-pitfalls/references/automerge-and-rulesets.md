# Automerge and Rulesets — ci-pitfalls

Part of [ci-pitfalls](../SKILL.md) — Renovate automerge mechanics, the single `main` ruleset and its required check names, and the `create-github-app-token` cross-repo scoping failure.

---

## Renovate automerge — how it works in `common`

<!-- TODO(context7): verify platformAutomerge behavior and merge queue interaction against Renovate docs -->

`common` uses `platformAutomerge: true` in `renovate.json`. Renovate calls GitHub's native
auto-merge API when it opens an eligible PR (digest/pin/patch/minor). GitHub's auto-merge
enqueues the PR into the merge queue once all required checks pass — no separate workflow needed.

**Why `platformAutomerge` instead of a workflow:** `common/main` is governed by a merge queue
ruleset with `bypass_actors: []` — **nobody bypasses it, Renovate included.** Any workflow
attempting a direct `--squash` merge is rejected with `The merge strategy for main is set by the
merge queue`. `platformAutomerge` sidesteps this by using GitHub's own auto-merge API, which the
merge queue respects natively: the PR enqueues itself once its required checks are green and the
approval requirement is satisfied.

**Eligible update types:** `digest`, `pin`, `patch`, `minor`. Major bumps require human review.

**Stuck Renovate PR (required checks passed but PR not merging):** Check that auto-merge is
enabled on the PR (`gh pr view <N> --json autoMergeRequest`). If null, Renovate hasn't enabled
it — check the `matchUpdateTypes` rule. If enabled but not merging, verify all required checks
(`validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)`) show SUCCESS or
SKIPPED. Org admin can force-merge via:
```bash
gh api repos/projectbluefin/common/pulls/<N>/merge -X PUT -f merge_method=squash
```

**`build.yml` paths-ignore and workflow-only Renovate PRs:** Renovate bumps GitHub Actions SHAs
via digest PRs that only change `.github/workflows/**`. The `pull_request` trigger in `build.yml`
intentionally does NOT ignore `.github/workflows/**` so required Build checks always run on these
PRs and the merge queue can satisfy them. The `push` trigger DOES ignore `.github/workflows/**`
to avoid redundant post-merge rebuilds.

> There is no `renovate-automerge.yml` in this repo — it was deleted in
> [#783](https://github.com/projectbluefin/common/pull/783) and must not be re-added. See
> [workflow-map.md](../../workflow-map.md).

---

## Ruleset required status check names must match exact CI job names

<!-- TODO(context7): verify ruleset required status check matching semantics against GitHub branch protection / rulesets docs -->

`main` has **one** ruleset and no classic branch protection (`/branches/main/protection` returns
404). Its required checks must be the **exact** job `name:` values from `validate.yml` and
`build.yml`; a wrong name silently blocks the merge queue, because a check that never arrives is
indistinguishable from one still running.

| Ruleset | id | Required checks |
|---|---|---|
| `main — merge queue` | 17513003 | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |

**Past breakage:** a second ruleset once required `"Build and push image"` with no arch suffix — it
never matched any actual check and blocked every Renovate PR. That ruleset is gone; only 17513003
remains.

Re-derive before trusting the table:
```bash
gh api repos/projectbluefin/common/rulesets --jq '.[] | "\(.id) \(.name) \(.enforcement)"'
```

If `build.yml` or `validate.yml` job names change, update the ruleset in the same PR:
```bash
gh api --method PUT repos/projectbluefin/common/rulesets/17513003 --input ruleset.json
```

---

## create-github-app-token — do not use `owner` + `repositories` for cross-repo scoping

<!-- TODO(context7): verify create-github-app-token owner + repositories failure mode and cross-installation token creation against the action's docs -->

`create-github-app-token@v3` fails with `Invalid keyData` when `owner: <org>` + `repositories: <other-repos>` are specified. The action attempts cross-installation token creation which does not work reliably with this key format.

**Pattern to avoid:**
```yaml
uses: actions/create-github-app-token@...
with:
  owner: projectbluefin
  repositories: bluefin,bluefin-lts,dakota  # breaks
```

Use the token without `owner`/`repositories` restrictions — the mergeraptor app is installed org-wide and the default token already has access.

There is no `notify-downstream` job in `build.yml` — it was removed because cross-repo token
dispatch failed silently. How a merged `common` change actually reaches downstream is in
[downstream-propagation.md](../../release-promotion/references/downstream-propagation.md).
