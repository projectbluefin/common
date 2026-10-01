---
created_date: "2026-08-29"
document_status: draft
closed_date: null
---

# Feature: systemd-homed-default

## Overview

Project Bluefin must choose whether systemd-homed becomes the default account model in Dakota, across every Bluefin variant, or remains opt-in. The choice affects login, encryption, upgrades, recovery and family safety; no default change is authorized while this specification is a draft. Sources: [common#1050](https://github.com/projectbluefin/common/issues/1050) and the held [dakota#962](https://github.com/projectbluefin/dakota/pull/962).

## Requirements

- [ ] **Set explicit product scope**
  Maintainers choose Dakota-only, org-wide, or opt-in/defer with an owner and the affected variants named. A pending discussion is not a default.
- [ ] **Define new-account protection and recovery**
  If homed is enabled, maintainers choose the actual storage mechanism and its at-rest protection, and users can create, unlock, and recover their accounts after a key or hardware change.
- [ ] **Protect existing installations**
  Existing non-homed users have a documented and tested migration, coexistence or no-migration path; switching bootc images alone does not change their homes.
- [ ] **Keep rollback possible**
  An upgrade or image rollback cannot silently strand a homed account or lose its data.
- [ ] **Decide the family-safety outcome**
  If `malcontent` and parental-control UI are removed, maintainers choose and document the user-facing replacement or support posture.
- [ ] **Own third-party and build inputs**
  The `gnome-initial-setup` fork has an owner, reviewed pin, upstreaming or review exit condition; a junction tracking bump is separately reviewable.
- [ ] **Prove the supported paths**
  Testsuite, lab and product owners demonstrate user creation, login, recovery, upgrade/rollback and supported multi-user behavior before any default changes.

## Constraints

- **Human approval is required.** The Design, Security and Breakage gates still apply; dakota#962 cannot leave `4-review` until maintainers accept a final specification and the affected repository's checks pass. No agent decides the account model from this draft.
- An image change does not migrate `/home/<user>`. Existing plain homes and any new homed homes may coexist; rollback to an image without homed support may strand them. The upgrade contract must cover both.
- Loss of the only passphrase or TPM PCR drift without another unlock method can cause lockout. The default unlock and recovery story must be approved before first-boot behavior changes.
- `malcontent` is a shipped family-safety feature. Removing it without an explicit product and support decision is a regression, not an implementation detail.
- A forked `gnome-initial-setup` and third-party code require supply-chain review. Do not tie a gnome-build-meta `gnome-50`→`master` junction bump to the account-model decision in one PR.
- This specification is the sole planning record for the choice; evidence may link to source code, upstream changes and tests, but no parallel approval record determines scope.
- A PR that re-opens this decision after maintainer sign-off must link this specification and state which decision item it invalidates.

## Acceptance Criteria

- [ ] **Scope and ownership recorded**
  A maintainer has selected one of the options below, named every affected variant, and recorded approval here with its date and rationale; dakota#962 links the reviewed version.
- [ ] **New account protection and recovery are proven**
  If homed ships, a fresh-install test inspects the selected storage mechanism, verifies the promised at-rest protection, unlocks the home, and recovers after the primary unlock fails. If deferred, the supported account default remains unchanged and is verified.
- [ ] **Existing account outcome verified**
  A test of a pre-change installation shows whether that user's plain home is migrated, offered migration, or intentionally left unchanged; mixed-model login and data access work when permitted.
- [ ] **Rollback evidence exists**
  A lab test boots the chosen upgrade and rollback paths and proves the user can still unlock or recover the same home and data.
- [ ] **Family-safety choice shipped consistently**
  Product copy, package set, and the three affected GNOME app surfaces reflect the approved parental-controls stance, with support guidance for families and shared machines.
- [ ] **Fork and junction decisions are auditable**
  The fork's pinned source, owner and exit condition are documented and checked; the junction bump is a separate reviewed change.
- [ ] **End-to-end gates pass**
  Testsuite and lab evidence covers the supported scenarios on the exact image digest before promotion, and no required human approval has been bypassed.

### Maintainer decision (maintainers fill in)

| Field | Value |
|---|---|
| **Decision** | _pending_ |
| **Scope** | _pending_ (Dakota-only / org-wide) |
| **Decider** | _pending_ |
| **Date** | _pending_ |
| **Unlock configuration & recovery story** | _pending_ (see Constraints) |
| **Upgrade path for existing users** | _pending_ (see Acceptance Criteria) |
| **Parental-controls stance** | _pending_ (see Acceptance Criteria) |
| **Conditions / exit criteria** | _pending_ |

## Technical Approach

The options remain **unselected** until a maintainer decides:

| Option | Product effect | Cost to examine |
|---|---|---|
| Dakota-only default | Dakota diverges on account model; other variants keep traditional homes | Dakota-specific upgrade, recovery and support paths |
| Org-wide default | All variants, including LTS, adopt the model | Upgrade and rollback for every existing install and image stream |
| Opt-in or defer | Traditional accounts remain the default | Define the opt-in story, or retain the current system pending upstream work |

The held PR combines `accountsservice -Dcreate_homed=true`, `DefaultStorage=subvolume`, a forked first-boot user-creation path, removal of `malcontent`/parental-controls UI, and a gnome-build-meta junction bump. **`subvolume` alone does not encrypt a home**: the [upstream storage reference](https://github.com/systemd/systemd/blob/main/docs/HOME_DIRECTORY.md) describes it as a plain btrfs subvolume, whereas `luks` and `fscrypt` provide distinct encrypted mechanisms. A maintainer must choose and test the actual storage mechanism before claiming per-home encryption. A first-boot offer, manual conversion, and fresh-install-only support have different consequences for existing users; check the current state of `gnome-build-meta!2681` before relying on it.

The threat model includes encryption-at-rest claims, passphrase loss, TPM-bound unlock drift, btrfs behavior, AccountsService interaction, and the consequences for backups and shared machines. Family-safety options are to retain `malcontent` opt-in, document an accepted gap, review a third-party bundle, or build/adopt a replacement. None is authorized by listing it here; the prior source evidence remains in Git history. Source: [systemd user-record documentation](https://github.com/systemd/systemd/blob/main/docs/USER_RECORD.md).

## Success Metrics

- Every variant covered by the chosen scope has an observable install, login, recovery and rollback result, not merely a passing build.
- Support can state the effect on existing homes and parental controls without a private maintainer explanation.
- The default is not changed until the owner has accepted this specification and the exact-digest tests have passed.

## Non-Goals

- Selecting an account model on behalf of maintainers or interpreting the old PR's existence as approval.
- Bundling the unrelated junction tracking bump with the default change.
- Silent conversion of existing homes, removal of family-safety features without a decision, or claiming a bootc rollback can unlock an unsupported homed home.
