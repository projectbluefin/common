# Developer Experience portal rebuild

## Summary

Rebuild `system_files/bluefin/etc/bazaar/article-devtools.md` into a working Markdown-first portal for Bluefin's developer stack. The page should render reliably in Bazaar, use current repo sources as truth, and act as the landing page for Developer Mode, Brew IDEs, container tooling, and command-line workflows.

## Problem

The current page is unfinished and brittle:

- it relies on large raw HTML blocks instead of the Markdown patterns used by working Bazaar articles
- it contains stale DX framing and references that drift from current `ujust devmode` behavior
- it ends with placeholder lorem ipsum content
- it is no longer serving as a useful portal for Bluefin's current developer tooling

## Goals

1. Make the page render cleanly in Bazaar.
2. Make `ujust devmode` the primary setup entrypoint.
3. Turn the article into an exhaustive portal for the requested sections:
   - entrypoint
   - IDEs and editors
   - containers and virtualization
   - CLI and CNCF tooling
   - recommended workflows
4. Source every listed tool from the current repository contents rather than hand-maintained marketing copy.

## Non-goals

- Adding new tools to Brewfiles or the devmode wizard
- Changing `system.just` behavior
- Building an automatic generator in this pass
- Reworking unrelated Bazaar articles

## Source of truth

- `system_files/bluefin/usr/share/ublue-os/just/system.just` for Developer Mode entrypoint and selected install surface
- `system_files/shared/usr/share/ublue-os/homebrew/ide.Brewfile` for IDEs, editors, and VS Code extensions
- `system_files/shared/usr/share/ublue-os/homebrew/cli.Brewfile` for core CLI tools
- `system_files/shared/usr/share/ublue-os/homebrew/cncf.Brewfile` for cloud-native tooling
- Existing Bazaar article patterns such as `article-ai.md` and `article-games.md` for render-safe Markdown structure

## Proposed structure

### 1. Opening section

Short explanation that Bluefin's developer experience is an in-place setup flow, not a special image flavor. The primary call to action is `ujust devmode`.

### 2. Developer Mode entrypoint

Small section explaining what `ujust devmode` turns on and which categories it exposes:

- IDEs and editors
- Docker and Podman Desktop
- virtualization options such as virt-manager, Lima, and incus
- developer-oriented group setup and reboot requirement

This section should stay brief and practical.

### 3. IDEs and editors

Use Markdown tables split by role:

- GUI IDEs and casks
- terminal editors
- VS Code extensions shipped by default

Each row should state the tool name, what it is for, and either:

- a Homebrew formula/cask page link, or
- a direct install hint when a web link is more useful than a Bazaar deep-link

### 4. Containers and virtualization

Use a Markdown table covering:

- Docker
- Podman Desktop
- Virtual Machines via virt-manager and QEMU
- Lima
- incus
- devcontainer CLI

This section should clearly separate what comes from the devmode wizard from adjacent tooling that supports the workflow.

### 5. CLI and CNCF tooling

Use grouped Markdown tables:

- core shell and workstation tools from `cli.Brewfile`
- cloud-native and Kubernetes tooling from `cncf.Brewfile`

Keep the list exhaustive but readable by grouping related tools and keeping descriptions short.

### 6. Recommended workflows

Close with short practical guidance mapping jobs to tools, for example:

- local container development
- remote development containers
- Kubernetes cluster work
- virtualization and local VM work
- general shell productivity

## Content rules

- Prefer Markdown tables and short lists over raw HTML layouts.
- Do not mention `bctl --screen developer` as the primary entrypoint.
- Do not describe DX as a retired `-dx` image flow.
- Do not leave placeholders, lorem ipsum, or speculative copy.
- Keep descriptions functional and source-backed.

## Validation

- Confirm the final article uses plain Markdown patterns already proven in other Bazaar pages.
- Confirm all named tools still exist in the current repo sources being cited.
- Run the existing Bazaar/config and repo validation commands appropriate for a doc-only Bazaar article change.

## Skill write-back

If the rewrite confirms a reliable authoring pattern for Bazaar portal pages, update `docs/skills/bazaar.md` in the same implementation change so future agents avoid raw-HTML article regressions.

## Acceptance criteria

- `article-devtools.md` no longer contains the broken card-wall HTML layout
- `article-devtools.md` uses `ujust devmode` as the main setup command
- the requested sections are present and exhaustive from current sources
- stale DX-image framing and placeholder text are removed
- the page reads as a portal for Bluefin developer tooling rather than unfinished marketing copy
