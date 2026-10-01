---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-69b688c8-fsdk-distroless-catalog-pattern

## Overview

Maintainers can add FSDK-based distroless OCI images for upstream projects with less repeated work and provable supply-chain benefit, rather than writing a bespoke element tree for each binary. One end-to-end exemplar establishes the pattern; the rest of the catalog expands only after its marginal cost is demonstrated. Source: [fsdk-containers#113](https://github.com/projectbluefin/fsdk-containers/issues/113).

## Requirements

- [x] **Establish catalog selection**
  Candidate images are chosen for proven provenance benefit over traditional distro-based final images and excluded if already equivalently distroless.
- [x] **Set a reproducible shared base**
  Every catalog image builds from one reviewed FSDK pin rather than one branch or version pin per image.
- [ ] **Prove source builds**
  The exemplar builds a real upstream binary from source with the correct FSDK/BuildStream lane and non-root runtime.
- [ ] **Collapse marginal integration cost**
  Adding another image needs one reviewed catalog record and generated shared wiring rather than eight hand-edited paths.
- [ ] **Respect org-wide CI capacity and prove provenance**
  Catalog growth stays within the 60-job org-wide concurrency ceiling, not merely GitHub Actions' 256-job matrix limit; published image SBOMs demonstrate FSDK lineage.
- [ ] **Prioritize measured candidates**
  High-impact CNCF and AI/ML images are selected from current measured evidence rather than asserted size wins.

## Constraints

- Size delta against upstream is reported, not used as a hard per-image gate; regression against a prior project build is a separate signal.
- Prefer source builds over prebuilt binary import; non-root identity is inherited consistently rather than reimplemented for every image.
- Catalog images run as numeric `65532:65532` with `/etc/passwd` and `/etc/group` entries (per-image overrides go through #119's `user` field). Inspect image-config User and smoke-test with `podman --passwd=false`: Podman's default synthetic passwd entry can otherwise hide an image that fails in a restricted Kubernetes pod.
- Do not require 20 images merged to declare the pattern successful; decisions must be settled before N+1 is added.
- Do not promise specific stable/beta dates from the old issue without checking current FSDK pin and consumer requirements.

## Acceptance Criteria

- [x] **Establish catalog selection**
  The closed #114 audit maps candidates to upstream final bases; accepted/excluded decisions cite source evidence.
- [x] **Set a reproducible shared base**
  Closed #125/#126 decisions supply the version boundary; an image rebuild can name its exact FSDK source.
- [ ] **Prove source builds**
  Open #123 builds Cloud Custodian end-to-end; the first go_module use passes before dependent catalog images.
- [ ] **Collapse marginal integration cost**
  After #123/#118/#119, an additional c7n rider adds one record, generated output is stable, and just verify is unchanged for existing images.
- [ ] **Respect org-wide CI capacity and prove provenance**
  At about 11 images (five jobs per image before batching), jobs are sharded into batches of 10 with a measured scheduling budget; open #128 ties the published digest to FSDK provenance.
- [ ] **Prioritize measured candidates**
  Open #124 records candidate base/provenance/size measurements and defers JVM/eBPF lanes lacking evidence.

## Technical Approach

- BuildStream 2 and freedesktop-sdk via oci-builder are the existing seams. The source map shows only curl/go already have FSDK components; tarball, go_module and JVM are distinct lanes.
- Closed #114–#122, #125–#127 and #130 capture selection, schema, CI and base decisions; open #123 exemplar, #124 priority and #128 provenance remain. #115 decided go_module but the old issue records zero actual uses; prove it before using it as a standard.
- The source has `buildstream-plugins-community` junctioned at `project.conf:61-66` but only `git_repo` and `patch_queue` enabled; `go_module` is not yet enabled or proven here. Build the source-build lane and exercise one real upstream module before making it a catalog convention.
- The source maps eight per-image touchpoints (element tree, targets.json, Justfile and oci-images.yml); the generator removes shared-file hand edits before parallel catalog additions.
- Closed source decisions: [#114 base audit](https://github.com/projectbluefin/fsdk-containers/issues/114), [#115 go_module source](https://github.com/projectbluefin/fsdk-containers/issues/115), [#116 static tier](https://github.com/projectbluefin/fsdk-containers/issues/116), [#117 exemplar](https://github.com/projectbluefin/fsdk-containers/issues/117), [#118 catalog record](https://github.com/projectbluefin/fsdk-containers/issues/118), [#119 generated wiring](https://github.com/projectbluefin/fsdk-containers/issues/119).
- More settled decisions: [#120 non-root](https://github.com/projectbluefin/fsdk-containers/issues/120), [#121 SBOM/Cosign gap](https://github.com/projectbluefin/fsdk-containers/issues/121), [#122 merge contract](https://github.com/projectbluefin/fsdk-containers/issues/122), [#125 FSDK line](https://github.com/projectbluefin/fsdk-containers/issues/125), [#127 CI scale](https://github.com/projectbluefin/fsdk-containers/issues/127).
- #127's measured constraint is 5 jobs per image and a 60-job concurrency ceiling shared across the org, reached around 11 images. Shard from `targets.json` in batches of 10 (`jobs = 5 × ceil(N/10)`), re-evaluate the batch when one image exceeds the measured runtime budget, and batch `publish-smoke` first. It is not a 256-job matrix problem.
- Remaining execution: [#123 exemplar](https://github.com/projectbluefin/fsdk-containers/issues/123), [#124 AI/ML and CNCF priorities](https://github.com/projectbluefin/fsdk-containers/issues/124), [#128 FSDK SBOM provenance](https://github.com/projectbluefin/fsdk-containers/issues/128). Closed decisions do not establish that the published artifact or provenance gate already passes.
- Keep the source’s measured FSDK components/tarball/go_module/JVM lanes distinct: Cloud Custodian is the exemplar; later c7n riders measure marginal cost. Falco/eBPF, OpenSearch/JRE, multi-runtime images, CVE/attestation scale and upstream-version tracking remain evidence gaps, not implicit deliverables of the first exemplar.

## Success Metrics

- By the c7n rider batch, an additional image requires one reviewed catalog record plus generated files, not an eight-file manual sweep.
- The exemplar’s published digest and SBOM prove reproducible, non-root FSDK lineage.

## Non-Goals

- Do not replicate static images already on scratch, ko, Chainguard/Wolfi or equivalent distroless bases without new evidence.
- No branch per FSDK version, blanket 250-image promise, or hard absolute size limit.
