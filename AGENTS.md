# bluefin-common — Fork Workflow Notes

> Project instructions (build, structure, labels): see upstream AGENTS.md (injected from system_files context).
> This file adds fork-specific workflow context for castrojo/common.

## Fork Identity

- **Upstream:** projectbluefin/common
- **Fork:** castrojo/common
- **Role:** Primary planning hub and label authority for ALL bluefin ecosystem repos

## Critical Context

This repo is the **source of truth** for:
1. GitHub label schema across `projectbluefin/*` and `ublue-os/bluefin*` repos
2. The GitHub Projects planning board for the entire Bluefin ecosystem
3. Shared OCI configuration layer consumed by all Bluefin image variants

**Label management scope** (only these repos — no others):
- @projectbluefin/common
- @projectbluefin/dakota (formerly distroless)
- @ublue-os/bluefin
- @ublue-os/bluefin-lts

**Label rules:**
- NEVER touch issues themselves — only labels
- Colors must remain consistent across all four repos
- `projectbluefin/common` is canonical; sync others to match it
- Known drift exists — see project-notes.md for the full inventory

## Session Start

```bash
git fetch upstream
git log --oneline upstream/main..main   # must show ≤1 commit (this file)
git rebase upstream/main && git push origin main --force-with-lease
git submodule update --init --recursive
```

## Validation

```bash
just check      # lint Justfile and all .just files
just build      # full container build (slow — requires podman + network)
```

## Work Branch Flow

```bash
git worktree add .worktrees/<branch> -b <type>/description
```

Changes here propagate to ALL downstream Bluefin variants. Keep changes surgical.

## Submodule

`bluefin-branding` → projectbluefin/branding (wallpapers, logos).
`just build` initializes it automatically.

## Ecosystem Fork Discipline

All `ublue-os` and `projectbluefin` repos worked on must have a fork in the `castrojo` namespace.

**Known bluefin ecosystem repos:**

| Upstream | Fork | Local path |
|---|---|---|
| `ublue-os/bluefin` | `castrojo/bluefin` | `~/src/bluefin` |
| `ublue-os/bluefin-lts` | `castrojo/bluefin-lts` | `~/src/bluefin-lts` |
| `ublue-os/bluefin-docs` | `castrojo/bluefin-docs` | `~/src/bluefin-docs` |
| `projectbluefin/common` | `castrojo/common` | `~/src/bluefin-common` |

Fork `main` (and `lts` where applicable) must always be **at most 1 commit ahead of upstream** — that commit being the fork-only `AGENTS.md` + `.gitattributes` commit.

For any repo not yet forked, run the `onboarding-a-repository` skill first.

### Sync after upstream moves

```bash
git fetch upstream
git rebase upstream/main
git push origin main --force-with-lease
```

Work branches are rebased onto freshly-synced `main` — never merged.

### Signs a fork needs cleanup (hard-reset if any are true)

- `git log upstream/main..main` shows more than 1 commit
- Renovate bot commits appear on fork `main`
- Old merge commits (`Merge branch 'ublue-os:main' into main`) are present

```bash
git fetch upstream
git reset --hard upstream/main
# re-apply fork-only commit
git cherry-pick <agents-md-commit-sha>   # or re-create it
git push origin main --force
```

## Extended Notes

> Full architecture, label schema, drift inventory, and session reference:
> `~/.config/opencode/plans/common/project-notes.md`
