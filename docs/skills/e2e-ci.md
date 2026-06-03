---
name: e2e-ci
description: Post-merge E2E CI architecture for projectbluefin/common — common suite, brew masking in CI, quarantined scenarios.
---

# E2E CI Architecture — projectbluefin/common

Reference for agents working on test failures in the post-merge E2E suite.

## How the common suite runs

The common post-merge E2E (`common/.github/workflows/e2e.yml`) calls the reusable
workflow at `projectbluefin/testsuite/.github/workflows/e2e.yml@main` with `suites: common`.

**The common suite is special** — it runs behave directly on the GHA runner (not inside
a pre-built container). The runner SSHes to the VM at `127.0.0.1:2222` as `bluefin-test`.

```yaml
# testsuite e2e.yml (simplified)
if: env.SUITE == 'common'
  run: |
    python3 -m pip install behave
    behave tests/common/features/
else
  # Load pre-built runner container, then run behave inside it
```

The pre-built runner container does **not** affect the common suite because of this conditional.

## VM kernel args

```
systemd.mask=brew-setup.service
```

`brew-setup.service` is masked for every test VM. This means:

- Homebrew itself is present at `/home/linuxbrew/.linuxbrew/bin/brew`
- **Brew packages are NOT installed** — `eza`, `fd`, `rg`, `bat`, `fzf`, `starship`, etc.
  are all from `cli.Brewfile` and require brew-setup to run first
- Any test that checks for these tools will fail in CI

## Known CI failures and their status

### brew CLI tools (eza, fd, ripgrep, bat, fzf, starship) — QUARANTINED

**Root cause:** These are `cli.Brewfile` packages. `brew-setup.service` is masked.
The `ublue-os/brew` image only ships a bare Homebrew tarball at `/usr/share/homebrew.tar.zst`.

**Status:** Quarantined in `tests/common/features/common_shell.feature` via `@quarantine`.
Tracking issue: projectbluefin/testsuite#210

**Options to unblock:**
1. Un-mask `brew-setup.service` in CI (adds ~60s)
2. Install tools as RPMs in the Containerfile
3. Add a CI step to `brew bundle install` before the suite runs

### zsh / fish — QUARANTINED

**Root cause:** zsh and fish ARE installed as RPMs (`/usr/bin/zsh`, `/usr/bin/fish`).
However, under the `bash -lc '...brew_shellenv...; zsh --version'` SSH command that
`environment.py` uses, they return `command not found`. PATH does not include
`/usr/bin` in this non-interactive login context for the fresh `bluefin-test` user.

**Status:** Quarantined. Tracking issue: projectbluefin/testsuite#210

### Dakota MOTD — FIXED (testsuite PR #208)

**Root cause:** `run_ssh()` in `ssh_steps.py` wraps commands in `bash -lc` (login shell)
when `ssh_command_prefix` is set. This triggers `/etc/profile.d/ublue-motd.sh`, which
calls `ublue-motd` and prints the MOTD to stdout. The `vm_reachable_over_ssh` step
checked `stdout == "ok"` (exact match) but got MOTD prepended.

Only Dakota prints a MOTD; Bluefin stable/LTS pass unaffected.

**Fix (testsuite PR #208):**
- Creates `~/.config/no-show-user-motd` for the CI user in VM setup
- Changes assertion to `stdout.strip().split('\n')[-1] == "ok"`

## SSH command execution model

```python
# testsuite/tests/shared/ssh_steps.py
# When context.ssh_command_prefix is set (always true for common suite):
cmd_wrapped = f"bash -lc {shlex.quote(f'{prefix}; {cmd}')}"
```

`environment.py` sets `ssh_command_prefix` to include `eval $(brew shellenv)` so brew
tools are on PATH inside the VM. Side effect: login shell triggers profile.d scripts.

## Images tested

| Job | Image |
|---|---|
| E2E — Bluefin LTS | `ghcr.io/ublue-os/bluefin:lts` |
| E2E — Bluefin Stable | `ghcr.io/ublue-os/bluefin:latest` |
| E2E — Dakota | `ghcr.io/projectbluefin/dakota:latest` |

All three run `suites: common` only. Post-merge only — not triggered on PRs.
