# Story e01s03: Normalize skill front-matter and add write-a-skill meta-skill

**type:** docs
**risk:** P2
**context:** docs / agent-skills

Make every skill file loadable as a lazily-selected skill: required front-matter,
short description, and a meta-skill that documents how to author new ones.

## Requirements

- All `docs/skills/*.md` files have `name`, `version`, `last_updated`, `tags`,
  `description` (≤256 chars), and `metadata.type`.
- `discord-chatops.md` gets a new front-matter block.
- `lab-testing.md` gets missing `version`, `last_updated`, and `tags`.
- `brew-lifecycle.md`, `bonedigger.md`, and `devmode.md` get `metadata.type`.
- Descriptions longer than 256 chars are rewritten to fit the budget while
  keeping the "Use when ..." trigger.
- Create `docs/skills/write-a-skill.md` covering authoring rules, front-matter,
  size budget, linking, verification sections, and the skill-drift policy.

## Steps

1. Audit current front-matter → verify: `bash scripts/check-skill-frontmatter.sh`
2. Add missing front-matter and shorten long descriptions → verify: `bash scripts/check-skill-frontmatter.sh`
3. Create `docs/skills/write-a-skill.md` → verify: `test -f docs/skills/write-a-skill.md`
4. Run hygiene checks → verify: `just check && pre-commit run --all-files`

## Out of scope

- Splitting oversized skills (>500 lines) — deferred to Phase E.
- Rewriting skill bodies beyond front-matter and cross-references.

## Risks

- Shortening a description can lose nuance. Mitigation: preserve the original
  "Use when ..." coverage in the body.
