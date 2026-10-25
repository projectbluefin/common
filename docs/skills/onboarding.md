---
name: onboarding
version: "2.0"
last_updated: "2026-09-13"
id: onboarding
one_line_purpose: Set up a verified dev environment for projectbluefin repos.
entry_point: docs/skills/onboarding.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [onboarding, setup, getting-started]
description: >-
  Setup commands and PR branch targets for projectbluefin repos, limited to
  what is verified against the live repositories. Use when setting up a dev
  environment or writing contributor documentation.
metadata:
  type: reference
---

# Onboarding — Setup Commands per Repo

Only non-obvious commands are recorded here — the ones where the obvious
invocation fails. Every repo below also has its own `README.md` and most have an
`AGENTS.md`; read those for the full build.

## common (this repo)

```bash
just check                    # Justfile + script syntax
pre-commit run --all-files    # lint/format checks (pip install pre-commit first)
just build                    # build the OCI layer locally
```

`.gitmodules` has exactly two entries — `bluefin-branding` and the
`custom-command-list@storageb.github.com` GNOME extension. Both are needed:

```bash
git submodule update --init --recursive
```

## documentation (docs.projectbluefin.io)

```bash
npm install --legacy-peer-deps   # bare npm install hits React 19 peer conflicts
npm run start
```

`package.json` pins `react: ^19.0.0`, which is what the peer conflict comes
from.

## website (projectbluefin.io)

```bash
npm install --include=dev   # without this, @vitejs/plugin-vue is missing
npm run dev
```

`@vitejs/plugin-vue` is a devDependency and `npm run dev` invokes `vite`
directly, so a production-only install fails at startup.

## bluefin / bluefin-lts

```bash
just check
pre-commit run --all-files
```

See each repo's `docs/build.md` for local image build prerequisites.

## Branch targets

Default branch is not always the PR target. Verified from the last 15 merged
pull requests in each repo on 2026-09-13:

| Repo | Default branch | PRs actually target |
|---|---|---|
| `bluefin` | `main` | `testing` — all 15 |
| `bluefin-lts` | `main` | mixed: `main` and `testing`, plus `v4` |
| `dakota` | `testing` | `testing` |
| `common` | `main` | `main` |
| `documentation` | `main` | `main` |
| `website` | `main` | `main` |
| `testsuite` | `main` | `main` |
| `knuckle` | `main` | `main` |
| `dakota-iso` | `main` | `main` |
| `lab` | `main` | `main` |

`bluefin` never takes a PR against `main`, `stable`, or `latest` — those are
promotion targets fed by the release pipeline.

There is no direct-push path anywhere in the factory that this repo documents.
`common`'s `main` requires a PR, two approvals, and the merge queue; see
[governance.md](governance.md#how-main-is-protected). Where other repos have
rulesets, the same table in that file lists them.

## Verification

- [ ] Branch targets still match reality:

  ```bash
  gh pr list --repo projectbluefin/<repo> --state merged --limit 15 \
    --json baseRefName --jq '[.[].baseRefName] | group_by(.) | map({(.[0]): length}) | add'
  ```

- [ ] Every repo named above is still live (not archived):
      `gh api repos/projectbluefin/<repo> --jq .archived` returns `false`.
