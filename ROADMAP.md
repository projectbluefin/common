# Project Bluefin Roadmap

> **Status: DRAFT — hold-gated planning artifact.** Filed by the strategist agent for
> human review. Nothing here is committed direction until a maintainer adopts it.
> Tracking issue: #957.

This document is a single view across the Project Bluefin org
(11 repos, 4 product lines) so contributors, users, and agents can see what
matters now, what comes next, and what is explicitly parked.

## Product lines at a glance

| Product | Repo | State | Update health (2026-08-07) |
|---|---|---|---|
| Bluefin (flagship, rolling) | `bluefin` | Production | **`:stable` frozen since 2026-07-20** — GNOME 50 smoke gate (#929, #989, #995, #1025) |
| Bluefin LTS | `bluefin-lts` | Production | Healthy — daily `:stable` promotions |
| Dakota (GNOME OS, from source) | `dakota`, `dakota-iso` | **Alpha** | Active; user feedback loop producing issues daily |
| Bluefin Server | `server` | Early | Architecture roadmap lives in `server/docs/skills/architecture-roadmap.md` |
| Shared layer | `common` (this repo) | Production | OCI layer for every image; very active |
| Tooling | `bluefinctl`, `finpilot`, `actions`, `testsuite`, `fsdk-containers` | Various | — |

## Now (next ~30 days)

1. **Unfreeze Bluefin `:stable`.** The GNOME 50 smoke gate has failed since
   2026-06-25. Either the gate gets fixed or a risk-accepted manual promotion
   happens — but the project needs the *decision*, not just more CI debugging.
   See #955 (release-gate stall policy) and the CI issues above.
2. **Land Dakota adoption telemetry.** The privacy-preserving weekly countme
   client (PR #807) has been in review since 2026-07-01. Alpha prioritization
   is currently blind to install-base size and growth. See #956.
3. **Keep Dakota's feedback loop fed.** The `ujust report/confirm/verify` loop
   is the product differentiator; user-filed alpha issues (audio, LUKS
   keyboard layout, WiFi regdb, GVFS playback) need triage velocity more than
   new features.

## Next (1–2 quarters)

1. **Dakota install path + upgrade hardening.** The README lists installation
   and upgrades/rollbacks as the known gaps; both block a beta label.
2. **Dakota aarch64 bring-up.** Qualcomm x13s service failures on
   non-Qualcomm hardware (dakota#1193) and aarch64 boot-test gaps
   (dakota#1306) are the visible edge of the ARM story.
3. **Bluefin Server definition.** Grow the server architecture roadmap into a
   user-facing "what is Bluefin Server" story.
4. **Review-bandwidth relief.** Multiple PRs in `common` have waited 5+ weeks
   in `4-review` (#805, #807, #808). Consider widening the reviewer pool or
   explicit review SLAs for agent-authored PRs.

## Later (long-term bets)

1. **Sealed images / verified boot** (bluefin#11). systemd-boot + signed UKI +
   composefs, targeting TPM-backed passwordless disk unlock. **Decision
   needed:** the epic has had no checklist progress since 2026-05-30 and the
   Fedora version skew is growing (Bluefin defaults to F42; sealed upstream
   publishes F44/45). Staff the `next`-branch spike or explicitly shelve it —
   either answer is fine, drifting is not.
2. **TPM-backed disk unlock** — the user-facing payoff of the sealed-images
   bet; blocked on it.

## Explicitly parked / accepted risks

- Bluefin `:stable` gate policy — until #955 lands, promotions during gate
  stalls are ad hoc (see #995 for what that looks like in practice).
- `common` carries 15 pre-existing test failures on main (#946) — accepted
  noise that reduces signal for new failures.

## How to use this document

- **Contributors:** pick from *Now* first; Dakota's queued issue queue is the
  agent-ready entry point.
- **Maintainers:** this doc should be revisited monthly; the strategist agent
  will propose updates as hold-gated PRs.
- **Users:** "Which image should I run?" — Bluefin LTS for stability today,
  Bluefin once `:stable` unfreezes, Dakota if you want to help shape the alpha.

---
*Drafted by the strategist agent (ACMM L5 — hold-gated mode). Human review
required before this becomes canonical.*
