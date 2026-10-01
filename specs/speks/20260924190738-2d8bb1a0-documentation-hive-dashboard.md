---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-2d8bb1a0-documentation-hive-dashboard

## Overview

People visiting Bluefin’s Hive pages can distinguish issue triage, contributor/community health and agent activity without decoding one overloaded dashboard. The split must preserve links to underlying GitHub issues and PRs and fit the site’s Docusaurus navigation. Source: [documentation#1003](https://github.com/projectbluefin/documentation/issues/1003).

## Requirements

- [ ] **Give issue triage its own overview**
  The default Hive view shows received, handled and resolved issues with useful filters and links to their source issues.
- [ ] **Show community and factory signals separately**
  A community view exposes meaningful repo/contributor progress, issue velocity, releases and system health.
- [ ] **Separate agent operations**
  A factory view shows governor/floor health, agent PRs, work queue, trends and formation history for maintainers.
- [ ] **Support legible site navigation**
  The resulting pages work in light and dark mode and blend into Docusaurus instead of adding another crowded card wall.
- [ ] **Keep PR-to-issue traceability**
  Merged PR listings link to their issue when one exists; missing links remain visible as an exception, not fabricated.

## Constraints

- The dashboard reads authoritative GitHub/Hive data; it does not change issue routing, labels or project board state.
- Do not copy another company’s triage state machine or redesign GitHub issues inside the docs site.

## Acceptance Criteria

- [ ] **Give issue triage its own overview**
  A reader can find the current triage state and open the corresponding issue without scanning agent and community cards.
- [ ] **Show community and factory signals separately**
  Community metrics and org health have documented source data and no duplicate leaderboard cards.
- [ ] **Separate agent operations**
  Maintainers can distinguish agent activity from user-facing issue progress and reach the underlying task or PR.
- [ ] **Support legible site navigation**
  Desktop and narrow viewport inspection shows readable hierarchy, accessible links and correct light/dark theming.
- [ ] **Keep PR-to-issue traceability**
  An issue→PR→merge path can be followed end-to-end without inferring state from a fake dashboard label.

## Technical Approach

- The source issue contains current screenshots and inspiration from Warp and Release.bar; use them as comparison, not a specification of Bluefin states.
- Prioritize the issue flow for users, community signal for contributors and factory execution for maintainers; avoid duplicating existing Docusaurus navigation.
- Source screenshots of the current Hive page: [1](https://github.com/user-attachments/assets/34299ac6-4c35-41e5-b7cf-3569227d8d66), [2](https://github.com/user-attachments/assets/e892372f-68b5-4333-8b65-635ab643243c), [3](https://github.com/user-attachments/assets/0e9e4b1f-86b1-4d02-8eb9-ea98a371e796), [4](https://github.com/user-attachments/assets/cedaf19e-4223-47a6-bb76-d208c34b7b50), [5](https://github.com/user-attachments/assets/6ee6abff-aa2f-4594-a939-30eb402d1925).
- Inspiration screenshots: [Warp overview](https://github.com/user-attachments/assets/a256136e-5635-44c4-8134-b5a8beab34e6), [Warp community](https://github.com/user-attachments/assets/d760ef1c-f02a-415d-9cc5-b5e605390a9d), [Release.bar organization](https://github.com/user-attachments/assets/516add09-0cff-401c-bc7a-db8b101aa8e4), [repo](https://github.com/user-attachments/assets/a1e304cb-eca0-448b-89ab-988b10dce9a9), [dashboard](https://github.com/user-attachments/assets/50535f1b-71d0-442f-b11a-689f711520d7).

## Success Metrics

- A first-time reader can find an issue and its resolution path without entering agent-only pages.

## Non-Goals

- No separate GitHub issue wrapper, new workflow labels, or make-believe agent states.
