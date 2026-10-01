---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: triage-first-response

## Overview

Human-authored issues can wait in `1-triage` while agent PR review consumes scarce maintainer time. This unadopted proposal was landed in [common#1195](https://github.com/projectbluefin/common/pull/1195) to complete [common#1067](https://github.com/projectbluefin/common/issues/1067); that issue's closure delivered a *proposal*, not an active response SLA. Maintainers must decide whether the proposed first-response target and triage-first allocation fit the live queue.

## Requirements

- [ ] **Measure a human's first response**
  A human-authored issue's age in `1-triage` can be measured until the first qualifying human action; bot acknowledgments do not count.
- [ ] **Surface aged human work**
  If a maintainer adopts a target and a human issue exceeds it without a response, backlog review can present that issue before an ordinary agent-PR batch, oldest first.
- [ ] **Retain ordinary review when current**
  An under-target queue does not constrain the existing PR review order, issue lifecycle or agent-filing decisions.
- [ ] **Observe the impact**
  Maintainers can compare aged human issues and first-response time with agent-PR review latency before making the allocation rule permanent.

## Constraints

- The source proposed **14 days** for first human response to a human-authored `1-triage` issue, with human action defined as a comment, label change, assignment or closure. This is a candidate target, not current factory policy; determine which actions actually belong to the owning workflow before implementing it.
- A non-bot filer is human-authored. A bot or automated acknowledgment does not stop the clock. The proposal starts the clock when `1-triage` is applied and pauses it under workflow-controlled `blocked` or `hold`; validate these transitions against live event history before using them to calculate an SLA.
- First response is not resolution or approval. Maintain the seven-label contract, existing human triage/merge decisions, repo ownership and branch protection. Do not add an aging label, automatic issue comment, bespoke CI gate or issue closure.
- The August–September 2026 snapshots (50 human-authored triage issues and 17 older than 90 days on August 31; 77 total triage issues on September 5) are historical evidence, not a current baseline.

## Acceptance Criteria

- [ ] **Clock distinguishes humans from bots**
  In a known sample of human- and bot-filed issues, the clock starts on `1-triage`, stops on the first eligible human action, ignores bot acknowledgments and treats `blocked`/`hold` according to the approved pause rule.
- [ ] **Only breaches change presentation**
  With an adopted 14-day target, a 15-day unanswered human issue appears ahead of routine agent PR cards and older breaches appear first; a 13-day issue does not reorder the normal PR queue.
- [ ] **Human verdict remains the gate**
  Presenting a breached issue does not relabel, assign, close, approve or queue it; the person decides the next action through the existing issue-review loop.
- [ ] **Before/after evidence exists**
  A reviewer can retrieve the count of unanswered over-target human issues, time to first human action, older-than-90-day count and agent PR first-review age for the same measurement period.

## Technical Approach

A maintainer selects a target, clock rule and owner after checking current GitHub event history. If adopted, the [issue triage sweep](../skills/pr-review/references/triage-operations.md) can present over-target human-authored `1-triage` issues first, oldest first, ahead of ordinary agent PR cards. Under target, the current review cadence is unchanged. The source proposed a one-query aging report or queue-feed ordering in reusable lifecycle automation only if later justified; this draft neither enables nor assumes that implementation. The [reviewer-ladder specification](reviewer-ladder.md) addresses reviewer capacity, and the [hold-gate prioritization draft](hold-gate-prioritization.md) addresses PR order separately.

## Success Metrics

- Against a fresh pre-adoption baseline, the number of unanswered human issues over the adopted target and the median first-human-response time fall without worsening urgent security/release PR review.
- Breached issues receive a meaningful human triage decision, not merely a bot-generated acknowledgment.

## Non-Goals

- Treating a closed proposal issue as proof that its SLA was adopted.
- Requiring every human issue to be resolved within 14 days, changing bot intake lanes, or overriding urgent human review decisions.
- New workflow labels, unattended issue mutations, PR merge rules or an image-blocking CI convention.
