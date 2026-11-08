---
name: human-gates
version: "1.4"
last_updated: "2026-09-24"
id: human-gates
one_line_purpose: Decide when to stop for Design, Security, Breakage, or Merge review.
entry_point: docs/skills/human-gates.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [gates, approval, security]
description: >-
  Use when a change needs a human decision or when operating a
  maintainer-controlled PR review tool.
metadata:
  type: reference
---

# Human decision gates

[AGENTS.md](../../AGENTS.md) defines Design, Security, Breakage, and Merge gates.
When one applies, stop the affected work and present the proposed change,
impact, alternatives, evidence, and decision needed. Wait for explicit approval;
do not grant yourself acceptance or manipulate holds to proceed. If the gate
is unclear, ask the maintainer rather than guessing.

## Product decisions

Account/identity models, user-visible defaults, and features such as family
safety need a maintainer-approved specification before merge. It should cover
affected products, alternatives, threat/UX impact, upgrade and rollback,
verification, and the maintainer's choice; agents do not choose product policy.

The `systemd-homed` decision in
[common#1050](https://github.com/projectbluefin/common/issues/1050) holds
[dakota#962](https://github.com/projectbluefin/dakota/pull/962) until the product
decision and evidence are complete. Relevant hazards: subvolume storage alone
does not encrypt homes; switching images does not migrate existing homes; and
rollback to an image without homed can strand users. Account defaults and
parental-controls removal require Design, Security, and Breakage approval.

## Maintainer-controlled review tools

A tool executing a merge or close on a maintainer's explicit **per-item
keypress** is the human acting at the gate, not permission for agent self-merge.
The reviewed `pr-review` card loop allows one keypress per card, never a
confirm-all batch. GitHub protections must still hold; closes also require
per-item confirmation because GitHub does not enforce review gates on closing.

Arming auto-merge on that keypress must use `--match-head-commit` with the head
SHA captured alongside the diff the human reviewed, not a head re-read at
keypress time. Drift must fail server-side rather than land unreviewed code.
Admin overrides, submitting an approving review, and non-interactive batch
mutation remain forbidden.
