---
name: utah-merge-policy
version: "1.0"
last_updated: "2026-11-02"
id: utah-merge-policy
one_line_purpose: Merge routine trusted pin updates to Utah workflows automatically, keep credential changes behind a human.
entry_point: docs/skills/utah-merge-policy.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: ["human-gates"]
tags: [utah, merge, auto-merge, sensitive-path, policy, hive]
description: >-
  The bounded policy for when Hive may merge maintenance PRs that touch sensitive
  paths in the Utah and utah-packages repos. Use to decide whether a trusted
  pin-only update can merge unattended or a credential change stays held.
metadata:
  type: policy
---

# Utah Sensitive-Path Merge Policy

## Contents
- [Overview](#overview)
- [Repositories and paths in scope](#repositories-and-paths-in-scope)
- [The two lanes](#the-two-lanes)
- [Conditions for the automated lane](#conditions-for-the-automated-lane)
- [Rejection and escalation](#rejection-and-escalation)
- [Hold and path policy must agree](#hold-and-path-policy-must-agree)
- [Deployment owner and where the config lives](#deployment-owner-and-where-the-config-lives)
- [Relationship to the Merge Gate](#relationship-to-the-merge-gate)

---

## Overview

Some pull requests change files that control how an image is built, released,
promoted, or secured — workflows, ownership lists, security and Hive config. A
user cares about these because a bad change can break every downstream variant or
open a security hole.

Historically every such change in the Utah repositories needed a person to merge
it by hand, even when the change was a boring, trusted, one-line version bump.
That created a permanent "manual merge" lane: a trusted update would sit on hold
forever waiting for a maintainer, even though it was safe.

This policy replaces "everything sensitive is always manual" with two lanes:

1. **Automated lane** — a routine, trusted, pin-only update passes review, CI,
   and a soak, then Hive merges it unattended. No repeated human merge.
2. **Human-gated lane** — a change that adds or changes permissions, credentials,
   or trust boundaries stays blocked until a maintainer independently authorizes
   it. This lane never auto-merges.

The goal is simple: stop making people merge safe version bumps, while keeping a
human on anything that could raise privileges or weaken verification. Do **not**
read this as "remove the hold and let everything through". The hold stays for the
second lane. This only opens a narrow automated lane for the first.

## Repositories and paths in scope

| Repository | What it is |
|---|---|
| `projectbluefin/utah` | Builds and releases the Utah image. |
| `projectbluefin/utah-packages` | Package set consumed by Utah. |

**Sensitive paths** are the files whose contents control build, release,
promotion, ownership, or security. Examples (not exhaustive):

- `.github/workflows/*.yml` — build, execute-release, promote-testing-to-main, sync-main-to-testing
- `OWNERS` and any approver/ownership list
- Hive and `auto_merge` configuration (including `auto_merge.human_merge_paths`)
- Security, signing, attestation, and provenance config

This policy governs **pull requests that touch those paths**. Ordinary file
edits and non-sensitive changes follow the normal review flow.

## The two lanes

Every sensitive-path pull request is classified into exactly one lane.

### Lane 1 — Automated (routine pin-only)

A change that only **bumps a pinned reference to a new, reviewed, green commit**
and changes nothing else. The classic case is a Renovate/mergeraptor update of a
shared actions digest (for example `projectbluefin/actions` `d0abf89 → cbf1ce0`)
that touches build and release workflows.

Such a change is merged by Hive without a human merge once every condition in
[The automated lane](#conditions-for-the-automated-lane) is met.

### Lane 2 — Human-gated (permission / credential / trust-boundary)

A change that **adds or alters who can do what, or how something is verified**:

- adding or removing an approver, owner, or team
- changing approval rules, merge settings, or branch protection
- adding a repository, third-party source, secret, key, or signing method
- changing cosign/SBOM/provenance/attestation logic
- anything that raises privileges or moves a trust boundary

Lane 2 **always** stays held and requires an independent human decision. This
policy does not widen it, and removing the `hold` label on a Lane 2 change does
not merge it — the change must be authorized on its own merits.

## Conditions for the automated lane

A pull request qualifies for the automated lane only if **all** of these are true:

1. **Authenticated, trusted author.** The author is an allow-listed bot or
   identity (for example the `mergeraptor` release bot or Renovate). Unauthenticated
   or unlisted authors never qualify, even for pin-only changes.
2. **Exact-head diff.** The commit that is about to merge is exactly the commit a
   reviewer looked at. No force-push, rebase, or edit after review. Hive checks
   that the review head matches the merge head before merging.
3. **Allowed update class.** The change is a pure pin/digest/bump. It adds no new
   logic, no new files, no new paths, and no new steps to the workflows it touches.
   If the diff does anything beyond the pinned reference, it is Lane 2.
4. **Required CI green.** Every required check for the changed workflows passes
   (build, release, promotion, lint). CI is not skipped or waived.
5. **Soak.** The change sits for the configured soak window with no regressions,
   so a bad bump is caught before it propagates to every downstream variant.
6. **Review clean.** Hive review reports no findings, or a human has approved it.
   A heuristic finding (for example "touches sensitive paths") is acceptable only
   when the author is trusted and the change is classified as Lane 1.

If any condition is unmet, the pull request stays in Lane 2.

## Rejection and escalation

Hive rejects (does not merge) and escalates when:

- the author is not on the trusted allow-list,
- the head does not match the reviewed diff,
- the change goes beyond the allowed update class,
- CI is not fully green,
- the soak is incomplete, or
- review reports a finding that is not cleared.

Escalation means: keep the `hold` label, record the reason in a comment, and leave
the decision to a maintainer. Hive does not guess past this.

## Hold and path policy must agree

The `hold` label and the sensitive-path policy must never contradict each other:

- **Removing `hold` is not a policy.** Clearing the label on a Lane 2 change does
  not redefine the automated lane and must not silently re-add or remove a manual
  gate by the back door.
- **The lane is defined here, not by absence of a label.** The automated lane
  exists because this policy names it and its conditions. It is not created by
  deleting `hold` or by an empty `human_merge_paths` list.
- **A reviewer "remove hold" comment is not approval.** A comment suggesting the
  hold be removed does not itself define or widen the automated lane. The change
  must be classified under this policy and meet its conditions.

## Deployment owner and where the config lives

| Item | Owner / location |
|---|---|
| **Policy owner** | `@projectbluefin/maintainers` — the team that owns merge authority in Utah. |
| **Merge config** | Each repo owns its own `auto_merge` / `human_merge_paths` setting (in Utah). `common` documents this policy; it does not hold or edit the merge config in Utah. |
| **Ownership lists** | `OWNERS` in each repo, synced from `projectbluefin/.project` `maintainers.yaml`. Edit there, not in the repo. |

`@projectbluefin/maintainers` deploys and changes the merge configuration in each
Utah repository and can widen or narrow the automated lane. `common` records the
policy so the two repos behave the same way and so a future contributor can find
the rule instead of rediscovering it.

## Relationship to the Merge Gate

This policy is the **scoped exception** to the Merge Gate in
[`human-gates.md`](human-gates.md). The Merge Gate still says "the merge is always
human" as the default. This policy carves out one narrow case — a trusted,
pin-only, reviewed, green, soaked update to a Utah sensitive path — where Hive may
merge unattended. Everything else, especially Lane 2, keeps the Merge Gate fully
in force. Agents still never self-merge, never bypass branch protection, and never
force-push to a protected branch.
