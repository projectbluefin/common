# Plan Audit — common-docs-overhaul
**Date:** 2025-07-20 · **Verdict:** NOT READY

Incoming plan: `/tmp/common-docs-overhaul-plan.md`
Repository: `projectbluefin/common`

## Principles Alignment

| Check | Status | Note |
|---|---|---|
| Vertical slices | ⚠️ | Phases A–E are horizontal (structure → rewrites → additions → validation → future). Each phase does not necessarily ship a complete, self-consistent audience-facing improvement. For bigpowers execution, prefer vertical slices such as "agent entry-point overhaul" (agents.md + SKILL.md + copilot-instructions) or "testing docs consolidation". |
| Scope bounded | ✅ | Explicit keep/merge/rewrite/delete verdicts per file, target tree, and path mapping table bound scope well. |
| Success criteria | ⚠️ | Phase D lists validation commands but lacks per-phase `verify:` commands or explicit done criteria. Every bigpowers task/step needs a runnable `verify`. |
| Hard gates identifiable | ⚠️ | Implicit gates exist (AGENTS.md vs agents.md case rename; proposed CI checks that may conflict with project policy) but are not called out as explicit human decision gates. |
| Domain language / ubiquitous terminology | ✅ | Plan consistently uses AAIF, skill front-matter, lazy-loading, progressive disclosure, and token budgets. |

## Conventions Completeness

| Check | Status | Note |
|---|---|---|
| `CLAUDE.md` / `CONVENTIONS.md` | ❌ | Neither exists. `AGENTS.md` currently serves as the per-repo contract and is being rewritten into a shorter `agents.md`; this is the closest equivalent but not bigpowers-standard `CLAUDE.md`. |
| `specs/` directory layout | ⚠️ | Only legacy `specs/00-bluespeed-specification.md` exists. No bigpowers YAML cockpit (`state.yaml`, `release-plan.yaml`, `epics/`, `requirements/`). If this plan is adopted as a bigpowers epic, the YAML scaffolding must be created. |
| Commit conventions documented | ✅ | Conventional Commits are already required by `AGENTS.md` and the plan preserves this. |
| Git workflow mode (`solo-git` / `team-pr`) | ⚠️ | The repo effectively uses team-pr with human `lgtm`, but the plan does not select a bigpowers workflow profile. Since this is a factory repo, `team-pr` is the safe assumption. |

## Bigpowers Pre-flight Answers

| Question | Value |
|---|---|
| Test command | `just test` (per proposed `agents.md` draft) |
| Build command | `just check` (lint Justfile); `just build` for image builds, but not needed for docs-only work |
| Lint command | `pre-commit run --all-files` |
| Typecheck command | N/A — Markdown/shell repo |
| CI platform | GitHub Actions |
| Solo or team? | Team (human `lgtm` required for merge; doc-only `docs/**` + `AGENTS.md` may push directly per repo exception) |
| Primary language + framework | Markdown, GitHub Actions, Just, shell |
| Greenfield or existing codebase? | Existing codebase (`projectbluefin/common`) |

## Project-specific Conflicts / Risks

| # | Risk | Status | Mitigation |
|---|---|---|---|
| 1 | **AGENTS.md vs agents.md case.** Plan explicitly marks as **UNVERIFIED** whether tooling/CI expects uppercase. Renaming may break `.github/copilot-instructions.md`, `bonedigger` lifecycle bot references, downstream repos, and any hardcoded agent loader paths. | ⚠️ | Verify before any rename. Treat as a **Design/Breakage human gate**. If in doubt, keep `AGENTS.md` uppercase and only rewrite content. |
| 2 | **Process conventions as CI gates.** `common/AGENTS.md` states: *"Process conventions ... are self-enforced by agents. **Never implement a process convention as a CI gate.**"* The plan proposes CI checks for front-matter schema, size budget, and TOC freshness. These are process conventions unless framed as hygiene/pre-commit guards. | ⚠️ | Decide whether these checks live in `pre-commit` (hygiene, allowed) or in blocking CI (conflict). Update plan to align with repo policy. |
| 3 | **Mixed doc-only and non-doc phases.** Phase A includes `.github/copilot-instructions.md` changes; Phase C touches `.github/pull_request_template.md`; Phase D adds CI checks. These require PRs, while pure `docs/**` + `AGENTS.md` changes may push directly per `common/AGENTS.md`. | ⚠️ | Split the plan so that `.github/` and CI changes are separate PRs from `docs/**` moves. Or accept all phases go through PR because of the mixed scope. |
| 4 | **Size budget immediately violated.** `docs/skills/lab-testing.md` is 906 lines; several others exceed the proposed 500-line hard limit. Phase E (per-skill directory migration) is intentionally deferred, so the plan as executed will be out of conformance with its own budget rule until Phase E. | ⚠️ | Either add Phase E to the initial rollout, grandfather existing long skills with an exemption list, or relax the 500-line gate to a warning-only rule until migration. |
| 5 | **`docs/skills/INDEX.md` deletion.** Many skill-drift/link checks may reference `INDEX.md`. The plan merges it into `docs/SKILL.md`, but any external links or `bonedigger`/workflow references to `docs/skills/INDEX.md` will 404. | ⚠️ | Add redirect or verify no external references before deleting. |
| 6 | **Context7 methodology claim in the plan is a session artifact, not a specification.** The plan includes Context7 research narrative that is useful background but does not belong in the final committed plan file. | ⚠️ | Strip research notes from the spec that gets committed; keep only findings that changed the plan. |

## Open Gaps

- [ ] Confirm uppercase vs lowercase `AGENTS.md` / `agents.md` before rename.
- [ ] Re-slice plan into vertical, independently shippable PRs (e.g., entry points, testing docs, skill normalization, CI hygiene).
- [ ] Add explicit `verify:` commands for every phase/task.
- [ ] Resolve CI vs pre-commit classification of front-matter/size/TOC checks against `common/AGENTS.md`.
- [ ] Decide how to handle existing skills >500 lines before the budget rule takes effect.
- [ ] Create bigpowers YAML scaffolding if this is to be tracked as an epic (`specs/state.yaml`, `specs/release-plan.yaml`, etc.).
- [ ] Verify `just test` actually runs the intended test suite in the current `Justfile`.
- [ ] Confirm no external/bonedigger references to `docs/skills/INDEX.md` before deletion.

## Verdict

**NOT READY** — 8 open gaps remain; close the highlighted gates before proceeding to `survey-context` or `kickoff-branch`.

## Recommended Next Skill

`elaborate-spec` (to tighten scope, add per-phase verification, and resolve the open gates) or `scope-work` (to convert the horizontal phases into vertical slices with explicit in_scope/out_of_scope).
