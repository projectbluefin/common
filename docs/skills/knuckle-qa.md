---
name: knuckle-qa
description: End-to-end PR review + VM e2e workflow for projectbluefin/knuckle. Covers complexity gate, code review, GHA vm-e2e testing (or local just vm-e2e), and merge-queue dispatch. Load before reviewing any knuckle PR.
---

# knuckle-qa — PR Review + VM E2E

End-to-end knuckle PR review: complexity gate → code review → vm-e2e test → queue.

Load with: `cat ~/src/skills/knuckle-qa/SKILL.md`

> Load on demand: `cat ~/src/skills/knuckle-qa/REFERENCE.md`

## When to Use
- Reviewing any open PR on projectbluefin/knuckle
- Running vm-e2e tests (GHA workflow_dispatch or `just vm-e2e` locally)
- Deciding whether to queue or hold a PR

## When NOT to Use
- PRs you've already tested this session with evidence
- Single-file docs/typo PRs — review inline and queue directly

---

## Pre-Flight Checklist (run once per session before any QA)

```bash
# First-time contributor CI gate — check for action_required runs before reviewing
gh api repos/projectbluefin/knuckle/actions/runs?status=action_required \
  --jq '.workflow_runs[] | "\(.id) \(.name) \(.head_branch)"'
# If any: gh api repos/projectbluefin/knuckle/actions/runs/<ID>/approve --method POST
```

---

## Batch PR Session Start

```bash
# 1. List open PRs with labels
gh pr list --repo projectbluefin/knuckle --state open \
  --json number,title,labels,additions,deletions \
  --jq '.[] | "#\(.number) \(.additions+.deletions)L [\(.labels|map(.name)|join(","))] \(.title)"'

# 2. File overlap check (MANDATORY — files in 2+ PRs must queue sequentially)
for pr in $ALL; do
  echo -n "PR $pr: "
  gh pr diff $pr --repo projectbluefin/knuckle --name-only | tr '\n' ' '; echo
done

# 3. Categorize by tier, then run SEQUENTIALLY (not in parallel — see parallelism note)
```

**⛔ Run QA scripts SEQUENTIALLY, not in parallel.** Parallel `go mod tidy` runs race on
`go.mod`/`go.sum` ("existing contents have changed since last read") and `golangci-lint`
uses a shared file lock. The "max 3 concurrent" rule was wrong — **max 1 at a time**.

---

## Tier Classification

Tier is set by the highest-tier domain label present. `kind/test` alone = Tier 0.

| Labels | Tier | What runs |
|---|---|---|
| `domain:ci`, `kind/test`, docs | 0 | `just ci` on dev machine |
| `domain:probe`, `domain:tui` | 1 | Tier 0 + VM tool check + dry-run (local or GHA) |
| `domain:security` | 1+sec | Tier 1 + bad-input rejection tests |
| `domain:install`, `domain:headless`, `domain:ignition`, swap, tailscale, sysext | **3** | Tier 1 + full install + **boot installed system** + domain assertions (GHA `vm-e2e.yml` or `just vm-e2e`) |
| `domain:iso` | 3 | Tier 3 + hardware-repro |

**Tier trigger uses LABELS only — never PR title.** A PR titled "fix tailscale validation"
with `domain:validate` labels is Tier 0, not Tier 3. The script (`qa-test-pr.sh`) enforces this.

---

## The Workflow

```
Step 1 → Complexity gate
Step 2 → Code review (rubber duck required)
Step 3 → VM e2e test (GHA workflow_dispatch or just vm-e2e locally)
Step 4 → Decision    (approve + queue OR request changes)
```

### Step 1 — Complexity Gate

Skip to review-only (no vm-e2e, no queue) if ANY:

| Signal | Threshold |
|---|---|
| `size:XL` or `size:XXL` label | present |
| Domain labels | >4 distinct `domain:*` |
| Workflow files | any `.github/workflows/*.yml` changed |
| Architecture boundary | `cmd/knuckle` + `internal/runner` + `internal/ignition` together |

### Step 2 — Code Review Checklist

```
□ gofmt clean: double space before // is the most common failure
□ No exec.Command outside internal/runner
□ Disk identity via /dev/disk/by-id (not /dev/sdX)
□ Ignition tempfile: os.CreateTemp + chmod 0600 + defer os.Remove
□ No secrets in slog output
□ Test assertions check err.Error() content, not just err != nil
□ Permission tests skip with t.Skip if os.Getuid() == 0
□ Every LGTM backed by a file:line reference from the diff
```

### Step 3 — VM E2E Test

**Option A — GitHub Actions (preferred for Tier 3 PRs on a branch):**

```bash
# Trigger all 4 passes on the PR branch
gh workflow run vm-e2e.yml \
  --repo projectbluefin/knuckle \
  --ref <branch-name>

# Watch progress
gh run list --repo projectbluefin/knuckle --workflow vm-e2e.yml --limit 3
gh run view <RUN_ID> --repo projectbluefin/knuckle
```

> ⚠️ `workflow_dispatch` only works once `vm-e2e.yml` is on `main`. For PRs before it's merged, use Option B.

**Option B — Local (`just vm-e2e`):**

```bash
cd ~/src/knuckle
git checkout <pr-branch>
just vm-e2e   # runs 4 passes: DHCP → static → sysext → NVIDIA
# output tee'd to /tmp/vm-e2e-run.log
```

Requires `/dev/kvm` accessible + QEMU installed. Any Linux machine with KVM works.
Flatcar base image (~480 MB) is cached at `.vm/flatcar_base_amd64.img` after first run.

**4 passes + what each verifies:**
| Pass | Verifies |
|---|---|
| DHCP | hostname, update strategy, core user groups |
| Static | `/etc/systemd/network/10-static.network` content (address, gateway, interface) |
| Sysext | `docker.raw` present + size, `systemd-sysext` active, `docker version` |
| NVIDIA | `/etc/flatcar/enabled-sysext.conf` contains `nvidia-drivers-*` |

**Old ghost path (`qa-test-pr.sh` with `QA_HOST=jorge@192.168.1.102`) is deprecated.**
Ghost is now optional for local dev only; GHA is the canonical CI path.

### Step 4 — Decision

**⛔ ONE COMMENT RULE: Post the strike report once, as a PR comment. That is the only substantive text that goes on the PR.**
- The report IS the review evidence. No separate review body text.
- `gh pr review --approve` with NO `-b` flag.
- `gh pr review --request-changes` via `gh` currently **requires a non-empty body**. Use the smallest possible body, e.g. `See strike report comment for requested changes.`
- The report comment explains the decision. Nothing else needed.
- If a PR flips from NOGO → GO after a fix, **edit the existing strike report comment** instead of posting a second comment.

```bash
# 🟢 GO — post report, approve with no body, queue
gh pr comment <N> --repo projectbluefin/knuckle \
  --body-file /tmp/qa-stdout-<N>.txt
gh pr review <N> --repo projectbluefin/knuckle --approve
gh pr merge --auto <N> --repo projectbluefin/knuckle

# 🔴 NOGO — post report, request changes with minimal body (gh requires it)
gh pr comment <N> --repo projectbluefin/knuckle \
  --body-file /tmp/qa-stdout-<N>.txt
gh pr review <N> --repo projectbluefin/knuckle --request-changes \
  --body "See strike report comment for requested changes."
```

| Code review | Ghost test | Action |
|---|---|---|
| APPROVE | 🟢 GO | Post report → approve (no body) → queue |
| APPROVE | 🔴 NOGO | Post report → request changes (minimal body only because gh requires it) |
| REQUEST_CHANGES | any | Post report → request changes (minimal body only because gh requires it) |
| Complex (skipped) | skipped | Post Tier 0 CI result only → leave review |

⛔ **ALWAYS use `gh pr merge --auto`. Never `gh pr merge` without `--auto`.**
Direct merge bypasses CI on the combined branch.

---

## PR Review Patterns by Domain

| Domain | Key check |
|---|---|
| `install` | `wipefs → flatcar-install → sfdisk` order; DryRunner no-ops all three |
| `ignition` | `{{- end}}` balanced; `yamlEscape` on every user string |
| `headless` | `Validate()` called before `ToInstallConfig()`; SSH keys validated |
| `tui` | No business logic in view model; `wizard.Apply*` for mutations |
| `validate` | Table-driven tests; error messages include the bad value |
| `wizard` | Conditional steps check selector in Next/Previous/GoToStep |
| `bakery` | SHA512 + GPG both checked; no per-call `http.Client` |
| `ci/release` | `persist-credentials: false` on all checkout steps |

---

## Posting the vm-e2e Report

After `just vm-e2e` or a GHA run completes, post a strike report comment:

```bash
# For local runs — summarize from /tmp/vm-e2e-run.log
gh pr comment <PR> --repo projectbluefin/knuckle --body "$(tail -20 /tmp/vm-e2e-run.log)"
gh pr review <PR> --repo projectbluefin/knuckle --approve        # if PASS
gh pr review <PR> --repo projectbluefin/knuckle --request-changes # if FAIL
```

For GHA runs, link the run URL in the comment. The run URL format:
`https://github.com/projectbluefin/knuckle/actions/runs/<RUN_ID>`

---

## cmd/knuckle TTY Issue in Non-Interactive Environments

`TestMain_TUINormalMode` and friends fail with `open /dev/tty: no such device or address`
when running without a PTY (nohup, SSH -f, non-interactive shells). These tests
pass in GitHub Actions CI (authoritative for Tier 0).

**This is a pre-existing infrastructure limitation** — not a PR regression. Work-around:
- For Tier 0 PRs, rely on GitHub Actions CI (authoritative) + note TTY issue in report
- Filed as tracking issue: see GitHub issues for "cmd/knuckle TTY test non-interactive"

---



## Common Failures and Fixes

| Failure | Cause | Fix |
|---|---|---|
| `'upstream' does not appear to be a git repository` | Ghost missing upstream remote | `git remote add upstream https://github.com/projectbluefin/knuckle.git` on ghost (one-time) |
| `To get started with GitHub CLI, please run: gh auth login` | gh not authed on ghost | Pass `GH_TOKEN=$(gh auth token)` — keyring not available on ghost |
| `go: updating go.mod: existing contents have changed since last read` | Parallel QA runs race on go.mod | Run QA scripts **sequentially**, never in parallel |
| `open /dev/tty: no such device or address` (cmd/knuckle tests) | No PTY in nohup/non-interactive worktree | Pre-existing infra bug; rely on GitHub CI (authoritative) for Tier 0; note in report |
| VM boot timeout | `flatcar-base.raw` corrupt | Re-run; first run reconverts from qcow2 |
| SSH permission denied | Key injection failed silently | Check `kv_inject_ssh_key`; `losetup -j img` for leftover loops |
| `--dry-run` non-zero | Binary from wrong commit | Verify `git rev-parse HEAD` matches PR head SHA |
| `INSTALL_FAILED` | `flatcar-install` non-zero | Read install log in report |
| `INSTALLED_BOOT_TIMEOUT` | Ignition failed at first boot | Check Ignition errors in knuckle-install.log |
| `FAIL: /var/swapfile NOT FOUND` | Swap service didn't run | Check `knuckle-create-swapfile.service` status |
| `BAD_PW_ACCEPTED_FAIL` | Plaintext password not rejected | Security regression — block the PR |
| PR stuck `BLOCKED`, no CI runs | First-time contributor — GitHub holds workflow runs | `gh api repos/projectbluefin/knuckle/actions/runs?status=action_required` then approve each run |
| `git index.lock` in parallel runs | Multiple scripts fetch/checkout concurrently | One git worktree per PR — run sequentially |
| KubeVirt VM stuck deleting | Controller race | Poll both VMI AND VM object gone before reuse |
| `git fetch ... pr<N>-qa` exits 128 | Stale local ref from prior run | `git update-ref -d refs/heads/pr<N>-qa` then rerun |
| `git worktree add` fails for `/tmp/knuckle-qa-wt-<N>` | Stale worktree from prior run | `git worktree remove /tmp/knuckle-qa-wt-<N> --force` before rerun |

---

## Script Rules (qa-test-pr.sh) — 2026-05-24

These rules are baked into the script (PR #336). Needed if extending the script.

- **RUNDIR must be absolute** — `$(pwd)/.qa/runs/${RUN_ID}`. Relative paths break inside `(cd $WORKTREE && ...)` subshells.
- **Quoted heredoc: no `\$` escaping** — Inside `<< 'ASSERT_SCRIPT_EOF'`, write `$(hostname)` and `${VAR}` directly. The quoted delimiter prevents local expansion. `\$(hostname)` is a bash syntax error.
- **Variable ordering** — Write `HOSTNAME_EXPECTED` and `HOST_PUB_KEY` to the script BEFORE the heredoc assertions. `set -u` rejects unbound variables.
- **COUNT: use `wc -l`** — `grep -cv '^$' || echo 0` produces `0\n0` on empty input; integer comparison fails.
- **Feature injection: LABELS only** — Check `$LABELS`, never `$TITLE`. A PR titled "fix tailscale tests" would otherwise inject a fake auth key into the QA config.
- **by-id empty on KubeVirt** — virtio disks have no serial numbers; `SKIP` not `FAIL`.
- **Stale ref cleanup** — if `git fetch upstream "pull/${PR}/head:pr${PR}-qa"` exits 128, delete the stale ref with `git update-ref -d refs/heads/pr${PR}-qa` before retrying.
- **Stale worktree cleanup** — if `/tmp/knuckle-qa-wt-${PR}` already exists or points at the wrong branch, remove it with `git worktree remove --force` before rerunning.

---

## Hanthor PR Patterns

- Stale branches accumulate all upstream changes — check `git diff merge-base..pr-HEAD --stat` to isolate the actual change.
- `size:XXL` PRs trigger complexity gate — do NOT ghost-test them.
- Verify unique change is not already in main before rebasing.

---

## Workflow File PRs

`.github/workflows/*.yml` PRs **cannot be auto-merged** — require `workflow` OAuth scope.
Jorge merges these manually via GitHub UI. Approve + leave; do not attempt `gh pr merge`.

Renovate already SHA-pins via `@SHA # vX` format. When Renovate and a SHA-pinning PR target
the same file, merge Renovate first, then rebase the pinning PR.

---

## VM E2E Infrastructure

VM e2e tests run on any Linux machine with KVM, or via GHA `vm-e2e.yml` workflow.

**Local requirements:** `/dev/kvm` accessible, `qemu-system-x86_64` installed, Go toolchain.
**GHA:** `ubuntu-latest` with KVM enabled (same pattern as `iso-boot-smoke` in `ci.yml`).

Ghost (192.168.1.102) remains available as an optional dedicated test machine but is no longer the canonical CI path. Load `ghost-testlab` skill only if you need to use ghost directly.

---

## ISO Boot Smoke Test

`just vm-e2e` does NOT test ISO boot — it installs via headless mode directly into a VM disk.
ISO boot is tested by the `iso-boot-smoke` GHA job in `ci.yml` (headless serial-log assertions).

For a full ISO boot test locally:

```bash
just iso stable         # build ISO → output/knuckle-installer-stable-amd64.iso
just iso-smoke output/knuckle-installer-stable-amd64.iso /usr/share/OVMF/OVMF_CODE_4M.fd 120
```

**Serial log invariants (checked by `iso-smoke.sh`):**
- `systemd.gpt_auto=0` must appear on BOTH BLS entries (primary + serial)
- `initrd-root-device.target`, `initrd-usr-fs.target`, `getty.target` must appear
- `x2dauto` / `xd2root.device` / `dracut.*skip` must NOT appear

**Critical ISO boot invariants (checked in build-iso.sh):**
- `systemd.gpt_auto=0` must be on **both** BLS entries (primary + serial)
- Without it: bare metal GPT disks cause systemd-gpt-auto-generator to create device units → dracut xd2root hook is skipped
- Root cause of v0.6.2 bare metal boot failure (fixed in v0.7.0)

---

## Worktree Hygiene

Worktrees from prior sessions accumulate silently in `/tmp/knuckle-pr-*`. Run cleanup at the **end of every batch session** to prevent `/tmp` bloat and git confusion (16 stale worktrees found 2026-05-24):

```bash
cd ~/src/knuckle
for wt in $(git worktree list --porcelain | grep worktree | awk '{print $2}' | grep /tmp/knuckle-pr-); do
  git worktree remove "$wt" --force 2>/dev/null && echo "removed $wt"
done
git worktree list  # verify clean
```

---

## Merge Conflict Guardrails

```bash
# Try GitHub auto-rebase first
gh pr update-branch <N> --repo projectbluefin/knuckle
# If that fails, rebase locally (see REFERENCE.md → PR Sequencing)
```

Never regex-based conflict surgery on Go files. Require `go build ./...` before staging.

---

## Powerlevel

- **Level:** 4

---

## Lessons Learned (2026-05-26)

### SA5011 lint gap: local passes, CI fails

`golangci-lint-action@v9` in CI catches SA5011 (nil-deref after t.Fatal) even when
`golangci-lint run ./...` locally reports clean. **Rule: always add `return` immediately
after every `t.Fatal(...)` nil-check guard.** Pattern:

```go
if result == nil {
    t.Fatal("expected non-nil result")
    return  // ← REQUIRED even though t.Fatal stops the test logically
}
```

Failing to do this blocks the entire merge queue for all open PRs.

### BATS test / script alignment: three rules

When modifying `scripts/qa-test-pr.sh`, follow these rules exactly — the BATS
test suite greps the mock git log for literal strings:

1. **`remove_worktree_path()` must unconditionally call `git worktree remove --force`**
   when the path exists on disk (not just when registered in `git worktree list`):
   ```bash
   if [[ -e "$path" ]]; then
     git worktree remove --force "$path" 2>/dev/null || true
     if [[ -e "$path" ]]; then rm -rf "$path"; fi
   fi
   ```
2. **`--force` before path** in all `git worktree remove` calls:
   `git worktree remove --force "$path"` (not `git worktree remove "$path" --force`)
3. **Use `git branch -D "$ref"` directly** for local branch cleanup — not
   `git update-ref -d || git branch -D` (the mock makes update-ref succeed, so
   branch -D fallback is never reached)

### Merged tests that break main

When a test-first PR merges (tests for behavior not yet implemented), all subsequent
PRs will fail BATS in CI. **Always run `bats scripts/tests/qa-test-pr.bats` locally
on main immediately after any script-touching PR merges.**

### File overlap = sequential queue

If two in-flight PRs touch the same file, they WILL conflict in the merge queue.
Check overlap before queueing: `gh pr diff <N> --name-only` on both PRs side-by-side.
Queue them sequentially, not simultaneously.

### Kubernetes API first, but ghost exec still gates Tier 3

When reviewing knuckle PRs, use the Kubernetes API / MCP tools first to inspect
`knuckle-test` state instead of SSHing to ghost for cluster operations. This is
the correct way to confirm whether VM/VMI resources still exist, whether stale
KubeVirt objects are blocking cleanup, and whether any boot/install evidence is
recoverable from the cluster side.

However, a missing or unavailable ghost execution path still blocks Tier 3
report generation today. `scripts/qa-test-pr.sh` and `scripts/lib/vm-kubevirt.sh`
still depend on ghost-side disk prep, artifact staging, and VM SSH hops. If the
cluster shows no live PR-specific VM/VMI resources, treat the Tier 3 rerun as
blocked rather than trying to reconstruct evidence from stale namespace state.

## Lessons Learned (2026-05-27)

### PR scope hygiene for agent-authored branches

Sub-agents repeatedly opened knuckle PRs that accidentally included unrelated
commits from stacked branch history. Add an immediate scope gate after every
agent-authored PR:

```bash
gh pr view <N> --repo projectbluefin/knuckle --json commits,files
gh pr diff <N> --repo projectbluefin/knuckle --name-only
```

If commit count or file list includes unrelated paths, **replace the PR**:
1. Create a clean branch from `upstream/main` in a fresh worktree.
2. Cherry-pick only the intended commit.
3. Open a replacement PR.
4. Close superseded PR with a pointer to the clean replacement.

This check must happen before reporting the issue/PR task as complete.

### vm-e2e debugging hygiene: never boot the base image directly

When reproducing vm-e2e issues manually, do **not** boot `.vm/flatcar_base_<arch>.img`
as a writable installer disk. Doing so mutates first-boot state and causes later runs
to skip Ignition key injection, which looks like random SSH auth failures.

Always boot a fresh overlay:

```bash
qemu-img create -f qcow2 -b "$(pwd)/.vm/flatcar_base_amd64.img" -F qcow2 .vm/boot.qcow2
```

and use `.vm/boot.qcow2` as installer disk. If a base image was accidentally booted
directly, delete it and let `just _ensure-base` redownload a clean copy.

### vm-e2e sysext/nvidia passes: disable swap explicitly

Headless config defaults swap to enabled when `swap` is omitted. In sysext-focused passes,
that can introduce unrelated boot ordering noise (e.g. `systemd-sysext` cycle messages)
that obscures the real signal.

For sysext and nvidia vm-e2e passes, set:

```json
"swap": {"enabled": false}
```

to keep assertions focused on sysext/NVIDIA behavior.

## Lessons Learned (2026-05-28)

### Always verify current coverage before filing coverage PRs

Before opening a PR to add tests for "uncovered" functions, always run
`go tool cover -func` against the **current main** branch (after pulling latest).
Coverage gaps in older quality agent reports may have been closed by subsequent PRs.

```bash
cd /var/home/jorge/src/knuckle
git fetch upstream main && git checkout upstream/main
go test -count=1 ./internal/<pkg>/... -coverprofile=/tmp/cov.out
go tool cover -func=/tmp/cov.out | grep -v "100.0%"
```

If all target functions already show 100%, close the issue and do NOT open the PR.

**Root cause of PR #616**: Filed by quality agent for `splitSSHKeys`/`mergeKeys`
(both at 0% in its stale coverage data). By the time it opened the PR, both functions
were at 100% on main (covered by earlier tests in the sprint). Issue #609 was also
already closed.

### Ghost kv_prepare_disk failure is infrastructure noise for kind/test PRs

For Tier 1 PRs labeled `kind/test` (pure test additions, no behavior change):
- If `kv_prepare_disk` fails and GitHub Actions CI is all green → post strike report
  noting the infra issue and proceed with approve + queue.
- Do NOT block a `kind/test` PR for ghost infra failures.

Pattern in the report:

```
### Tier 1 — Ghost VM
⚠️ Infrastructure failure: kv_prepare_disk failed — disk preparation error unrelated to this PR.
Pre-existing infrastructure issue. GitHub Actions CI is authoritative for Tier 0/1 kind/test PRs.
```

### detectLocalSSHKeys: UserHomeDir error path is unit-testable

`os.UserHomeDir()` returns an error when `HOME=""` on Linux:

```go
// In tests:
t.Setenv("HOME", "")
keys := detectLocalSSHKeys()  // triggers error path — returns nil
```

This is reliable on Linux (Go checks `$HOME` first; empty string triggers the error).
Use `t.Setenv` (auto-restored after test) rather than `os.Setenv` to avoid test pollution.

## Lessons Learned (2026-05-29)

### Quality agent stale coverage — third recurrence, escalation pattern

The quality agent has now filed duplicate coverage PRs for already-covered functions three times:
- PR #616 (2026-05-28): `splitSSHKeys`/`mergeKeys` — closed
- PR #629 (2026-05-29): same functions again — closed
- PR #635 (2026-05-29): ignition non-HTTPS guard — closed (`internal/ignition` already 100%)

**Root cause:** Quality agent snapshots coverage data at task creation time and does not re-check before filing. By the time it files the PR, the gap may have been closed by a sprint.

**Detection:** Before closing a coverage PR as stale, run coverage against current main and confirm. Post a comment explaining the root cause — the quality agent will see it.

**If the agent files a 4th recurrence for the same function:** the agent's coverage snapshot mechanism needs a fix at the source (pre-flight `go tool cover -func` check against `upstream/main` before any issue/PR is created).

### FCOS rubber duck: installer wiring — OS unknown at construction time

When reviewing the FCOS implementation plan, the rubber duck caught a critical architectural flaw:

`cmd/knuckle/main.go` constructs `FlatcarInstaller` and `bakery.NewHTTPClient()` **before** the TUI starts. The user selects the OS (Flatcar / FCOS) at `StepWelcome` inside the wizard. By construction time, `cfg.OS` is unknown.

**Pattern for any knuckle feature that branches on user input from StepWelcome:** Never construct OS-specific impls in main.go and pass them as concrete types. Use a `DispatchingInstaller` that holds both impls and delegates at `Install()` call time based on `cfg.OS`.

```go
installer = &install.DispatchingInstaller{
    Flatcar: install.NewFlatcarInstaller(cmdRunner, logger),
    FCOS:    install.NewFCOSInstaller(cmdRunner, logger),
}
```

Same pattern applies to the bakery client — the wizard must call the correct `FetchCatalog*` method based on `cfg.OS` at `StepSysext`, not at startup.

### FCOS ISO: use `coreos-installer iso customize`, not `pxe customize`

For embedding knuckle into an FCOS live ISO:
- **Correct:** `coreos-installer iso customize --dest-ignition installer.ign --output out.iso fcos-live.iso`
- **Wrong:** `coreos-installer pxe customize` (for PXE images, not ISO)

Also: FCOS live image runs `getty@tty1.service` with autologin for `core`. The knuckle service unit must add `Conflicts=getty@tty1.service` and `Before=getty@tty1.service` or the TUI will not render.

### SA5011 + gofmt: two failure modes in quality agent PRs (2026-05-29)

Two new failure patterns observed in quality agent PRs this session:

1. **gofmt**: `form_logic_coverage_test.go` had no tab indentation in the import block or function bodies. Always run `gofmt -w <file>` before committing any new test file. The gofmt check in `just ci` is authoritative.

2. **`t.Error` before nil deref** (distinct from SA5011): Using `t.Error` (not `t.Fatal`) before a field access on an error value causes a runtime panic if the assertion fails. `t.Error` does not stop the test — it only marks it failed. Pattern:

```go
// WRONG — panics if m.err == nil
if m.err == nil {
    t.Error("expected error")
}
if !strings.Contains(m.err.Error(), "...") { // panics

// CORRECT
if m.err == nil {
    t.Fatal("expected error")
    return
}
if !strings.Contains(m.err.Error(), "...") {
```

## Lessons Learned (2026-05-29, session 2)

### action_required: first-time contributor PRs need workflow approval

PRs from first-time contributors have CI runs stuck at `action_required` — GitHub holds
all workflow runs until a maintainer approves. CI shows `null` checks in `statusCheckRollup`.

**Detection:**
```bash
gh run list --repo projectbluefin/knuckle --branch <branch> --limit 3 \
  --json status,conclusion,name | jq '.[]'
# conclusion: "action_required" = needs approval
```

**Fix:**
```bash
gh api repos/projectbluefin/knuckle/actions/runs/<RUN_ID>/approve --method POST
# Approve all action_required runs (CI + Security separately)
```

### Can't self-approve: author cannot approve their own PR

`gh pr review <N> --approve` fails with `Review: Can not approve your own pull request`
when the agent's GitHub account authored the PR. Leave the strike report comment and
note in the report that manual approval is required.

### Quality agent gofmt + nil-guard failures (4th recurrence pattern)

Quality agent PRs consistently fail with two patterns — check both before approving:

1. **gofmt**: New test files submitted without proper tab indentation.
   Fix: `gofmt -w <file>` then push. CI gofmt check is authoritative.

2. **`t.Fatal` missing `return`** (SA5011): New tests use `t.Fatal` but omit `return`
   before dereferencing the checked value. Must add `return` on the line after every
   `t.Fatal` that guards a subsequent dereference.

3. **`t.Error` before dereference** (runtime panic): `t.Error` does not stop the test.
   Using `t.Error` before `value.Field()` panics if value is nil. Use `t.Fatal` + `return`.

**Quick check before approving any quality agent PR:**
```bash
gofmt -l <file>                    # must be empty
grep -n "t\.Error" <file>          # check each: is there a dereference after?
grep -A2 "t\.Fatal" <file>         # check each: is return present?
```

### codecov.yml overlap: sequence PRs that touch the same file

PRs #648 and #650 both modified `codecov.yml`. Queue sequentially — merge #648 first,
then approve + queue #650 after it lands. The merge queue will conflict otherwise.

## Lessons Learned (2026-05-30)

### vm-e2e.yml: Go JSON silently ignores unknown fields

When writing headless configs in the GHA vm-e2e workflow, use the **exact JSON field
names from `internal/headless/headless.go`**. Go's `encoding/json` silently ignores
unknown fields — the install succeeds, but the feature is not configured.

Correct NVIDIA config:
```json
{"nvidia_driver_version": "570-open", "swap": {"enabled": false}, ...}
```
Wrong (silently ignored):
```json
{"nvidia": {"enabled": true, "driver_type": "open"}, ...}
```

Always cross-reference `docs/HEADLESS-CONFIG.md` for the canonical field names
before writing any headless config in a workflow file.

### vm-e2e GHA assertion paths must match actual Butane output

Assertions in `vm-e2e.yml` must match what knuckle's Butane template actually writes.
Check `internal/ignition/ignition.go` (the `butaneTemplate` const) for the exact file
paths written to the installed system before writing any `$E2E_SSH "test -f ..."` check.

NVIDIA writes to `/etc/flatcar/enabled-sysext.conf` — NOT `/etc/sysupdate.d/`.

### vm-e2e.yml first successful GHA run baseline

Run [#26690064969](https://github.com/projectbluefin/knuckle/actions/runs/26690064969)
(2026-05-30): all 4 passes green on Flatcar 4593.2.1.
- Cold run: ~8 min. Cache hit run: ~3 min.
- Flatcar image cached as `flatcar-qemu-stable-amd64-<VERSION>` (~480 MB).

## Lessons Learned (2026-06-01)

### Quality agent stale issues — detection and cleanup pattern

Three recurring stale/duplicate issue patterns resolved this session:

1. **Stale coverage gap**: Before acting on a quality issue, always verify the gap still
   exists on current `upstream/main`:
   ```bash
   go test -count=1 -cover ./internal/<pkg>/... 2>/dev/null
   ```
   Issue #661 (tui at 98.1%) was stale — actual was 99.7%, above the 99% gate.

2. **Duplicate issues**: Quality agent filed #669 and #673 for the same gap
   (`cmd/compile-butane-fresh` missing from cover-check), and #663 and #670 for the
   same `cmd/knuckle` threshold issue. Close the lower-quality/older one as a duplicate
   with a pointer to the canonical issue.

3. **Batch fix**: A single PR (#675) can close multiple small quality issues
   (Justfile gate fixes + BATS test additions) to avoid merge queue noise.

### httptest patching for cmd/ tools: const → var pattern

When a `cmd/` tool has a hardcoded URL constant and you want to write httptest
tests that patch it, convert `const` to `var`:

```go
// Before (untestable)
const docsURL = "https://..."

// After (patchable in tests)
var docsURL = "https://..."
```

Then in tests:
```go
orig := docsURL
docsURL = srv.URL
defer func() { docsURL = orig }()
```

This was done for `cmd/nvidia-check/main.go` to enable 100% coverage of
`fetchNvidiaDocs`. Note: removing any now-orphaned companion constants to avoid
`golangci-lint unused` failures.

### cmd/ package coverage expectations

`main()` in `cmd/` packages is typically 0% covered (CLI entry with network
calls, fmt.Println, os.Exit). This is normal and expected. Focus coverage
efforts on the non-main functions (`fetchX`, `extractX`, etc.) which are
fully testable. Do not add `cmd/<tool>` to the cover-check gate unless
non-main functions can be driven above a meaningful threshold (≥50%).
