---
name: factory-onboarding
version: "2.0"
last_updated: "2026-10-04"
id: factory-onboarding
one_line_purpose: Onboard an opted-in repository to the shared issue lifecycle and constrained Prow controls.
entry_point: docs/skills/factory-onboarding.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [factory, onboarding, setup]
description: >-
  Defines repository opt-in, authority inspection, shared callers, preview,
  migration, and release proof. Use when onboarding a factory repository or
  reviewing lifecycle and Prow adoption.
metadata:
  type: procedure
---

# Factory Onboarding

## When to use

Use this procedure for an explicit repository opt-in or lifecycle cutover.
**Common and ChairLift are opted-in consumers**, not permission to migrate the
organization. Other repositories keep their local contracts until reviewed opt-in.
For daily operation and command capabilities, load [label-workflow](label-workflow.md).

The reusable implementation belongs to `projectbluefin/actions`; each consumer
owns its catalog, forms, caller, and local human/security/ownership rules.
Common is a shared-contract sidecar, never a replacement for target authority.
Link this procedure from the local skill router; do not copy a user-level policy
skill, a sibling's policy tree, or a lifecycle bot into the consumer.

## Core process

### 1. Establish local authority and the live control plane

Read the target's `AGENTS.md`, skill router/catalog, CODEOWNERS, forms, workflow source, task/PR ownership, delivery pipeline, and security boundaries.
Resolve Hive assignments against the actual GitHub repository/issue before editing; check existing PRs before starting duplicate work.

Inventory **every reader and writer**: installed clients, default-branch/scheduled/organization workflows, GitHub Apps, external workers, label sync, and label-triggered dispatch.
Record each label read/write and native-state dependency. A workflow file, label definition, or Hive `ready` response alone does not prove deployment/admission.
Mark inaccessible external/Hive configuration **unverified** and request observable evidence from its owner.
Adoption preserves protected readers; it does not assume invisible worker settings.

Read repository/organization rulesets, legacy branch protection, check names/producers, review requirements, queue, environments, and bypass actors.
Common's separate native rulesets are `17513003` (queue/checks) and `23854231` (two reviews).
Both expose `OrganizationAdmin` `always` bypass; that capability is not permission to use it.
Re-read live target state; do not promise zero bypass.

**Gate:** every competing writer has an owner/cutover plan, every protected reader/human gate has a preservation rule, and unknown admission is explicit.

### 2. Choose the repository-owned catalog and delivery contract

Author `.github/issue-policy.json` for the exact repository: distinct `display_name`/`comment_marker`, five stages, definitions, `retired_stages`, one-time `label_aliases`, and `standing_issues`.
`kind_sources` can classify still-active operational labels without deleting/reverse-mirroring them; `gate_labels` preserves native reader gates.
Keep one `kind/*` on open issues; `area/*` labels stack.
Declare only locally justified descriptive `intake_rules`; do not inherit
another application's ACMM/agent/title routing. Rules use bounded literal title
prefixes, body text or headings and catalog metadata labels only. They cannot
grant stages, infer consent, assign work, remove an independent gate or override
an existing primary kind; conflicting inferred kinds remain human-gated.
Missing/ambiguous kind requires human classification, not arbitrary migration priority.

Choose `delivery.type: image` for Common-style image delivery or `delivery.type: release` for ChairLift-style application/package delivery.
Identify actual consumption paths, including required image-installed helpers. See the label skill's evidence fields.
A successful build, merged reference, or skipped publication cannot prove the reporter can install the fix.

Preserve `human-only`, independent `needs-human`, `needs-decision`, active-reader `question`, blockers/holds, operational/`agent/*`/`hive/*` labels, assignees, approvals, reviews, branches, and queue state.
Map only labels whose writers/readers are retired; never reverse-mirror stages into old queues.
Historical queues do not establish acceptance.

**Gate:** maintainers approve mappings, native-reader gates, trackers, scope acceptance, and the actual delivered-product boundary.

### 3. Install shared callers, constrained Prow config, and intake

Install a small `.github/workflows/issue-lifecycle.yml` caller of
`projectbluefin/actions/.github/workflows/reusable-issue-lifecycle.yml@v1`.
Reuse the opted-in caller's events and dispatch inputs, scoped to the target.
The shared workflow serializes Prow then lifecycle reconciliation in one
repository concurrency group; bot-token writes need not trigger a second event.
Hourly repair is labels-only. `pull_request_target` reads trusted default-branch
data only: no fork/PR code executes with write permissions.

Install `.github/prow.yaml` as catalog-derived JSON-compatible YAML: kind values
exclusive, area values nonexclusive, literal `hold`, `tide.merge_on_events: false`,
and empty `require_matching_label`. Use only the shared Prow wrapper; do not
install upstream's broad merge workflow. First-party callers/actions use managed
`@v1`; third-party CNCF Prow is immutable-SHA pinned in Actions source.

Adapt `.github/ISSUE_TEMPLATE/bug-report.yml`, `feature-request.yml`, and chooser `config.yml` to local products/ownership; start triage plus exactly one catalog kind, never acceptance/legacy queues.
Required **Automation preference** offers **Human interaction only**, **Machine analysis is welcome**, and **No preference**, without preselecting machine consent. Match catalog `bug_fields` and `feature_fields` to their corresponding required form headings.
CLI structured bodies initialize server-side. Explain ordinary replies, separate acceptance, and delivery/verification; analysis consent never accepts implementation.
Link local authority and the shared label skill from the router, not another lifecycle.
Use `GITHUB_TOKEN` with caller-scoped permissions; add no secrets or app credentials.

**Gate:** the consumer has one lifecycle writer, one shared implementation, and
no label-only acceptance/assignment/repair dispatch path competing with it.

### 4. Preflight and produce a read-only consumer preview

From trusted Actions source with PyYAML installed, run structural preflight against caller data:

```bash
python3 scripts/check-issue-onboarding.py --workspace "$CALLER_WORKSPACE" --repository "$REPOSITORY"
```

Install a consumer read-only `pull_request`/`workflow_dispatch` caller whose `jobs.preview.uses` is `projectbluefin/actions/.github/workflows/reusable-issue-policy-preview.yml@v1`; run it on the candidate PR or by dispatch.
Inputs: `runtime-ref` (released `v1`), `caller-ref` (reviewed caller commit), optional `issue`, and `migrate` (true for full-history migration preview).
For bootstrap before the additive preview interface is released, use a reviewed
first-party candidate branch for the **read-only preview interface/runtime only**;
record its actual commit in the archive. Production remains `@v1`. Switch the
preview interface to `@v1` once native Actions review, main CI and publication
complete; candidate preview evidence is not released-source deployment authority.
Grant only `contents: read`, `issues: read`, and `pull-requests: read`; inherit no secrets.
Caller checkout is data only; no consumer scripts execute.
Archive `issue-policy-preview-<run-id>-<attempt>`: `issue-policy-preview.json`, `onboarding-preflight.txt`,
and `issue-policy-source-revisions.txt` with actual runtime/caller commits in the review.

Review every proposed label, comment, mention request, closure, and mapping across **open/closed issues and PRs** with `migrate=true`.
Then use `migrate=false` and optional `issue=<number>` for comment/mention-aware normal previews.
Read-only preview does not prove Prow writes, notification receipt, production trust,
or successful activation; require separate live proof.

**Gate:** preflight passes and humans approve concrete consumer-visible plans;
unavailable released source blocks production activation, not an invented pin.

### 5. Review, merge natively, and prove the released deployment

All changes, including docs, use a branch and PR. Obtain the target's required
human/security/ownership reviews; satisfy live checks and merge-queue controls.
Use native controls, never direct-main writes, REST merge/admin bypass, or reduced
rules to land the change. Existing approval labels do not replace native reviews.

Merge Actions first and verify required CI on actual `main`; its reviewed `update-v1-tag.yml` publisher advances managed `@v1` after main push.
Verify published `@v1` resolves to reviewed merged source containing the reusable workflow/actions; never manually force-tag around publisher gates.
Merge the consumer natively; verify required CI on its actual `main` commit before public bot writes.
Catalog `main_ci_workflows` lists native main CI workflow paths. The runtime
refuses writes until their latest runs at current main succeed, plus released
Actions unit-tests/actionlint. Grant only additional `actions: read`, not write.
Keep main CI triggers unfiltered to avoid a missing evidence deadlock; PR/queue
green does not replace actual main evidence. The v1 publisher itself waits for
both Actions main workflows before moving the managed tag.
PR-green or workflow presence is insufficient. Separate installation/activation when needed so a newly merged caller cannot write before these gates.
Any pause must be explicit, owned, and reviewed.

**Gate:** record actual Actions release resolution, main CI run/job results,
consumer main revision, and approval/queue evidence. No fabricated green links.

### 6. Pause competing writers and migrate quietly with an archive

Pause/remove inventoried old lifecycle, mirror, sync, and label-only dispatch
writers before apply; verify the live default branch and external owners reflect
the cutover. Keep protected descriptive/operational readers working.
Repeat full-history read-only migration preview against current state and archive
it with existing label definitions/assignments before mutation. Apply only through
the reviewed default-branch caller with Bot provenance:

```bash
gh workflow run issue-lifecycle.yml --repo "$REPOSITORY" -f apply=true -f migrate=true
```

Migration is quiet: no status comments, reporter mentions/action requests, or
closures. The runtime backs up all-state assignments, definitions, catalog, and
preview before writes; download the workflow evidence artifact (30-day retention)
to the operator's durable archive. Preserve partial-failure archives and review
skipped changed records against fresh state rather than force-overwriting them.

**Gate:** all history, including closed PRs, is accounted for; ownership and
consent survive; no legacy writer recreates removed assignments.

### 7. Declare supported-client cutoff before definition retirement

Identify every supported installed report client and label-writing version; publish minimum version/cutoff and upgrade path in the local contract.
Verify supported versions no longer write retired labels and obtain human confirmation.
Keep inert definitions while supported clients need them; they are neither stages nor approval.
Unsupported versions require an explicit support decision, not assumed fleet-wide updates.

After deployment and zero old assignments across full history, dispatch retirement:

```bash
gh workflow run issue-lifecycle.yml --repo "$REPOSITORY" -f apply=true -f retire=true -f confirm-client-cutover=true
```

**Gate:** the cutoff is reviewable evidence; the confirmation input attests to
that evidence and cannot discover installed clients. Retirement retains its backup.

### 8. Refresh reviewed statuses, prove outcomes, then preview again

Approve targeted comment/mention-aware normal previews before refresh; dispatch `issue=<number>` and `apply=true` without quiet flags for each reviewed record.
Archive superseded owned bot statuses, preserve human comments, and inspect requester identity/dedup before notifying reporters.
Do not mass-ping the backlog or treat scheduled labels-only repair as status proof.

Capture actual GitHub UI/API labels, role-headed comments, closure/retriage, preserved assignees/reviews, and command-result links for every stage and Prow outcome.
Exercise authorized classification/hold, help, denied, invalid, PR rejection, and observable failure handling.
Distinguish simulation from real upstream results; prove reporter information/verification notifications only for actual requests.
Formatting/repair alone must not repeat notifications.

Run a second read-only preview on settled live state; review any change and prove stable labels/comments/mentions/state, not merely an empty quiet plan.
Handoff actual evidence and remaining external uncertainties. Update the nearest canonical skill/catalog in the same PR with durable, source-backed learning.
The next repository should reuse the seam, not copy the bot.

## Red flags and verification

Stop for unresolved design/security/cross-repository breakage/merge gates,
unknown writer ownership, unsupported API decisions, or new credential needs.
Read live rules with `gh api repos/$REPOSITORY/rulesets?includes_parents=true`,
individual ruleset IDs, and `gh api repos/$REPOSITORY/branches/main/protection`;
absence of one API object is not absence of all protections. Inspect exact main
run/job conclusions and released source, not inventory claims. Onboarding is done
only when the numbered gates, UI/state/Prow proof, and stable second preview hold.
