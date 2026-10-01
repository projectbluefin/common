# Printer Application version semantics

Part of [release-promotion](../SKILL.md) — the version contract for the four
FSDK OCI Printer Applications (`ps-printer-app`, `hplip-printer-app`,
`gutenprint-printer-app`, `ghostscript-printer-app`). Tracked by
[common#1245](https://github.com/projectbluefin/common/issues/1245), a child of
the printer epic [common#1209](https://github.com/projectbluefin/common/issues/1209).

> Scope note: this covers **which string a version is and what each part
> means**. Promotion mechanics live in
> [printer-app-promotion.md](./printer-app-promotion.md), the artifact evidence
> matrix in [printer-app-evidence-matrix.md](./printer-app-evidence-matrix.md),
> and upstream source lag in
> [printer-app-source-baseline.md](./printer-app-source-baseline.md). Do not
> duplicate that ownership here.

## The rule this repo records

**Every published version is `<upstream version>` plus a packaging/rebuild
counter, and the version string is the only identity of a published artifact.**
Renovate, ChairLift, the release workflows and the release audit all read the
same string, so the string has to say both *which upstream code* is inside and
*which build of that upstream code* it is. An FSDK base-image bump, a packaging
patch or a driver-payload change with unchanged upstream application code is a
**new build of the same upstream version**, and it must be able to get a new
immutable tag. It must never be published under a tag that already exists, and
it must never overwrite one.

The machine-readable form of that rule — grammar, version source, enforcement
site, published tags and worked examples per family — is
[printer-app-version-grammar.json](./printer-app-version-grammar.json), checked
by `scripts/check-printer-app-versions.py`. The check reports the gaps below;
it does not decide them (that is a maintainer decision, see
[Open decision](#open-decision-maintainer)).

## Per-family forms as observed and inferred (2026-09-29)

The grammar (the regex) for each family and the published_tags column are
**observed/inferred from each printer-app repo's `stable` branch** (the
`VERSION` file and existing release tags); only the version source and the
tag-equality / stable-ancestry enforcement are transcribed from each repo's
`.github/workflows/registry-actions.yml`. Ghostscript's grammar is inferred
from its existing tags (`10.07.1-1`, `10.07.1-2`) — its publish workflow
verifies the release tag equals `v$VERSION` and points at a stable commit,
but does not validate the version shape itself. Re-derive with the recipe in
[Re-derivation recipe](#re-derivation-recipe) before relying on it.

| Family | Version form | Version source | Upstream part | Rebuild slot | Published tags |
|---|---|---|---|---|---|
| Ghostscript | `10.07.1-2` (grammar inferred from tags) | `VERSION` file | Ghostscript `10.07.1` | **shared** with the packaging revision | `10.07.1-1`, `10.07.1-2` |
| HPLIP | `3.26.4` | `VERSION` file, cross-checked against `# source-tag:` in `elements/printer-app/hplip.bst` | HPLIP `3.26.4` | **none** | `3.26.4` |
| Gutenprint | `5.3.6-4.1` | `include/source-pins.yml` (`gutenprint-version`) | Gutenprint `5.3.6` + Debian revision `4` | **`.N` suffix** — documented in the repo's own workflow as "an OCI-only rebuild of the same Debian revision, because immutable registry tags can never be republished" | `5.3.6-4`, `5.3.6-4.1` |
| PostScript | `20240504-20` | `VERSION` file, staged by `elements/printer-app/version.bst` | foomatic-db snapshot date `20240504` (calendar date, not semver) | **shared** with the packaging revision | none — release held on [ps-printer-app#27](https://github.com/projectbluefin/ps-printer-app/issues/27) |

Every family also publishes `<version>-x86_64` and `<version>-aarch64`
architecture tags, and every family's publish step refuses to push a tag that
already exists ("Refusing to overwrite immutable tag"). That refusal is the
mechanical reason a rebuild needs its own version string: without one, an
FSDK-only rebuild simply cannot be published.

### Stale claim in #1245, corrected

#1245 lists the PostScript version as `1.0.0`. No `1.0.0` exists anywhere in
`projectbluefin/ps-printer-app` on `stable` today; the release workflow pins
`VERSION` to `^[0-9]{8}-[0-9]+$` and `stable` carries `20240504-20`. The PS
form is therefore **foomatic-db snapshot date + packaging revision**, which is
the one family that is not semver-shaped at all. Re-derive before repeating the
`1.0.0` figure anywhere.

## Worked examples

Both transitions are recorded per family in the JSON and enforced by the
validator's `examples` block. `R` = same upstream source, new build.

| Family | New upstream release | Unchanged-upstream FSDK rebuild (`R`) |
|---|---|---|
| Ghostscript | `10.07.1-2` → `10.07.2-1` | `10.07.1-1` → `10.07.1-2` (real: FSDK `26.08rc.1` → `26.08.1`, per [chairlift#393](https://github.com/projectbluefin/chairlift/issues/393)) |
| HPLIP | `3.26.4` → `3.26.5` | **no valid version today** — see the finding below |
| Gutenprint | `5.3.6-4.1` → `5.3.7-1` | `5.3.6-4` → `5.3.6-4.1` (real, and the `.1` suffix means exactly this) |
| PostScript | `20240504-20` → `20240601-1` (new snapshot date) | `20240504-20` → `20240504-21` (same snapshot, bumped revision) — but indistinguishable from a packaging bump |

ChairLift displays the same string: `internal/printerapp/printerapp.go` carries
a `Version` field per family alongside an optional `Digest`, and `Image()`
returns `repo@digest` whenever the digest is set, falling back to
`repo:version` when it is empty. So a user-visible version
string and the immutable identity are already kept in the same struct, and a
version bump is what a ChairLift pin update has to carry alongside the digest.

## Findings (the parts that are not yet consistent)

1. **HPLIP cannot publish a rebuild at all.** `VERSION` is pinned by regex to
   the upstream version (`debian/<upstream>+dfsg0-<n>` → `<upstream>`), the
   release tag must be `v$VERSION`, and the tag must not already exist. After
   `3.26.4` is published there is no second immutable version available for the
   same upstream code, so the next FSDK-only bump has nowhere to go. The
   validator reports this as `rebuild_slot: none`.
2. **Ghostscript and PostScript overload one number.** Their trailing digit is
   the packaging revision, and an unchanged-upstream rebuild has to move that
   same digit, so `10.07.1-2` does not say whether upstream shipped a new
   packaging revision or we rebuilt. Gutenprint's `.N` suffix is the only form
   that separates the two.
3. **PostScript is not semver-shaped.** `20240504-20` sorts correctly by
   snapshot date, but any tool that parses these four strings as semver (a
   generic changelog or version-bump helper) will reject or misorder it.
4. **Only Gutenprint's `.N` is documented in the repo that enforces it.** The
   rebuild meaning exists as a comment in
   `gutenprint-printer-app/.github/workflows/registry-actions.yml`; the other
   three repos have no equivalent statement, which is why the semantics had to
   be re-derived here.

## Re-derivation recipe

Each family's version string and its enforcement live in its own repo. To
re-derive (no `skopeo` needed, the GitHub API is enough):

```bash
for app in ghostscript-printer-app hplip-printer-app ps-printer-app; do
  echo "== $app VERSION on stable:"
  gh api "repos/projectbluefin/$app/contents/VERSION?ref=stable" --jq .content | base64 -d
  gh api "repos/projectbluefin/$app/contents/.github/workflows/registry-actions.yml?ref=stable" \
    --jq .content | base64 -d | sed -n '/Validate\|Require stable ancestry/,/GITHUB_OUTPUT/p'
done
echo "== gutenprint version pin:"
gh api "repos/projectbluefin/gutenprint-printer-app/contents/include/source-pins.yml?ref=stable" \
  --jq .content | base64 -d
echo "== published (immutable) tags:"
for app in ghostscript-printer-app hplip-printer-app gutenprint-printer-app ps-printer-app; do
  echo "-- $app"; gh api "repos/projectbluefin/$app/tags" --jq '.[].name'
done
```

After editing the contract, run the check and the tests:

```bash
python3 scripts/check-printer-app-versions.py            # findings and warnings reported, exit 0
python3 scripts/check-printer-app-versions.py --strict   # findings and warnings are failures
python3 -m pytest tests/test_check_printer_app_versions.py
```

To check a version you are about to propose, without editing the contract:

```bash
python3 scripts/check-printer-app-versions.py --family gutenprint-printer-app --candidate 5.3.6-4.2
python3 scripts/check-printer-app-versions.py --family hplip-printer-app --candidate 3.26.4-1   # rejected today
```

## Open decision (maintainer)

Recording the four forms as data is the part that does not need a decision.
Choosing the single suite-wide rule does, and it is a version-policy decision
under [`docs/skills/human-gates.md`](../../human-gates.md). The options, with
what each costs:

- **Option A — Gutenprint's form, everywhere:** `<upstream>[-<packaging>][.<rebuild>]`,
  a distinct rebuild counter. HPLIP gains `3.26.4-1`; Ghostscript moves to
  `10.07.1-1.1`; PostScript becomes `20240504-20.1`. Needs a workflow regex
  change in three repos and a one-line doc in each. **Already-published tags are
  untouched** — new tags are additive.
- **Option B — keep per-family forms, document the exceptions:** treat Gutenprint
  as the reference, record Ghostscript/PS shared-digit and HPLIP no-rebuild as
  accepted exceptions with reasons. Cheapest, but HPLIP still cannot ship an
  FSDK-only rebuild as a new immutable version, so the gap in finding 1 remains
  open by decision.
- **Option C — one uniform opaque form for all four,** e.g. `v<N>` per family
  with upstream version carried only in a label. Most uniform, loses the
  human-readable upstream link that the current tags have, and is the largest
  change.

Recommendation (agent view, not a decision): **Option A**, because it is the
only option under which every family can satisfy "an unchanged-upstream rebuild
gets its own immutable tag" without overwriting a published one, and because
Gutenprint already implements and documents exactly that rule.

### Not done in this repo, and why

- **No published tag is changed, retagged or deleted.** Immutable tags are never
  rewritten to make strings uniform; the new forms are additive.
- **No workflow in the four printer-app repos is changed from here.** Each
  enforces its own version form; this repo records the contract and the
  evidence. Changes belong in the owning repo, under its own review.
- **CI wiring is active.** `tests/test_check_printer_app_versions.py` runs as part
  of unit test validation in `.github/workflows/unit-tests.yml`, and
  `scripts/check-printer-app-versions.py` runs in `.github/workflows/validate.yml`.
  The check is non-strict by default: recorded findings do not fail, only errors
  do.
- **No version transition is performed.** Verifying a representative transition
  per family (the third acceptance item) means publishing a real tag from a real
  `stable` promotion, which is operational work in those repos and a
  maintainer dispatch, not a `common` change.
- **Physical print behavior stays unverified.** No printer hardware exists; the
  socket-sink harness remains the only evidence, as in
  [printer-app-evidence-matrix.md](./printer-app-evidence-matrix.md).
