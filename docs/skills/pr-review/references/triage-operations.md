# Issue Triage and Blast Radius Map

Part of [pr-review](../SKILL.md) — issue triage verdict vocabulary and blast radius classification for common PRs.

## Issue Triage Sweep

Same dossier → verdict → stage → land loop, with issue verdicts:

| Verdict | Effect |
|---|---|
| `close` | Close with the human's stated reason |
| `label <name>` | Apply a label — only the 7 canonical labels per [label-workflow](../../label-workflow.md). Queue labels swap, never stack |
| `assign` | Assign to a user or bot |
| `dup <#>` | Close as duplicate, link to the original |
| `wrongrepo <repo>` | Transfer or close with redirect |
| `needsinfo` | Comment requesting more information |
| `defer` | Leave open |

### Triage-first ordering (proposed)

A triage-SLA proposal ([triage-sla.md](../../../contributing/triage-sla.md))
adds one ordering rule to this sweep: when human-authored `1-triage` issues
are over SLA (14 days, no first human response), present them first in the
session, oldest first, before agent-lane PR cards. This is a proposal — it
does not change the verdict vocabulary above until adopted.
---

## Blast Radius Map

| Path pattern | Affects | Fast-lane eligible? |
|---|---|---|
| `system_files/shared/` | bluefin + bluefin-lts + dakota | **Never** |
| `system_files/bluefin/` | GNOME / Bluefin only | No |
| `system_files/nvidia/` | NVIDIA overlay | No |
| `.github/workflows/` | CI pipeline | No |
| `Containerfile` | ALL variants | No |
| `docs/**`, `AGENTS.md` | Documentation only | N/A (doc-only push) |
| `tests/**` | Test suite only | N/A |

For hold-gate queue risk tiers (P0 security/shared blast radius, P1 release-gate/defects, P2 tests/docs) and the release-gate expedite lane, see the draft [prioritization rubric](../../../contributing/hold-gate-rubric.md).
