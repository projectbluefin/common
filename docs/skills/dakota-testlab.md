---
name: dakota-testlab
description: Ghost + exo-dakota active hardware loop for dakota. Build on ghost, publish to zot, test on exo-dakota, and gate PR approval on lab evidence.
---

# Dakota Testlab — Active Dev Loop

Load with: `cat ~/src/skills/dakota-testlab/SKILL.md`

> Load on demand (full runbooks/history): `cat ~/src/skills/dakota-testlab/REFERENCE.md`

Load `ghost-testlab` first for shared topology/ports/SSH constraints.

---

## When to Use
- Running the live dakota loop: build → publish → exo-dakota test
- Dispatching PR builds/tags through ghost
- Producing PASS/FAIL lab evidence for PR decisions
- Debugging dakota-specific failures in the ghost/exo-dakota path

## When NOT to Use
- One-time provisioning (use `dakota-testlab-setup`)
- Knuckle PR QA or KubeVirt workflows (use `knuckle-qa` / `knuckle-testlab`)
- Local-only VM OTA loop (use `dakota-local-ota`)

---

## Hard rules

- Do not rebase ghost local `~/src/dakota` main (diverged). Use clean test branches from upstream main.
- `x86_64_v3` build flag is mandatory for dakota builds in this loop.
- PR approval requires exo-dakota evidence for changes affecting image/runtime behavior.
- If exo-dakota validation fails, do not approve.
- **BUILD FAILURES = IMMEDIATE ISSUE.** Any element that fails during a ghost lab build must be filed as a GitHub issue immediately — even if it appears pre-existing or unrelated. Do not continue past it without filing.
- **NUC IS MANDATORY.** Ghost build alone is not a lab result. Full loop: ghost build → export → push to zot → `bootc switch` on exo-dakota → verify `uname -r` + `bootc status` + GDM active. Never mark a dakota lab test done without NUC confirmation.
- **THE REPORT IS THE ARTIFACT.** If the user asked for lab evidence, issue filing, or merge decisions from the lab run, do not stop after dispatch or code changes. Finish only when the PASS/FAIL report, issue, or PR state exists and you can point to it.

---

## ⚡ Lessons Learned (2026-06-01)

### zstd:chunked on exo-dakota — enabled in /etc, not shipped in image yet

exo-dakota now has `/etc/containers/storage.conf` with `enable_partial_images = "true"` (written directly, survives reboot). **This is not yet in the dakota image itself.** To make it permanent for all installs, add to `files/etc/containers/storage.conf` in dakota:

```toml
[storage]
driver = "overlay"

[storage.options.pull_options]
enable_partial_images = "true"
```

**Verification commands:**
```bash
ssh jorge@192.168.1.247 "cat /etc/containers/storage.conf"
# Should show enable_partial_images = "true"
```

The NUC was also confirmed to be using **unified bootc storage** (no `/sysroot/ostree`, composefs verity active at root) with bootc 1.15.2.

---

## ⚡ Lessons Learned (2026-05-29 — session 2)

### lab-runner.sh bootc switch timeout — 180s is too short for full image pulls

The default `timeout 180` on `bootc switch` kills the SSH session at ~2.1 GB when pulling a 3.1 GB image from the local zot registry. The process dies and the queue entry is marked FAIL even though the NUC hardware is fine.

**Fix applied (2026-05-29):** bumped to `timeout 600` in lab-runner.sh (both `bootc upgrade` and `bootc switch` paths). Rule of thumb: allow 10 minutes for any full-image pull from local zot. If the image is chunkified and the NUC already has most chunks, it will finish much faster; the extra slack is cheap.

If a run fails with `bootc switch FAILED for <label>` and the log shows `Fetching layer ...` mid-download, it is a timeout false-negative — requeue with `cp ~/.dakota-lab/done/<entry>.json ~/.dakota-lab/queue/` and restart the runner.

### `gh pr merge --auto` silently enqueues to merge queue despite warning

When a merge queue ruleset is active on the target branch, `gh pr merge --auto` prints:

```
! The merge strategy for dev is set by the merge queue
```

This looks like an error but the PR **is** enqueued. Confirm with:
```bash
gh api graphql -f query='{repository(owner:"projectbluefin",name:"bootc-installer"){mergeQueue(branch:"dev"){entries(first:20){nodes{position state pullRequest{number}}}}}}'
```

If you try `enqueuePullRequest` via GraphQL on an already-queued PR it returns `Pull request is already in the queue` — that confirms it worked.

### `enqueuePullRequest` GraphQL mutation no longer accepts `mergeQueueId`

The `mergeQueueId` argument was removed from `EnqueuePullRequestInput`. Pass only `pullRequestId`:
```graphql
mutation { enqueuePullRequest(input: {pullRequestId: "PR_kwDO..."}) { mergeQueueEntry { position state } } }
```

---



`gum spin -- command` suppresses stdout. To capture command output while showing a spinner:

```bash
GIST_OUT=$(mktemp); SCRIPT=$(mktemp)
printf '#!/bin/bash\ngh gist create ... > "%s"\n' "$GIST_OUT" > "$SCRIPT"
chmod +x "$SCRIPT"
gum spin --spinner pulse --title "Uploading..." -- bash "$SCRIPT"
GIST_URL=$(cat "$GIST_OUT")
rm -f "$GIST_OUT" "$SCRIPT"
```

For collecting multiple variables while showing a spinner, write to a temp file and `source` it:

```bash
COLLECTION_OUT=$(mktemp)
gum spin --title "Collecting..." -- bash -c "
  VAL1=\$(command1)
  VAL2=\$(command2)
  printf 'VAR1=%q\nVAR2=%q\n' \"\$VAL1\" \"\$VAL2\" > '$COLLECTION_OUT'
"
source "$COLLECTION_OUT"
rm -f "$COLLECTION_OUT"
```

### GitHub issue form URL prefill

`?field_id=<encoded_value>` prefills a field in GitHub issue templates.
The `id` in the YAML template maps directly to the URL query param.

Use `python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$URL"` for reliable encoding, with `sed` as fallback.

### ujust vs just distinction

- `just` = developer build system in repo root `Justfile` (build/test/deploy)
- `ujust` = user-facing commands inside the running image (`files/just-overrides/default.just`, installed to `/usr/share/ublue-os/just/default.just`)

Never confuse them. Changes to `files/just-overrides/default.just` require a BST element rebuild to land in the image.

### Raptors travel in kettles, not packs

Lore canon for the project. Use "kettle" in all raptor-related messages, spinners, and flavor text.

---

## ⚡ Lessons Learned (2026-05-23)

### just 1.47.1 heredoc tokenizer — CRITICAL

just 1.47.1 aggressively tokenizes heredoc content in shebang recipes, rejecting:
- Lines starting with `-` (treated as error-ignore modifier)
- `...` (three dots — unknown token)
- `$(uname -m)` — the `-m` flag inside `$(...)` at column 25+
- `(1/5/15 min)` — `(` followed by digit parsed as expression
- `<<-EOF` heredocs with tab-indented content (mixed whitespace)

**Fix:** Replace heredocs with `printf '%s\n'` per line. No block of arbitrary text for just to misparse.

```bash
# BAD — just tokenizes this
cat <<SUMMARY
- Kernel: ${KERNEL_VER}
* Load average (1/5/15 min): ${LOAD_AVG}
SUMMARY

# GOOD — just never sees these strings
printf '* Kernel: %s\n' "${KERNEL_VER}"
printf '* Load avg 1m/5m/15m: %s\n' "${LOAD_AVG}"
```

Also: pre-compute ALL command substitutions with flags (`uname -m`, `uname -r`) into variables BEFORE any heredoc or printf block.

### bootc switch same-content trap

`bootc switch <tag>` silently does nothing if the tag resolves to the already-booted digest. Always use **exact digest** when forcing an upgrade:

```bash
DIGEST=$(curl -sI http://192.168.1.102:5000/v2/dakota/manifests/<TAG> \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r')
sudo bootc switch --transport registry 192.168.1.102:5000/dakota@${DIGEST}
```

### BUILD_SKIP_NVIDIA

Set `export BUILD_SKIP_NVIDIA=1` on ghost to skip the nvidia variant locally (CI builds both). Already in `~/.bashrc` on ghost. Same pattern as `BUILD_SKIP_CHUNKIFY`.

Builds drop from ~15-20 min to ~3 min locally.

### Monitoring lab runs — Argo MCP only (SSH is off)

SSH to ghost is stopped. Monitor builds via Argo MCP, not tmux/SSH log tails:

```
argo-mcp-list_workflows   namespace=argo  status=[Running]
argo-mcp-get_workflow     name=<workflow-name>  namespace=argo
argo-mcp-get_workflow_logs  workflowName=<name>  namespace=argo  logLevel=info
```

Do NOT attempt `ssh jorge@192.168.1.102 'tail -f /tmp/build-*.log'` — SSH is off.

### Assertions must actually run the command

File-presence assertions (`test -f /path`) are not functional tests. Any recipe that runs at the terminal must also be tested via SSH assertions that **execute it** and check output:

```
--assert 'recipe-runs:echo n | TERM=dumb ujust report 2>&1 | grep -qiE "Collecting"'
```

Don't mark PASS until the recipe has actually executed on hardware.

### ujust --help is broken — never use it for existence checks

`ujust <recipe> --help` always fails with `error: justfile does not contain recipe '--help'`. just does not support per-recipe --help flags.

**Valid assertion patterns:**

```bash
# Existence check — recipe is listed
ujust --list | grep -q probe

# Invocation check — recipe runs and produces expected output
echo n | TERM=dumb ujust probe 2>&1 | grep -qiE "some expected output"

# Exit-code check — recipe exits cleanly (use for idempotent recipes)
ujust probe && echo OK
```

Never use `ujust <recipe> --help` or `ujust <recipe> -h` as an existence or smoke test.

---

## Primary entrypoint — Argo MCP (SSH is off — this is the only path)

⛔ **`lab-cli.py dispatch` requires SSH to ghost. SSH is off. Do not use it.**

All lab dispatches go through `argo-mcp-submit_workflow`. This is the ONLY way to trigger a lab build and test.

### Dispatch a PR lab run

Use `argo-mcp-submit_workflow` with:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dakota-pr-NNN-   # replace NNN with PR number
  namespace: argo
spec:
  workflowTemplateRef:
    name: dakota-qa-pipeline
  arguments:
    parameters:
      - name: branch
        value: <branch-name>              # e.g. fix/toggle-devmode-booted-image
      - name: variant
        value: default                    # default | nvidia
      - name: repo
        value: https://github.com/projectbluefin/dakota
        # For fork PRs: https://github.com/castrojo/dakota
      - name: suites
        value: smoke
```

### Monitor a running workflow

```
argo-mcp-list_workflows   namespace=argo  status=[Running]
argo-mcp-get_workflow     name=<workflow-name>  namespace=argo
argo-mcp-get_workflow_logs  workflowName=<name>  namespace=argo
```

### lab:fail reset — update in place, never spam

When resetting a `lab:fail` PR, find the `<!-- lab-status -->` sentinel comment and PATCH it:
```bash
PR=NNN
COMMENT_ID=$(gh api repos/projectbluefin/dakota/issues/${PR}/comments \
  --jq '.[] | select(.body | contains("<!-- lab-status -->")) | .id' | tail -1)

gh api --method PATCH \
  repos/projectbluefin/dakota/issues/comments/${COMMENT_ID} \
  --field body="⏳ **lab:reset** — new run dispatched (Argo workflow \`dakota-pr-${PR}-xxxxx\`). <!-- lab-status -->"
```
If no sentinel comment exists, create one with `<!-- lab-status -->` in the body so future resets can find it.

### Legacy scripts (SSH required — unavailable while SSH is off)

`lab-cli.py dispatch`, `lab-runner.sh`, `lab-approve.sh` all require SSH to ghost. They are preserved as reference but cannot be used while SSH is stopped. Use Argo MCP instead.

Result/state for completed workflows: use `argo-mcp-get_workflow` and `argo-mcp-get_workflow_logs`.

---

## Report Format

**Canonical template:** `skills/ghost-testlab/report-template.md` → Dakota Example section.
Edit structure there; this section reflects the dakota-specific field mapping.

**Dakota header fields:**

| Field | Dakota value |
|---|---|
| **Target** | `dakota` |
| **VM/Host** | `exo-dakota` (192.168.1.247) |
| **Image** | `dakota:{tag}` + short digest |

**Section structure:** System Identity → bootc Status → CPU & Build Verification → Desktop → GNOME Extensions → dconf & Keybindings → Packages → Services → Custom Assertions

Generated by: `lab-cli.py run` (or `lab-cli.py approve <label> <pr>` which posts automatically)

**Trailer:**
```
<!-- status:{PASS|FAIL} target:dakota label:{label} digest:{digest} -->
```

**Header lines (in order):**
```
## ⚡ Vanguard Lab Strike Report: {hostname}
**Alpha**: Blue Universal CI Companion · Iron Forge Defender · Exo-Class NUC
**Guardian on Duty**: `castrojo` on Ghost Homelab

*"{flavor text}"*
```

**Verdict line:**
- GO: `🟢 GO — {summary}`
- NOGO: `🔴 NOGO — {summary}`## PR approval gate (required)

Require exo-dakota lab evidence when PR touches image/runtime behavior, including:
- `elements/**`
- `files/**`
- `patches/**`
- `Justfile`
- boot pipeline logic

Evidence expectations (minimum):
- bootc status + booted digest
- GDM/session health
- required package/service checks
- domain-specific assertions from `--assert`
- explicit PASS/FAIL verdict in report

No evidence → no approval.

Report must be generated via `lab-cli.py run` (or `lab-cli.py run --target lts` for bluefin-lts).
See `ghost-testlab` skill for the universal verification requirement.

---

## Publish + upgrade notes

Current publish path is chunkify + push (see REFERENCE for exact commands and recovery matrix).

Tag conventions:
- `dakota:latest` — main tracked image
- `dakota:pr-N` — per-PR lab image
- `dakota:<label>` — named custom test image

---

## Monitoring + troubleshooting (quick)

Prefer file-based polling, not tmux scrollback scraping.

```bash
ssh jorge@192.168.1.102 "tail -f /tmp/dakota-build.log"
ssh jorge@192.168.1.102 "ss -tlnp | grep 5000"
ssh jorge@192.168.1.247 "sudo bootc status"
```

If NUC appears down, check sleep first before calling test failed:
```bash
ping -c 1 192.168.1.247 >/dev/null 2>&1 || echo "exo-dakota sleeping"
```

If dispatches seem stuck:
```bash
# 1. Confirm the queue runner is actually alive
pgrep -af 'lab-runner.sh --loop'

# 2. Use lab-cli status as the source of truth
~/src/skills/dakota-testlab/lab-cli.py status

# 3. Distinguish build-lock wait from NUC wait
# - ghost build-lock wait: dispatch acknowledged, but item may not yet be in ~/.dakota-lab/queue/
# - NUC wait: item is in ~/.dakota-lab/queue/ but exo-dakota may be sleeping/unreachable
```

---

## Memory protocol (project scope)

After each lab run, store reusable outcome/fix:

```bash
memory(mode="add",
  content="[DATE] exo-dakota test result: <pass|fail>. Test: <what>. Outcome: <details>. Fix: <if fail>.",
  type="error-solution",
  scope="project"
)
```

Bootstrap recall hint:
```bash
recall(query="dakota exo-dakota bootc upgrade test loop failures fixes", limit=5)
```

---

## Cross-references

- One-time provisioning: `cat ~/src/skills/dakota-testlab-setup/SKILL.md`
- BuildStream editing rules: `cat ~/src/skills/dakota-buildstream/SKILL.md`
- CI troubleshooting: `cat ~/src/skills/dakota-ci/SKILL.md`
- Deep runbooks/history: `cat ~/src/skills/dakota-testlab/REFERENCE.md`

## Powerlevel
- **Level:** 3

---

## Desktop Smoke Test (verify-desktop.sh)

Script: `skills/dakota-testlab/scripts/verify-desktop.sh`
Run on: any homelab VM via SSH (exo-dakota, titan-lts, titan-fedora)

Dispatch via `lab-verify.sh --vm <name>` or manually:
```bash
# via lab-verify (handles SCP + SSH for any VM)
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh --vm exo-dakota --skip-switch
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh --vm titan-lts  --skip-switch
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh --vm titan-fedora --skip-switch
# ⚠️ titan-dakota DOES NOT EXIST — do not use --vm titan-dakota

# manual SCP + run
scp ~/src/skills/dakota-testlab/scripts/verify-desktop.sh jorge@192.168.1.247:/tmp/
ssh jorge@192.168.1.247 'bash /tmp/verify-desktop.sh'
```

| Check | What it verifies |
|---|---|
| `gdm-service-active` | `systemctl is-active gdm` = active |
| `gdm-no-failures` | No "maximum number of display failures" in journal |
| `graphical-seat-present` | A session is on seat0 (physical display) |
| `session-type-wayland` | `loginctl show-session -p Type` = wayland |
| `wayland-socket-exists` | `/run/user/1000/wayland-0` is a socket |
| `dbus-session-socket` | `/run/user/1000/bus` is a socket |
| `gnome-shell-running` | `pgrep -x gnome-shell` |
| `gnome-shell-user-mode` | gnome-shell launched with `--mode=user` |
| `ghostty-binary-exists` | `/usr/bin/ghostty` is executable |
| `ghostty-version` | `ghostty --version` responds |
| `ghostty-opengl` | Version output includes OpenGL/renderer |
| `ghostty-launches-with-shell` | Ghostty holds a window for 5s with a child shell process |
| `nautilus-binary-exists` | `/usr/bin/nautilus` is executable |
| `nautilus-version` | `nautilus --version` responds |
| `nautilus-desktop-file` | `org.gnome.Nautilus.desktop` present in applications |
| `nautilus-gschema-present` | `org.gnome.nautilus` schema visible in gsettings |
| `nautilus-launches` | Nautilus holds a window for 3s |

**Invoke from lab loop (preferred — handles SCP automatically):**
```bash
# with bootc switch (exo-dakota only)
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh pr-42 pr-42

# smoke test only, any VM
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh --vm titan-lts  --skip-switch
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh --vm titan-fedora --skip-switch
bash ~/src/skills/dakota-testlab/scripts/lab-verify.sh --vm titan-dakota --skip-switch
```

**lab-verify.sh VM registry:**
| VM | SSH | bootc switch |
|---|---|---|
| `exo-dakota` | `jorge@192.168.1.247` | yes (from zot) |
| `titan-lts` | `root@192.168.1.102 -p 30220` | only with `--image` |
| `titan-fedora` | `root@192.168.1.102 -p 30221` | only with `--image` |
| `titan-dakota` | `root@192.168.1.102 -p 30222` | only with `--image` | ⚠️ VM DOES NOT EXIST — port 30222 is stale |

**Requirements:** jorge/root must be logged into the GNOME session (auto-login or manual). The Wayland socket at `/run/user/1000/wayland-0` must exist before running.

## ⚡ Lessons Learned (2026-05-26)

### BST build log monitoring — `tail -1` misses active builds

The master build log (`/tmp/build-*.log`) only updates when an element **completes** (SUCCESS/FAILURE line). During a long single-element build (e.g., WebKitGTK), the log is silent for 30-60 minutes — the poll looks stalled even though BST is working.

**Pattern:** Check the element's own log file directly when the master log stops growing:
```bash
# Find the actively-written element log
find ~/.cache/buildstream/logs -name '*.log' -mmin -2

# Tail it directly for live progress (e.g. ninja step N/M)
tail -5 ~/.cache/buildstream/logs/gnome/sdk-webkitgtk-6.0/*-build.*.log
```

To distinguish "stalled" from "single slow element": verify `pgrep -c bst` is non-zero AND the CASD log (`~/.cache/buildstream/logs/_casd/*.log`) has recent timestamps.

### WebKitGTK is the dominant CAS-miss build time

`gnome-build-meta.bst:sdk/webkitgtk-6.0.bst` takes **~60 minutes** to build from source on ghost (32 cores). It is the single most expensive element in the GNOME stack.

When you see the master build log stall at ~1480 successes with `[--:--:--]` activity, check whether WebKitGTK is active:
```bash
find ~/.cache/buildstream/logs/gnome/sdk-webkitgtk-6.0 -name '*.log' -mmin -5
tail -3 <that-log>   # shows current ninja step N/9437
```

When WebKitGTK finishes, BST caches it locally — subsequent builds hit the CAS and skip this entirely.

### E2E loop was NOT completed this session

**State at session close (2026-05-26):** BST build of `castro-opus-one` branch on ghost is in progress (WebKitGTK building from source, ~93% done). The following steps were NOT reached:
- `just export` → OCI archive
- chunkify + push to zot (`192.168.1.102:5000/dakota:pr-219`)
- `bootc switch` on exo-dakota + reboot
- `verify-desktop.sh` + custom assertions
- Lab report generation + posting to PR #219

**Resume point:** Wait for build completion (`pgrep bst` exits 0), then follow the next-steps in the session checkpoint.

## ⚡ Lessons Learned (2026-05-27)

### titan-dakota KubeVirt VM does not exist

`titan-dakota` (port 30222) in `lab-verify.sh` VM registry is **stale and non-functional**. No corresponding KubeVirt VM exists in the cluster, and no `disk.raw` exists in `projectbluefin/testing-lab` manifests. Dakota lab work is NUC-only (exo-dakota). Do not attempt `--vm titan-dakota` until a provisioning issue is filed and resolved.

### Merge queue blocked by unresolved CodeRabbit threads

The `main-review-required-with-renovate-bypass` ruleset has `required_review_thread_resolution: true`. Unresolved CodeRabbit review threads silently block merge queue entry — the PR shows CI green and approved but never enters the queue.

**Fix:** Resolve threads via GraphQL mutation:
```bash
gh api graphql -f query='
  mutation { resolveReviewThread(input:{threadId:"PRRT_..."}) { thread { isResolved } } }
'
```
Get the thread ID from the PR review page URL or `gh pr view --json reviewThreads`.

### `gh pr merge --admin` bypasses the merge queue (and build CI)

When using `--admin` to force-merge, the `build` CI job (which fires on `merge_group`) does **not** run. The nightly scheduled build at 13:00 UTC will pick up these commits. Only use `--admin` when `validate` has passed and the change is low-risk.

### Self-approve blocked on own PRs

`gh pr review --approve` returns "Review Cannot approve your own pull request" for PRs authored by the same GitHub user. PRs you authored need an external maintainer or bot review to satisfy the approving-review requirement.

### `lab:pass` label must be created before first use

The `lab:pass` label is not pre-seeded in new repos. If `gh pr edit --add-label lab:pass` fails, create it first:
```bash
gh label create "lab:pass" --repo projectbluefin/dakota \
  --color "0e8a16" --description "Maintainer lab validation passed"
```

### Patch Upstream-Status: Submitted vs Accepted

If a fix is already merged upstream (e.g., gnome-build-meta or freedesktop-sdk has the commit), the patch header **must** say `Upstream-Status: Accepted`, not `Submitted`. CodeRabbit flags this correctly — fix it by amending the commit rather than dismissing the review comment.

### lab-approve.sh — removed useless review body, added in-place update

`lab-approve.sh` previously posted `--body "NUC hardware verified. See lab report above."` on approve — this was redundant noise. Fixed to use no body on approve. Also updated to find an existing `<!-- status: -->` comment and PATCH it in-place rather than creating duplicate strike report comments on multiple runs.
