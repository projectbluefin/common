---
name: bonedigger
version: "1.2"
last_updated: "2026-10-04"
id: bonedigger
one_line_purpose: Operate bonedigger and kubestellar-bot issue/report automation.
entry_point: docs/skills/bonedigger/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [bonedigger, triage, automation]
description: >-
  bonedigger + kubestellar-bot lifecycle automation. Use when working on
  ujust report, issue lifecycle, priority escalation, or how fixes ship back
  to images.
metadata:
  type: reference
---

# bonedigger & kubestellar-bot

**Repo:** https://github.com/projectbluefin/bonedigger

## When to Use

Use when changing `ujust report`, its confirmation flow, bonedigger intake, or
the labels that route user reports into the factory.

## When Not to Use

Do not use this skill for generic GitHub issue triage, unrelated GitHub CLI
configuration, or general issue-admission routing. bonedigger's
`.github/workflows/lifecycle.yml` was removed from `main` in `bonedigger#40`
(commit `3397cad`, 2026-09-29). `bluefin`, `bluefin-lts`, `dakota`, and `knuckle`
keep `bonedigger.yml` report-intake callers as retention pins at full commit
SHAs (see [`references/full-loop.md`](references/full-loop.md)). Common and
ChairLift use the shared Actions lifecycle instead. Narrow intake callers
pinned to `d530767` (tag `v1`) are being
wired into the four OCI printer forks (`ps-printer-app`, `hplip-printer-app`,
`gutenprint-printer-app`, `ghostscript-printer-app`); see
`projectbluefin/common#1224`. Use
[`label-workflow.md`](../label-workflow.md) for the opted-in shared lifecycle
and [`hive.md`](../hive.md) for cross-repo coordination.

## Core Process

1. Keep collection local, targeted, bounded, and redacted.
2. Route bugs from the booted image and feature requests to common.
3. Preview the exact public payload and require consent before any upload.
4. Submit with authenticated `gh`, preserve failures as resumable drafts, and
   verify the target, queue label, and receipt.

## Red Flags

- Collecting diagnostics before the user selects an intent.
- Uploading a gist or creating an issue before preview and explicit consent.
- Applying both queue labels, using `machine-id`, or reviving generic OTel
  capture.
- Falling back to a browser issue form or a QR login flow.
- Parsing a booted OCI ref by cutting at the first colon: that colon may be a
  registry port (`localhost:5000/bluefin:latest` → `localhost`). Strip the
  digest, take the repository basename, then strip the tag — in that order.

## Verification

- [ ] Integration tables list each reusable workflow once, combining its
  responsibilities and callers rather than treating each purpose as a workflow.
- [ ] Bug routing matches Bluefin, Bluefin LTS, Dakota, and the common fallback.
- [ ] A bug submits at most one supported queue label.
- [ ] Baseline and selected profile limits are enforced after redaction.
- [ ] Missing or unauthenticated `gh` leaves a resumable local draft.
- [ ] A confirmation accepts a positive number or GitHub issue URL without a
  persistent device identifier.

## References

| File | Description |
|---|---|
| [`references/full-loop.md`](references/full-loop.md) | The full bonedigger→kubestellar-bot loop, what each component does and does NOT do, integration status table, and template sync. |
| [`references/lessons-learned.md`](references/lessons-learned.md) | Lessons learned, common rationalizations, and sources. |
