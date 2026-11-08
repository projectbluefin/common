---
name: write-a-skill
version: "1.3"
last_updated: "2026-09-24"
id: write-a-skill
one_line_purpose: Author useful task-specific agent reference docs.
entry_point: docs/skills/write-a-skill.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [skills, authoring, documentation]
description: >-
  Use when adding or revising reusable task-specific guidance in docs/skills/.
metadata:
  type: procedure
---

# Writing a skill

Prefer correcting an existing reference. Add a skill only when reusable,
non-obvious operational guidance has no existing home; routine implementation
needs no accompanying skill. Describe when to use it, the useful procedure or
constraint, and sources needed to check facts. Avoid repeating repo policy.

Use either `docs/skills/<name>.md` or `docs/skills/<name>/SKILL.md`. Keep the
entry point short; split detail only when it helps the reader. Merely touching
a large or flat skill is not a reason to migrate it. Update inbound links if
you intentionally move a file.

Preserve existing YAML front matter. Give new skills a recognizable `name` and
an informative `description`; do not add placeholder metadata for hypothetical
tooling. There is no generated documentation catalog to maintain.

## Shipped on-device skills

Declare `scope: on-device` as a top-level front-matter key to include a skill in
`scripts/generate_skill_index.py`. Unscoped notes are not parsed by the builder.
Declared sources must have valid YAML and `id`, `name`, `one_line_purpose`, and
`description`; `category` and `status` are optional. If changing this subset,
regenerate its shipped
copies with `python3 scripts/generate_skill_index.py --write` and include the
result under `system_files/shared/usr/share/ublue-os/agent/`. Do not edit the
shipped copies directly. `--check` checks bundle freshness; it is not a general
documentation validator. No bundle regeneration is needed for other skills.
