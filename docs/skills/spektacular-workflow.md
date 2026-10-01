---
name: spektacular-workflow
version: "1.1"
last_updated: "2026-09-24"
id: spektacular-workflow
one_line_purpose: Move product work from reviewed requirements through a plan to verified delivery.
entry_point: docs/skills/spektacular-workflow.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [spektacular, planning, hive, issues]
description: >-
  Guides Project Bluefin's issue-to-specification and plan-to-delivery
  handoffs. Use when drafting or reviewing a specification, triaging an epic,
  planning a multi-repo feature, or deciding whether Hive may run its plan.
metadata:
  type: procedure
---

# Spektacular workflow at Project Bluefin

Use **specification** for the document and **Spektacular** for the upstream
tool. Keep upstream CLI and store identifiers literal (`spektacular`,
`/spek-*`, `.spektacular/`); Project #2 uses full-word field and view names.

## When to Use

Write a specification for a product feature, an epic with several independently
delivered parts, a cross-repository change, or work whose acceptance and
non-goals need a human decision. A bounded bug with a known reproduction and
finish line can stay a normal issue. If the problem is not understood,
investigate first and write the specification once the outcome is clear.
[Upstream's unknown-criteria example](https://spektacular.dev/tutorials/unknown-criteria/)
makes this boundary explicit.

## When NOT to Use

Do not turn a bounded, reproducible bug into a staged project or use this
procedure to enable Hive. Feature flags and execution need a separate pilot
and maintainer approval.

## Core Process

**Keep three things separate:** the GitHub issue routes work, the specification
records *what* is required, and an approved plan says *how* to build and verify
it. Writing a specification never approves the issue for an agent queue.
Follow the owning repository's contract, [label workflow](label-workflow.md),
and [human gates](human-gates.md) at every transition.

1. **Draft and trace.** Read the owning issue, open child issues, linked PRs,
   and current code. Keep the source issue URL and child/task links. Write a
   specification with `Overview`, `Requirements`, `Constraints`, `Acceptance
   Criteria`, `Technical Approach`, `Success Metrics`, and `Non-Goals`, in
   that order. Requirements are atomic observable outcomes; acceptance is
   independently pass/fail. Keep settled UX/API/data shapes and the reasons
   for them in this specification's Constraints and Technical Approach.
   Preserve the original issue body before replacing it; do not append it as another
   requirements section or point Hive at a local-only backup.
2. **Review the specification.** A maintainer resolves product, security,
   breakage, and ownership questions. Unresolved decisions remain explicit;
   they do not become made-up implementation requirements.
   `document_status: draft` means the document is still under review;
   `final` means requirements were reviewed, not that the feature shipped.
   The specification and plan are historical after delivery; code describes
   current behavior.
3. **Record planning identity.** For a CLI-managed specification, use the
   CLI-returned artifact name, never a hand-made ID. Project
   [#2](https://github.com/orgs/projectbluefin/projects/2) records it in
   `Specification ID` and displays `Workflow Stage: Specification`. The
   `Specifications` view filters on `has:specification-id`. Keep `Component`,
   `Priority`, parent `Epic`, and issue queue labels in their own fields.
   `Workflow Stage` is `Specification`/`Planning`/`Implementation`, not
   `document_status`.
4. **Plan only from approved requirements.** In a configured Spektacular
   project, check its version and use the installed agent's `/spek-plan` flow.
   Spektacular reads registered repositories and knowledge, then writes
   `plan.md`, `research.md`, and `context.md`. A human
   reviews coverage of every requirement, repository ownership, dependencies,
   tests and accepted descopes. Move the board to `Planning` only when a real plan
   exists; approve that plan before implementation.
5. **Implement with evidence.** Hive may run the approved plan only after
   its upstream Spektacular runner, triage, and work-source configuration
   are deliberately enabled and verified. Implement in the owning repository
   on its correct target branch; exercise changed behavior and required CI.
   Move the board to `Implementation` only when execution has begun. Close the
   issue through the owning PR/merge process, never on document status alone.

### Issue bodies are not CLI artifacts

A specification-shaped GitHub issue or checkout-local Markdown file is not
automatically registered with Spektacular. Check for an initialized
`.spektacular/config.yaml` and use the CLI's own artifact status before
telling Hive to poll an ID. GitHub frontmatter is fenced for rendering;
file-store artifacts require YAML frontmatter at the start of the file.
Keep original-body backups outside the committed product tree, and do not
stage an unrelated backup collection with a broad `git add specs`.

Hive's current [issue admission](https://github.com/hivecommons/hive/blob/v5/src/pkg/dashboard/stage_leases.go)
uses `<owner/repo>#<issue>` as its run key; its
[adapter](https://github.com/hivecommons/hive/blob/v5/src/pkg/spektacular/adapter.go)
polls that key as an artifact name. Spektacular normally mints a different
timestamp-based name. No issue-to-artifact binding has been proven for this
factory. Resolve and exercise that seam before enabling automatic triage.

Upstream [Hive's Spektacular runner](https://github.com/hivecommons/hive/blob/v5/src/docs/spektacular.md)
and `runs.triage` both default **off**. If enabled after a pilot, upstream
triage sends `kind/feature` and `Epic` toward a spec stage and sends
`kind/bug` or `good first issue` toward direct fixes; these defaults must
match labels in each participating product repository. Hive polls the real
Spektacular CLI by bare artifact name; a `draft` stays put, a `final` may
advance, and a stale plan waits for human re-approval. Hive plan export is
still an [upstream request](https://github.com/hivecommons/spektacular/issues/50);
its documented `tasks.json` / small `plan.md` fallback must be verified before
a rollout. An issue-body rewrite alone does not enable any of this.

## Red Flags

- Treating issue closure, checked child boxes, or `document_status: final` as
  evidence that the whole feature shipped.
- Assuming `Workflow Stage: Planning` means a plan exists, or that `Queued`
  means Hive's optional specification runner is active.
- Assuming Project #2's `Specification ID` translates a GitHub issue key into
  a Spektacular CLI artifact without a tested binding.
- Copying an old epic's implementation checklist into Requirements without
  rechecking finished children, conflicting designs, or present code.
- Reading a stale clone as current in multi-repo planning. Spektacular does
  not fetch or pull registered git sources for you.
- Enabling Hive's runner/triage, adding a secret, or changing defaults across
  product repos without the named human gates.

## Common Rationalizations

- "The issue has the right headings, so Hive can run it." A GitHub body is
  not a CLI-managed artifact or an approved plan.
- "The specification is final, so close the issue." Only verified delivery
  through the owning repository's PR process resolves the work.

## Verification

- Read the owning issue and `AGENTS.md`; query live labels, child state, PRs,
  and board fields. `gh issue view <number> --repo projectbluefin/<repo>
  --json state,labels,body` gives the issue, not Hive runtime state.
- Check Project #2's `Specification ID` and `Workflow Stage` fields; an issue
  body or local path alone is not a CLI status response. Before claiming
  automation works, read authenticated Hive config/status and observe a real
  stage receipt and approved plan for the same artifact name.
- Follow the [Spektacular adoption specification](../specifications/spektacular-adoption.md)
  and its linked plan for pilot gates. Upstream references:
  [workflow](https://spektacular.dev/how-it-works/),
  [configuration](https://spektacular.dev/configuration/),
  [multi-repo projects](https://spektacular.dev/projects/),
  [knowledge](https://spektacular.dev/knowledge-base/), and
  [Hive work sources](https://github.com/hivecommons/hive/blob/v5/src/docs/work-sources.md).
