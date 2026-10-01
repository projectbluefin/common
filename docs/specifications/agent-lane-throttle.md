---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: agent-lane-throttle

## Overview

The factory should prevent bursts of low-priority agent PRs from overwhelming human review without slowing human contributors or urgent repairs. A reversible, queue-depth-based filing gate could pause new non-urgent agent filings and lift itself after reviewers drain the queue. This draft captures [common#1052](https://github.com/projectbluefin/common/issues/1052); it does not activate a throttle.

## Requirements

- [ ] **Measure the live review queue**
  A filing decision uses current open hold-gated PR counts by repository and across the org, not a dated snapshot or a count of issues.
- [ ] **Pause only new non-urgent agent work**
  When an approved threshold is reached, non-urgent agent lanes defer new PR filings for the affected repo without closing or relabelling work already open.
- [ ] **Preserve urgent and human work**
  Security, supply-chain, core-integrity and release-gate repairs can proceed; human-filed PRs are not subject to an agent filing gate.
- [ ] **Resume automatically when safe**
  The gate lifts when the verified count falls below its approved threshold, without a forgotten manual expiry switch.
- [ ] **Expose the cost of the rule**
  Maintainers can observe stand-down events, duration and the review delay imposed on non-urgent defects before extending the pilot.

## Constraints

- No threshold is operative until a maintainer approves its scope and live baseline. The historical proposal used **8 open hold-gated PRs per repo** and **60 org-wide** as candidate thresholds; these are not factory settings today.
- A filing gate does not add `hold-p0`/`hold-p1`/`hold-p2` labels, alter the seven workflow labels, bypass a PR review, or change existing merges. Do not implement it as a bespoke image-blocking CI job.
- The source proposed optional per-lane caps (scanner ≤5, quality ≤8 per repo until an org queue below 40). Those are alternatives requiring their own approval, not implicit requirements of the first gate.
- A P0 classification must use a maintainer-approved risk rule rather than an agent's self-declared urgency; the pending [hold-gate prioritization specification](hold-gate-prioritization.md) is not active policy.

## Acceptance Criteria

- [ ] **Counts agree with GitHub**
  A sample of live repos' open hold-gated PRs matches the gate's per-repo and org totals at one named observation time.
- [ ] **Threshold scope is correct**
  At a pilot repo threshold, a non-urgent agent filing is deferred there while an under-threshold repo remains unaffected; the approved org-wide limit applies only when reached.
- [ ] **Urgent and human paths survive**
  A human PR and a verified security or broken-release-gate repair are still offered while the gate is active.
- [ ] **Existing work remains untouched**
  Activating and lifting the gate creates no closure, relabel, revert, assignment or queue-status mutation on already open issues or PRs.
- [ ] **Recovery and impact are observable**
  When the count drops below threshold, deferred work becomes eligible again and maintainers can measure both burst prevention and delayed P1 work.

## Technical Approach

The earlier analysis found a burst from 33 to 85 open agent PRs in late August 2026, followed by a drain to 32 by September 23 through review rather than a throttle. This supports a *burst* guard, not permanent rationing; re-measure before selecting any threshold. A per-repository gate and an org-wide gate are independent inputs. Quality/scanner and ordinary refactor/documentation lanes are the proposed deferred set; sec-check and release-gate repair are the proposed exceptions. One deliberately scoped pilot should prove the source of each count, decision, retry and rollback before any multi-repo policy change.

## Success Metrics

- A measured repeat burst stays below the approved queue ceiling without silently suppressing human or urgent PRs.
- Affected non-urgent work resumes after the queue drains, and its extra wait time is visible to maintainers.

## Non-Goals

- Closing, relabelling, reverting or deprioritizing existing work.
- A new GitHub label taxonomy, CI merge gate, contributor permissions model or blanket human PR throttle.
- Treating old queue snapshots or the closure of a proposal-document issue as proof that its policy was adopted.
