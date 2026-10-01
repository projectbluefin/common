# Decision Record — Open Gaming Collective Branding on Gaming Images

**Status:** `OPEN` — pending maintainer decision (Design Gate, [`docs/skills/human-gates.md`](../skills/human-gates.md))
**Decision owner:** `@projectbluefin/maintainers` **and** the Open Gaming Collective (fill in §9)
**Filed:** [common#1156](https://github.com/projectbluefin/common/issues/1156)
**Already shipped (not gated by this record):** [chairlift#194](https://github.com/projectbluefin/chairlift/pull/194) — merged 2026-09-22, makes the OGC mark ChairLift's *default* panel icon when `imageinfo.Info.IsGaming()` is true
**Scope question:** Org-wide convention (all gaming surfaces, all gaming images) vs. one application default

---

## 1. The decision being requested

The gaming images (`dakota-gaming`, `dakota-nvidia-gaming`) ship the Open
Gaming Collective's stack — gamescope-session, ScopeBuddy, the OGC kernel
packages, asusctl — but present themselves with the same generic mark as
every other image. common#1156 asks four questions and this record frames
them; it does not answer them:

1. Is the OGC mark the right identity for the gaming images, by convention?
2. If yes, where does the canonical artwork live so it does not get copied
   into three places and drift?
3. Is there an approved OGC **square icon / symbolic** variant, rather than a
   wordmark asset converted downstream?
4. Which surfaces beyond the panel icon follow the gaming flavor?

Until §9 is filled in, the standing position is **no change beyond what
chairlift#194 already shipped**: no org-wide convention exists, no artwork
is vendored by common, and downstream components are free to keep their
current behaviour.

## 2. What is already in place

`image-info.json` already distinguishes the gaming images, so the signal
exists and is machine-readable:

```json
{
  "image-name": "dakota-gaming",
  "image-flavor": "gaming",
  "image-vendor": "projectbluefin"
}
```

Per [`docs/skills/image-identity.md`](../skills/image-identity.md), that
flavor field is runtime identity vocabulary owned by **common** — so any
convention that keys off `image-flavor: gaming` (or a `-gaming` image-name
suffix) needs a common-side statement, not nine independent implementations.
That is why the decision is filed here rather than in ChairLift. That skill's
"`image-flavor` is identity, not (yet) a branding contract" note carries the
matching carve-out: no *org-wide* contract exists until §9 is filled in, while
a per-application default such as chairlift#194 stays the owning
application's call.

chairlift#194 is a **default, not an override**: a user who deliberately
picked another mark keeps it. It also explicitly leaves the org-wide
convention and artwork ownership to this issue, so it does not resolve it.

## 3. Options

| Option | Meaning | Consequences |
|---|---|---|
| **A — Org-wide convention** | Gaming images carry the OGC mark on every reachable surface (panel icon, Files icon, app-grid glyph, wallpaper, installer, plymouth), driven off `image-flavor: gaming` | Real differentiation between gaming and non-gaming images; requires canonical artwork (§4), a common-side contract, and per-repo implementation in ChairLift, installer, docs site, plymouth |
| **B — Per-application default** | Each application may adopt OGC as a default when it wants to; no org statement, no common contract | Status quo after chairlift#194; lowest coordination cost; risk of the artwork drifting between vendored copies and no repo being accountable for it |
| **C — Opt-in only** | OGC is one mark in the user's mark list, never a default anywhere | Requires reversing chairlift#194's default; strongest user control; gaming images look like every other image again |

The chairlift#194 authors assumed A. The collective owns its own identity,
so B or C are legitimate outcomes, and so is "A for the desktop, opt-in
everywhere else".

## 4. Artwork ownership (question 2)

The mark is currently vendored from
[`opengamingcollective/opengamingcollective.org`](https://github.com/opengamingcollective/opengamingcollective.org)
`public/logo.svg`, converted downstream to a symbolic rendition. The
published asset's `viewBox` (`0 0 256 84.768`) does **not** match its path
bounds (roughly `0 -86 256 256`), so it needs correcting before it renders
as a square icon. Fixing that downstream, in every consumer, is the drift
the decision should prevent.

Candidate homes, framed here for the maintainers to rank (this list is not a
maintainer preference order; common#1156 calls a press-kit path "the obvious
candidate" and says nothing about the rest):

1. A press-kit path in an OGC repository (`opengamingcollective.org` or a
   dedicated `opengamingcollective/brand` repo) that publishes the wordmark,
   a square icon mark, and a symbolic rendition with correct `viewBox`.
2. A ublue-os press-kit location, if the org already vendors such assets.
3. Status quo: each consumer vendors its own copy, with common's
   `image-identity.md` recording the source URL and the required fix-up.

Whichever is chosen, the record should also name the **update path**: how a
consumer picks up a revised asset (pinned URL + digest, submodule, or
versioned tag), because a brand asset with no pin is a supply-chain surface
like any other.

## 5. User-visible surface model (question 4)

| Surface | Reachable via the same `IsGaming()` mechanism? | Notes |
|---|---|---|
| Panel icon (ChairLift / Livery) | yes | Already defaulted to OGC by chairlift#194 |
| Files (Nautilus) icon | yes | Would change every file-manager surface; highest visibility |
| App-grid / dash glyph | yes | Smaller surface, easier to justify |
| Wallpaper | no — different mechanism | A user-setup hook (`system_files/bluefin/usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh`) enables the `bluefin-dynamic-wallpaper.timer` and calls `/usr/libexec/bluefin-dynamic-wallpaper`; the actual selection logic lives in that libexec script, not in the hook. Neither file reads `image-flavor` today, so Option A would have to add flavor keying to `/usr/libexec/bluefin-dynamic-wallpaper` (or replace it). |
| Installer / plymouth | build-time, not runtime | Cross-repo: installer and plymouth themes live outside common; a decision here implies work there |

Overriding a user's explicit mark choice is **not** on this list. Whatever
is decided, it stays a default.

## 6. Rollback / upgrade path

- **Rolling back Option A** is a config revert, not a data migration: remove
  the OGC default and each surface falls back to the generic mark. No user
  data, no installed system files, and no image tags are involved.
- Users who *manually* selected the OGC mark under Option A keep it after a
  rollback, because an explicit choice is stored separately from the default.
  This is the same property chairlift#194 relies on.
- If Option A later ships a new asset path (corrected `viewBox`, square
  icon), consumers must re-render from the canonical source rather than
  carrying a stale local conversion — that is the drift §4 is about.

## 7. Supply-chain notes

- Any vendored brand asset should be pinned the way other external inputs
  are (see [`docs/skills/ci-tooling/SKILL.md`](../skills/ci-tooling/SKILL.md)),
  even though it is a static SVG.
- Licence of the OGC mark must be recorded before common vendors it. A
  downstream conversion of a wordmark does not change whose trademark it is,
  and the org should not be shipping a collective's mark without the
  collective's explicit permission recorded alongside the decision.
- A symbolic rendition generated downstream from a wordmark is a derived
  asset; the derived file needs an owner and a regeneration procedure.

## 8. Gate checklist for any org-wide convention PR

A PR implementing Option A may leave `4-review` only when **all** of the
following are true:

- [ ] §9 is filled in by a maintainer (decision, scope, date, decider).
- [ ] The OGC's explicit agreement to the org-wide default is recorded here
      (question 1 is theirs as much as ours).
- [ ] A canonical artwork location and pin method are recorded (§4), and the
      licence of the mark is stated (§7).
- [ ] The set of surfaces in §5 is explicit, and each repo's implementation
      is linked from this record.
- [ ] The common-side contract for the `image-flavor: gaming` key is written
      into [`docs/skills/image-identity.md`](../skills/image-identity.md), or
      the record states that the flavor is not a branding contract.
- [ ] Rollback is a revert with no data migration (§6), and the testsuite /
      lab verification plan is recorded per [`docs/TESTING.md`](../TESTING.md).

A PR that re-opens this decision after §9 is filled in must link this record
and state which item it invalidates.

## 9. Decision (maintainers fill in)

| Field | Value |
|---|---|
| **Decision** | _pending_ (A — org-wide / B — per-application / C — opt-in only) |
| **Scope** | _pending_ (org-wide / dakota gaming only / desktop only) |
| **Surfaces in scope** | _pending_ (§5) |
| **Canonical artwork location + pin method** | _pending_ (§4) |
| **Approved icon variants (wordmark / square / symbolic)** | _pending_ |
| **OGC agreement recorded by** | _pending_ |
| **Licence of the mark** | _pending_ (§7) |
| **Decider** | _pending_ |
| **Date** | _pending_ |
| **Conditions / exit criteria** | _pending_ |

## References

- [common#1156](https://github.com/projectbluefin/common/issues/1156) — the issue this record frames
- [chairlift#194](https://github.com/projectbluefin/chairlift/pull/194) — merged; per-application OGC default, defers the org question here
- [`opengamingcollective/opengamingcollective.org`](https://github.com/opengamingcollective/opengamingcollective.org) — current source of the vendored `public/logo.svg`
- [`docs/skills/human-gates.md`](../skills/human-gates.md) — Design Gate: product-defining decisions require this kind of record
- [`docs/skills/image-identity.md`](../skills/image-identity.md) — who owns the `image-flavor` field the convention keys off
- [`docs/TESTING.md`](../TESTING.md) — testing contract for any shipped default
