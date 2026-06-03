---
name: bluefin-ci
description: Bluefin CI/CD troubleshooting — use when a GitHub Actions workflow is failing, understanding the CI pipeline, checking build status, or diagnosing common build failures.
---

# Bluefin CI/CD Skill

## Powerlevel

- **Level:** 4


Diagnose and fix GitHub Actions failures in Bluefin repos.

Load with: `cat ~/src/skills/bluefin-ci/SKILL.md`

## When to Use

- A GitHub Actions workflow is failing in any Bluefin repo
- Understanding the CI pipeline structure or job dependencies
- Checking build status on a branch or PR
- Diagnosing common build failures (OOM, rate limits, signing, pre-commit)

## When NOT to Use

- Local build failures unrelated to CI — use `cat ~/src/skills/bluefin-build/SKILL.md`
- Package-level changes that need testing — use `cat ~/src/skills/bluefin-packages/SKILL.md`
- ISO-specific pipeline failures — use `cat ~/src/skills/bluefin-iso/SKILL.md`

## How It Works

1. Check current CI status: `bash /mnt/skills/user/bluefin-ci/scripts/check-ci.sh`
2. Identify failing job and read logs
3. Apply fix and re-run

## Usage

```bash
# Check CI on current branch
bash ~/src/skills/bluefin-ci/scripts/check-ci.sh

# Read full logs for failed run
gh run view RUN_ID --log-failed
```

## Output

check-ci.sh prints current run status and highlights failures.

## Common CI Failures

| Failure | Cause | Fix |
|---|---|---|
| `just check` fails | Justfile formatting | `just fix` |
| pre-commit fails | Lint/format issue | `pre-commit run --all-files` and fix |
| Build OOM | Not enough memory in runner | Reduce parallelism in workflow |
| Container pull rate limit | ghcr.io rate limit | Wait and re-run |
| COPR package not found | COPR repo down or package removed | Check COPR repo status |
| Cosign verification fails | Image not signed | Check signing step in workflow |
| Weekly promotion cannot find digest artifact | Artifact expired (1-day retention) | Push fresh commit to `main`; fix tracked in #212 |
| `generate-release.yml` fails: "No SBOM referrer found" | Testing-stream images lack SBOMs (skip flag in reusable-build.yml) | See `allow_missing_sbom=True` pattern in Learnings below; tracked in #213 |
| Renovate/mergeraptor PRs not auto-merging | Author filter in `renovate-automerge.yml` — must match both `renovate[bot]` and `app/mergeraptor` | Fix jq select: `select(.author.login == "renovate[bot]" or .author.login == "app/mergeraptor")` |
| Action bump PRs blocked by E2E failure | `pr-validation.yml` ran full testsuite on every PR including workflow-only changes | Fix: add `detect-changes` job using `projectbluefin/actions/bootc-build/detect-changes`; skip testsuite when no image paths changed |
| Hadolint / action pin Renovate PRs hitting E2E | Same root cause as above | Same fix — detect-changes skips e2e for non-image PRs so they automerge |

## Centralized actions (`projectbluefin/actions`)

**Rule:** Any action used in more than one workflow, or whose pin bump should not require touching a workflow file, belongs in a composite action in `projectbluefin/actions`. Do NOT add new action pins inline in workflow YAML.

### Available shared composite actions

| Name | Path | Purpose |
|---|---|---|
| `setup-runner` | `bootc-build/setup-runner` | Install just/cosign/oras/syft, optionally update podman, set up storage. Use `storage-backend: 'none'` to skip storage for non-build jobs |
| `detect-changes` | `bootc-build/detect-changes` | Outputs: `image_changed`, `should_build`, `nvidia_changed`, `image_flavors` |
| `validate-pr` | `bootc-build/validate-pr` | just check + shellcheck + hadolint + pre-commit. All action pins live here — Renovate updates this one file |
| `dnf-cache` | `bootc-build/dnf-cache` | Restore/save DNF build cache |
| `ghcr-cleanup` | `bootc-build/ghcr-cleanup` | Delete old images from GHCR |
| `preflight` | `bootc-build/preflight` | Pre-build cosign verify, key checks |
| `push-image` | `bootc-build/push-image` | Push OCI image to GHCR |
| `sign-and-publish` | `bootc-build/sign-and-publish` | Cosign sign, SBOM attach, attest |
| `rechunk` | `bootc-build/rechunk` | rpm-ostree rechunker step |

### Referencing shared actions

Pin to full SHA during development; move to `@v1` after the actions PR merges and maintainer advances the tag:

```yaml
uses: projectbluefin/actions/bootc-build/validate-pr@<SHA>   # during dev
uses: projectbluefin/actions/bootc-build/validate-pr@v1       # after release
```

### SHA drift check

Run this whenever reviewing PRs or noticing inconsistent Renovate bumps:

```bash
grep -rh "actions/checkout@" .github/workflows/ | sort -u
grep -rh "github/codeql-action" .github/workflows/ | sort -u
# Any file showing a different SHA than the others has drifted — align to the majority
```

### Files deleted / moved out of bluefin

- `.github/actions/bootstrap-just/` — **DELETED** (superseded by `bootc-build/validate-pr` which installs `just` internally)
- `reusable-build.yml` — **DELETED** (moved to `projectbluefin/actions/.github/workflows/reusable-build.yml@v1`)



## Workflow Files (complete inventory for projectbluefin/bluefin)

| Workflow | Trigger | Purpose |
|---|---|---|
| `pr-validation.yml` | PRs, merge_group | detect-changes → validate (shared action) → e2e smoke (skipped for non-image paths) |
| `pr-smoke.yml` | PRs touching build files | Full build + smoke test; pushes to `bluefin-pr` namespace (not `bluefin`) |
| `build-image-testing.yml` | Push to `main`, dispatch | Testing image builds via `projectbluefin/actions` reusable workflow |
| `post-testing-e2e.yml` | Testing build on `main` | Smoke+common gate; issues on failure |
| `weekly-testing-promotion.yml` | Tuesday 06:00 UTC | Full e2e → retag to :stable/:latest |
| `build-image-stable.yml` | Push to `stable`, dispatch | Stable rebuild |
| `build-image-latest-main.yml` | Push to `latest`, dispatch | Latest rebuild |
| `build-images.yml` | Manual dispatch | Rebuild all streams |
| ~~`reusable-build.yml`~~ | **DELETED** | Core build engine moved to `projectbluefin/actions/.github/workflows/reusable-build.yml@v1` |
| `run-testsuite.yml` | Called by all e2e workflows | **Canonical testsuite wrapper — always call this, never e2e.yml directly** |
| `nightly.yml` | 02:00 UTC daily | smoke+common+vanilla-gnome against :latest |
| `vulnerability-scan.yml` | Testing build + weekly | Grype → SARIF to Security tab |
| `renovate-automerge.yml` | PR Validation / PR Smoke success | Auto-merge Renovate/mergeraptor by risk tier |
| `e2e-dispatch.yml` | `/e2e` comment (write+ only) | Manual e2e on PR |
| `generate-release.yml` | Stable build, dispatch | GitHub Release + changelog |
| `copr-health-monitor.yml` | Daily | COPR staleness check |
| `check-cosign-key-rotation.yml` | Weekly | Key rotation detection → P1 issue |
| `cache-maintenance.yml` | Weekly | GHA cache pruning |
| `clean.yml` | Weekly | GHCR image cleanup (>90d) |
| `scorecard.yml` | Push to main, weekly | OSSF Scorecard |
| `cherry-pick-to-stable.yml` | `cherry-pick` label on PR | Backport via GitHub App token |
| `bonedigger.yml` | Issue events, daily | Issue lifecycle |
| `moderator.yml` | Issues/comments | AI spam detection |

> Never use `web_fetch` for GitHub URLs. See: github skill for the full rule.

## Re-running Failed Jobs

```bash
gh run rerun RUN_ID --failed-only
```

## Learnings

### Copilot PR review caught real bug in create-lts-pr.yml (added 2026-03-17)

Copilot reviewed PR #1195 and left 4 comments. All were valid. Key findings:

**What:** `git log origin/lts..origin/main --oneline` in the "Build commit list" step bloats after squash-merge promotions. Confirmed recurring in production.

**Why:** Squash-merge loses individual commit provenance. `lts` gets one commit, so the range walks back to the original divergence point and lists all historical commits.

**Fix:** Tree-hash anchor (see bluefin-lts skill → "NEVER use git log origin/lts..origin/main"). Fixed in PR #1197.

**|| true silences failures — don't use on body-update steps:**
`gh pr edit ... || true` masked API failures, leaving the promotion PR body stale with no signal. Removed in PR #1197. Maintainers rely on the PR body to know what's being promoted — silent stale body = risk of wrong merge.

**Don't repeat:** Never use `|| true` on `gh pr edit` or any step where failure would leave a human-visible artifact in a stale/wrong state.

### Workflow files in bluefin-lts (added 2026-03-17)

The bluefin-ci skill listed old/wrong workflow names. Correct list for bluefin-lts:
- `build-regular.yml`, `build-dx.yml`, `build-gdx.yml`, `build-regular-hwe.yml`, `build-dx-hwe.yml` — callers
- `reusable-build-image.yml` — reusable workflow all callers invoke
- `scheduled-lts-release.yml` — weekly Tuesday 6am UTC production release dispatcher
- `create-lts-pr.yml` — auto-creates/updates draft promotion PR (main→lts)
- `generate-release.yml` — creates GitHub Release after GDX build on lts

<!-- Background agents append here automatically -->

### generate-release fails: No SBOM referrer found (added 2026-05-28)

**What:** `generate-release.yml` fails at "Generate Release Text" with:
```
RuntimeError: No SBOM referrer found for ghcr.io/ublue-os/<image>@sha256:...
```

**Why:** `changelogs.py` fetches SBOMs for both the current and previous stable tags to build a package diff. Tags built before SBOM attachment was added to the pipeline have no SBOM referrer, causing a hard failure.

**Fix pattern applied (PR #4677):**
1. Add `allow_missing_sbom=True` to `get_packages()` — only suppresses "No SBOM referrer found" RuntimeError; all other errors still propagate
2. Pass `allow_missing_sbom=True` for both current and previous tag fetches
3. Use intersection of images (both sides have SBOM data) for the diff — avoids false "all packages added" output
4. Add `re.sub(r"\{pkgrel:[^}]+\}", "N/A", changelog)` to clean up unresolved version placeholders

**How to manually retrigger the stable release:**
```bash
gh workflow run generate-release.yml \
  --repo ublue-os/bluefin \
  --ref <branch-with-fix> \
  --field stream_name='["stable"]'
```
Watch: `gh run watch <RUN_ID> --repo ublue-os/bluefin`

**Note:** The `generate-release.yml` workflow creates a real GitHub release when triggered via `workflow_dispatch` for the "stable" stream. Confirm the release was created with `gh release list --repo ublue-os/bluefin`.

### dakota publish pipeline — e2e gates :latest (added 2026-05-30)

**Pattern:** `publish.yml` is a 4-stage pipeline: `setup → publish → e2e-gate → promote`

- `publish`: exports from CAS, pushes `:$sha`, signs, SBOM, attests — fires on all triggers
- `e2e-gate`: smoke-tests `ghcr.io/projectbluefin/dakota:$sha` via `projectbluefin/testsuite` — schedule/dispatch only
- `promote`: re-tags `:$sha` → `:latest` after e2e passes — schedule/dispatch only

`:latest` is never published without a passing e2e smoke test.

**e2e path filter behavior:** `e2e.yml` has `paths:` filter on `elements/`, `files/`, `patches/`, `Justfile`, `project.conf`. When a PR doesn't touch those paths, GitHub marks e2e as **skipped** — skipped counts as passing for the required status check. This is intentional: action pin bumps skip e2e; junction bumps in `elements/` run e2e.

**Ruleset (dakota):** Required status checks: `validate` + `e2e`. Bypass actors: OrganizationAdmin, Renovate (2740), mergeraptor (3069633).

**Key bypass actor IDs:**
- Renovate: integration ID `2740`
- mergeraptor: integration ID `3069633`

### projectbluefin/bluefin e2e — GNOME 50 AT-SPI changes (added 2026-05-31)

**Context:** `projectbluefin/bluefin` e2e smoke suite runs against headless GNOME 50 in QEMU via `projectbluefin/testsuite`. GNOME 50 introduced several AT-SPI and UI structural changes that break tests written for GNOME 47–48.

**Key GNOME 50 AT-SPI changes to know:**

| Widget | Old (≤48) | New (50) |
|---|---|---|
| Nautilus app name | `"nautilus"` | `"Files"` or `"org.gnome.Nautilus"` |
| Nautilus sidebar — Home | `roleName: list item`, name `"Home"` | `roleName: button`, name `"Home Home"` |
| Nautilus sidebar — bookmarks | `roleName: list item`, short name | `roleName: list item`, full path (e.g. `/var/home/user/Downloads`) |
| Nautilus breadcrumb | `roleName: toggle button`, name `"Downloads"` | `roleName: label`, full path string |
| Nautilus new-folder | Traditional dialog with AT-SPI text entry | Inline popover — AT-SPI entry may not be exposed in headless QEMU |
| Nautilus search bar | AT-SPI text entry visible after Ctrl+F | May not surface in headless QEMU |
| Extensions process | `pgrep -f gnome-extensions` finds it | Process name varies; pgrep unreliable |
| GNOME Shell DND | `_do_not_disturb.checked` via Shell.Eval | `_do_not_disturb` is `undefined`; use gsettings fallback |
| Notification banner | `banner.destroy()` dismisses | `banner.destroy()` has no effect in headless QEMU — make soft warn |

**Fix patterns:**

1. **Nautilus app lookup**: try multiple names in order: `"Files"`, `"org.gnome.Nautilus"`, `"nautilus"`, `"gnome-files"`. Patch `dtree.root.application` at instance level in `environment.py`.

2. **Sidebar navigation**: use `"button"` for Home, `"list item"` for bookmarks (substring match on short name still works with full-path widget name).

3. **Breadcrumb location check**: add a custom step `Nautilus location shows "{location}"` that calls `app.findChildren(lambda n: n.showing and location.lower() in (n.name or "").lower())`.

4. **New-folder/search-bar AT-SPI**: search broadly for any `text`/`entry` widget; demote to `WARNING + return` if not found (not hard failure) — coredump scenario covers crashes.

5. **Extensions soft-pass**: `_extensions_window(allow_process_fallback=True)` — if `_extensions_app()` succeeds (app is in AT-SPI tree) but no windows are found after 20s, return `None` (soft pass). No pgrep needed.

6. **DND Shell.Eval**: existing gsettings fallback in `_set_dnd_enabled()` covers GNOME 50; the Shell.Eval path logs TypeError noise but correctly falls through to gsettings.

**Testsuite merge flow (projectbluefin/testsuite):**
- Requires 2 approvals + CI via merge queue
- Enqueue via GraphQL: `gh api graphql -f query="mutation { enqueuePullRequest(input: { pullRequestId: \"${NODE_ID}\" }) { mergeQueueEntry { id position } } }"`
- After merge, update pin in `projectbluefin/bluefin`'s `.github/workflows/post-testing-e2e.yml` line 49 and merge via `gh pr merge N --repo projectbluefin/bluefin --squash --admin`
- Build triggers automatically on push to `main`; e2e triggers as `workflow_run` on "Testing Images" completing

### Testsuite pin management across projectbluefin repos (added 2026-05-31)

**Problem:** Testsuite SHAs drift silently — the same workflow (`e2e.yml`) gets pinned at different commits across workflows in the same repo and across repos. This causes inconsistent behavior and is hard to notice until something breaks.

**Renovate covers this automatically:** `config:best-practices` includes the `github-actions` manager which tracks `uses: owner/repo/.github/workflows/*.yml@sha` pins. No custom manager needed in `renovate.json5`. Renovate opens PRs to bump pins when testsuite advances.

**Exception:** `dakota` was using `@main` (unpinned) — Renovate can only track pins, not floating refs. Any repo using `@main` must be manually pinned first; Renovate will then maintain it.

**Always fetch testsuite before pinning:** The SHA at analysis time may differ from SHA at implementation time. Always run `git -C ~/src/testsuite fetch origin && git -C ~/src/testsuite rev-parse origin/main` immediately before writing pins.

**Pin alignment protocol:**
```bash
NEW=$(git -C ~/src/testsuite rev-parse origin/main)
grep -r "e2e.yml@" /path/to/repo/.github/workflows/ | grep -v "^Binary"
# Update all stale pins to $NEW
```

### projectbluefin e2e workflow pattern (added 2026-05-31)

The standard continuous e2e gate pattern across all projectbluefin image repos:

| Workflow | When | Suites | Image |
|---|---|---|---|
| `post-{build}-e2e.yml` | `workflow_run` after every push to `main` succeeds | `smoke,common` | `:testing` tag |
| `weekly-testing-promotion.yml` | Weekly, before promoting | `developer,vanilla-gnome,software,common` | `@digest` |
| `nightly.yml` | Cron 02:00 UTC daily | `smoke,common,vanilla-gnome` | `:latest` |
| `pr-testsuite.yml` | PR gate | `smoke` | `:lts-testing` |

The `post-build-e2e.yml` continuous gate was **missing from bluefin-lts** until 2026-05-31 (PR #16). All image repos should have this pattern.

**Suites not yet in GHA action (SSH-mode only):** `lifecycle`, `security`, `hardware` — testsuite epics #43/#44.
**Suite `dx`** requires a `dx` image variant in the build matrix; not yet wired.
**Suite `software`** is GHA-ready but only runs at weekly promotion (expensive).

### Mergeraptor automerge — author.login discrepancy (added 2026-05-31)

**Problem:** `renovate-automerge.yml` in both `projectbluefin/bluefin` and `projectbluefin/bluefin-lts` filtered on `author.login == "renovate[bot]"`. However, mergeraptor PRs appear as `author.login == "app/mergeraptor"`. This caused ALL mergeraptor dependency-update PRs to be silently skipped with "No open Renovate PR found for SHA ... — skipping" even when CI passed.

**Fix:** Update the jq filter to accept both:
```jq
select(.author.login == "renovate[bot]" or .author.login == "app/mergeraptor")
```

**Pre-existing LTS issue:** `build-gdx.yml` has been failing on every branch including `main` since at least 2026-05-31. This is a pre-existing build regression unrelated to automerge. It does NOT affect `PR Validation — testsuite` (which is in a separate workflow).

**Two-step dependency for LTS automerge to work:**
1. PR #16 merges (updates stale `12bd892e` pin → `969d471` in `pr-testsuite.yml`)
2. PR #17 merges (adds `app/mergeraptor` to automerge filter)

Once both land, future mergeraptor PRs will pass e2e and get auto-merged.

### PAT policy for projectbluefin (added 2026-05-31)

**PATs are FORBIDDEN in projectbluefin repos.** Never add `RENOVATE_TOKEN` or any PAT secret to workflow files.

Renovate authentication uses the **GitHub App** pattern via `actions/create-github-app-token` with `RENOVATE_APP_ID` + `RENOVATE_PRIVATE_KEY` org secrets — see `projectbluefin/renovate-config` for the canonical workflow.

Renovate runs are kicked off by triggering the self-hosted workflow in `projectbluefin/renovate-config`:
```bash
gh workflow run "Renovate Self-Hosted" --repo projectbluefin/renovate-config
```
Individual repos do NOT need their own `renovate.yml`. Renovate is managed centrally.

### projectbluefin/testsuite nightly CI — GNOME 50 fixes (added 2026-05-31)

**Context:** Made nightly CI green after GNOME 50 broke multiple suites. Run #26722510375: 35/35 passed.

**Key fixes and root causes:**

| Fix | Root Cause |
|---|---|
| `sys.exit(1)` → `raise` in all `environment.py` hooks | `sys.exit` in `before_scenario` terminates the entire behave process, not just the scenario |
| `qecore>=4.12` pin | qecore 3.35.3 on Fedora 44 never set `unsafe_mode` → `GetWindows` AccessDenied on all scenarios |
| `--tags ~quarantine` enforced in `behave_retry.py` | The tag was cosmetic — never actually passed to behave |
| `--bootloader` probed before use | Flag only exists in bootc ≥ 0.1.13; older LTS images reject it |
| `CC=gcc` for python-uinput on gnomeos | gnomeos compiled with cross-toolchain; `x86_64-unknown-linux-gnu-gcc` not found |
| `nvidia-persistenced` + `ublue-nvctk-cdi` in IGNORED_FAILED_UNITS | These always fail in QEMU without a physical GPU |
| `_scenario_skipped = False` for `@plain_ssh` scenarios in dx env | qecore only sets this flag inside `sandbox.before_scenario()`, which is skipped for SSH-only scenarios; after_all fires `AssertionError: No scenario matched tags` |

**Nightly matrix (9 jobs):**

| Image | Suites |
|---|---|
| `bluefin:latest/gts/lts` | smoke, developer, common |
| `bluefin-dx:latest/gts/lts` | smoke, developer, dx, common |
| `bluefin-nvidia-open:latest` | smoke, common |
| `bazzite-gnome:latest` | bazzite |
| `gnomeos-latest` | vanilla-gnome, software |

**`software` suite is gnomeos-only** — Bluefin ships Warehouse, not GNOME Software.  
**`bazzite-gnome` runs bazzite suite only** — not vanilla-gnome (bazzite makes shell modifications).  
**Use `bluefin-nvidia-open`**, not `bluefin-nvidia:latest` — nvidia-open is built daily; the non-open variant was last published Oct 2025 with bootc too old for `--bootloader`.

**All learnings documented in `projectbluefin/testsuite` `docs/skills/ops.md`, `suite-map.md`, `contributing.md`, `e2e-workflow.md`, and `RUNBOOK.md`.**

### common suite E2E — known CI failures (added 2026-06-02)

The `common` suite is unique: behave runs **directly on the GHA runner**, not inside a pre-built container. The runner SSHes to the VM at `127.0.0.1:2222` as `bluefin-test`.

**Brew CLI tools (eza/fd/ripgrep/bat/fzf/starship) — QUARANTINED**

`brew-setup.service` is masked via `KERNEL_ARGS systemd.mask=brew-setup.service` in the E2E workflow. All `cli.Brewfile` tools require brew-setup to run first — they are absent in CI. Quarantined in `tests/common/features/common_shell.feature`. Tracking issue: projectbluefin/testsuite#210.

**zsh / fish — QUARANTINED**

Both are installed as RPMs but fail under `bash -lc '...brew_shellenv...;  zsh --version'` SSH commands — PATH does not include `/usr/bin` for the fresh `bluefin-test` user in this non-interactive login context. Tracking issue: projectbluefin/testsuite#210.

**Dakota MOTD — FIXED (testsuite PR #208)**

`run_ssh()` in `ssh_steps.py` wraps commands in `bash -lc` (login shell) when `ssh_command_prefix` is set. This triggers `/etc/profile.d/ublue-motd.sh` → MOTD on stdout. Only Dakota prints a MOTD. Fix: create `~/.config/no-show-user-motd` in VM setup + use `stdout.strip().split('\n')[-1] == "ok"` assertion.

**SSH execution model:**
```python
# environment.py sets ssh_command_prefix = "eval $(brew shellenv)"
# run_ssh() wraps: bash -lc "eval $(brew shellenv); <actual cmd>"
# Side effect: login shell → triggers all profile.d scripts
```

Full architecture: `/var/home/jorge/src/common/docs/skills/e2e-ci.md`

### Pre-production CI/CD security audit (added 2026-06-01)

Full adversarial review of all 23 workflow files. 6 blocking + 8 non-blocking findings. Epic: **projectbluefin/bluefin#209**. Sub-issues: **#210–#215, #218–#225**.

**Blocking findings (P1):**

| # | File | Finding |
|---|------|---------|
| #210 | `reusable-build.yml` L26 | Architecture default `"['x86_64']"` uses single quotes — invalid JSON. `fromJson()` fails for callers not passing architecture. Fix: `'["x86_64"]'` |
| #211 | `weekly-testing-promotion.yml` L103-119 | Tests only `bluefin-main`, promotes ALL flavors incl. `nvidia-open` without coverage |
| #212 | `reusable-build.yml` L515 | Digest artifact retention `1d`. Weekly runs Tuesday 06:00 UTC; if no push in 24h, promotion fails. Raise to `7d` |
| #213 | `reusable-build.yml` L209+ | Testing stream skips SBOM (`if: inputs.stream_name != 'testing'`). Since promotion retags testing digests, `:stable`/`:latest` lack signed SBOMs. Breaks `generate-release.yml` changelogs |
| #214 | `Justfile` | Base image cosign verify is `|| echo "WARNING...Continuing"` — non-fatal. Compromised base flows through |
| #215 | `Justfile` | Cosign binary bootstrapped from `cgr.dev/chainguard/cosign:latest` (unverified). Should use same SHA-pinned `sigstore/cosign-installer` used for signing |

**Non-blocking findings (P2):**

| # | File | Finding |
|---|------|---------|
| #218 | `weekly-testing-promotion.yml` | No cosign verify before retag — unsigned digest can reach production |
| #219 | `weekly-testing-promotion.yml` L12-15 | `contents/actions/packages: write` at workflow level — read-only jobs get unnecessary write permissions |
| #220 | `build-image-*.yml` | All callers use `secrets: inherit` — only `GITHUB_TOKEN` needed; passes all org secrets to reusable workflow |
| #221 | `vulnerability-scan.yml` L48 | Scans `:testing` tag not build digest — TOCTOU: another build can push between trigger and scan |
| #222 | `pr-smoke.yml` L83-87 | Builds push `ghcr.io/projectbluefin/bluefin:pr-N-sha-XXX` under official namespace |
| #223 | `pr-validation.yml` L55 | Testsuite SHA `5d273131` differs from canonical `969d4713` in `run-testsuite.yml` + bypasses wrapper |
| #224 | `pr-validation.yml` L28 | `pip install pre-commit` unpinned — should use `pip install pre-commit==VERSION` |
| #225 | `build-image-stable.yml` | Parallel rebuild pathway (branch push → full rebuild) coexists with retag-only promotion — dual provenance models; needs maintainer decision |

**Verified-good security controls** (do not remove):
- All action pins use SHA (not floating tags)
- `permissions: {}` at workflow level + per-job escalation in `reusable-build.yml`
- `/e2e` dispatch gated to write/maintain/admin collaborators only
- Shell injection protected via env-variable binding for PR branch names
- GitHub App tokens (not PATs) for cherry-pick workflow
- `persist-credentials: false` in scorecard checkout
- OSSF Scorecard + Grype scanning active
- Weekly cosign key rotation detection via `check-cosign-key-rotation.yml`

### Centralization session — CI hardening #221/#222/#223 (added 2026-06-02)

**What was done (bluefin PR #250, actions PRs #33/#34):**

| Fix | Issue |
|---|---|
| `vulnerability-scan.yml` uses immutable digest instead of `:testing` tag | #221 |
| PR builds push to `bluefin-pr` namespace, not `bluefin` | #222 |
| All e2e callers now use `run-testsuite.yml` wrapper, not direct cross-repo call | #223 |
| `detect-changes` shared action skips e2e for non-image PRs | action-automerge fix |
| `validate-pr` shared action centralises hadolint/shellcheck/pre-commit/just-check | #254 |
| `actions/checkout` aligned to v6 in `check-cosign-key-rotation.yml` | #252 |
| `github/codeql-action/upload-sarif` aligned to v4 in `vulnerability-scan.yml` | #251 |
| `.github/actions/bootstrap-just` deleted | #253 |

**Dependency order for merging:** actions PR #33 (detect-changes) → actions PR #34 (validate-pr) → bluefin PR #250 (then update `@SHA` refs to `@v1`).

**PR smoke push namespace:** PR builds must push to `ghcr.io/projectbluefin/bluefin-pr`, not `bluefin`. The `clean.yml` workflow now also cleans `bluefin-pr` images older than 90d.
