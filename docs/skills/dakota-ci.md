---
name: dakota-ci
description: Use when debugging CI failures in projectbluefin/dakota, understanding the build pipeline, modifying the GitHub Actions workflow, working with the cache.projectbluefin.io remote CAS, or troubleshooting why a BST build succeeded locally but fails in CI
---

# CI Pipeline Operations (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-ci/SKILL.md`

## When to Use

- Debugging a CI build failure in projectbluefin/dakota GitHub Actions
- Understanding or modifying the `.github/workflows/build.yml` pipeline
- Troubleshooting remote cache connectivity or mTLS authentication issues
- Investigating why a build succeeds locally but fails in CI
- Understanding GHCR image publishing or build artifact retention

## When NOT to Use

- Diagnosing an individual element build failure (log shows the element) → use `dakota-debugging`
- Writing or modifying `.bst` element files → use `dakota-buildstream`
- Understanding what packages flow into the OCI image → use `dakota-oci-layers`

## Overview

The CI pipeline (`.github/workflows/build.yml`) builds the Bluefin OCI image inside the bst2 container on **standard `ubuntu-24.04` GitHub-hosted runners**, validates it with `bootc container lint`, and pushes to GHCR on every successful build (not just main). Caching uses a **self-hosted BuildStream CAS server at `cache.projectbluefin.io:11002`** with mTLS authentication, which acts as a remote artifact + source cache + remote execution service.

There are **no Blacksmith runners**, no sticky disks, no R2, and no rclone in this pipeline.

## Quick Reference

| What | Value |
|---|---|
| Workflow file | `.github/workflows/build.yml` |
| Runner | `ubuntu-24.04` (standard GitHub-hosted) |
| Build target | `oci/bluefin.bst` |
| Build timeout | 360 min job-level (GitHub hard ceiling); build step 330 min |
| bst2 container | `registry.gitlab.com/.../bst2:<sha>` (pinned in Justfile / workflow) |
| Remote cache server | `cache.projectbluefin.io:11002` — single AX102-U, 32 cores |
| Cache auth | mTLS — `CASD_CLIENT_CERT` (repo variable) + `CASD_CLIENT_KEY` (secret) |
| Cache usage | Artifacts, source-caches, storage-service, remote-execution, action-cache |
| Published image | `ghcr.io/projectbluefin/dakota:latest` and `:$SHA` |
| Build logs artifact | `buildstream-logs-x86_64-<variant>` (7-day retention) |
| Trigger (validate) | pull_request — `bst show --deps all`, no AX102-U |
| Trigger (build) | merge_group, schedule (13:00 UTC), workflow_dispatch — NOT pull_request |
| Concurrency | `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` |

## Workflow Steps

| # | Step | What it does | Notes |
|---|---|---|---|
| 1 | Checkout | Clones the repo | Pinned `actions/checkout` SHA |
| 2 | Setup Just | `extractions/setup-just` | Provides `just` command |
| 3 | Capture build timestamp | `date -u` → `$GITHUB_OUTPUT` | Used in OCI image labels |
| 4 | Generate BST CI config | Writes `buildstream-ci.conf` with CI-tuned settings | See config table below; conditionally appends remote cache section |
| 5 | Build OCI image | `just bst build oci/bluefin.bst` | `BST_FLAGS: --no-interactive --config /src/buildstream-ci.conf`; timeout 120 min |
| 6 | Export OCI image | `just export` | `BST_FLAGS` + `BUILD_IMAGE_NAME`, `OCI_IMAGE_CREATED`, `OCI_IMAGE_REVISION`, `OCI_IMAGE_VERSION` env vars set |
| 7 | Verify image loaded | `sudo podman images` | Diagnostic |
| 8 | bootc lint | `just lint` | Validates image structure |
| 9 | Upload build logs | `actions/upload-artifact` | Always runs, even on failure |
| 10 | Login to GHCR | `sudo podman login ghcr.io` with `GITHUB_TOKEN` | Always (not main-only) |
| 11 | Tag for GHCR | Tags as `:latest` and `:$SHA` | Always |
| 12 | Push to GHCR | `sudo podman push` with retry loop (3 attempts, 5s sleep) | Always on successful build |

## CI BuildStream Config

Generated as `buildstream-ci.conf` at step 4. Values and rationale:

| Setting | Value | Why |
|---|---|---|
| `on-error` | `continue` | Find ALL failures in one run, not just the first |
| `fetchers` | `32` | Parallel downloads from artifact caches |
| `builders` | `4` | Concurrent builds (actual parallelism controlled by casd server) |
| `network-retries` | `3` | Retry transient network failures |
| `retry-failed` | `True` | Auto-retry flaky builds |
| `error-lines` | `80` | Generous error context in logs |
| `cachedir` | `/srv/cache` | CI-specific cache directory |
| `logdir` | `/srv/logs` | CI-specific log directory |

Note: `cache-buildtrees` is **not set** (omitted) — differs from the old stale skill content which had `never`.

## Remote Cache Architecture

The `cache.projectbluefin.io:11002` server handles all five BST remote services:

| Service | Config key | Role |
|---|---|---|
| Artifact cache | `artifacts.servers[]` | Stores and retrieves built artifacts |
| Source cache | `source-caches.servers[]` | Stores and retrieves source tarballs |
| CAS storage | `cache.storage-service` | Content-addressable storage backend |
| Remote execution | `remote-execution.execution-service` | Remote build execution |
| Action cache | `remote-execution.action-cache-service` | Cache of build actions |

All five use the same endpoint with identical connection config:
```yaml
url: https://cache.projectbluefin.io:11002
push: true
connection-config:
  keepalive-time: 60
  retry-limit: 5
  retry-delay: 1000
  request-timeout: 180
auth:
  client-key: /src/client.key
  client-cert: /src/client.crt
```

### mTLS Authentication

Auth uses a client certificate/key pair:

| Variable | Type | Source | Content |
|---|---|---|---|
| `CASD_CLIENT_CERT` | Repository **variable** (not secret) | `vars.CASD_CLIENT_CERT` | PEM-encoded client certificate (public) |
| `CASD_CLIENT_KEY` | Repository **secret** | `secrets.CASD_CLIENT_KEY` | PEM-encoded private key (secret) |

The workflow writes these to `/src/client.crt` and `/src/client.key` at config generation time.

**Push is conditional:** The remote cache section is only appended to `buildstream-ci.conf` if **both** `CASD_CLIENT_CERT` and `CASD_CLIENT_KEY` are set. If either is missing, CI runs with local cache only — slower but functional.

> **FIXME in workflow:** There is a commented-out JWT auth path (`actions/github-script` to get `id-token`). mTLS is the current live implementation; JWT auth is not yet implemented.

### Cache Behavior Without Credentials

When credentials are absent (e.g., a fork running CI without the org secrets/variables):
- `buildstream-ci.conf` is generated without any `artifacts:`, `source-caches:`, `cache:`, or `remote-execution:` sections
- BST builds entirely from source using only its local disk cache
- Builds are much slower (no artifact reuse across runs)
- This is normal and expected for external contributors' forks

## Secrets and Permissions

| Variable/Secret | Type | Required? | Purpose |
|---|---|---|---|
| `CASD_CLIENT_CERT` | Repository variable | Optional | mTLS client cert for cache.projectbluefin.io |
| `CASD_CLIENT_KEY` | Repository secret | Optional | mTLS private key for cache.projectbluefin.io |
| `GITHUB_TOKEN` | Auto-provided | Always | GHCR login + packages:write |

Job permissions: `contents: read`, `packages: write`.

## Trigger Behavior

| Behavior | pull_request | merge_group | schedule | workflow_dispatch |
|---|---|---|---|---|
| `validate` job | **Yes** (bst show, no AX102-U) | No | No | No |
| `build` job | **No** | Yes (max-jobs: 32) | Yes | Yes |
| AX102-U used? | **Never** | Yes | Yes | Yes |
| Push to GHCR? | No | Via publish.yml | Via publish.yml | Via publish.yml |

**PR path:** `validate` only — `bst show --deps all` on both variants, zero remote execution. ~15 min cached, ~30 min cold. Required check for merge queue entry.

**Merge queue path:** `build` fires on `merge_group` — full OCI build, max-parallel: 2, max-jobs: 32. Real CI gate before merge.

**Publish path:** `publish.yml` triggered via `workflow_run` filtered to `branches: [main, 'gh-readonly-queue/main/**']` — fires only on real builds, not PR validate runs.

**Nightly schedule rationale:** gnome-build-meta nightly pipelines start ~02:00 UTC and typically finish by ~08:00 UTC (worst-case ~11:30 UTC). 13:00 UTC gives sufficient buffer to guarantee dakota picks up the freshest upstream artifacts.

## ⚠️ Branch Base Rule — Hard Fail

**Always create feature branches from `upstream/main`, never from local `main`.**

```bash
git checkout upstream/main -b feature/my-change
```

The `castrojo/dakota` fork diverges from `projectbluefin/dakota` (often by 20+ commits). Branching from local `main` produces PRs with hundreds of unrelated file changes. Verify before pushing:

```bash
git diff upstream/main...HEAD --stat
```

If the diff contains files outside your intended change, you branched from the wrong base. Rebase onto `upstream/main` before pushing.

**Recovery when a branch is already dirty (cherry-pick pattern):**
```bash
# Rebase onto upstream/main, dropping all commits before your real change:
git rebase --onto upstream/main <last-unwanted-commit-sha> <branch-name>
git push --force-with-lease origin <branch-name>
```
`<last-unwanted-commit-sha>` is the SHA of the last commit you do NOT want (the final stray commit). The rebase replays only commits AFTER that SHA onto `upstream/main`.

## Workflow Files

The primary pipeline has two files — read both when touching publishing or post-merge behavior:

| File | Role |
|---|---|
| `.github/workflows/build.yml` | BST build + push to remote CAS. Fires on merge_group/schedule/dispatch. Does NOT push to GHCR. |
| `.github/workflows/publish.yml` | Pulls artifact from CAS, exports OCI, pushes to GHCR, signs, attests. Fires via `workflow_run` when build succeeds on main. |

> Never use `web_fetch` for GitHub URLs. See: github skill for the full rule.

## Workflow consistency rule

If you modify Dakota's issue-routing or automation flow, do not review the workflow file in isolation.

Cross-check all related surfaces together:
- `.github/workflows/*.yml`
- `.github/ISSUE_TEMPLATE/*`
- `AGENTS.md`

Verify that labels, section headings, queue transitions, and operator instructions still match. A workflow gate that does not accept the issue template's emitted body/labels is a blocking bug.

## Completion rule for merge/queue work

When the task involves PR automation, auto-merge, merge queue, or GitHub state transitions, completion requires **live GitHub state**, not only YAML edits.

Before concluding, confirm with `gh`:
- actual PR numbers and URLs
- auto-merge enabled/disabled state
- merge-queue position or readiness
- labels/comments/issues created by the workflow, when relevant

## Debugging CI Failures

### Where to Find Logs

| Log | Location | Contents |
|---|---|---|
| Build log | `buildstream-logs` artifact → `logs/` | Full BuildStream build output |
| Config generation | "Generate BuildStream CI config" step | Shows the generated `buildstream-ci.conf`; confirms whether remote cache was configured |
| Workflow log | GitHub Actions UI → step output | Each step's stdout/stderr |

### Common Failures

| Symptom | Likely cause | Fix |
|---|---|---|
| Build OOM or hangs | Memory pressure with 4 builders | Check element's own build resource usage; reduce `builders` locally for testing |
| "No space left on device" | BST cache fills runner disk | Runner has limited disk; check if any element generates large buildtrees |
| `bootc container lint` fails | Image has `/usr/etc`, missing ostree refs, or invalid metadata | Check `oci/bluefin.bst` assembly; ensure `/usr/etc` merge runs |
| Build succeeds locally, fails in CI | Different element versions cached, or network-dependent sources | Compare `bst show` output; check if remote CAS has stale artifacts |
| `bst artifact list-contents` fails in CI | Remote execution does NOT populate the local BST cache — the command is local-only | Pre-commit generated files that depend on `list-contents`; see "Generated Files" section below |
| GHCR push fails | Token permissions or transient failure | Check `packages: write` permission; retry loop handles transient (3 attempts × 5s) |
| Source fetch timeout | `cache.projectbluefin.io` or upstream source unreachable | `network-retries: 3` handles transient; check server status |
| Remote cache not used | `CASD_CLIENT_CERT` or `CASD_CLIENT_KEY` not set | Check repo Variables and Secrets; confirm config step shows the full cache config in output |
| Auth error connecting to cache | Expired or wrong cert/key pair | Rotate `CASD_CLIENT_CERT` and `CASD_CLIENT_KEY` repo variable/secret |
| `request-timeout` errors | Slow response from cache server | Transient; `retry-limit: 5` handles most cases |

### Debugging Workflow

1. **Check config step output**: The "Generate BuildStream CI config" step prints the full `buildstream-ci.conf`. Confirm whether the `artifacts:` / `source-caches:` / `remote-execution:` sections are present. If absent, the cert/key are not configured.

2. **Search build log**: Download `buildstream-logs` artifact. Look for `[FAILURE]` lines. `on-error: continue` means all failures are collected — don't stop at the first one.

3. **Check if remote cache was hit**: In build output, look for `[get artifact]` lines showing `https://cache.projectbluefin.io:11002` as source. If all artifacts are built from source, the remote cache wasn't used.

4. **Reproduce locally**: `just bst build oci/bluefin.bst` uses the same bst2 container. For CI-equivalent behavior, create a `buildstream-ci.conf` matching the generated one (without the remote cache section if you don't have credentials).

5. **BST_FLAGS environment**: Build and export steps inject `BST_FLAGS: --no-interactive --config /src/buildstream-ci.conf`. If testing locally, set this env var or pass the flags manually.

## Generated Files That Must Be Pre-committed (Cargo.lock Pattern)

Some files in `projectbluefin/dakota` are generated locally and committed — they CANNOT be regenerated in CI because the generation requires `bst artifact list-contents`, which only reads the **local** BST artifact cache. Remote execution on `cache.projectbluefin.io` does NOT populate the local cache on CI runners.

| File | Generator | Requires | When to Regenerate |
|---|---|---|---|
| `files/filemap.json` | `python3 scripts/gen-filemap.py` | Local BST cache populated | After any element change that affects file layout |
| `files/fakecap-manifest.tsv` | `python3 scripts/gen-filemap.py` | Local BST cache populated | Same as above |

**Conditional regen guard in Justfile:**
```bash
if [ ! -s files/filemap.json ] || [ ! -s files/fakecap-manifest.tsv ]; then \
    python3 scripts/gen-filemap.py; \
fi
```
- Use `-s` (non-empty file test) on **both** files together — if either is missing or empty, regenerate both
- CI uses BuildStream remote execution/CAS; `bst artifact list-contents` does not see remote-only artifacts on the runner's local cache
- These files are intentionally committed (`.gitignore` exempts them); treat updates like `Cargo.lock` updates
- The local BST cache at `/var/home/jorge/.cache/buildstream/` must be populated first (`just bst build` completes)

**Chunkah tag:**
- Justfile pins chunkah by SHA digest: `quay.io/coreos/chunkah@sha256:faa8209f...` (v0.4.0 as of 2026-05-02).
- Renovate tracks via `customManagers` in `renovate.json` — PRs bump the digest automatically.
- Always run `grep CHUNKAH_REF Justfile` to confirm the actual pinned digest before chunkify work.

**To regenerate:**
```bash
rm files/filemap.json files/fakecap-manifest.tsv
python3 scripts/gen-filemap.py
git add files/filemap.json files/fakecap-manifest.tsv
git commit -m "chore: regenerate chunkah filemap and fakecap manifest"
```

## ⚠️ Pre-Commit BST Syntax Gate (Hard Rule)

For any change to `project.conf`, `*.bst` elements, or `Justfile`:

```bash
just bst show oci/bluefin.bst
```

**Must exit clean (no `Error loading project`) before git commit.** Catches:
- Invalid option names (hyphens forbidden — only alphanumeric + underscores)
- Non-existent option types (`string` invalid — valid: bool, enum, flags, element-mask, arch, os)
- Unknown element references and malformed YAML

Takes 5 seconds. Skipping wastes a 90-second CI build slot.

**No upstream PR without validation evidence:** The PR description MUST include `just bst show` output. NUC hardware validation (`bootc upgrade` + reboot + user verification) required before any upstream PR.

## ⚠️ Session Bootstrap (Hard Rule)

At the start of every dakota session, check GNOME OS upstream status before any build or patch work:

```bash
gh pr list --repo gnome/gnome-build-meta --state open --limit 10
gh run list --repo projectbluefin/dakota --limit 5
```

## ⚠️ Pre-PR Test Gate (Hard Rule)

Before opening any upstream PR for a dakota fix:
1. SSH to ghost: `ssh jorge@192.168.1.102`
2. Run `cd ~/src/dakota && just bst build <element>` — must show `failed 0`
3. Quote `Build Queue: processed N, failed 0` before opening any PR

**Two separate gates:** User waiving the ghost test ("ignore ghost, I'm travelling") waives the TEST only — not PR permission. Both gates must be satisfied independently.

## Cross-References

| Skill | When |
|---|---|
| `dakota-oci-layers` | Understanding what the build produces |
| `dakota-debugging` | Diagnosing individual element build failures |
| `dakota-buildstream` | Writing or modifying `.bst` elements |
| `dakota-update-refs` | Understanding the source tracking workflow |

## Ruleset (main-review-required-with-renovate-bypass)

Ruleset ID: 14485779. Key configuration:

| Rule | Value |
|---|---|
| Required reviews | 1 approving review |
| Required status checks | `validate` only |
| Merge queue | ALLGREEN, max_entries_to_build=1, check_response_timeout=120 min |
| Bypass actors | OrganizationAdmin (always), Renovate/2740 (pull_request), mergeraptor/3069633 (pull_request) |

**Critical:** Required status checks must only include checks that fire on `pull_request`. A check that only fires on `merge_group` will be permanently pending on every PR head, blocking "Add to merge queue" indefinitely.

## Bot PR CI — GITHUB_TOKEN suppression

PRs created by a workflow using `GITHUB_TOKEN` do NOT fire `pull_request` events. GitHub suppresses all workflow triggers from its own bot token to prevent recursive loops. Affects `gh pr create`, close/reopen — all suppressed when done with `GITHUB_TOKEN`.

**Fix:** Use a GitHub App token (mergeraptor) for `gh pr create` in `track-bst-sources.yml`.

```yaml
- name: Get mergeraptor token
  id: app-token
  uses: actions/create-github-app-token@<sha> # v3
  with:
    client-id: ${{ secrets.MERGERAPTOR_APP_ID }}     # client-id not app-id (v3 change)
    private-key: ${{ secrets.MERGERAPTOR_PRIVATE_KEY }}
# On gh pr create steps:
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
```

Secrets (repo-level on projectbluefin/dakota):
- `MERGERAPTOR_APP_ID` = `Iv23liM0qfqdQgXpazX4` (app ID 3069633)
- `MERGERAPTOR_PRIVATE_KEY` = PEM private key from GitHub App settings page

**Workaround (no app token):** Close + reopen the PR manually — human-triggered events bypass the suppression:
```bash
gh pr close NNN --repo projectbluefin/dakota && gh pr reopen NNN --repo projectbluefin/dakota
```

## Lessons Learned

### scorecard-action SHA — annotated tag object vs commit SHA (2026-05-02)

`ossf/scorecard-action` was failing: `imposter commit: 99c09fe... does not belong to ossf/scorecard-action`

**Root cause:** Annotated git tags have two SHAs — the tag *object* SHA and the *commit* SHA it points to. The scorecard service only accepts real commit SHAs; tag-object SHAs are rejected.

**How to get the correct commit SHA for any action version:**
```bash
# Dereferences annotated tags automatically:
gh api repos/OWNER/REPO/commits/vX.Y.Z --jq '.sha'
```

**Fix applied in PR projectbluefin/dakota#393:** `99c09fe...` (tag object) → `4eaacf05...` (verified commit for v2.4.3).

### aarch64 CI — cron-only gate + config differences (2026-05-24)

Gate aarch64 jobs to schedule/dispatch only — not PRs or merge queue:
```yaml
build-aarch64:
  if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
```

Key differences from x86_64 job:
- runner: `ubuntu-24.04-arm`
- **No `remote-execution`** in BST config — `cache.projectbluefin.io` only has x86_64 workers and rejects aarch64 with "Unsupported ISA". Builds run locally on the ARM runner; artifacts still pushed to cache for future hits.
- `continue-on-error: true` — ARM failures don't block x86_64 publication
- `create-manifest` gates on `needs.build-aarch64.outputs.pushed == 'true'` (not job result — `continue-on-error` makes result `success` even on failure)

WebKit aarch64 artifacts come from `gbm.gnome.org:11003` (already in `project.conf`). The original `if: false` disable was because this cache wasn't populated; gnome-build-meta now builds aarch64 natively.

**Org branch PRs:** If a contributor PR is on `projectbluefin:branch-name` (org branch, not a fork), `maintainerCanModify` is irrelevant — you cannot push to it. Create a superseding PR from `castrojo:upstream-pr/<scope>`.

## Homelab BST builds via Argo (ghost)

Dakota BST builds can also be driven through the k8s control plane on ghost via the `dakota-bst` WorkflowTemplate in `projectbluefin/testing-lab`. This uses jorge's existing warm BST cache for fast local builds — do not re-implement, just use the existing lever.

```bash
cd ~/src/testing-lab
just run-dakota-validate              # bst show — fast graph check, no build
just run-dakota-build                 # default variant: bst build + lint
just run-dakota-build nvidia          # nvidia variant
just run-dakota-build all             # both variants
```

**Design:** privileged pod pinned to ghost (`nodeSelector`), mounts `/var/home/jorge/.cache/buildstream` for warm cache, `/dev` and `/var/lib/containers/storage` from host — same pattern as `bib-build-and-push`. No changes to the dakota repo. Pod calls `just validate` / `just build <variant>` / `just lint` from a fresh clone.

**When to use this vs GitHub CI:**
- Local iteration / pre-PR validation → homelab Argo (warm cache, ~2–5 min)
- Merge gate + CAS push + GHCR publish → GitHub Actions (authoritative)

## Lessons Learned (2026-05-28)

### actionadon.yml workflow permissions

The `on-pr-review` job posts a comment via `gh pr comment`. The global `permissions:` block
must include `pull-requests: write` alongside `issues: write` or the `addComment` GraphQL
call fails with "Resource not accessible by integration":

```yaml
permissions:
  issues: write
  pull-requests: write
  contents: read
```

### SC2006 in heredocs with markdown backticks

Unquoted heredoc delimiters (`<< EOF`) cause shellcheck to parse the body as shell. Any
markdown inline code (`` `status/approved` ``) is treated as legacy command substitution
(SC2006). Fix: escape the backtick with a backslash inside the heredoc, OR switch to a
quoted delimiter (`<< 'EOF'`) when the body contains no variable expansion.

### `set -e` + `set +e` anti-pattern in just recipes

Using `set -e` (collect variables) then `set +e` (before interactive prompts) is unsafe:
a failed `pkexec` between the two silently continues. Correct pattern:

```bash
set -euo pipefail
gum confirm "...?" || exit 0   # user cancel — soft exit
pkexec bootc switch ... || exit 1   # hard failure — abort
```

Never use `set +e` to suppress errors across critical commands. Use explicit `|| exit N`
on every command that should stop execution on failure.

---

## e2e CI Pipeline (projectbluefin/testsuite)

The e2e pipeline (`.github/workflows/e2e.yml` in testsuite) runs GNOME smoke tests against a
live QEMU VM booted from the dakota image. This is distinct from the BST build pipeline.

### Architecture

```
dakota e2e.yml → testsuite e2e.yml (reusable) → QEMU VM (boots :sha image)
                                               → qecore/behave smoke tests
```

### Hard-Won Lessons

#### GDM restarts flush environment
qecore-headless calls `gdm restart` before running tests. Any PATH injected via:
- `/tmp/session.env`
- `~/.config/environment.d/99-ci-path.conf`
...is LOST. The GNOME session launched after restart gets the default PAM-set PATH.

Fix: Disable the keyring step entirely — GNOME 50 apps don't require it:
```python
# tests/smoke/features/environment.py — after sandbox init
context.sandbox.set_keyring = False
```

#### GNOME 50 AT-SPI roleName change
In GNOME 50, Nautilus and Settings expose their top-level window as `roleName="filler"`
not `roleName="frame"`. All AT-SPI window finders must accept both:
```python
n.roleName in {"frame", "filler"}
```

#### GNOME 50 Shell.Eval format change
`gdbus call ... org.gnome.Shell.Eval` returns `(true, '"true"')` (double-quoted JS string)
in GNOME 50. The `_eval_bool` regex must be: `r',\s*\'"?(true|false)"?\'\s*\)'`

Also: `context.sandbox.shell.eval_js()` was removed in newer qecore.
Use `_shell_eval()` helper in steps.py instead.

#### bootc status in QEMU VMs
`sudo bootc status` fails with `opendir(boot): Operation not permitted` in CI VMs.
The QEMU VM is booted via direct kernel+initrd (no bootupd), so `/boot` is not accessible
from within the guest in the expected way. Skip or mock this test step in CI.

#### gnome-ponytail-daemon meson.build
The upstream `meson.build` has `dependency('systemd')` which fails on Debian (no
`systemd.pc`, only `libsystemd.pc`). Apply at build time:
```bash
sed -i "s/dependency('systemd')/dependency('systemd', required: false)/" meson.build
```
The daemon functions without libei (falls back to Mutter D-Bus).

#### systemd units that fail at boot in VMs
Mask these in KERNEL_ARGS or deployment service masks to prevent health check failures:
- `avahi-daemon.service avahi-daemon.socket`
- `cups.service cups.path cups.socket cups.browsed`
- `ModemManager.service`
- `malcontent-control.service`
- `podman-auto-update.timer`
- `gnome-remote-desktop.service`
- `blueman-mechanism.service`

### Test Progress Baseline
As of 2026-05-30, latest full run (run 26686736854):
- 26 passed, 28 failed
- Fixes applied (commits 092a6c7 and earlier):
  - SSH auth (900s deadline, AuthorizedKeysCommand)
  - Home dir creation (tmpfiles.d)
  - python-uinput wheel build on runner
  - PATH in SSH session (`~/.local/bin`)
  - gnome-ponytail-daemon build + install
  - Shell.Eval GNOME 50 regex fix
  - eval_js → _shell_eval() for workspace steps
- Still failing:
  - keyring PATH (qecore_create_keyring not found) — fix: set_keyring = False
  - Nautilus/Settings window (AT-SPI roleName "filler") — fix: accept both roles
  - bootc status /boot permission — fix: skip in CI
  - system_health failed units — fix: mask more units

### Merge queue / testing branch (added 2026-06-01)

**Key patterns for clearing the dakota merge queue:**

1. **Chore/dep-update PRs default to `main`** — always retarget to `testing` before merging:
   ```bash
   gh pr edit <N> --repo projectbluefin/dakota --base testing
   ```
   After retargeting, branches will be `CONFLICTING` (they were based on `main`, not `testing`). Rebase required.

2. **`gh pr merge --auto` fails on `testing`** — branch protection on `testing` does not have auto-merge enabled. Use `--squash` directly:
   ```bash
   gh pr merge <N> --repo projectbluefin/dakota --squash
   ```

3. **AGENTS.md conflict is recurring on `testing` rebases** — `testing` added PR review rules not in `main`. Always keep HEAD:
   ```bash
   sed -i '/<<<<<<< HEAD/d; />>>>>>> .*/d; /^=======$/d' AGENTS.md
   git add AGENTS.md && GIT_EDITOR=true git rebase --continue
   ```

4. **Sequential merges cause cascading conflicts** — recheck `mergeable` after each batch and do a final rebase pass.

5. **Empty PR after rebase** — check `ahead_by` after rebase (`gh api .../compare/testing...<branch>`). If 0, close instead of merge.

Full merge-queue workflow: `cat ~/src/skills/merge-queue/SKILL.md`
