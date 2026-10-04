# Issue Triage and Blast Radius Map

Part of [pr-review](../SKILL.md) — issue triage verdict vocabulary and blast radius classification for common PRs.

## Issue Triage Sweep

Same dossier → verdict → stage → land loop, with issue verdicts:

| Verdict | Effect |
|---|---|
| `close` | Close with the human's stated reason |
| `label <name>` | Follow the common pilot's five issue stages and preserve descriptive, operational, and routing labels — see [label-workflow](../../label-workflow.md). PRs use native review state, not issue stages or numbered queues. |
| `assign` | Assign to a user or bot |
| `dup <#>` | Close as duplicate, link to the original |
| `wrongrepo <repo>` | Transfer or close with redirect |
| `needsinfo` | Comment requesting more information |
| `defer` | Leave open |

---

## Blast Radius Map

| Path pattern | Affects | Fast-lane eligible? |
|---|---|---|
| `system_files/shared/` | bluefin + bluefin-lts + dakota | **Never** |
| `system_files/bluefin/` | GNOME / Bluefin only | No |
| `.github/workflows/` | CI pipeline | No |
| `Containerfile` | ALL variants | No |
| `docs/**`, `AGENTS.md` | Documentation only | N/A (doc-only push) |
| `tests/**` | Test suite only | N/A |

Use current GitHub evidence and maintainer intent for security or release-gate
priority; no unpublished rubric is a workflow rule.
