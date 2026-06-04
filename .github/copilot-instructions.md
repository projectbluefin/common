# bluefin-common — Copilot Instructions

**bluefin-common** is the shared OCI layer consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical.

## Session start — mandatory

Run this first, every time, before any other work:

```bash
~/src/hive-status
```

No arguments, no auth required, completes in under 5 seconds. It surfaces P0/P1 blockers and the current advisory queue. Do not proceed without it.

## Repo layout

```
Containerfile              # OCI image build
Justfile                   # Build automation
system_files/
  shared/                  # Config applied to ALL Bluefin variants (and Aurora)
  bluefin/                 # Config applied to Bluefin-specific variants only
.github/
  CODEOWNERS               # Triager sentinel — source of truth for all repos
  workflows/
    build.yml              # Build + push on merge to main
    e2e.yml                # Post-merge e2e against bluefin, bluefin-lts, dakota
    sync-codeowners.yml    # Syncs TRIAGERS block to downstream repos
    validate-just.yml      # PR gate: just check
    validate-brewfiles.yaml
docs/skills/               # Institutional memory — INDEX.md lists all skills
```

**When adding files:** `system_files/bluefin/` for GNOME/desktop-specific changes; `system_files/shared/` for everything else (Aurora consumes shared).

## Build and validate

```bash
just check                    # lint Justfile + all .just files (run before every commit)
just build                    # full OCI build — requires podman + network, slow
pre-commit run --all-files    # json/yaml/toml hygiene + actionlint
```

## PR procedure — follow exactly

1. Fetch and branch from upstream `main`, never from a stale local base:
   ```bash
   git fetch upstream && git checkout -b feat/my-change upstream/main
   ```
2. Make changes. Run `just check` and verify it passes.
3. Squash all commits to **one logical commit** before opening the PR.
4. Resolve any conflicts locally before pushing — never open a PR with conflicts.
5. PR title: Conventional Commits format (`feat:`, `fix:`, `chore(deps):`, etc.)
6. Attribution trailer on every AI-authored commit:
   ```
   Assisted-by: <Model> via <Tool>
   Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
   ```
7. Push and open the PR. Do not leave uncommitted changes at end of session.

**Never open a WIP PR. Max 4 open PRs at once.**

## CI gates

| When | What runs |
|---|---|
| Every PR | `validate-just` + `build` (no VM boot) |
| Merge to main | Full `common` behave suite via testsuite (SSH, ~15 min) |

PRs only need the PR gates to pass. Do not wait for post-merge e2e.

## CODEOWNERS — sentinel pattern

The triager block in `.github/CODEOWNERS` is the **single source of truth** for triage permissions across all four repos:

```
# BEGIN TRIAGERS — managed by projectbluefin/common, do not edit manually in downstream repos
docs/**  @handle1 @handle2
*.md     @handle1 @handle2
# END TRIAGERS
```

**Only edit this block in `projectbluefin/common`.** The `sync-codeowners.yml` workflow pushes changes to `bluefin`, `bluefin-lts`, and `dakota` automatically on push to `main`. Never edit the sentinel block in downstream repos.

Cross-repo writes use the **mergeraptor** GitHub App (`MERGERAPTOR_APP_ID` / `MERGERAPTOR_PRIVATE_KEY`). PATs are banned in this org.

## Issue lifecycle

`filed → approved → queued → claimed → done`

- `queue/agent-ready` label = available to claim
- `/claim` comment = assigns the issue to you, removes from pool
- 7 days without PR activity = auto-returns to queue

## Scope discipline

When given a task, read the intent literally:
- "work on hive priority issues" = pick the top issue from `~/src/hive-status` output and fix it
- "do PR reviews" = review open PRs, do not start fix work
- If a session could involve both, confirm scope before acting

## PR comment policy

One comment per PR event. Combine all findings. Never post a follow-up — edit the existing comment. Never duplicate GitHub UI state (approvals, CI status). When in doubt, post nothing.

## Downstream impact

Changes to `system_files/shared/` affect **bluefin, bluefin-lts, Aurora, and dakota** simultaneously. A broken shared change will fail all downstream builds at next compose. Test locally with `just build` before pushing anything to shared.
