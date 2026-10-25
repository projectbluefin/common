---
name: review-appliance
version: "1.1"
last_updated: "2026-09-13"
id: review-appliance
one_line_purpose: Operate and integrate the Bluefin Review appliance and Hive worker.
entry_point: docs/skills/review-appliance.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: [apptainer-sif, pr-review, hive]
tags: [review, appliance, dashboard, hive, contribute]
description: >-
  Operate and integrate the projectbluefin/review appliance and Hive worker.
  Use when running `bluefin review`, using the review-queue dashboard, or
  configuring contributor worker images.
metadata:
  type: reference
---

# Bluefin Review Appliance

`projectbluefin/review` is the dedicated Bluefin review appliance and Hive
contributor worker repository. It bridges the human maintainer review process
and automated agent toil reduction.

## Purpose and Architecture

The appliance provides two distinct modes:

1. **Maintainer Review Surface (`review-queue` / `bluefin review`):**
   A keyboard-driven terminal dashboard (built with Textual) that unifies
   live GitHub pull request dossiers, check rollups, CI failure logs, and
   audit actions into one interface. OMP is the default review backend; Codex
   is an alternate.
2. **Hive Contributor Worker (`contribute` / `bluefin-contribute`):**
   An isolated worker container executing Hive-assigned tasks under the
   contributor's identity. Hive remains the sole assignment and completion
   authority. Opening the maintainer dashboard never starts a contributor worker.

## Packaging and Distribution

The appliance is distributed via multiple surfaces:
- **Homebrew Formula:** `brew install ublue-os/experimental-tap/bluefin-contributor-tools`
  puts `bluefin` (with `review` and `contribute` subcommands) and
  `bluefin-contribute` on `PATH` in the Homebrew prefix. There is no
  `bluefin-review` executable — that string is only a directory name
  (`image/extension/bluefin-review/`) and a state path
  (`~/.local/state/bluefin-review/`). The formula builds from
  `github.com/projectbluefin/review` branch `omp-port`, not `main`. None of
  these paths exist in `projectbluefin/common`.
- **Apptainer SIF:** `bluefin-review.sif` and `bluefin-contribute.sif` run
  unprivileged via Apptainer with isolated temporary state (`--writable-tmpfs --no-home`).
  See [`apptainer-sif/SKILL.md`](apptainer-sif/SKILL.md).
- **Distroless OCI Images:** Published to GitHub Container Registry:
  - `ghcr.io/projectbluefin/review:stable` (distroless review appliance)
  - `ghcr.io/projectbluefin/review-contributor:stable` (contributor dashboard + worker)
  - `ghcr.io/projectbluefin/contribute:stable` (isolated Hive + OMP worker)

## Operating Principles and Disciplines

1. **Live State Over Static Snapshots:**
   `projectbluefin/review`'s own `.github/copilot-instructions.md` states it
   directly: "The PR queue is live GitHub/Hive evidence … never create or
   consume a static queue snapshot." The appliance queries GitHub and Hive
   live.

   The review Pages pipeline does publish a static feed at
   `https://projectbluefin.github.io/review/queue.json`, and
   `https://queue.projectbluefin.io/` 301-redirects to it — but
   `https://queue.projectbluefin.io/queue.json` returns 404, so never append
   `/queue.json` to that hostname. The feed is **not authoritative**: its
   `generated_at` was 7 days stale when last checked on 2026-09-13. It is a
   cheap first-pass source list at best; verify every item live.
2. **Human Decides, Agent Implements:**
   The dashboard prepares review drafts, diffs, and verification context.
   Approval, merge, and closing actions require explicit human confirmation.
3. **Strict Credential Hygiene:**
   Tokens (`GH_TOKEN`, `GITHUB_TOKEN`, Copilot tokens) pass via inherited process
   environment variables, never as command-line arguments (`--env KEY=val`),
   which leak secrets to `/proc` and `ps`.
4. **No Lab Dependencies:**
   The review appliance owns no cluster or lab and depends on none. A check that
   cannot run falls back to published registry evidence; the absence of evidence
   is recorded as a finding, never as a blocked PR. An optional host-side
   `review-lab-broker` can be explicitly enabled by maintainers for QA dispatch.
5. **Latest Upstream Everywhere & Forward Fixes:**
   Base images and tool pins track upstream. Pins advance automatically via
   Renovate; breaking changes are fixed forward, not held behind manual review gates.
6. **No Grandfathering or Doc-Buried Gaps:**
   Defects and gaps are filed as GitHub issues with clear close criteria, never
   excused as "legacy exceptions" or buried in documentation prose.

## Core Commands

```bash
# Maintainer review via the Homebrew CLI
bluefin review

# Launch review dashboard from a projectbluefin/review checkout
just review-queue

# Run isolated contributor worker
CONTRIBUTE_IMAGE=ghcr.io/projectbluefin/contribute:stable just contribute

# Verify review appliance contracts
just review-doctor
```

## References

- Repository: `https://github.com/projectbluefin/review`
- SIF Architecture: [`apptainer-sif/SKILL.md`](apptainer-sif/SKILL.md)
- Backlog Review: [`pr-review/SKILL.md`](pr-review/SKILL.md)
- Hive Coordination: [`hive.md`](hive.md)
- Factory Model: [`../factory/agentic-model.md`](../factory/agentic-model.md)
