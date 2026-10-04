---
name: label-workflow
version: "4.1"
last_updated: "2026-10-03"
id: label-workflow
one_line_purpose: Operate the common-only issue lifecycle and preserve other repositories' local label contracts.
entry_point: docs/skills/label-workflow.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [labels, issues, workflow]
description: >-
  The common-only pilot's issue stages, human acceptance gate, delivery evidence,
  and reporter next steps. Use when triaging common reports, linking PRs,
  reconciling lifecycle labels, or checking a target repository's local authority.
metadata:
  type: procedure
---

# Label Workflow — common pilot

This is the lifecycle authority for **`projectbluefin/common` only**. It does
not migrate other repositories or change Hive deployment, authentication, or
scheduling. Start with the target repository's `AGENTS.md` elsewhere. The
numbered workflow and `queue/*` dialects in other repositories remain local
contracts, not instructions to apply the common pilot across the organization.

## Issue stages

An open common issue carries exactly one of these five stages. Pull requests
carry none: use native GitHub assignment, review requests, review status,
checks, and the merge queue instead.

| Stage | Status | Next actor and specific next step | Reporter action |
|---|---|---|---|
| `needs-triage` | Submitted, not yet accepted for implementation | Trusted human triager reads the report and decides whether to clarify, accept, or decline it | Wait; add relevant details in an ordinary reply if available |
| `triage/needs-information` | A specific question prevents a decision | The person named in the triager's question provides the missing information; triager then reassesses | Reply normally to the question; no label or command required |
| `triage/accepted` | Trusted human has accepted implementation scope | Maintainer records acceptance criteria and assigns or explicitly routes work; assignee implements and links a PR | No action unless a specific question is asked |
| `awaiting-release` | Implementation is merged, but delivery to the affected image or channel is unproven | Authorized human records evidence that the fix is available in the reporter's affected image/channel | Wait for delivery instructions; merge alone is not a reason to update |
| `needs-verification` | Delivery evidence is recorded and the outcome needs checking | Reporter follows the specified update/reboot/reproduction steps; maintainer reviews the reply and closes or reopens work | Verify on the named image/version and report the result in a normal reply |

Declined, duplicate, or completed work can be closed with a reason rather than
inventing another stage. Code-only work whose acceptance criteria are met at
merge may close then; image reports remain open until delivery and verification
are recorded. Do not leave an accepted issue looking completed just because
its implementation PR merged.

### Overlays and analysis preference

| Label | Meaning | Required context |
|---|---|---|
| `blocked` | A decision or external dependency prevents progress | Name the dependency, who can resolve it, and the next step in the same lifecycle post |
| `hold` | Work is intentionally paused | State who paused it, why, and what permits resuming |
| `human-only` | Reporter requests human interaction rather than machine analysis or agent implementation | Preserve the preference during triage, assignment, migration, and reconciliation; routine status automation may still run |

These coexist with one issue stage; they do not imply acceptance or erase an
existing assignee, approval, review request, branch, or merge-queue entry.
Preserve descriptive labels (including `kind/bug` and `kind/feature`),
operational labels (`lgtm`, `automerge`, `chore/deps`), and
`agent/*` and `hive/*` routing labels. Change the owned stage labels, not the
entire unrelated label set.

## Intake and trusted acceptance

Common owns `bug-report.yml`, `feature-request.yml`, and the chooser
`config.yml` under `.github/ISSUE_TEMPLATE/`. The forms start with
`needs-triage` plus `kind/bug` or `kind/feature`. Reporters do not need label
permissions. Ordinary user CLI submissions cannot reliably set labels; the
server initializes intake from the structured issue body instead.

The form's **Automation preference** has three choices:

- **Human interaction only** requests `human-only` handling.
- **Machine analysis is welcome** permits analysis, not implementation acceptance.
- **No preference** expresses no analysis preference, not implementation acceptance.

Intake records preference, not approval. A trusted human accepts the current
scope through GitHub's label picker. The runtime checks the immutable label
event's actor, current repository write/maintain/admin permission, and
`lastEditedAt`; changing the body requires fresh acceptance. A bot label, old
queue, reporter reply, or Hive `ready` result is not approval. Reporters reply
normally, without slash commands. A response returns an information request
to maintainer assessment, not directly to accepted work. Acceptance does not
self-assign a task or authorize changes outside the agreed scope.

## PR linkage and delivery

1. Link the accepted issue with **`Refs #NNN`** while the reporter's affected
   image remains unresolved. Keep existing assignments, approvals, review
   requests, branches, and merge-queue decisions intact.
2. Use GitHub's native PR status during implementation and review. Do not add
   an issue stage or a replacement review label to the PR.
3. For an image report, a merged implementation moves the issue to
   `awaiting-release`, not closed. Identify the merged PR/commit and the
   affected image/channel; neither a common build nor a downstream PR proves
   that the reporter can consume the fix.
4. An authorized human records verified delivery under **Delivery evidence**
   in the issue body, then selects `needs-verification`. Required fields:

   ```text
   Image: <actual-published-image-reference>@sha256:<64-hex-digest>
   Fix revision: <40-hex-commit>
   Release/build: https://<actual-release-or-successful-publishing-run>
   Verify: <specific-update-reboot-and-reproduction-instructions>
   ```

   The runtime checks the actor and record shape; the human verifies the image
   actually contains the fix. A skipped publishing job is not delivery.
5. After that request, the reporter replies `Confirmed fixed` with the tested
   version to close, or `Still broken` to return to triage. Other ordinary
   replies remain available for discussion; no slash commands are required.

Use **`Closes #NNN`** only for code-only tasks whose acceptance criteria are
satisfied at merge, or reports whose delivery and verification are already
complete. Do not blanket-close image reports from an implementation PR.

## Lifecycle posts

Every project-owned lifecycle post includes all four:

- **Status:** what is known now, including whether implementation is accepted,
  merely merged, or evidenced as delivered.
- **Next actor:** the reporter, triager, assignee, or delivery maintainer who
  actually owns the next action.
- **Specific next steps:** the question, decision, implementation scope,
  delivery evidence, or update/reproduction instructions required.
- **Reporter action:** the exact requested reply or verification step, or an
  explicit statement that no action is needed yet.

Do not make reporters decipher labels, issue commands, or interpret a merge as
proof of delivery. Avoid repeating unchanged lifecycle notices.

## Operating the common runtime

Source: `scripts/common_issue_policy.py`, `.github/issue-policy.json`, and
`.github/workflows/issue-lifecycle.yml`, all scoped to common. Events and hourly
reconciliation repair labels. Event-driven reconciliation maintains one status
comment per record; scheduled sweeps use `--labels-only`, without comments or
closures. Native PR review, assignment, checks, branches, and merge-queue state
are untouched.

Preview and archive the existing issue/PR migration before applying:

```bash
python3 scripts/common_issue_policy.py --migrate --dry-run --output /tmp/common-migration.json
gh workflow run issue-lifecycle.yml --repo projectbluefin/common -f apply=true -f migrate=true
```
Run dispatch only after review and merge. Local-token apply is refused: gates
must have bot provenance, not a human operator's actor.
Migration is labels-only: it posts no status comments, sends no reporter action
requests, and closes no records. After migration, normal events handle targeted
status updates; scheduled sweeps remain quiet. Historical comments alone do not
trigger migration backups; removing retired assignments does.

Ambiguous queues return to triage. Existing human routing becomes `human-only`;
overlays and unrelated labels survive. Every migration archives assignments and
definitions under `~/.local/state/common-issue-policy/` before mutation; workflows
upload these snapshots as 30-day artifacts, including after a failed apply.

Retirement removes definitions from the label picker as well as assignments.
Supported common report clients must not request retired labels; older clients
that do must upgrade. After deployment and the explicit client cutoff, retire:

```bash
gh workflow run issue-lifecycle.yml --repo projectbluefin/common -f apply=true -f migrate=true -f retire=true -f confirm-client-cutover=true
```

Retirement refuses an undeployed policy or remaining active old assignments.
No mutation in another repository is allowed.

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

### Hive boundary

The runtime uses Hive's native **`needs-human` enumeration gate** while
common work is unaccepted or requests human-only interaction. This is local
GitHub label enforcement, not a new Hive custom approval API or a deployment
change. Independent human/app `needs-human` gates are never cleared by acceptance;
their owner must explicitly withdraw them after resolving the reason. Only
automatic lifecycle-bot gates clear when the accepted scope is eligible.

Hive's current `ready` queue is **not a verified `triage/accepted` admission
gate**. The native enumeration gate does not establish a universal guarantee
for cached, assigned, or differently configured Hive workers.
Read live Hive state for coordination, then verify GitHub's trusted acceptance,
scope, assignment, overlays, and `human-only` preference before acting.
Acceptance and scheduling are separate facts. See [hive.md](hive.md).

Other repositories retain their local contracts and synchronization. Do not
run an organization-wide sync or infer adoption from label definitions.

## Operator review checklist

- [ ] The target is `projectbluefin/common`, with exactly one open-issue stage
      and no issue-stage labels on PRs.
- [ ] Acceptance has an authorized human event, not just label presence or
      consent to machine analysis.
- [ ] Existing overlays, preferences, unrelated labels, assignments, approvals,
      reviews, branches, and merge-queue state are preserved.
- [ ] Image reports use references and remain open after implementation merge.
- [ ] Delivery and verification changes cite validated human evidence; no
      unimplemented delivery automation is claimed.
- [ ] Each lifecycle post names status, next actor, specific next steps, and
      reporter action without requiring label permissions or slash commands.
