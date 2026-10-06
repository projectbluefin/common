# Spektacular Adoption Rollout Plan

**Specification:** [Spektacular adoption](../spektacular-adoption.md)

**Goal:** Make reviewed specifications and approved plans the normal path for substantive Bluefin product work while keeping GitHub issues, repository CI, and human decisions authoritative.

**Architecture:** GitHub issues remain intake and traceability; Project Bluefin uses Spektacular for the requirements → plan → implementation artifacts and Hive for optional orchestration of approved stages. Start with one product pilot and verify the issue-to-artifact identity and plan-import contracts before enabling automatic triage or execution. Keep one owner for each status: issue labels for work routing, Spektacular document status for artifact review, and Project #2's existing `Workflow Stage` field for the visible pipeline stage.

**Tech Stack:** GitHub Issues and Project #2, Spektacular's file store and a supported agent, Hive v5's optional run triage/stage runner, Markdown, existing repository validation. No new credentials or package sources are part of this document.

## Global Constraints

- User-facing language is **specification** and **Spektacular**. Upstream CLI commands (`spektacular spec ...`, `/spek-plan`) retain their literal syntax; Project #2 displays `Specification ID` and `Workflow Stage` without new aliases.
- Do not close or queue an issue because its specification is `final`. A reviewed plan and verified implementation remain separate gates. Maintain each repo's branch, security, breakage, review and merge rules; never write to `ublue-os/*`.
- `runs.triage.enabled` and `runs.spektacular.enabled` are **off by default** upstream. Do not enable either in the hosted factory until the maintainer has approved the design, security impact and consumer blast radius and a real pilot proves the identity and import path. Keep Hive's specification, planning and implementation checkpoints enabled.
- Hive's `runs.triage` setting has no per-repository allowlist in the reviewed v5 [configuration](https://github.com/hivecommons/hive/blob/v5/src/pkg/config/runs_config.go). An initial pilot must use an isolated deployment whose configured repositories contain only the pilot target; turning it on in the multi-repo factory would route every eligible repository.
- Use current code and live issues for shipped behavior. Specifications/plans become historical after delivery; current binding conventions belong in owned repository documentation or a deliberately configured knowledge store, not copies that silently drift.
- Audit the working tree before staging or initializing a pilot. Preserve unrelated user files and never mistake a local Markdown draft for a CLI-managed Spektacular artifact.

---

## Verified starting point and open contract

As observed on 2026-09-24, 21 open issues were rewritten in the seven-section format and Project #2 shows them with `Workflow Stage: Specification` and artifact-shaped IDs; this does **not** imply they have CLI-managed artifacts or approved plans. There is no initialized `.spektacular/config.yaml` in this checkout, and the Spektacular binary was unavailable here. The public site still advertised v0.19.2 while the latest observed GitHub release was [0.22.0](https://github.com/hivecommons/spektacular/releases/tag/0.22.0); pin and verify the release during a pilot, not by copying the site's older banner.

**The integration mismatch is a hard gate, not a polish item.** Hive's [issue admission](https://github.com/hivecommons/hive/blob/v5/src/pkg/dashboard/stage_leases.go) keys a run as `<owner/repo>#<issue>`. Its [adapter](https://github.com/hivecommons/hive/blob/v5/src/pkg/spektacular/adapter.go) passes that key to `spektacular spec status <name>`, while Spektacular's timestamp-named [specifications](https://github.com/hivecommons/spektacular#how-it-works) use a distinct bare artifact name. Hive's [artifact-key normalizer](https://github.com/hivecommons/hive/blob/v5/src/pkg/spektacular/runner.go) removes `.md` or `/plan.md` but does not translate an issue key into a timestamp name. Resolve this with a tested issue→artifact binding or an upstream-approved external-ID scheme before switching on run triage. Do not rely on the `Specification ID` board text field as an implicit Hive binding.

Hive's requested [`plan export` contract](https://github.com/hivecommons/spektacular/issues/50) is still open in the upstream integration documentation. The current Hive [runner](https://github.com/hivecommons/hive/blob/v5/src/docs/spektacular.md) offers `tasks.json` then a narrow `plan.md` task-list fallback; neither should admit prose as executable work by guesswork. Hive's [run documentation](https://github.com/hivecommons/hive/blob/v5/src/docs/runs.md) also marks some live end-to-end coverage gaps. Treat these as pilot checks, not shipped guarantees.

## Files and ownership

| Owner | Deliverable |
|---|---|
| `docs/skills/spektacular-workflow.md` | Current issue → reviewed specification → plan → delivery procedure; no claim that a GitHub issue is already a CLI artifact. |
| `docs/SKILL.md` and generated `docs/skills/index.json` / `index.md` | Route agents to the procedure without duplicating it. |
| `.github/ISSUE_TEMPLATE/report.yml` | Keep the one existing intake form. Add feature-specific finish-line guidance without auto-queuing work or introducing a second form by default. |
| Each product repository | Own its issue, reviewed specification, implementation, tests and branch target. Its AGENTS.md is authoritative before a plan touches it. |
| Future `.spektacular/` project | CLI-created configuration, member repo descriptions, specifications, plans and knowledge; not created by this documentation change. |
| Hosted Hive | Owns optional triage, leases, receipts, human checkpoints and plan import; no local doc edit activates it. |

## Task 1: Make intake and review usable today
- [x] Keep standard issue form intake (`needs-triage` default, replacing legacy `1-triage`) and add an optional feature/epic finish-line prompt. A maintainer may add `kind/feature` or `Epic` only after reviewing scope; the form itself neither admits an agent nor starts a Hive run.
- [ ] A reviewer checks the seven sections against current code, child states and issue history, keeps original child links, resolves conflicting requirements and records true dependencies. The GitHub body renders metadata in a YAML fence; a later file-store artifact requires actual leading YAML frontmatter.
- [ ] Set Project #2 `Specification ID` to the **actual CLI-returned name only after import**. Until then, treat existing values as provisional issue-era identifiers. `Workflow Stage: Specification` stays put while the document is under review; labels and issue queue state remain separate.
- [ ] Check the [procedure](../../skills/spektacular-workflow.md) and local [human gates](../../skills/human-gates.md) with one real reviewer, not just a Markdown linter. A bounded bug remains a direct issue; unclear work can be investigated before a specification is drafted.

**Acceptance:** the issue form routes bugs and features without duplicate forms or unauthorized queue admission, and a person can reject an incomplete specification before implementation work starts.

## Task 2: Prove one real Spektacular project without production automation

- [ ] Choose one currently open, bounded feature with an owning maintainer; `testsuite#703` is a candidate only if its three Flatcar scenarios and dependency on `testsuite#704` remain current. Do not fabricate a pilot feature to exercise the tool.
- [ ] On a clean feature branch, review the official [install](https://spektacular.dev/install/), [configuration](https://spektacular.dev/configuration/) and [multi-repo](https://spektacular.dev/projects/) references. Obtain security approval for the third-party binary/source, pin a released version, choose a supported agent (`claude`, `bob` or `codex`), and initialize only the repositories the pilot touches. Set `auto_commit: "off"`; preview any migration using `spektacular migrate --dry-run`. Do not add credentials or copy absolute workstation paths into config.
- [ ] Import/re-author the issue's requirements through the CLI store boundary, using the returned artifact name. `spektacular version check`, `spektacular repo list`, `spektacular spec status <returned-name>` and a clean checkout must all resolve the **same** artifact. Link the GitHub issue back to that artifact; no hand-made filename stands in for a successful CLI import.
- [ ] Record settled API, UX, data and threat decisions in the owning specification's Constraints and Technical Approach, with source links and rationale. Verify existing docs/skills guidance reaches planning without copying an entire skill catalog into a second store.

**Acceptance:** another contributor can clone the pilot project, use the supported CLI to read the same artifact ID and follow the source issue without a private path or missing repo. No Hive production config has changed.

## Task 3: Review the plan and prove the handoff

- [ ] Complete the upstream planning workflow on the reviewed specification. Its `plan.md`, `context.md` and `research.md` name the owning repositories, dependencies, tests and accepted descopes. Have a maintainer approve the plan after checking each requirement and acceptance criterion; then and only then set board stage `Planning`.
- [ ] Verify the exact plan task export that this pinned binary supplies. If `plan export` is unavailable, prove Hive's documented `tasks.json` or narrow `plan.md` fallback on a disposable run; malformed or missing task lists must remain parked rather than generating imaginary implementation issues.
- [ ] Change the specification after plan approval in the pilot and check whether `plan.strict_spec_changes` makes the plan stale. Hive must hold a stale plan for a new human approval rather than advancing to implementation. Keep the implementation checkpoint, repository CI and PR review gates.

**Acceptance:** one real final plan covers every reviewed criterion, exports/imports tasks without loss or duplication, and a changed specification invalidates stale execution.

## Task 4: Resolve issue-to-artifact identity before enabling Hive

- [ ] Compare a real run admitted from `<repo>#<issue>` with Spektacular's returned artifact name. If they differ, implement a supported binding at the upstream Hive/Spektacular seam with its own upstream tests, or select a documented external ID that both CLIs accept. The existing `Specification ID` board field alone is not a tested binding.
- [ ] With a deliberately scoped non-production Hive, exercise one stage receipt from `spec` to `plan`, explicit approval of the imported plan, and a staged `implement` task. [Hive's configuration](https://github.com/hivecommons/hive/blob/v5/src/docs/spektacular.md) requires `runs.spektacular.enabled`; [work sources](https://github.com/hivecommons/hive/blob/v5/src/docs/work-sources.md) add `run_stages` when stage leases are offered to contributors. Keep default spec, plan and implement human checkpoints on.
- [ ] Check the actual hosted deployment's authenticated `/api/config`, `/api/status`, `/api/runs/{key}` and receipts before proposing production flags. The public endpoint redirected to sign-in during research, so its current feature state is **unknown**, not disabled merely because upstream defaults are off.

**Acceptance:** the exact GitHub issue key, CLI artifact ID, Hive lease, stage receipt and approved plan identify one feature end-to-end. Any mismatch leaves production triage and runner off.

## Task 5: Opt in product lines incrementally

- [ ] With maintainer approval, enable triage and the runner only in a deployment scoped to one product repository, or first add and validate upstream per-repository gating. Upstream defaults send `kind/feature` and `Epic` to a specification stage and `kind/bug`/`good first issue` to direct fixes; verify deployed labels and the current [classifier](https://github.com/hivecommons/hive/blob/v5/src/pkg/classify/triage.go). Short or unfinished form bodies must ask for clarification, not enter a run.
- [ ] Prove a small direct bug still bypasses the specification stage, a reviewed feature produces one run, an unresolved feature waits for a human, and a stale plan cannot run. Do not assume Project #2 `Queued` equals a Hive-ready work item; compare to live Hive admission and the owning issue label.
- [ ] Only after the pilot, propose opt-in for Bluefin's other active product repositories with their local owners. LTS, Knuckle and archived repositories remain outside this rollout until their maintainers explicitly choose otherwise. Do not write to `ublue-os/*`.
- [ ] To roll back, disable Hive's optional triage/runner flags; existing issue routing and PRs continue. Keep reviewed specifications and plan receipts as history, and explain any interrupted lease before resetting it.

**Acceptance:** a product feature completes a real reviewed PR with passing repository checks, while the same build's direct bug path and human checkpoints still work. Measure reviewed specifications, approved plans, rejected/stale runs, and implementation outcomes separately; never report specification count as delivered features.

## Primary sources

- Spektacular: [how it works](https://spektacular.dev/how-it-works/), [tutorial](https://spektacular.dev/tutorials/getting-started/), [configuration](https://spektacular.dev/configuration/), [multi-repo projects](https://spektacular.dev/projects/), [knowledge base](https://spektacular.dev/knowledge-base/), [plugin support](https://spektacular.dev/plugins/), [debugging](https://spektacular.dev/debugging/).
- Also reviewed: [installation](https://spektacular.dev/install/), [extending](https://spektacular.dev/extending/), [unknown criteria](https://spektacular.dev/tutorials/unknown-criteria/), and a [real final artifact](https://github.com/hivecommons/spektacular/blob/main/.spektacular/specs/000054_project-level-design-documents.md). GitHub's [issue-form syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms) explains why auto-adding Project #2 from a form would depend on each reporter's permissions.
- Hive v5: [Spektacular runner](https://github.com/hivecommons/hive/blob/v5/src/docs/spektacular.md), [runs](https://github.com/hivecommons/hive/blob/v5/src/docs/runs.md), [work sources](https://github.com/hivecommons/hive/blob/v5/src/docs/work-sources.md), [triage code](https://github.com/hivecommons/hive/blob/v5/src/pkg/classify/triage.go), [run admission](https://github.com/hivecommons/hive/blob/v5/src/pkg/dashboard/stage_leases.go).
