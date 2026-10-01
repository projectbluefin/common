---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-281bfa04-contribute-fsdk-drop-in-image

## Overview

Hive can use a narrow FSDK-derived contributor image as a drop-in for selected work only after the actual published artifact and runtime path are proven. This issue is not ready for automated pickup until admission and deployment owners settle their prerequisites. Source: [contribute#421](https://github.com/projectbluefin/contribute/issues/421).

## Requirements

- [ ] **Preserve auditable source identity**
  The contributor artifact derives from FSDK and uses the pinned upstream Hive checkout and runtime.
- [ ] **Publish a qualified artifact**
  The selected native platforms publish an OCI image whose digest and contents can be read back from the registry.
- [ ] **Execute supported work through the real launcher**
  Auth/preflight, Hive assignment, worker execution, completion, cancellation, cleanup and foreground lifecycle work from the published image.
- [ ] **Respect unresolved owner choices**
  The image cannot be marked ready until admission #169 and distribution #468/semantics #167 have approved roles and runtime target.

## Constraints

- Classification remains NOT READY; do not manufacture agent queue admission or a test-only child.
- Do not conflate image/Containerfile source presence with a shippable artifact; refresh the Hive pin affected by Renovate #484.
- No new tokens, universal maintainer image, OMP replacement, second launcher/scheduler or fork of Hive.

## Acceptance Criteria

- [ ] **Preserve auditable source identity**
  Source and immutable artifact hashes are recorded and agree with the pinned scripts in the built image.
- [ ] **Publish a qualified artifact**
  Build receipt, published registry digest, runtime identity and expected platform entries agree exactly.
- [ ] **Execute supported work through the real launcher**
  For each supported path, a real launcher run reaches the expected state; fake source-only tests are not delivery evidence.
- [ ] **Respect unresolved owner choices**
  The selected deployment/profile decision is recorded and #169/#468/#167 dependencies are met before the image is offered to Hive.

## Technical Approach

- Use existing image/Containerfile, published ghcr.io/projectbluefin/review-contributor and the supported contributor launcher; owner #468 handles distribution and #167 handles selected backend semantics.
- Any missing artifact or execution case is identified after the distribution target is selected; prefer existing image/audit contracts.

## Success Metrics

- The same immutable digest passes artifact and real runtime conformance gates before promotion.

## Non-Goals

- No automated pickup before #169 or new container/backend semantics beyond the FSDK drop-in contract.
