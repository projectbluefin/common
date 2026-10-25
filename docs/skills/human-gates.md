---
name: human-gates
version: "1.1"
last_updated: "2026-09-13"
id: human-gates
one_line_purpose: Decide when to stop for Design, Security, Breakage, or Merge review.
entry_point: docs/skills/human-gates.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [gates, approval, security]
description: >-
  The four human decision gates — Design, Security, Breakage, and Merge —
  when an agent must stop and request human input. Use when uncertain whether
  a change requires human review, or to verify evidence requirements before
  opening a PR.
metadata:
  type: reference
---

# Human Decision Gates

Agents implement autonomously **except** at these four gates. At each gate, stop work and request human input explicitly. Never guess past a gate.

## Contents
- [The Four Gates](#the-four-gates)
- [How to Signal a Gate](#how-to-signal-a-gate)
- [Verification Evidence Requirement](#verification-evidence-requirement)
- [When in Doubt](#when-in-doubt)

---

## The Four Gates

### 1. Design Gate

**Stop when:** You are about to make an architecture change, introduce a new subsystem, or change behavior that is visible to users.

Examples:
- Changing how images are built or composed
- Adding a new pipeline stage or automation system
- Changing defaults that affect what users see or can do
- Restructuring the repo layout or CI model

**Action:** Describe your proposed design clearly: what you're proposing, why, and what you're uncertain about. Ask for human approval before writing code or opening a PR.

---

### 2. Security Gate

**Stop when:** Your change touches authentication, signing, supply chain, secrets handling, or third-party package sources.

Examples:
- Adding a new COPR repo or third-party RPM source
- Changing cosign or SBOM logic
- Adding or modifying secrets in workflows
- Changing how packages are verified or pinned
- Any change to the signing or attestation pipeline

**Action:** Describe exactly which security property is affected and what your proposed approach preserves or changes. Ask for explicit human approval before opening any PR. Security changes require maintainer review regardless of how minor they appear.

---

### 3. Breakage Gate

**Stop when:** Your change removes or renames a public input, changes a default that consuming repos depend on, or could break `bluefin`, `bluefin-lts`, `dakota`, or `iso`.

Examples:
- Renaming or removing a workflow input used by downstream callers
- Changing a system file path that other scripts reference
- Modifying `projectbluefin/actions` in a way that could break consumers
- Changing a dconf key or GSettings schema that affects downstream images

**Action:** Identify all affected consumers before opening the PR. List them in the PR description. Confirm no consumer will silently break. If cross-repo coordination is needed, note that explicitly.

> ⚠️ All four consumers break differently. `bluefin` and `bluefin-lts` pull this layer as a build stage (`COMMON_IMAGE`), so a broken `system_files/shared/` change breaks both images on their next build. `iso` clones the repo for Brewfiles. `dakota` consumes it as a pinned git source through BuildStream (`elements/bluefin/common.bst`) and carries two local patches against this repo (`patches/common/0001-fastfetch-install-date.patch`, `0002-ghostty-dual-theme.patch`) — a `Containerfile` grep will not reveal that dependency, and changes to the fastfetch layout or Ghostty theming can break `dakota`'s build without touching anything it owns. `system_files/shared/` is no longer bound to the `aurorafin-shared` submodule; that dependency was severed (see `submodule-boundary.md`), so do not assume an automatic Aurora path either way.

---

### 4. Merge Gate

**Stop when:** Your PR is ready for final review and merge.

This gate is enforced by GitHub, not by convention. The `main` ruleset
requires **two** approving human reviews and three green required checks
(`validate`, `Build and push image (x86_64)`, `Build and push image
(aarch64)`), and merges run through the merge queue. There are no bypass
actors, so no agent and no maintainer can skip it. Full parameters:
[governance.md](governance.md#how-main-is-protected).

Agents never self-approve and never self-merge. `--admin` requires an explicit
human instruction for that specific PR.

Note that `require_code_owner_review` is `false`: a CODEOWNERS match assigns a
reviewer but is not one of the two required approvals.

---

## How to Signal a Gate

When you hit a gate:

1. Stop. Present what you've done (branch, diff) and what decision is needed — do NOT open a PR yet.
2. Describe the gate clearly:
   ```
   Hitting the Security Gate — need human approval before opening a PR.

   Proposed change: [describe it]
   Security property affected: [what it is]
   My approach: [what you're proposing]
   Alternative approaches: [if any]
   ```
3. Apply the `blocked` label to the related issue and, in the same comment,
   name the exact decision or dependency you are waiting on. A `blocked`
   label without that sentence is not a signal — see
   [label-workflow.md](label-workflow.md#agent-rules).
4. Wait for explicit human approval before opening a PR.

---

## Verification Evidence Requirement

Before removing draft status and requesting formal review, both of these must
be true:

- [ ] CI is passing — link the run in the PR description.
- [ ] If no automated test covers the change, describe how you verified it by
      hand.

The PR title, commit trailers, and skill-doc requirements are in
[`.github/pull_request_template.md`](../../.github/pull_request_template.md)
and `AGENTS.md`. A PR without evidence is not ready.

---

## When in Doubt

If you are uncertain whether something hits a gate — it does. Describe what you're doing and what you're uncertain about, and ask. A short human answer costs less than a wrong implementation. Do not open a PR speculatively.
