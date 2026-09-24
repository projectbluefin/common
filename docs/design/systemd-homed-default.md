# Decision Record — systemd-homed by Default

**Status:** `OPEN` — pending maintainer decision (Design Gate, [`docs/skills/human-gates.md`](../skills/human-gates.md))
**Decision owner:** `@projectbluefin/maintainers` (fill in §9)
**Filed:** [common#1050](https://github.com/projectbluefin/common/issues/1050) (2026-08-29)
**Stalled PR:** [dakota#962](https://github.com/projectbluefin/dakota/pull/962) — opened 2026-06-20, in `4-review` ~70 days
**Roadmap position:** Phase 2 "Product-defining decisions", item 1 — org-wide roadmap planning artifact on the `strategy/org-roadmap` branch (pending sign-off)
**Scope question:** Dakota-only, or org-wide (`bluefin`, `bluefin-lts`, `dakota`)

---

## 1. The decision being requested

One explicit maintainer decision: **whether Bluefin-family images enable
`systemd-homed` by default, for which product lines, and under what
conditions.** This record exists so that decision stops being deferred by
review latency. Until §9 is filled in, the standing position is **no
change**: no variant ships homed by default, and dakota#962 stays gated by
§8.

## 2. What dakota#962 actually changes

A port of [gnome-build-meta!2681](https://gitlab.gnome.org/GNOME/gnome-build-meta/-/merge_requests/2681)
into Dakota's `gnome-build-meta` junction:

| Change | Effect |
|---|---|
| `accountsservice` built with `-Dcreate_homed=true` | User creation through AccountsService delegates to systemd-homed |
| Live generator sets `DefaultStorage=subvolume` | New homes are per-user LUKS2-encrypted subvolumes (btrfs) |
| `gnome-initial-setup` switched to a homed fork | First-boot user creation targets homed; fork is **not upstreamed** |
| `malcontent` dropped; parental-controls flags off in `gnome-control-center`, `gnome-initial-setup`, `gnome-software` | First-party family-safety UI is removed |
| Junction bumped `gnome-50` → gnome-build-meta `master` (49-branchpoint+737) | Bundled in the same PR; the patch's own exit condition is "drop after gnome-build-meta gnome-50 merges MR !2681" |

Review note: this PR mixes a product decision, a junction tracking bump, and
the removal of a shipped feature into one diff. That entanglement is part of
why it has stalled — see the "one logical change per PR" item in §8.

## 3. Options

| Option | Meaning | Consequences |
|---|---|---|
| **A — Dakota-only default** | Homed by default in Dakota only; `bluefin`/`bluefin-lts` keep traditional `/home` accounts | Dakota diverges on account model; the org still owes a stance on the other lines; upgrade story scoped to Dakota users |
| **B — Org-wide default** | All variants, **including LTS**, default to homed | Identity-model change for every existing install; LTS users inherit the full upgrade story in §5 |
| **C — Opt-in / defer** | Keep traditional accounts by default; expose homed as opt-in (or wait for gnome-build-meta upstream) | No product commitment; #962 closed or reworked; parental-controls gap in §6 deferred, not decided |

The choice is not "merge #962 or not". Option C is a legitimate outcome of
this record, and so is "Option A now, revisit org-wide at the next major".

## 4. Threat / UX model

**What homed provides.** `systemd-homed` manages user accounts and stores
each home as a LUKS2-encrypted object (a btrfs subvolume under
`DefaultStorage=subvolume`). Unlock methods are per-user and composable:
LUKS2 passphrase, FIDO2/passkey, TPM2-bound PIN. At login,
`pam_systemd_home` unlocks the home; the user cannot reach their data
without a key.

**Security property gained.** Whole-home encryption at rest. Physical
theft of a device no longer exposes the user's documents, photos, or
browser profiles — a property traditional `/home` accounts on Bluefin do
not provide.

**What changes for the user.**

- Login is now home-unlock; the lock screen is the security boundary.
- Account administration shifts from `/etc/passwd` + `useradd` habits to
  `homectl` (AccountsService still participates for desktop properties).
- Backup/restore changes: the encrypted home object must be moved as a
  whole; partial home copies are not a recovery path.
- Disk layout: subvolumes are copy-on-write on btrfs, so there is no
  doubling of user data, but home recovery and re-encryption are homed
  operations, not `cp` operations.
- Failure modes a user can hit: lost passphrase with no second unlock
  method = data loss; TPM2 PCR drift after kernel/hardware changes with
  only a TPM-bound key = lockout. The record requires that the default
  unlock configuration (and its documented recovery story) be part of the
  decision, not an afterthought.
- Multi-user and shared machines: each user's home is independent and
  encrypted — a plus for shared devices, but it complicates the
  family-safety story in §6 because parental controls operated across
  accounts through a shared desktop assumption.

This section frames the decision; verify current homed behavior against the
`systemd.homed(5)`/`homectl(1)` man pages before quoting details in
user-facing docs.

## 5. Upgrade path for existing non-homed users

Today's installs have plain `/home/<user>` directories on the btrfs root.
A bootc image swap leaves `/home` untouched, so **flipping the default in a
future image does not migrate anyone** — it only changes the model for
users created after the flip. A mixed-model machine (legacy users + homed
users) is a support scenario the decision must address explicitly.

Migration options to choose between:

1. **First-boot offer** — a first-boot path proposes converting existing
   users to homed homes (create the homed user, move data into the new
   encrypted subvolume, retire the legacy dir). The gnome-initial-setup
   homed fork currently handles *user creation*; confirm whether it
   includes *migration* before relying on it — if not, a migration step
   must be written and tested.
2. **Per-user manual migration** — a documented `homectl`-based procedure
   for users who want encryption without a fresh install.
3. **Fresh install** — homed homes only on new installs; existing users
   keep legacy homes (and the machine stays mixed-model).

Whatever is chosen, the decision record must state:

- Whether existing users are migrated, offered migration, or left legacy.
- What a **rollback** looks like: homed homes live in `/home` as encrypted
  subvolumes with metadata in `/var/lib/systemd/home`. Rolling the OS
  image back to a pre-homed build would strand homed homes — the rollback
  story is part of the upgrade story, not separate from it.
- Test coverage: the upgrade path must be covered by the
  [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)
  layer-validation suite and lab-verified before the flip ships
  (see [`docs/TESTING.md`](../TESTING.md)).

## 6. Parental controls story

`malcontent` (GNOME Parental Controls as a Flatpak) is the only first-party
family-safety feature in the stack today. dakota#962 removes it and
disables the parental-controls UI in three apps.

Context: upstream GNOME dropped built-in parental controls in GNOME 46, so
"no first-party parental controls in GNOME" is an upstream reality —
Bluefin-family images currently *extend* upstream by shipping malcontent,
and this decision is really about what we do about that extension.

Options for the record:

| Option | Meaning |
|---|---|
| Accept the gap | No first-party parental controls; publish a support/positioning doc stating what we recommend, and train support |
| Third-party bundle | Ship or recommend a commercial product (licensing, cost, and privacy review required) |
| Keep malcontent opt-in | Don't remove the feature from the image; make it non-default |
| Build/adopt a replacement | Fund or adopt a maintained alternative (longest lead time) |

Family and shared-machine users are a known Bluefin audience. Dropping
this feature without a documented stance creates the support and
positioning risk called out in common#1050 — the decision must include
the support posture, not just the package list.

## 7. Supply-chain / portability notes

- The **gnome-initial-setup homed fork** (Adrian Vovk) is unpinned-to-upstream
  code in a shipping image. The decision must name an upstreaming path
  (gnome-build-meta MR !2681 is the vehicle) with an owner and an exit
  condition, or explicitly accept the fork pin with a review cadence.
- `accountsservice -Dcreate_homed=true` is an upstream feature — no fork
  involved there.
- The **junction tracking bump** (`gnome-50` → `master`, 49-branchpoint)
  bundled into #962 is a separate logical change from the product decision
  and should land independently (§8).

## 8. Gate checklist for dakota#962

dakota#962 may leave `4-review` only when **all** of the following are
true:

- [ ] §9 below is filled in by a maintainer (decision, scope, date).
- [ ] Scope is explicit (Dakota-only or org-wide) and matches the chosen option.
- [ ] The upgrade/migration path for existing non-homed users (§5) is
      documented and covered by testsuite + lab verification.
- [ ] The parental-controls stance (§6) is decided and the support
      documentation is updated in the same change set.
- [ ] The gnome-initial-setup fork has a tracked upstreaming path with an
      exit condition, or the fork pin is explicitly accepted with an owner.
- [ ] The junction tracking bump is split out of the product-decision PR
      (one logical change per PR).
- [ ] The org stance is recorded here and referenced from the downstream
      repo(s) affected, so the decision propagates to all variants.

A PR that re-opens this decision after §9 is filled in must link this
record and state which item it invalidates.

## 9. Decision (maintainers fill in)

| Field | Value |
|---|---|
| **Decision** | _pending_ |
| **Scope** | _pending_ (Dakota-only / org-wide) |
| **Decider** | _pending_ |
| **Date** | _pending_ |
| **Unlock configuration & recovery story** | _pending_ (§4) |
| **Upgrade path for existing users** | _pending_ (§5) |
| **Parental-controls stance** | _pending_ (§6) |
| **Conditions / exit criteria** | _pending_ |

## References

- [common#1050](https://github.com/projectbluefin/common/issues/1050) — strategic finding that filed this record
- [dakota#962](https://github.com/projectbluefin/dakota/pull/962) — the stalled PR this record gates
- [gnome-build-meta!2681](https://gitlab.gnome.org/GNOME/gnome-build-meta/-/merge_requests/2681) — upstream vehicle
- Org-wide roadmap, Phase 2 item 1 — `ROADMAP.md` on the `strategy/org-roadmap` branch (planning artifact, pending sign-off)
- [`docs/skills/human-gates.md`](../skills/human-gates.md) — Design Gate: product-defining decisions require this kind of record
- [`docs/TESTING.md`](../TESTING.md) — testing contract for the upgrade path
