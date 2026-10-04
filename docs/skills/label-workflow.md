---
name: label-workflow
version: "5.0"
last_updated: "2026-10-04"
id: label-workflow
one_line_purpose: Operate opted-in Common and ChairLift issues with trusted acceptance, delivery, and constrained Prow.
entry_point: docs/skills/label-workflow.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [labels, issues, workflow]
description: >-
  Documents opted-in Common and ChairLift stages, human gates, Prow controls,
  delivery evidence, and notifications. Use when triaging issues, linking PRs,
  refreshing status, or reviewing lifecycle migration.
metadata:
  type: procedure
---

# Label Workflow — opted-in Common and ChairLift

## When to use

This contract applies to explicitly opted-in **`projectbluefin/common` and `projectbluefin/chairlift`**; local `AGENTS.md`, catalogs, forms, delivery, and ownership remain authoritative.
Other repositories retain local lifecycle/queue contracts; labels do not opt them in.
For installation/cutover, use [factory-onboarding](factory-onboarding.md).

## Issue stages and human gates

Each open issue has one stage. PRs have none: native assignment, draft/readiness,
requested reviewers, review decisions, checks, and merge queue own PR progress.

| Stage | Current status | Owner and next action | Reporter action |
|---|---|---|---|
| `needs-triage` | Waiting on Maintainer; implementation not accepted | Maintainer reads scope, clarifies, accepts, or closes with a reason | No action unless asked; ordinary replies are welcome |
| `triage/needs-information` | A specific fact/question/decision is missing | Named requester/decision owner resolves it; maintainer reassesses | Answer a reporter-directed request normally; no label access needed |
| `triage/accepted` | Trusted human accepted current scope, not assignment | Maintainer assigns/routes work; contributor implements; native PR review follows | No action unless asked |
| `awaiting-release` | Actual fix merged; delivery remains unproven | Release owner proves publication reached the affected installation/channel | Wait; no update requested yet |
| `needs-verification` | Authorized delivery evidence recorded | Reporter tests named version/instructions; result closes or retriages | Reply `Confirmed fixed` with tested version or `Still broken` with observations |

Decline/duplicate/completion is closure with a reason, not another stage. Standing trackers retain `tracking`; triage/assign actionable children separately.
One catalog `kind/*` describes issue type; multiple `area/*` labels describe scope.
Missing/unresolved conflicting kinds retain `needs-kind` and implementation gating until trusted human classification, never acceptance by classification.

| Overlay/gate | Meaning and owner action |
|---|---|
| `blocked` | Name dependency, resolver, and next step; owner resolves it before resumption |
| `hold` | Record pause reason/owner/resumption condition; owner explicitly withdraws only the pause |
| `human-only` | Human interaction/contributors only. Set from the reporter's preference at intake; a maintainer can waive it by removing the label |
| `needs-human` | Native reader gate; acceptance clears only the lifecycle bot's automatic gate, never a human/app's independent gate |
| `needs-decision`, catalog `gate_labels` | Owner answers the question, then removes the label. On accepted work, `needs-decision` pauses it; acceptance stays |

ChairLift's catalog preserves `question` as a native reader gate, not a stage. Keep operational labels with active consumers: routing, request, provenance, priority, review/dependency labels, `agent/*`, and `hive/*`.
Examples include `ai-fix-requested`, `from-review`, `source:agent`, `lgtm`, `automerge`, and `chore/deps` where locally used; they grant no shared lifecycle authority.
`kind_sources` can classify an active legacy label without deleting it; `label_aliases` is a one-time migration, never a reverse mirror.
Never erase assignees, approvals, reviews, branches, or merge-queue entries.

### Intake and exact acceptance action

Consumers own forms/chooser. Forms initialize triage plus kind; structured CLI bodies initialize server-side because reporters cannot reliably set labels.
**Automation preference** distinguishes **Human interaction only**, **Machine analysis is welcome**, and **No preference**.
Analysis consent, old queues, reporter comments, bot labels, and Hive `ready` never accept implementation.
Descriptive title/body rules live in each catalog's `intake_rules`, not in a
shared application's code. Common opts in its own bug/feature/question taxonomy;
ChairLift additionally declares its ACMM/guide/quality and documentation rules.
Those labels are metadata, not authenticated provenance, analysis consent,
acceptance or assignment; existing primary kinds and independent gates win.

A trusted human reviews/updates body scope and criteria **first**, then adds `triage/accepted` in **Labels**. Runtime checks immutable actor, current write/maintain/admin permission, and body revision.
Later body edits or assessment/information resets require fresh human acceptance.
Evaluate human grant/withdrawal history before bot projections; reconciliation must neither erase valid decisions nor resurrect withdrawn ones.

Removing `needs-triage`/`needs-human` does not accept work: automatic waiting gates
return. `/hive approve` is not a Common or ChairLift lifecycle acceptance action.
Resolve each blocker/hold/decision/native human gate through its owner. Acceptance
does not clear independent gates, assign a contributor, or guarantee scheduling.
Use **Assignees** or explicit routing to the existing work owner; respect human-only.

A maintainer with write access can waive `human-only` by removing the label. The
bot then stops re-adding it, until someone adds it back.

When `needs-decision` is added to an accepted issue (for example by Hive), the
issue stays accepted and `needs-human` stays on. Removing `needs-decision`
resumes work; no re-accept is needed.

For an actionable reporter question, explicitly `@reporter` in a new request
and select `triage/needs-information` within five minutes, or select the stage
first and then ask. Older or answered questions and requests to another
maintainer do not create reporter notifications; unclear recipient stays
maintainer-owned. Ordinary replies require no labels or commands.

## Constrained Prow commands

Post **one command-only line in a new comment**. Mutations need immutable human commenter/sender match, current write/maintain/admin permission, an **open issue**, and trusted default-branch catalog/config.
Edited commands, multiline/prose, PR mutations, unauthorized actors, unknown values, and broad Prow features do not execute.
`/help` and `/prow help` are read-only human help without mutation permission; help grants no authority.

| Enabled command | Observed effect / limit |
|---|---|
| `/help`, `/prow help` | List enabled values, controls, and next actions; no labels change |
| `/kind VALUE` | Select one catalog kind, replacing existing kinds |
| `/area VALUE` | Add a catalog area; areas stack; enabled only when catalog has areas |
| `/remove-area VALUE` | Remove that catalog area only |
| `/hold` | Add negative pause; maintainer records reason and resumption condition |
| `/hold cancel`, `/unhold`, `/remove-hold` | Withdraw `hold` only; independent gates remain |

Values come from the catalog; Common has no area commands unless it opts areas in, while ChairLift does. No `/remove-kind` is enabled.
Prow cannot change stages, accept/assign/dispatch work, clear independent gates, approve reviews, close issues, or merge. Native PR controls remain intact.
The wrapper runs immutable-SHA CNCF Prow, then re-reads GitHub labels. Every command gets applied/denied/invalid/help role-headed feedback with actual changes, controls, and next steps.
Partial failure/unreadable final state is reported accurately, not assumed success or falsely claimed no mutation.

## PR linkage and delivery evidence

1. Use **`Refs #NNN`** while the product report remains unresolved. Route through
   existing assignees/PR owners; do not duplicate work or replace native review.
2. Maintainer verifies the **actual fix** merged, then selects `awaiting-release`
   with **Labels**. A merged reference/documentation PR is not a fix or delivery.
3. Authorized human records **Delivery evidence** in the body, verifies real
   publication, then selects `needs-verification` after the body edit. Common uses:

   ```text
   Image: <published-image>@sha256:<64-hex-digest>
   Fix revision: <40-hex-commit>
   Release/build: https://<actual-release-or-successful-publishing-run>
   Verify: <specific-update-reboot-and-reproduction-instructions>
   ```

   ChairLift uses these fields instead of `Image`, retaining the other three:

   ```text
   Package: <published-application-or-package>
   Version: <published-version>
   ```

   Application delivery includes required image-installed helpers and the actual
   installation/channel. Runtime validates authority/shape; the human verifies
   published contents reached the reporter. A green run with publication skipped
   or an unrelated downstream build is not delivery.
4. A reporter result **after the authorized verification request** can close
   (`Confirmed fixed`) or return to `needs-triage` (`Still broken`). Bot restoration
   does not move that request anchor. Unrelated replies never confirm a fix.

Use **`Closes #NNN`** only for code-only criteria satisfied at merge, or already
delivered/verified reports. Product reports do not close merely because code merged.

## Role-headed reports and notifications

Every lifecycle stage and Prow outcome uses `**Status:**`, role headings, concise
action bullets, and a separate `## Reporter` / `**Reporter action:**`. The normal
Common waiting report is exactly this visible layout (plus its hidden marker):

```markdown
**Status:** Waiting on Maintainer

## Maintainer

- To accept, add `triage/accepted`.
- Removing `needs-triage` or `needs-human` does not work, let the bot do it.
- Accepting means we want it in Bluefin - you are not committed to working on this.
- Need more information? Ask, then add `triage/needs-information`. To decline, close with a reason.

## Reporter

**Reporter action:** No action needed unless information is requested.
```

ChairLift substitutes its display name. Blocker/classification/stale-scope/human-gate/existing-work/tracker advice belongs in relevant role bullets.
Other stages put transitions inside bullets, not extra **Next actor** or **Expected transition** headers.
PR reports direct contributors/reviewers to native controls; reporters reply on the linked issue.

Missing fields can request reporter information; a `needs-decision`, tracker, or
bot-authored report needs a maintainer decision instead and does **not** notify
a reporter. A free-form information stage needs an actual trusted maintainer
question/request before asking a reporter to act. Verification needs complete
authorized delivery evidence. Normal waiting/accepted/release/Prow reports do not
request reporter action or add a reporter mention merely for status maintenance.

### Cleanup and recovery

- Zero open assignments does not mean unused. Check closed history, forms,
  workflows, and skill/API consumers before deleting definitions. Hive still
  uses `lgtm` and `good first issue`; preserve its routing namespaces.
- Archive definitions and all issue/PR assignments before deletion. Recreating
  a definition does not restore its historical assignments; restore those
  associations separately from the backup when undoing a mistaken deletion.
- Account type alone does not prove authorship. Older generated notices may have
  used a maintainer token. Migrate an owner-authorized, exact known template only
  after archiving it; never rewrite ordinary discussion or human-modified variants.
- `GitHub.request()` does not retry 5xx failures. An apply can stop partway;
  inspect failed logs, preserve its snapshot, and compare live state before
  re-dispatching the quiet migration. Pause scheduled/event repair during recovery.
- A queued rerun with no job is not progress. Inspect competing runs; if the
  rerun is stuck or its control state is inconsistent, dispatch a fresh migration
  rather than waiting indefinitely. Keep `migrate=true` on retirement dispatches.
- Classification is not substantive triage. Read the current discussion, verify
  every completion criterion against merged implementation and runtime evidence,
  preserve linked-PR ownership, and publish a specific next action or real decision.
  Documentation, a withdrawn PR, and a delivered user fix are different outcomes.
  Preparing an actionable scope does not itself grant implementation acceptance.
- For content migration, pause the workflow before editing issue bodies with a
  user token. Remove only bounded machine-owned pipeline panels; preserve human
  text and recorded preferences. Body edits can invalidate acceptance or satisfy
  an information request, so inspect the resulting stage before restoring repair.
- Verify definitions and assignments separately, plus kind/area coverage, native
  ownership, holds, preferences, and comment/closure behavior. Re-enable repair
  and finish with a quiet migration dispatch, not a bulk status-comment pass.

Notification eligibility is structured, not parsed from Markdown. Dedup keys
bind repository, issue, authorized request identity, and semantic action; formatting
changes and bot projections do not re-request the same action. One current owned
bot status is updated in place; superseded owned bot statuses are visibly archived,
not human comments. Because editing a comment is not a fresh notification, a newly
required reporter action also gets a new targeted mention comment when needed.
Notification markers prevent repeated requests; GitHub UI receipt still needs proof.

## Runtime operation and verification

Shared Actions owns `scripts/issue_policy.py`, `scripts/issue_status.py`, and `scripts/prow_commands.py`, packaged as `issue-lifecycle`/`prow-labels`.
Consumers own `.github/issue-policy.json`, `.github/prow.yaml`, and thin `issue-lifecycle.yml` callers; first-party references use `@v1`.
Trusted default-branch data/repository-scoped Bot writes are required; local user-token apply is refused.
Events serialize Prow/lifecycle; hourly sweeps are labels-only. Native assignment/review/checks/merge state is never rewritten.

From trusted Actions source, preview live consumer data without writes:

```bash
python3 -m scripts.issue_policy --workspace "$CALLER_WORKSPACE" --repo "$REPOSITORY" --dry-run --output /tmp/issue-preview.json
```

Full-history quiet migration, archive, client cutoff/retirement, read-only consumer
CI preview, and reviewed targeted refresh are one procedure in
[factory-onboarding](factory-onboarding.md); do not substitute local-token apply.
Verify actual UI/state and each enabled Prow outcome, then a stable second preview.
Hive's native `needs-human` enumeration gate is local protection, **not verified
universal Hive admission** for cached/assigned/differently configured workers.
Read live Hive coordination, then verify GitHub acceptance, scope, ownership,
overlays, classification, and human preference before implementation. Invisible
Hive settings remain unverified; readiness and acceptance are separate facts.

## Red flags

No organization-wide label sync, legacy reverse mirrors, label-only dispatch,
assumed client updates, reporter slash-command requirement, or merge-as-delivery.
Preserve independent gates and existing work; use native human review and merge
controls. Consult the target contract before changing any other repository.
