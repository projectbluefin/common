# Story e01s01: Normalize agent entry points

**type:** refactor  
**risk:** P1  
**context:** docs / repo-contract

Consolidate the agent entry-point layer so every agent loads the same short
contract and the skill router is a single lazy-load index.

## Requirements

- `AGENTS.md` becomes a short per-repo agent contract (≤200 lines) with deep
  links to `docs/skills/` and `docs/factory/`. It keeps the
  `ublue-os` prohibition, build commands, scope warning, doc-only push
  exception, and human gates in concise form; long context moves to skills.
- `docs/SKILL.md` absorbs `docs/skills/INDEX.md` and stays <150 lines.
- `.github/copilot-instructions.md` shrinks to a thin pointer.
- `.github/pull_request_template.md` adds skill/doc checkboxes.

## Steps

1. Rewrite `AGENTS.md` → verify: `wc -l AGENTS.md | awk '$1<=200{print "OK"}'`
2. Merge `docs/skills/INDEX.md` into `docs/SKILL.md` and delete `docs/skills/INDEX.md` → verify: `test ! -f docs/skills/INDEX.md && wc -l docs/SKILL.md | awk '$1<=150{print "OK"}'`
3. Trim `.github/copilot-instructions.md` → verify: `wc -l .github/copilot-instructions.md | awk '$1<=40{print "OK"}'`
4. Update `.github/pull_request_template.md` → verify: `grep -qE 'skill|AGENTS|docs/SKILL' .github/pull_request_template.md && echo OK`
5. Update any remaining `docs/skills/INDEX.md` references → verify: `grep -R 'docs/skills/INDEX.md' docs .github 2>/dev/null && echo FAIL || echo OK`
6. Run hygiene checks → verify: `just check && pre-commit run --all-files`

## Out of scope

- Renaming `AGENTS.md` to lowercase.
- Normalizing skill front-matter (e01s03).
- Adding docs-hygiene scripts (e01s04).

## Risks

- External tools/readmes reference `docs/skills/INDEX.md`. Mitigation: search
  and replace before deletion.
- `AGENTS.md` rewrite could drop a hard rule. Mitigation: every removed
  paragraph must land in a linked skill or `docs/factory/` doc.
