# Printer Application upstream source baseline

Part of [release-promotion](../SKILL.md) — reviewed upstream-code baseline and
lag for the three OpenPrinting-derived printer application forks
(`ps-printer-app`, `hplip-printer-app`, `gutenprint-printer-app`), tracked by
[common#1244](https://github.com/projectbluefin/common/issues/1244).

> Scope note: this covers **application source code** parity against
> `OpenPrinting/*`. Driver/FSDK version pins are owned separately by
> [common#1242](https://github.com/projectbluefin/common/issues/1242)
> (Renovate fork-processing) and the Ghostscript FSDK source tracker. Do not
> duplicate that ownership here.

## Re-derivation recipe

Each fork replaced upstream's Snap/Rockcraft build with a from-source
BuildStream (`.bst`) OCI appliance, so GitHub's `compare` API `files`/`commits`
counters are unreliable once the trees diverge structurally (it can report a
nonzero `behind_by` with an empty commit/file list). Verify with a real clone
instead:

```bash
for app in ps-printer-app hplip-printer-app gutenprint-printer-app; do
  git clone --quiet https://github.com/projectbluefin/$app.git $app
  cd $app
  git remote add upstream https://github.com/OpenPrinting/$app.git
  git fetch --quiet upstream
  git merge-base --is-ancestor upstream/master testing \
    && echo "$app: upstream/master is an ancestor of testing (no source lag)" \
    || echo "$app: testing has diverged from upstream/master — review needed"
  cd ..
done
```

## Baseline as of 2026-09-25

| Fork | Upstream default branch | `upstream/master` ancestor of `testing`? | Source lag |
|---|---|---|---|
| [`ps-printer-app`](https://github.com/projectbluefin/ps-printer-app) | `OpenPrinting/ps-printer-app@master` (`e54d07c`) | ✅ yes | None — `testing` (`dc2b941`) contains `e54d07c` plus the from-source FSDK OCI appliance work; only the Snap/Rockcraft/`docs/fsdk-ci.md` files were intentionally dropped. |
| [`hplip-printer-app`](https://github.com/projectbluefin/hplip-printer-app) | `OpenPrinting/hplip-printer-app@master` (`b3fc7f3`) | ✅ yes | None — `testing` (`18bb8a4`) contains `b3fc7f3`; the diff is entirely the replaced build system (`elements/`, `tests/`, `renovate.json`, Snap plugin/patch files removed in favor of the BuildStream layout). |
| [`gutenprint-printer-app`](https://github.com/projectbluefin/gutenprint-printer-app) | `OpenPrinting/gutenprint-printer-app@master` (`8712a9f`) | ✅ yes | None — `testing` (`263c1aa`) contains `8712a9f`; same pattern, plus an expanded `README.md`. |

**Finding: as of this baseline, all three forks' `testing` branches are fully
current with upstream — there is no unreviewed upstream application-code
change waiting to be proposed.** The GitHub REST `compare` endpoint's
`behind_by` counter (2/1/1 at time of writing) is misleading here: it counts
commits reachable from `upstream/master` that aren't reachable via the
*default-branch-relative* comparison GitHub computes internally, not real
divergence — `git merge-base --is-ancestor` against the actual `testing` ref
is the ground truth and shows zero lag on all three.

## What remains unresolved (needs a maintainer decision, not code)

The acceptance criteria in
[common#1244](https://github.com/projectbluefin/common/issues/1244) ask for
more than a one-time inventory: a standing, authorized proposal path that
opens reviewable upstream-code PRs into each fork's `testing` branch going
forward, using an approved GitHub App token, without importing upstream's
Snap/Rockcraft workflows or overwriting local FSDK patches. That is
infrastructure/credential work — which GitHub App, what token scope, whether
it reuses the `app/mergeraptor` identity already used for driver pins in
common#1242, and how "upstream source PR" is distinguished in CI from a
routine dependency-pin PR — and falls under this repo's Security/Design human
decision gates (`docs/skills/human-gates.md`). It should be scoped and
approved by a maintainer before an agent wires any automation or token access
into the three forks.

Until that path is designed, re-run the recipe above periodically to confirm no
new upstream lag has accumulated. The Renovate side of that flow landed on
2026-09-25 — all three forks now carry `"forkProcessing": "enabled"` in
`renovate.json` and the org runner extracts each one on `testing` (evidence and
the verification recipe: [ci-tooling →
Fork processing](../../ci-tooling/references/renovate-and-tools.md#fork-processing-in-the-org-runner)).
That changes only *dependency-pin* flow; it does not yet distinguish an
upstream source PR from a routine pin PR, which is the part still gated above.
