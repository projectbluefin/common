---
name: skill-improvement
version: "1.3"
last_updated: "2026-09-24"
id: skill-improvement
one_line_purpose: Capture durable agent learnings in maintained skill docs.
entry_point: docs/skills/skill-improvement.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [skills, improvement, documentation]
description: >-
  Use when task-relevant guidance is wrong or a reusable, non-obvious
  operational requirement needs documenting.
metadata:
  type: reference
  context7-sources:
    - /anthropics/skills
    - /addyosmani/agent-skills
    - /vercel-labs/agent-skills
---

# Maintaining useful guidance

Update an existing reference when the requested change makes it inaccurate or
when a source-backed, non-obvious requirement would prevent a recurring mistake.
A routine fix does not require a skill update or a new document.

Keep corrections close to the owning topic and cite the source or a useful
reproduction command. Avoid task diaries, ephemeral status, duplicate policy,
and facts readily apparent from code. Create a skill only for reusable guidance
with no existing home; do not restructure unrelated docs during implementation.

Out-of-scope gaps can go through normal issue triage, not self-accepted work.
Documentation maintenance does not override the [repo contract](../../AGENTS.md)
or its human gates. For authoring details, see [write-a-skill](write-a-skill.md).
