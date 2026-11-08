---
name: context7
version: "1.0"
last_updated: "2026-07-19"
id: context7
one_line_purpose: Verify external API details against current documentation.
entry_point: docs/skills/context7.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [context7, docs, verification, tooling]
description: >-
  Use when an external tool's API, configuration, or version-specific behavior
  needs verification against current documentation.
metadata:
  type: reference
---

# External documentation lookup

Read repository source for project-internal facts. For external APIs or CLI
behavior in question, consult current upstream documentation rather than
inventing flags or copying stale examples.

Context7 supports two steps: `resolve-library-id` for the library or tool,
then `query-docs` for the specific API or behavior. Use the result relevant to
the installed version; consult upstream documentation if it is not indexed.

Cite a source where it explains a non-obvious constraint. Routine source
reading and prose edits do not require a separate lookup, metadata edit,
or new skill document.
