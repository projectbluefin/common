---
name: context7
version: "1.1"
last_updated: "2026-09-13"
id: context7
one_line_purpose: Verify external tool behaviour against upstream docs before asserting it.
entry_point: docs/skills/context7.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [context7, docs, verification, tooling]
description: >-
  How to verify external tool behaviour before asserting it, and what the
  Context7 lookup path actually is in this repo. Use before documenting or
  relying on a flag, label, config key, or API shape for bootc, cosign,
  buildah, GitHub Actions, or Renovate.
metadata:
  type: reference
---

# External tool docs — verify before you assert

## What this repo actually configures

`.cursor/mcp.json` and `.vscode/mcp.json` each register exactly one MCP server:

```json
{ "projectbluefin": { "url": "https://mcp.projectbluefin.io/mcp" } }
```

That server exposes three tools — `search_knowledge`, `get_factory_status`,
`get_work_queue`. All three are about this factory. None of them look up
external tool documentation.

**This repo does not configure a Context7 server.** Whether
`resolve-library-id` and `get-library-docs` exist in your session depends on
the runtime you happen to be in, not on anything in this checkout. Check your
own tool list before planning around them.

## The rule

Never assert an external tool's flag, default, label, config key, or API shape
from memory. Read the current upstream docs, implement from them, cite the
section you implemented from.

Training data is a snapshot and these tools move:

- bootc adds and removes CLI flags and labels between releases
- GitHub Actions changes `actions/checkout`, `upload-artifact`, app-token APIs
- pre-commit hook semantics and the floating-tag guard depend on current behaviour
- Renovate automerge and digest-tracking behaviour shifts across versions
- cosign keyless signing attestation format changes

Guessing here has produced silent CI failures and `startup_failure` cascades in
this factory.

## How to look it up

Use the first of these that is available to you:

1. **Context7**, if your runtime exposes it: `resolve-library-id: <tool>` then
   `get-library-docs: <library ID>`.
2. **The upstream docs site or the project's own docs tree**, read directly —
   e.g. `gh api repos/bootc-dev/bootc/contents/docs`.
3. **The tool's own `--help` or man page**, run in the container the factory
   actually builds with.

If none of the three is reachable, say so and leave the claim out. A gap is
cheaper than an unverified sentence about tool behaviour.

## When this applies

Before writing a `Containerfile` instruction, a workflow step that calls an
action or CLI, a `just` recipe that shells out, a pre-commit hook config, or
any sentence in a skill, issue, or PR that describes a tool's behaviour. Also
when debugging a CI failure where a tool's behaviour is in question.

It does not apply to this repo's own source. Image names, tags, registry
paths, and workflow outputs come from this repo's files — see
[`image-registry.md`](image-registry.md). Prose and link edits need no lookup.

## Recording the source

| Change location | Where to record it |
|---|---|
| Skill file | `metadata.context7-sources` front matter, plus inline `Source: <tool> docs → "<section>"` |
| Containerfile / workflow / recipe | Inline comment naming the doc section |
| Commit message | Name the source when the change's correctness depends on doc behaviour |

Fifteen skill files carry `metadata.context7-sources` today. The field is a
citation record; no script reads it, and the generated catalog drops it.

```yaml
metadata:
  type: reference
  context7-sources:
    - /bootc-dev/bootc
```

## Library IDs seen in this repo

Starting points, not a substitute for resolving fresh — IDs change.

| Tool | Library ID | Used for |
|---|---|---|
| bootc | `/bootc-dev/bootc` | image build, kargs, filesystem layout |
| WirePlumber | `/websites/pipewire_pages_freedesktop_wireplumber` | OEM hook config fragments |

## Red flags

- Writing a Containerfile instruction or an action input name from memory.
- Copying a flag out of another doc, or out of training data.
- "I think this flag does X."
- Mandating a Context7 lookup in a session whose runtime has no Context7
  tools. Check first, then fall back down the list above.

## Verification

```bash
# The only MCP server this repo configures
jq -r '.mcpServers | keys[]' .cursor/mcp.json
jq -r '.servers | keys[]' .vscode/mcp.json

# Its tool surface: search_knowledge, get_factory_status, get_work_queue
curl -sS -X POST https://mcp.projectbluefin.io/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | sed -n 's/^data: //p' | jq -r '.result.tools[].name'

# Skill files recording where an external fact came from
grep -rl context7-sources docs/skills | wc -l
```

## See also

- [`bootc.md`](bootc.md) — the canonical example of citing upstream docs
- [`ci-pitfalls/SKILL.md`](ci-pitfalls/SKILL.md) — CI traps these lookups prevent
- [`skill-improvement.md`](skill-improvement.md) — where the source gets recorded
