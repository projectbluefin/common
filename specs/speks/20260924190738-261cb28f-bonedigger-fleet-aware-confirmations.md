---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-261cb28f-bonedigger-fleet-aware-confirmations

## Overview

People responsible for multiple Bluefin machines can see whether a reported issue affects several of their own devices instead of mistaking repeated confirmations for independent users. Fleet correlation must be opt-in and removable while GitHub Issues remains the only backend. Source: [bonedigger#4](https://github.com/projectbluefin/bonedigger/issues/4).

## Requirements

- [ ] **Opt into fleet identification**
  A reporting user can elect to attach a privacy-reviewed fleet tag without exposing a hostname or raw machine ID.
- [ ] **Count affected machines**
  The issue view distinguishes how many distinct machines in a consenting fleet confirmed a problem.
- [ ] **Surface fleet-relevant issues**
  An admin can see open issues matching digests running on a selected machine using a local fleet-status workflow.
- [ ] **Keep confirmation escalation truthful**
  Fleet counts do not replace the existing per-issue confirm escalation rules.

## Constraints

- Fleet tag is explicitly opt-in, documented, removable and designed for privacy; security/design review settles identifier construction before implementation.
- No central server or new credential system: GitHub Issues remains the state backend.
- This is a v2 outcome, not part of the v1 single-user/single-machine report contract.

## Acceptance Criteria

- [ ] **Opt into fleet identification**
  Reporting without opting in sends no fleet tag; the submitted tag is not reversible to a hostname and can be removed.
- [ ] **Count affected machines**
  Three confirmations from one device count as one affected machine and three distinct opted-in machines count as three.
- [ ] **Surface fleet-relevant issues**
  ujust fleet-status lists only relevant open issues with digest evidence and does not enroll machines without consent.
- [ ] **Keep confirmation escalation truthful**
  The configured 3/5 confirmation priority steps still operate when fleet correlation is disabled or enabled.

## Technical Approach

- Use the existing bonedigger report/confirmation path and common ujust client as separate owners; the source issue still says the bonedigger repo is to be created, which is now stale.
- Threat-model collisions, tracking across users and deletion semantics before accepting any machine-id-derived design; do not treat the old hashed-family phrase as approved implementation.

## Success Metrics

- A multi-machine report yields the correct per-fleet machine count without altering opt-out users’ issue data.

## Non-Goals

- No hostname collection, background enrollment, central telemetry or v1 behavior change.
