---
name: context7
version: "1.0"
last_updated: 2026-07-19
tags: [context7, docs, verification, tooling]
description: >-
  Context7 is the mandatory first-lookup source for any external tool used in
  this repo. Before writing or asserting anything about bootc, cosign, skopeo,
  buildah, ostree, rpm-ostree, just, GitHub Actions, pre-commit, Renovate, or
  any other named tool — resolve its library ID and read the live docs via
  Context7. Training data is stale; the docs are the source of truth.
metadata:
  type: policy
---

# Context7 — mandatory first-lookup policy

## The rule

**Before using any external tool in this repo, look up its current docs via
Context7 first. Always. No exceptions.**

This is repo-wide policy, restated from `AGENTS.md`. It applies to every agent
working in `projectbluefin/common`, regardless of runtime (Copilot, Claude, pi,
etc.). If your runtime does not expose the Context7 MCP tools, you cannot
satisfy this rule in that session — escalate to a human or switch runtimes
rather than guessing.

## Why

Training data is a snapshot. The tools this factory depends on evolve
constantly:

- bootc adds/removes CLI flags and labels between releases
- GitHub Actions changes `actions/checkout`, `upload-artifact`, app-token APIs
- pre-commit hook semantics and the floating-tag guard depend on current behavior
- Renovate automerge and digest-tracking behavior shifts across versions
- cosign keyless signing attestation format changes

Asserting a flag, label, config key, or API shape from memory has caused silent
CI failures and `startup_failure` cascades in this factory. The fix is always
the same: read the live docs, then implement, then cite the section.

## The pattern

```
1. resolve-library-id: <tool name>
   → returns the Context7 library ID (e.g. /bootc-dev/bootc)
2. query-docs: <library ID>
   → returns the current authoritative docs
3. implement from the docs
4. cite the doc section you implemented from (in the code comment, commit
   message, or skill file you update)
```

## What counts as "using a tool"

You must run the Context7 lookup **before** any of these:

- Writing a `Containerfile` instruction, `LABEL`, `RUN`, or `COPY`
- Writing a `.github/workflows/*.yml` step that calls an action or CLI
- Writing a `just` recipe that shells out to a tool
- Writing a pre-commit hook config
- Asserting a tool's flag, default, or behavior in a skill file, issue, or PR
- Debugging a CI failure where a tool's behavior is in question

## What does NOT require Context7

- Reading this repo's own source (`read`, `bash`, `gh api`) — source is truth
- Editing prose, reorganizing docs, fixing links
- Project-internal facts (image names, tags, registry paths) — those come from
  this repo's own workflows, see `image-registry.md`

If a task is purely about this repo's own files and no external tool behavior is
in question, Context7 is not required. When in doubt, look it up.

## Recording what you looked up

When you implement from Context7 docs, record the library ID and the section
you used, in the place the change lands:

| Change location | Where to record the Context7 source |
|---|---|
| Skill file edit | `metadata.context7-sources` frontmatter + inline `Source: <tool> docs → "<section>"` citations |
| `Containerfile` / workflow / recipe | Inline comment citing the doc section |
| Commit message | Mention the library ID if the change's correctness depends on doc behavior |

Example frontmatter (see `bootc.md` for a real one):

```yaml
metadata:
  type: reference
  context7-sources:
    - /bootc-dev/bootc
```

## Known library IDs used in this repo

This list is a starting point, not a substitute for `resolve-library-id`.
Library IDs can change; always resolve fresh.

| Tool | Library ID (last confirmed) | Used for |
|---|---|---|
| bootc | `/bootc-dev/bootc` | image build, kargs, filesystem layout |
| WirePlumber | `/websites/pipewire_pages_freedesktop_wireplumber` | OEM hook config fragments |

Add rows here as you confirm new IDs during sessions, with the date.

## Red flags — you are violating this policy if

- You write a `Containerfile` instruction from memory without checking bootc docs
- You assert an action's input name without checking the action's docs
- You copy a flag from another doc or from training data
- You describe a tool's behavior without citing the doc section
- You say "I think this flag does X" — that is a guess; look it up

## See also

- [`bootc.md`](bootc.md) — the canonical example of this policy in action
- [`ci-pitfalls.md`](ci-pitfalls.md) — CI traps that Context7 lookups prevent
- [`skill-improvement.md`](skill-improvement.md) — record Context7 sources in skill frontmatter
