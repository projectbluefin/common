---
name: write-a-skill
version: "1.2"
last_updated: "2026-09-23"
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

A skill is an agent-facing markdown file in `docs/skills/*.md` that records how
to work safely in a specific domain. Every agent session that introduces a new
domain or discovers a durable pattern must write or update one.

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

Every `docs/skills/*.md` file must start with:

```yaml
---
name: <kebab-case-skill-name>
version: "<semver>"
last_updated: YYYY-MM-DD
id: <kebab-case-skill-name>
one_line_purpose: <short imperative summary, distinct from description>
entry_point: docs/skills/<name>.md
category: <ci-ops | test-authoring | meta | platform | product>
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
- `category`: one of `ci-ops`, `test-authoring`, `meta`, `platform`, `product`.
  Pick the closest fit (`platform` for OS/desktop/runtime integration; `product`
  for user-facing surface/copy); propose widening the enum in a PR if none fit
  (update `docs/skills/index.schema.json` in the same change).
- `mcp_compliance_level` / `optimization_status`: currently informational
  placeholders (`partial` / `draft` for every skill) — kept for forward
  compatibility with MCP tooling, not yet load-bearing.
- `status`: `active` unless the skill is being phased out (`deprecated`) or
  documents something not yet built (`reserved`).
- `dependencies`: list of other skill `id`s this one assumes are loaded first.
  Usually `[]`.
- `tags`: 3-6 lowercase keywords.
- `description`: ≤256 characters, third person, capability first sentence,
  "Use when ..." second sentence.
- `metadata.type`: one of `procedure`, `reference`, `runbook`, `policy`.

All of the above (except `metadata`) are validated against
`docs/skills/index.schema.json` and compiled into `docs/skills/index.json` /
`index.md` by `scripts/generate_skill_index.py`. After adding or editing a
skill, run:

```bash
python3 scripts/generate_skill_index.py --write
```

and commit the regenerated `index.json`/`index.md` alongside your change.
`scripts/generate_skill_index.py --check` runs in pre-commit and CI and fails
if the catalog is stale.

## Description rules

The description is the only text an agent sees when choosing a skill. Make it
specific enough to trigger loading:

- **Good:** `Documents ... . Use when editing ... or debugging ... .`
- **Bad:** `Helps with ... .`

Keep it under 256 characters. Preserve the original body coverage if you
shorten the description.

## Size budget

- **Soft max:** 200 lines.
- **Hard max:** 500 lines.
- **Migrate on sight.** Any session that touches an oversized or
  legacy-format skill must migrate it to the per-skill directory layout
  (`SKILL.md` + `references/`) in the same change. The size budget applies
  uniformly to every skill — no exemptions, no deferral list.

If a draft exceeds 200 lines, split rarely-needed detail into a separate
`references/` file and link to it.

### Per-skill directory migration (migrate on sight)

When you encounter a skill that outgrows a single flat file — whether you were
sent to migrate it or you merely touched it for another reason — migrate it to
`docs/skills/<name>/SKILL.md` + `docs/skills/<name>/references/*.md` as part of
that same change:

- `SKILL.md` keeps the front matter, `## When to Use`, core workflow, and a
  table pointing to each reference file with a one-line description of what's
  in it.
- Each `references/*.md` file gets its own `# Title`, a short intro linking
  back to `../SKILL.md`, and (if over 300 lines, per the Anthropic Agent
  Skills convention) a `## Contents` table of contents.
- Update every inbound link across the repo (`docs/SKILL.md`'s router table,
  any other skill that references it) from `skills/<name>.md` to
  `skills/<name>/SKILL.md`.
- `scripts/check-skill-frontmatter.sh` and `scripts/check-skill-index.sh` both
  recognize `docs/skills/*/SKILL.md` alongside flat `docs/skills/*.md` — no
  script changes needed for a new migration.

See [`lab-testing/SKILL.md`](./lab-testing/SKILL.md) for a worked example
(migrated 2026-07-29 from a 910-line flat file).

## Link to canonical sources

Do not duplicate facts that live in source files, workflow YAML, or upstream
docs. Instead, record how to derive the fact:

- Project-internal facts: add a `## Verification` section with the exact
  command to re-derive the fact (`gh api`, `grep`, `skopeo inspect`, etc.).
- External tools: record the Context7 library ID in
  `metadata.context7-sources`, then link to the section in the upstream docs.

See [`image-registry.md`](./image-registry.md) for the reference
implementation of a verification section.

## Body sections

A well-formed skill contains:

1. `## When to Use` — specific triggers andscopes.
2. `## Core Process` or `## What this covers` — the agent workflow.
3. `## Red Flags` — mistakes that violate repo policy.
4. `## Verification` — commands to self-check project-internal facts.

## The skill-update mandate

Every implementation PR must include a matching skill update in the same PR.

There is no CI check for this. The `skill-drift.yml` workflow was retired
across the factory because it never enforced anything — see
[`skill-drift.md`](./skill-drift.md). The obligation is enforced by review, by
`pre-commit`, and by the self-repair loop.

- Why: [`skill-improvement.md`](./skill-improvement.md)
- Why the CI check was retired: [`skill-drift.md`](./skill-drift.md)

## Verification

Before committing a new or updated skill:

- [ ] Front-matter includes all required keys and `description` ≤256 chars.
- [ ] `metadata.type` is appropriate for the content.
- [ ] Body has `When to Use`, process/reference content, `Red Flags`, and
      `Verification` sections.
- [ ] Project-internal facts include a verification command.
- [ ] `bash scripts/check-skill-frontmatter.sh` passes with no errors.
- [ ] File is under 200 lines (soft) or under 500 lines (hard max).
- [ ] `python3 scripts/generate_skill_index.py --write` run and the
      regenerated `docs/skills/index.json`/`index.md` are committed.
