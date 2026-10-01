# Decision Record — Centralize the Bluefin Contract in `common`

**Status:** `OPEN` — pending maintainer decision (Design Gate, [`docs/skills/human-gates.md`](../skills/human-gates.md))
**Decision owner:** `@projectbluefin/maintainers` (fill in §8)
**Filed:** [common#1328](https://github.com/projectbluefin/common/issues/1328) (2026-09-30)
**Author:** `@hanthor` (issue author)
**Related skills:** [`docs/skills/image-identity.md`](../skills/image-identity.md), [`docs/skills/image-registry.md`](../skills/image-registry.md)
**Scope question:** Whether to centralize the shared Bluefin contract (package set, desktop/service surface, branding identity) in `common` so every Bluefin-derived image is held to the same executable promise.

---

## 1. The decision being requested

One explicit maintainer decision: **whether `common` becomes the canonical
home for the Bluefin contract — both the data (package set, desktop/service
surface, branding identity) and the verifiers that enforce it — and how
that contract is consumed by `bluefin`, `bluefin-lts`, `dakota`,
`aurora`-adjacent variants, and downstream derivatives such as
`projectbluefin/utah`.**

The issue lists four open questions this decision must answer:

1. **Granularity** (§4): one contract file or a split?
2. **Versioning** (§5): Renovate-style bump PRs or floating tags per
   stream?
3. **Enforcement** (§6): in-build only, or also a scheduled cross-repo
   report?
4. **Test relationship** (§6a): the contract lives as data + a new
   verifier in `common` `tests/`, or the existing per-repo `tests/`
   suites grow contract assertions?

Until §8 is filled in, the standing position is **no change**: each
consumer repo keeps its own copy of the contract and runs its own
verifiers, with drift detected only by hand. This record exists so the
question stops being deferred by review latency.

The decision is **not** "merge a PR or not". Several legitimate outcomes
are possible, including "no centralization — keep per-repo contracts but
add a cross-repo conformance report" (§3 Option C).

## 2. What the issue actually documents

The issue cites three concrete drift surfaces in `projectbluefin/utah`,
each already a known per-repo enforcement point:

| Surface | Where it lives today | What enforces it today |
|---|---|---|
| Bluefin RPM package set | `packages/bluefin.toml` (a snapshot of `projectbluefin/bluefin`'s `build_files/packages/base.toml`) | `scripts/install-packages.py` re-resolves locally; `scripts/verify-rpm-contract.py` asserts presence |
| Bluefin desktop surface | `contracts/bluefin-desktop.toml` (branding + os-release + Flatpak policy + services) | `scripts/verify-desktop-contract.py` |
| Image identity vocabulary | Per-repo `image-info.json` writers (six writers across three repos) | None at the contract level; only the readers in `common` are shared — see [`docs/skills/image-identity.md`](../skills/image-identity.md) |

The issue is correct that **nothing forces these to agree with what
classic Bluefin, Bluefin LTS, Aurora, or the next Bluefin actually
ship**. `projectbluefin/bluefin`'s `build_files/packages/base.toml` is the
provenance; Utah's copy is a snapshot of it at some past fork point. A
package dropped upstream, a renamed service, or a changed default is
discovered by hand, per repo, if at all.

The pre-existing related work already in `common`:

- [`docs/skills/image-identity.md`](../skills/image-identity.md) — the
  ownership split for *runtime identity vocabulary* (layer 1, owned by
  `common`) versus *build-time variant declaration* (layer 2, per-repo)
  versus *presentation* (layer 3, owned by `projectbluefin/actions`).
  This skill is **already** the canonical decision record for the
  identity-vocabulary slice of the contract; this record does **not**
  duplicate it.
- `system_files/shared/usr/libexec/ublue-image-repo` and
  `system_files/shared/usr/bin/ublue-image-info.sh` — the readers that
  consumers route through, with their own BATS coverage
  (`tests/test_image_repo.bats`, `tests/test_ublue_image_info.bats`).
- `tests/test_bluefin_countme.bats` — an example of `common` already
  asserting a Bluefin-specific surface.

What the issue adds is the **broader** Bluefin contract: not just
identity vocabulary, but the shared package set, the desktop/service
surface, and the branding identity that together answer "is this image
really a Bluefin?".

## 3. Options

| Option | Meaning | Consequences |
|---|---|---|
| **A — Centralize data + verifiers** | Publish the canonical Bluefin contract (packages + desktop/services + branding) from `common`, with executables in `tests/` that consumers run in-build and in CI. Renovate bumps it into consumers as a dependency update | One source of truth; drift detected mechanically; per-repo overlay shape stays as today (Utah `[gnome]`/`[parity]`/`[hardware]` sections, LTS CentOS deltas, etc.); cross-repo PRs move in lockstep |
| **B — Centralize data only, verifiers stay per-repo** | Publish the contract data from `common`; each consumer keeps its own verifier, rewritten to consume the shared data | Lower risk of breaking per-repo build flow; drifts in verifier behavior remain possible; the "answer is in one place" benefit is only partial |
| **C — No centralization; cross-repo conformance report** | Per-repo contracts stay as today; add a scheduled workflow (in `projectbluefin/actions` or `bonedigger`) that diffs every Bluefin's contract against the canonical version and opens a drift issue when they diverge | Lowest blast radius; no consumer repo requires change; discoverability of drift improves without forcing convergence; the contract data still needs an authoritative source even if it is only consumed by the report |
| **D — Defer / no change** | Keep the standing position; revisit only after Utah's verifier surface stabilizes or another repo asks for the same | No new surface; drift continues to be discovered by hand; the original issue becomes a "tracking" issue with no shipped resolution |

The choice is not "Option A now or never". "Option A for the package
set, Option C for the desktop surface" is a legitimate hybrid, and the
record's gate checklist in §7 is structured so the per-section decision
can be made independently.

## 4. Granularity (issue open question 1)

The issue asks: one contract file vs. split?

Both patterns already exist in this repo and in the consumers:

- `build_files/packages/base.toml` is **one** TOML file in
  `projectbluefin/bluefin`, snapshotted into Utah as
  `packages/bluefin.toml`.
- `contracts/bluefin-desktop.toml` is **one** TOML file in Utah.
- [`docs/skills/image-identity.md`](../skills/image-identity.md) splits
  identity vocabulary into a five-key table, owned as a single layer.

A reasonable split for `common`-hosted data, if the decision is
Option A:

| File (in `tests/contracts/bluefin/` or `system_files/shared/contracts/bluefin/`) | Owner | Mirrors today's Utah file |
|---|---|---|
| `packages.toml` | **common** (consumes `projectbluefin/bluefin`'s `build_files/packages/base.toml` via Renovate or a curated sync) | `packages/bluefin.toml` |
| `desktop.toml` | **common** (branding, os-release, schemas, Flatpak policy, services) | `contracts/bluefin-desktop.toml` |
| `identity.toml` (or extend the existing `image-info.json` schema doc) | **common** — already partial via `docs/skills/image-identity.md` | (no per-repo equivalent today) |

Ownership split:

- The shared data, its schema, and the verifiers that read it are
  `common`'s.
- Per-distro overlays (Utah `[gnome]`/`[parity]`/`[hardware]`/LTS
  `[centos-deltas]`) **stay in the consuming repos**; centralization is
  for the *shared* Bluefin promise, not for documented deviation.
- Renovate owns the dependency bump into consumers (§5).

The granularity decision is therefore not "one file or three" — it is
"three top-level files in `common`, mirroring the layers that the
identity skill already names". A single mega-file is rejected because
it conflates the three layers that the identity skill deliberately
separates, and a deeper split is rejected because per-section reviewers
collapse into "everyone owns everything".

## 5. Versioning and rollout (issue open question 2)

The issue asks: Renovate-style bump PRs or floating tags per stream?

The repo's existing pattern for `common` consumers is **digest pinning**:

- Utah's `Containerfile` consumes `common` via
  `COPY --from=common /system_files/bluefin` against an immutable digest.
  The bump is a deliberate PR with a recorded diff, not a floating ref.
- `system_files/shared/usr/libexec/ublue-image-repo` is treated as a
  single source of truth for image-name/tag → upstream repo routing
  (skill doc: "single source of truth for 'which repository owns this
  booted image'").

The contract data should follow the same shape:

1. Contract data lives in `common` under a `contracts/bluefin/` tree.
2. The data is **versioned with the contract schema** (e.g.
   `schema_version: 1` in each TOML).
3. Consumers pin by **commit SHA** in their `Containerfile`/build
   inputs (same pattern as Utah's pin of the `common` image).
4. Renovate opens a bump PR into each consumer on `upstream/main` of
   `common`; the PR carries the contract diff in the body so review is
   the moment to flag a breaking change.
5. Per-stream tags (testing/stable/next) are **not** used for the
   contract itself — they are used for the *image* that bundles the
   contract. Drift between contract change and image publication is
   the same drift as today.

The precedent for pinning a first-party artifact by digest is Utah's own
`Containerfile`, which pins the `common` image by digest
(`COMMON_IMAGE_SHA`) and consumes it with `FROM
${COMMON_IMAGE}@${COMMON_IMAGE_SHA}`. Note that this is **not** the
`uses:` SHA-pinning policy in
[`docs/skills/ci-tooling/SKILL.md`](../skills/ci-tooling/SKILL.md): that
policy requires SHA pins for *third-party* actions and explicitly
exempts internal `projectbluefin/` refs, which use managed floating tags
(`@main`/`@v1`). Contract data is an artifact consumed by a build, not a
workflow `uses:` ref, so the digest-pin precedent applies and the
floating-tag exemption does not.

## 6. Enforcement points (issue open question 3)

The issue asks: in-build only, or also a scheduled cross-repo report?

Three enforcement points, each with a different cost:

| Point | What it catches | Cost |
|---|---|---|
| **In-build verifier (each consumer)** | Drift between the consumer's built image and the pinned contract — catches a regression *in this build* | Runs every build; cheap if the contract is small (TOML + BATS); already the pattern Utah uses |
| **In-CI verifier (consumer PR)** | Drift between a PR's planned change and the pinned contract — catches "we forgot to bump the contract" *before* the merge | Runs every PR; same shape as the in-build verifier, gated on the contract diff |
| **Cross-repo conformance report (scheduled)** | Drift between any consumer and `common`'s `main` after a contract change — catches "consumer hasn't bumped yet" *after* the merge | Daily/weekly cron; opens an issue in the lagging consumer with the diff; lives in `projectbluefin/actions` or `projectbluefin/bonedigger`, not in `common` |

A defensible default is **all three**, in order of priority:

1. In-CI verifier is the cheapest, highest-value gate — it is the gate
   that prevents drift from being merged.
2. In-build verifier is the backstop — it catches the case where the
   CI gate was bypassed or skipped.
3. Cross-repo conformance report is the safety net — it catches
   consumers that haven't bumped yet after `common` changed.

`common` ships the verifiers and the contract data; the cross-repo
report is owned elsewhere because it crosses repo boundaries that
`common` cannot enforce on its own.

## 6a. Relationship to existing tests (issue open question 4)

The issue asks: does the contract live as data + a new verifier in
`common` `tests/`, or do existing tests grow contract assertions?

Both patterns already exist:

- `tests/test_check_oci_refs.py`, `tests/test_curated_config.py`,
  `tests/test_skill_docs.py`, and the BATS suites under `tests/`
  exercise the **data the contract will read**: OCI labels, curated
  config JSON, skill docs cross-references, and bash gating. These
  are the right home for assertions about *the contract's existing
  consumers* (e.g. "Utah's desktop TOML still passes after the
  contract moves").
- No suite today exercises the **shape of the Bluefin promise
  itself** — package-set identity, desktop branding identity, image
  identity vocabulary. Each consumer repo re-derives these locally
  with its own verifier (Utah's `utah-verify-desktop-contract`,
  `utah-verify-rpm-contract`; the per-distro installer recipes).
  The verifiers duplicate logic that, under any of Options A–C, would
  become shared.

Two viable shapes:

1. **Centralize: data + new verifier in `common` `tests/`.** A
   `tests/test_bluefin_contract.py` reads the three contract files
   (§4) and asserts the same properties the per-distro verifiers
   do today, plus the cross-section invariants only `common` can
   see (e.g. "the identity vocabulary in `docs/skills/image-identity.md`
   is the same set the desktop TOML keys reference"). Per-distro
   verifiers shrink to consumers of `common`'s data.

2. **Grow assertions into the existing suites.** Each existing
   test file gets a new contract-assertion block, and the
   contract data lives as fixture inputs the suite reads. No new
   file under `tests/`; the per-distro verifiers stay as-is.

Shape 1 wins on two axes:

- The new file is the **single place** where a Bluefin-contract
  regression surfaces, matching the RFC's "centralized contract"
  premise. Shape 2 spreads the regression surface across N existing
  files in N repos.
- Shape 1 keeps the per-distro verifier logic in one repo (`common`),
  so a fix lands once. Shape 2 means every consumer repo's verifier
  still needs the same fix.

Shape 2 wins on one axis:

- Lower initial diff. No new test file, no fixture restructure, no
  deletion of per-distro verifier logic. Shape 2 is a *documentation*
  change for each existing suite.

The recommended default is Shape 1, with Shape 2 as a deferred
follow-up if Shape 1 turns out to require a deletion the maintainer
is unwilling to make. The decision lands in §8 alongside the others.

## 7. Gate checklist

The record may move from `OPEN` to a shipped state only when **all** of
the following are addressed:

- [ ] §8 filled in by a maintainer (option per section, scope, date).
- [ ] Granularity chosen (§4): three top-level contract files
      (packages / desktop / identity) under `tests/contracts/bluefin/`
      or `system_files/shared/contracts/bluefin/`.
- [ ] Versioning chosen (§5): SHA-pinned contract + Renovate bump PRs
      into each consumer.
- [ ] Enforcement chosen (§6): at minimum in-CI verifier per consumer;
      optionally in-build verifier and cross-repo conformance report.
- [ ] Per-section overlay shape documented: which overlay sections
      stay downstream (Utah `[gnome]`/`[parity]`/`[hardware]`, LTS
      CentOS deltas) and what the override grammar is.
- [ ] Verifier BATS/Pytest coverage in `common` proves the contract
      data round-trips through the verifier (parity test against the
      existing Utah verifiers).
- [ ] Backward-compat window: at least one release cycle where the
      centralized data and the existing per-repo copies produce the
      same answer; consumer migration is opt-in by repo.
- [ ] `docs/skills/image-identity.md` cross-references the new contract
      location so the identity-vocabulary ownership map stays current.
- [ ] The decision is recorded here and referenced from each consuming
      repo's build input, so it propagates to all Bluefin variants.

## 8. Decision (maintainers fill in)

| Field | Value |
|---|---|
| **Decision (packages section)** | _pending_ (Option A / B / C / D) |
| **Decision (desktop section)** | _pending_ (Option A / B / C / D) |
| **Decision (identity section)** | _pending_ (Option A / B / C / D; identity may already be "done" via the existing skill) |
| **Granularity** | _pending_ (three top-level files in `common`, or single mega-file, or other) |
| **Versioning** | _pending_ (SHA-pin + Renovate, floating tag per stream, or other) |
| **Enforcement** | _pending_ (in-build + in-CI + cross-repo report, or subset) |
| **Relationship to existing tests** | _pending_ (centralized contract + new verifier in `common` `tests/`, or grow assertions into the existing Utah `tests/` suites — see §6a) |
| **Decider** | _pending_ |
| **Date** | _pending_ |
| **Repos affected** | _pending_ (common, bluefin, bluefin-lts, dakota, utah, others) |
| **Backward-compat window** | _pending_ (one release, two releases, never) |
| **Conditions / exit criteria** | _pending_ |

## References

- [common#1328](https://github.com/projectbluefin/common/issues/1328) — the issue this record evaluates
- [`docs/skills/image-identity.md`](../skills/image-identity.md) — the prior decision on identity vocabulary ownership (layer 1 of the contract)
- [`docs/skills/image-registry.md`](../skills/image-registry.md) — where images live and how they are tagged
- [`docs/skills/human-gates.md`](../skills/human-gates.md) — Design Gate rationale for product-defining decisions
- Utah's existing per-repo enforcement:
  `scripts/verify-rpm-contract.py`,
  `scripts/verify-desktop-contract.py`,
  `scripts/install-packages.py`
- Bluefin's existing per-repo data:
  `build_files/packages/base.toml` in `projectbluefin/bluefin`
