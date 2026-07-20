# Story e01s04: Add docs-hygiene pre-commit checks

**type:** ci  
**risk:** P1  
**context:** docs / ci / hygiene

Add lightweight, local hygiene gates so future doc changes cannot break the
lazy-loading structure or internal links.

## Requirements

- `scripts/check-skill-frontmatter.sh` validates every `docs/skills/*.md`
  front-matter and size budget.
- `scripts/check-skill-index.sh` validates that `docs/SKILL.md` contains a
  task table row for every `docs/skills/*.md` file.
- `scripts/check-doc-links.sh` validates that every relative `.md` link in
  `docs/` points to an existing file.
- All three run as local pre-commit hooks.
- Run `just test` if any new shell script logic is added.

## Steps

1. Refine `scripts/check-skill-frontmatter.sh` → verify: `bash scripts/check-skill-frontmatter.sh`
2. Create `scripts/check-skill-index.sh` → verify: `bash scripts/check-skill-index.sh`
3. Create `scripts/check-doc-links.sh` → verify: `bash scripts/check-doc-links.sh`
4. Wire the three scripts into `.pre-commit-config.yaml` as local hooks → verify: `grep -q 'check-skill-frontmatter' .pre-commit-config.yaml && grep -q 'check-skill-index' .pre-commit-config.yaml && grep -q 'check-doc-links' .pre-commit-config.yaml`
5. Run `just check` and `pre-commit run --all-files` → verify: `just check && pre-commit run --all-files`

## Out of scope

- Blocking GitHub Actions CI workflows for these checks (they stay pre-commit hygiene).
- Checking external URLs (requires lychee; deferred to local optional tooling).

## Risks

- Overly strict size gate breaks existing skills. Mitigation: grandfather list
  in the script until Phase E.
- Link checker false positives on generated URLs. Mitigation: only check
  relative `.md` links.
