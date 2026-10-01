---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-82796046-bluespeed-custom-build-dashboard

## Overview

Contributors can start an OS image build and see the resulting images and build history from Bluespeed without replacing Argo Workflows or Zot. The panel exposes supported build paths while leaving detailed logs in the owning Argo UI. Source: [bluespeed#30](https://github.com/projectbluefin/bluespeed/issues/30).

## Requirements

- [ ] **List available images**
  Users can see built OCI images with latest digest and build time from Zot.
- [ ] **Show build history**
  Recent Argo workflows show state, duration and a working link to their detailed logs.
- [ ] **Trigger a new build**
  Contributors can submit a supported BuildStream, BlueBuild recipe or Containerfile input.
- [ ] **Respect path differences**
  BuildStream-from-source, BlueBuild/Fedora bootc and Containerfile/Fedora or CentOS have distinct base/input requirements.

## Constraints

- Do not reproduce Argo’s log UI or replace Zot; the panel shows status and triggers only.
- Closed pipeline issue #31 is evidence to inspect, not proof every build path is currently runnable; recipe source decision #34 remains a dependency.

## Acceptance Criteria

- [ ] **List available images**
  My Images agrees with Zot’s OCI catalog and a selected image offers the existing push-to-fleet action.
- [ ] **Show build history**
  A successful, failed and in-progress workflow appears with its real state and opens the matching Argo UI run.
- [ ] **Trigger a new build**
  Each available input launches the existing authorized Argo build path and reports its run ID or error.
- [ ] **Respect path differences**
  A user can select only a supported base for the chosen path; unsupported inputs are not advertised as ready.

## Technical Approach

- Read image metadata from Zot’s OCI catalog API and build status from Argo Workflows; provide a prominent contributor BlueBuild link.
- BuildStream is the first reference path in the original issue; gate other paths on actual pipeline availability.

## Success Metrics

- A contributor can trigger an image, observe its workflow and locate the immutable output digest without leaving the golden path except for logs.

## Non-Goals

- No new registry, custom workflow engine or duplicate Argo log viewer.
