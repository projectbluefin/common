---
name: knuckle-qa-lessons
description: "Historical lessons learned from knuckle QA sessions (May 2026). Archived from knuckle-qa.md to keep the main skill doc under the 500-line limit."
---

# knuckle-qa — Lessons Learned Archive (May 2026)

_Archived from `knuckle-qa.md` — see that file for the active workflow._

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
