---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: shared-skill-catalog

## Overview

`common` already generates and validates its skill catalog, but factory repositories have different skill shapes and discovery conventions. This draft preserves the still-unapproved cross-repository choices from the former `docs/factory/skill-catalog-proposal.md` (available in Git history). It does not direct another repository to change its schema, router or tooling until its owners approve a compatible contract.

## Requirements

- [ ] **Define interoperable metadata**
  Repositories that opt into a machine-readable skill catalog can represent the same skill identity, entry point and discovery metadata without incompatible schemas.
- [ ] **Keep lightweight consumers usable**
  A repository with only `name` and `description` frontmatter remains a valid skill source and is not forced to adopt `common`'s additional catalog fields.
- [ ] **Preserve local ownership**
  Each participating repo controls its skill router, documentation, validation and rollout; a shared schema does not copy or overwrite its skills.
- [ ] **Validate actual discovery**
  A contributor can resolve catalog entry points and internal Markdown links in participating repositories, rather than accepting a generated index with broken paths.

## Constraints

- A maintainer Design/Breakage decision is required before a schema moves to `projectbluefin/actions` or any consumer switches validators. `common`'s existing `docs/skills/index.schema.json` and `scripts/generate_skill_index.py` are reference inputs, not an adopted factory-wide contract.
- The July 2026 survey of `bluefin`, `bluefin-lts`, `dakota`, `knuckle`, `testsuite`, `actions`, `bonedigger`, `clankers` and Hive is historical. Check each current checkout and owner before planning its adoption; do not infer that the archived testsuite design or an old local branch was implemented.
- `skill-drift-check.yml` was retired rather than standardized. This draft must not resurrect a no-op workflow or introduce a bespoke image-blocking process gate.
- Cross-repository writes require each repository's review policy. No change to `ublue-os/*`, new credential, or unseen product build dependency is authorized here.

## Acceptance Criteria

- [ ] **One schema handles both shapes**
  Validating a minimal `name`+`description` skill and an opted-in `common` catalog skill succeeds, while a malformed entry point or wrong type fails with a useful error.
- [ ] **Local catalogs still work**
  In a clean checkout of each pilot repo, its router and generated (or manually maintained) skill links resolve and its own documentation checks pass without changing unrelated repositories.
- [ ] **Human owners approve migration**
  The shared schema's owner, versioning, backward compatibility and pilot consumers are recorded in the reviewed specification and per-repo PRs before any factory-wide adoption.
- [ ] **No phantom enforcement**
  The pilot does not add a silently-green skill-drift check or claim unimplemented validators are protecting CI.

## Technical Approach

A maintainer may choose to host an optional catalog schema in `projectbluefin/actions`, using `common`'s current implementation as one reference and comparing `bluefin-lts`'s link/directory validator with `common`'s local Markdown link check. Optional metadata must be additive for repositories with minimal frontmatter. Bootstrap guidance for repos without any router (`clankers`, Hive at the time of the historical survey) is a separate ownership decision, not an automatic consequence of this schema choice. Re-read live repo contracts and the archived proposal in Git history before selecting owners and migration order.

## Success Metrics

- A deliberately selected pilot pair can consume or validate the same reviewed metadata contract without breaking its own skill router.
- Contributors can locate the expected skill and follow its links in a fresh checkout; schema conformance alone is not counted as discovery success.

## Non-Goals

- Treating an old cross-repo survey or an archived design note as adopted policy.
- Standardizing every repo's directory layout, forcing unused catalog fields into minimal skills, or changing other repositories without review.
- Reviving a removed skill-drift workflow, tracking local-only commits, or creating a second process-gating system.
