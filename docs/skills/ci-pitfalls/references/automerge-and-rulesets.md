# Automerge and Rulesets — ci-pitfalls

Part of [ci-pitfalls](../SKILL.md) — Renovate automerge mechanics, the merge-queue-aware renovate-automerge.yml, ruleset required status check names, and create-github-app-token `owner`/`repositories` scoping.

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
SKIPPED. If the PR still does not enqueue, inspect merge-queue status; do not bypass the ruleset.

**`build.yml` change detection and workflow-only Renovate PRs:** The `pull_request` trigger in
`build.yml` has no `paths-ignore` at all, so the required Build checks always report on every PR
(including documentation-only ones). Whether the image is actually rebuilt is decided by the
`image_changes` job, which diffs base against head with an exclude pathspec. Renovate bumps
GitHub Actions SHAs via digest PRs that only change `.github/workflows/**`; that path is
intentionally NOT in the `image_changes` exclude list, so those PRs still build and the merge
queue can satisfy the required checks. The `push` trigger DOES ignore `.github/workflows/**`
to avoid redundant post-merge rebuilds.

---

## Ruleset required status check names must match exact CI job names

The live `main` rulesets must require the **exact** job names emitted by
`build.yml` and `validate.yml`. A former unsuffixed `Build and push image`
requirement never matched the architecture-qualified jobs and stalled the
merge queue. Compare the live ruleset API and current CI run job names before
renaming a job; ruleset updates are human-owned, not a saved `PUT` recipe.

---

## create-github-app-token — scope the token with `owner` (and `repositories` when needed)

`actions/create-github-app-token@v3` takes `owner` and `repositories` as **optional** inputs, and the org's workflows use them to scope the token deliberately. Leaving both empty scopes the token to only the current repository; `owner: projectbluefin` scopes it to every repository the mergeraptor app is installed on. The action's own README documents all of these patterns as supported — `owner` + `repositories` is not a failure mode.

**Org-wide access (the common case):** the mergeraptor app is installed on the `projectbluefin` organization, so `owner: projectbluefin` grants access to all of its repositories. `factory-drift.yml` mints a token this way to read workflow files across consumers:
```yaml
uses: actions/create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1 # v3
with:
  client-id: ${{ secrets.MERGERAPTOR_APP_ID }}
  private-key: ${{ secrets.MERGERAPTOR_PRIVATE_KEY }}
  owner: projectbluefin
  permission-contents: read
```

**Scope to specific repos:** add `repositories` (comma- or newline-separated). `factory-health.yml` watches a single consumer repo:
```yaml
uses: actions/create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1 # v3
with:
  client-id: ${{ secrets.MERGERAPTOR_APP_ID }}
  private-key: ${{ secrets.MERGERAPTOR_PRIVATE_KEY }}
  owner: projectbluefin
  repositories: common
  permission-issues: write
```

`owner:` is also required when a workflow runs from a fork: the per-repo installation lookup (`GET /repos/{owner}/{repo}/installation`) 404s, and `owner:` switches to the owner-level lookup (ghostscript-printer-app `update-base.yml`, fsdk-containers#331).

Factory callers that combined `owner: projectbluefin` with a
`repositories:` list for `actions/create-github-app-token@v3` reported
`Invalid keyData` during cross-installation token creation. This is not proof
that the private key is malformed. Bonedigger's template-sync caller supplies
`repositories:` without `owner:`; inspect the owning repo's existing inputs
and App installation before changing scope. Do not add a new credential.
