---
name: skill-drift
version: "2.1"
last_updated: "2026-09-24"
id: skill-drift
one_line_purpose: Redirect old skill-drift links to current skill-update rules.
entry_point: docs/skills/skill-drift.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: deprecated
dependencies: []
tags: [skills, drift, ci]
description: >-
  Use when following a legacy skill-drift link or checking whether a separate
  CI workflow enforces skill updates.
metadata:
  type: reference
---

# Skill drift (retired)

`skill-drift.yml` was an always-green stub and has been removed. Do not re-add
it. [Skill improvement](skill-improvement.md) owns the update obligation and
code-path mapping; the [factory contract](../factory/agentic-model.md) limits
CI enforcement to the aggregate `pre-commit` step.
