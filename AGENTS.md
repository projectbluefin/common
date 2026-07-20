# bluefin-common — Agent Operating Contract

`bluefin-common` is the shared OCI layer consumed by `bluefin`, `bluefin-lts`,
and `dakota`. Changes here propagate to every variant. Stay surgical.

## Read order

1. This file — repo rules, build commands, and boundaries.
2. [`docs/SKILL.md`](docs/SKILL.md) — find the skill for your task and load it.
3. [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md) — cross-repo
   rules if the task spans repos.

## Build, test, and lint

```bash
just check                 # lint Justfile
just test                  # pytest + bats
just build                 # full OCI build (slow, requires podman + network)
pre-commit run --all-files # yaml/json/sha/actionlint hygiene
```

Run `just check` and `pre-commit run --all-files` before every commit.

## Agent fast path

- Read source before asserting project-internal facts (image names, tags,
  workflow outputs). Use `gh api` to inspect workflows, not memory.
- Look up external tool docs via Context7 first — see `docs/skills/context7.md`.
- When a session surfaces a non-obvious pattern or workaround, update the
  matching `docs/skills/*.md` file in the same PR.

## What agents may touch

- `system_files/shared/` — global config (also consumed by Aurora).
- `system_files/bluefin/` — GNOME/Bluefin-specific config only.
- `system_files/nvidia/` — NVIDIA overlay.
- `Justfile`, `Containerfile`, tests, `docs/`, `AGENTS.md`, and
  `.github/workflows/`.

## What agents must not touch

- Any `ublue-os/*` repository (read-only; no writes of any kind).
- Vendored files under `system_files/bluefin/usr/share/gnome-shell/extensions/`.
- Org/app credential pairs; use `GITHUB_TOKEN` or provisioned GitHub Apps.

## Doc-only push exception

Changes that touch only `docs/**` and/or `AGENTS.md` may be pushed directly to
`main` without a PR. Verify first:

```bash
git diff --cached --name-only  # must show only docs/* or AGENTS.md
```

**Everything else requires a branch + PR targeting `main`.**

## PR rules

- Conventional Commits title (`feat:`, `fix:`, `docs:`, `ci:`, `refactor:`).
- One logical change per PR.
- Skill doc updated in the same PR when implementation context changed.
- AI-authored commits include both attribution trailers as a convention:
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- Ask before opening PRs autonomously; prepare the branch and diff first.
- After pushing, verify CI is green:
  `gh run list --repo projectbluefin/common --limit 5`.

## Human decision gates

Stop and request human input before: Design, Security, Breakage (cross-repo
breaking changes), or Merge review. See `docs/skills/human-gates.md`.

## Scope warning

A broken change in `system_files/shared/` breaks `bluefin`, `bluefin-lts`,
and `dakota` simultaneously. Test locally where possible.

## Code ownership

```
system_files/shared/**   @inffy @renner0e @ledif @castrojo @hanthor @ahmedadan
system_files/bluefin/**  @castrojo @hanthor @ahmedadan
**/*.md                  @repires @KiKaraage @projectbluefin/maintainers
```

## Canonical sources

| Topic | Source |
|---|---|
| Factory org structure | `docs/factory/README.md` |
| Cross-repo agent hard rules | `docs/factory/agentic-model.md` |
| Issue lifecycle / labels | `docs/skills/label-workflow.md` |
| CI tooling / SHA pinning | `docs/skills/ci-tooling.md` |
| Image registry / tags | `docs/skills/image-registry.md` |
| Skill improvement mandate | `docs/skills/skill-improvement.md` |
| PR review checklist | `docs/skills/pr-review.md` |

## See also

- [`README.md`](README.md) — project overview for humans.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contributor quick start.
- [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) — workflow index.
