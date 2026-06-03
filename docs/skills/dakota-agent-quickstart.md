---
name: dakota-agent-quickstart
description: Zero-context entry point for less-capable agents doing routine dakota maintenance — add package, remove package, update refs. Routing table only; load task-specific skills for details.
---

# Dakota Agent Quickstart (dakotaraptor)

Load with: `cat ~/src/skills/dakota-agent-quickstart/SKILL.md`

## When to Use
- Routine dakota maintenance tasks: add package, remove package, update refs
- Less-capable agents doing automated dakota upkeep
- Entry point when you need task-specific skill routing for dakota work

## When NOT to Use
- Complex debugging or CI failures — use dakota-debugging or dakota-ci instead
- First time setting up a new package type — use the specific packaging skill
- Any dakota work requiring deep context — load the full domain skill instead

For agents with no prior context. Read `AGENTS.md` in the repo root, then follow this skill.

## Powerlevel

- **Level:** 1

## 5 Always Rules

1. **Always run `just --list` first** — the Justfile is the ground truth for available recipes
2. **Always run `just validate <element>` before `just bst build`** — catches errors without building
3. **Always add new elements to `deps.bst`** (binary) or `gnome-shell-extensions.bst` (extensions)
4. **Always run `just remove-package <name>` before touching any files** — it prints the full checklist
5. **Always use `just bst` not bare `bst`** — BST must run inside the pinned container

## Throughput rule

If the user says **"fix bugs"**, **"fix open issues"**, or otherwise signals backlog throughput, do **not** stop after the first local bug you find.

Work from the repo issue backlog in this order:
1. `needs-human/agent-ready`
2. `kind/bug`
3. issues explicitly named by the user

Only fall back to opportunistic local regressions when they directly block the requested issue work.

## 5 Never Rules

1. **Never edit** `elements/freedesktop-sdk.bst` or `elements/gnome-build-meta.bst` without human review
2. **Never open a PR** to `projectbluefin/dakota` without NUC hardware confirmation AND explicit human permission
3. **Never add Renovate entries** for elements already in the `track-tarballs` CI job — causes racing PRs
4. **Never call `bst` directly** — always `just bst ...`
5. **Never skip `just validate`** even if `just bst build` "looks right"

## Task Routing

```
Add binary package    → just scaffold-binary <name> <owner/repo>  → skill: dakota-add-package
Add Rust package      → just scaffold-rust <name> <owner/repo>    → skill: dakota-add-package → dakota-package-rust
Add GNOME extension   → just scaffold-gnome-ext <name> <owner/repo> → skill: dakota-package-gnome-extensions
Remove package        → just remove-package <name>                → skill: dakota-remove-package
Update tarball        → just track-tarball <element.bst> <ver>    → skill: dakota-update-refs
Update git ref        → just track-one <element.bst>              → skill: dakota-update-refs
Build failure         → just bst shell --build <element.bst>      → skill: dakota-debugging
BST YAML reference    → skill: dakota-buildstream
```

## Tracking group rules

| Group | When to use |
|-------|-------------|
| `auto-merge` | App packages, shell extensions — low-risk, squash-merged automatically |
| `manual-merge` | Junctions (freedesktop-sdk, gnome-build-meta), Rust elements — requires human review |

## Commit conventions

```
feat(bluefin): add <name>
chore(deps): update <name>
fix(bluefin): <description>
chore: remove <name>
```

## Where things live

```
elements/bluefin/           All Bluefin-specific elements
elements/bluefin/deps.bst   Central dependency manifest
elements/bluefin/shell-extensions/         GNOME Shell extensions
elements/bluefin/gnome-shell-extensions.bst  Extension stack
files/templates/            Element scaffolds (binary, rust, gnome-ext, git-tracked)
include/aliases.yml         URL aliases
.github/workflows/track-bst-sources.yml    Tracking matrix
.github/renovate.json5      Renovate config
```
