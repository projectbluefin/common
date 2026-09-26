# Automerge and Rulesets — ci-pitfalls

Part of [ci-pitfalls](../SKILL.md) — Renovate automerge mechanics, the merge-queue-aware renovate-automerge.yml, ruleset required status check names, and create-github-app-token cross-repo scoping failure.

---

## Renovate automerge — how it works in `common`

Renovate applies every matching `packageRules` entry in order; later entries override
earlier values for the same option. Source: [Renovate packageRules
documentation](https://docs.renovatebot.com/configuration-options/#packagerules).

`common` uses `platformAutomerge: true` in `renovate.json`. For updates whose package
rules enable automerge, Renovate calls GitHub's native auto-merge API. GitHub's
auto-merge enqueues the PR into the merge queue once all required checks pass — no
separate workflow needed.

**Why `platformAutomerge` instead of a workflow:** `common/main` has a merge queue ruleset.
`github-actions[bot]` cannot bypass the merge queue, so any workflow attempting a direct
`--squash` merge would fail. `platformAutomerge` avoids this: Renovate is a bypass actor in the
PR review ruleset (actor_id 2740, bypass_mode: pull_request) and uses GitHub's own auto-merge
API, which the merge queue respects natively.

**Eligible update types:** `digest` and `pin` updates automerge for all managers. `patch`
and `minor` updates automerge for non-`github-actions` managers; GitHub Actions
`patch`/`minor` updates require human review, including `projectbluefin/actions`.
Major bumps require human review.

The inherited `github-actions (non-major)` group remains intact. Renovate only enables
automerge for a grouped branch when every upgrade in that branch is automerge-eligible;
therefore a mixed digest plus minor/patch group waits for human review as a whole.
Digest-only groups continue to automerge.

**Bypass actors in the PR review ruleset:**
- OrganizationAdmin — `bypass_mode: always`
- Renovate (actor_id 2740) — `bypass_mode: pull_request`
- Mergeraptor (actor_id 3069633) — `bypass_mode: pull_request`

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

---

## renovate-automerge.yml — merge queue on main requires --auto, not direct merge

<!-- TODO(context7): verify merge queue ruleset bypass actor behavior and gh pr merge --auto semantics against GitHub REST API docs -->

`common/main` has a **merge queue ruleset** (`main — merge queue`). `github-actions[bot]` is not a bypass actor for that ruleset. Calling `gh pr merge --squash` directly is rejected with:

```
The merge strategy for main is set by the merge queue
```

The reusable `reusable-renovate-automerge.yml` uses direct `--squash` merge (correct for `testing` branches which have no merge queue). Do **not** use it for `common`. The caller `renovate-automerge.yml` is intentionally inlined and uses `--auto --squash` to enqueue the PR. Since the workflow fires after a successful build, checks have already passed and the queue processes immediately.

**Symptom when broken:** The automerge workflow logs show `✅ Merged PR #N` but the PR remains open. The `||` catch in the merge command suppresses the real error; the success echo runs unconditionally after it.

**Fix already in place:** `renovate-automerge.yml` inlines the PR-find + enqueue logic with `gh pr merge --auto --squash` (PR #782). The reusable is not used here.

Do not "simplify" this back to the reusable — it will silently break again.

---

## Ruleset required status check names must match exact CI job names

<!-- TODO(context7): verify ruleset required status check matching semantics against GitHub branch protection / rulesets docs -->

The two branch rulesets on `main` must use the **exact** job names from `build.yml`. Wrong names silently block the merge queue — checks never arrive, queue waits forever.

Correct names (as of 2026-06-22):

| Ruleset | Required checks |
|---|---|
| `main — merge queue` (ID 17513003) | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |
| `main-review-required-with-renovate-bypass` (ID 17070417) | *(no required status checks — bypass actors cover Renovate/mergeraptor; merge queue ruleset handles build gate)* |

**Past breakage:** ruleset 17070417 had `"Build and push image"` (no arch suffix) — never matched any actual check, blocked every Renovate PR. Fixed 2026-06-22 by removing the check entirely from the review ruleset and using correct names in the merge queue ruleset.

If `build.yml` job names change, update both rulesets immediately via:
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

### notify-downstream token in common/build.yml

The `notify-downstream` job in `build.yml` uses `secrets.MERGERAPTOR_APP_ID` + `secrets.MERGERAPTOR_PRIVATE_KEY`. These secrets must be accessible to the `common` repo. If they are not, the job fails with:

```
The 'client-id' (or deprecated 'app-id') input must be set to a non-empty string.
```

Note: `vars.MERGERAPTOR_APP_ID` (variable, not secret) does **not** resolve in common — do not use it here. The correct ref is `secrets.MERGERAPTOR_APP_ID`. Verify at:
https://github.com/organizations/projectbluefin/settings/secrets/actions

The job has `continue-on-error: true` — build stays green while dispatches fail. Downstream tracking falls back to Renovate (bluefin/bluefin-lts) and dakota's daily cron.
