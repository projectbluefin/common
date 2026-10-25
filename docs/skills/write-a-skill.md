---
name: write-a-skill
version: "1.2"
last_updated: "2026-09-13"
id: write-a-skill
one_line_purpose: Author a new skill doc following front-matter and size rules.
entry_point: docs/skills/write-a-skill.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [skills, authoring, documentation]
description: >-
  Author a new agent skill for projectbluefin/common. Covers front-matter,
  size budget, canonical linking, verification sections, and the skill-update
  mandate. Use when creating a new docs/skills/*.md file or splitting an
  oversized skill.
metadata:
  type: procedure
---

# Writing a Skill

A skill is an agent-facing markdown file — `docs/skills/<name>.md` or
`docs/skills/<name>/SKILL.md` — recording how to work safely in one domain.
Every session that introduces a new domain or discovers a durable pattern must
write or update one.

## When to create a new skill

Create a new skill only when the change introduces a reusable domain that has
no existing home. Prefer updating an existing skill. Typical triggers:

- A new workflow, service, tool, or repo convention is introduced.
- A non-obvious workaround or correctness requirement is discovered.
- A project-internal fact (image names, tags, registry paths, workflow outputs)
  is documented and needs a verification command.

Do **not** create a skill for one-off task notes, ephemeral state, or obvious
developer knowledge. Do not duplicate content that already lives in another
skill or canonical source.

## Required front-matter

Every skill file must start with:

```yaml
---
name: <kebab-case-skill-name>
version: "<semver>"
last_updated: YYYY-MM-DD
id: <kebab-case-skill-name>
one_line_purpose: <short imperative summary, distinct from description>
entry_point: docs/skills/<name>.md
category: <ci-ops | test-authoring | meta>
mcp_compliance_level: partial
optimization_status: draft
status: <active | deprecated | reserved>
dependencies: []
tags: [tag1, tag2, tag3]
description: "<capability sentence>. Use when <triggers>."
metadata:
  type: <procedure | reference | runbook | policy>
---
```

- `name`: kebab-case, matches filename stem.
- `version`: semver string in quotes (e.g., `"1.0"`).
- `last_updated`: ISO-8601 date.
- `id`: same value as `name`. Used as the catalog primary key.
- `one_line_purpose`: ≤120 chars, a short imperative sentence distinct from
  `description` (no "Use when ..." trigger clause — that belongs in
  `description`).
- `entry_point`: repo-relative path to this file (`docs/skills/<name>.md`, or
  `docs/skills/<name>/SKILL.md` for a per-skill directory).
- `category`: one of `ci-ops`, `test-authoring`, `meta`. Pick the closest fit;
  propose widening the enum in a PR if none fit (update
  `docs/skills/index.schema.json` in the same change).
- `mcp_compliance_level` / `optimization_status`: currently informational
  placeholders (`partial` / `draft` for every skill) — kept for forward
  compatibility with MCP tooling, not yet load-bearing.
- `status`: `active` unless the skill is being phased out (`deprecated`) or
  documents something not yet built (`reserved`).
- `dependencies`: another forward-compatibility placeholder; nothing reads it.
  Use `[]`.
- `tags`: 3-6 lowercase keywords.
- `description`: ≤256 characters, third person, capability first sentence,
  "Use when ..." second sentence.
- `metadata.type`: one of `procedure`, `reference`, `runbook`, `policy`.

All of the above except `mcp_compliance_level`, `optimization_status`, and
`dependencies` are compiled into `docs/skills/index.json` / `index.md` by
`scripts/generate_skill_index.py` and validated against
`docs/skills/index.schema.json`. After adding or editing a skill, run:

```bash
python3 scripts/generate_skill_index.py --write
```

and commit the regenerated `index.json`/`index.md` alongside your change.

## What actually validates a skill

Four `local` hooks in `.pre-commit-config.yaml`:

| Hook | Script | What it rejects |
|---|---|---|
| `check-skill-frontmatter` | `scripts/check-skill-frontmatter.sh` | missing key, `name` ≠ `id`, wrong `entry_point`, bad `category`/`status`, empty `tags`, `one_line_purpose` over 120 chars, `description` over 256, file over 500 lines (warns over 200) |
| `check-skill-index` | `scripts/check-skill-index.sh` | a skill with no row in `docs/SKILL.md` |
| `check-doc-links` | `scripts/check-doc-links.sh` | a relative `.md` link under `docs/` that points at nothing |
| `check-skill-catalog` | `scripts/generate_skill_index.py --check` | an `index.json` that does not match the front matter on disk |

All four run at commit time and again on every pull request, because
`.github/workflows/validate.yml` runs `pre-commit run --all-files` as a single
aggregate step. Nothing runs after merge: there is no post-merge catalog
automation and no skill-specific CI job.

## Description rules

The description is the only text an agent sees when choosing a skill.
`Documents X. Use when editing Y or debugging Z.` triggers a load;
`Helps with X.` does not. Keep the body coverage if you shorten it.

## Size budget and layout conventions

- **Soft max:** 200 lines per `SKILL.md` or flat skill file.
- **Hard max:** 500 lines.
- **Layout:** Factory repos accept either `docs/skills/<name>.md` (flat) or
  per-skill directories `docs/skills/<name>/SKILL.md` + `references/*.md` (or
  `.agents/skills/<name>/SKILL.md` in repos standardizing on root-agent
  toolchains).
- **Migrate on sight.** Any session that touches an oversized or
  legacy-format skill must migrate it to the per-skill directory layout
  (`SKILL.md` + `references/`) in the same change. The size budget applies
  uniformly to every skill — no exemptions, no deferral list.
- **Banned artifacts.** Do not commit session notes (`PLAN.md`, `TODO.md`,
  `NOTES.md`, `docs/superpowers/**`) or changelogs (`CHANGELOG.md`). Session state
  belongs in the local agent session folder only.

If a draft exceeds 200 lines, split rarely-needed detail into a `references/`
file and link to it.

### Per-skill directory migration (migrate on sight)

When a skill outgrows a flat file, move it to `docs/skills/<name>/SKILL.md` +
`references/*.md` in the same change that touched it:

- `SKILL.md` keeps the front matter, `## When to Use`, the core workflow, and a
  table pointing at each reference file.
- Each `references/*.md` gets a `# Title` and a link back to `../SKILL.md`.
- Update every inbound link, including the `docs/SKILL.md` row, from
  `skills/<name>.md` to `skills/<name>/SKILL.md`.

Both `check-skill-frontmatter.sh` and `check-skill-index.sh` already accept
either layout. See [`lab-testing/SKILL.md`](./lab-testing/SKILL.md) for a
worked example.

## Link to canonical sources

Do not duplicate facts that live in source files, workflow YAML, or upstream
docs. Instead, record how to derive the fact:

- Project-internal facts: add a `## Verification` section with the exact
  command to re-derive the fact (`gh api`, `grep`, `skopeo inspect`, etc.).
- External tools: read the upstream docs, cite the section, and record where
  you read it in `metadata.context7-sources` — see [`context7.md`](./context7.md).

See [`image-registry.md`](./image-registry.md) for the reference
implementation of a verification section.

## Body sections

A well-formed skill contains:

1. `## When to Use` — specific triggers and scopes.
2. `## Core Process` or `## What this covers` — the agent workflow.
3. `## Red Flags` — mistakes that violate repo policy.
4. `## Verification` — commands to self-check project-internal facts.

## The skill-update mandate

Every implementation PR must include a matching skill update in the same PR.
No CI check enforces this; review, `pre-commit`, and the self-repair loop do.
Why, and why the retired `skill-drift.yml` is not coming back:
[`skill-improvement.md`](./skill-improvement.md).

## Verification

Before committing a new or updated skill:

- [ ] `bash scripts/check-skill-frontmatter.sh` — no errors, and no soft-max
      warning for your file.
- [ ] `python3 scripts/generate_skill_index.py --write`, with the regenerated
      `docs/skills/index.json`/`index.md` committed.
- [ ] `docs/SKILL.md` has a row linking to the skill.
- [ ] Body has `When to Use`, process or reference content, `Red Flags`, and
      `Verification` sections.
- [ ] Project-internal facts carry a command that re-derives them.
