---
name: e2e-ci
version: "1.1"
last_updated: "2026-09-29"
id: e2e-ci
one_line_purpose: Debug pre/post-merge E2E CI for common.
entry_point: docs/skills/e2e-ci/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [e2e, testing, ci]
description: >-
  Pre/post-merge E2E CI for common. Use when debugging E2E failures,
  understanding the PR gate flow, or diagnosing masked brew-setup issues.
metadata:
  type: reference
---

# E2E CI

## When to Use

Use when debugging E2E failures, understanding the PR gate flow, diagnosing
masked `brew-setup` issues, or wiring E2E as a gate in a promotion pipeline.

## When Not to Use

Do not use this skill for lab/KubeVirt testing (see
[`../lab-testing/SKILL.md`](../lab-testing/SKILL.md)), or for generic GitHub
Actions authoring unrelated to the `common` test workflows.

## Post-merge E2E

**File:** `.github/workflows/e2e.yml`

- Runs after merges to `main`
- Calls the local `.github/workflows/run-testsuite.yml` wrapper, which centralizes the pinned `projectbluefin/testsuite` SHA
- Validates the common layer against three downstream images:
  - `ghcr.io/projectbluefin/bluefin:latest`
  - `ghcr.io/projectbluefin/bluefin:lts`
  - `ghcr.io/projectbluefin/dakota:testing`
- Uses SSH-mode tests from the runner, so the common suite does not require a full GNOME session

## Pre-merge gate

**File:** `.github/workflows/pr-e2e.yml`

- Runs on PRs to `main` and on `merge_group`
- Builds the PR's `common` layer candidate first
- Composes a downstream test image from `ghcr.io/projectbluefin/bluefin:stable` by overlaying `/system_files/shared` and `/system_files/bluefin`
- Recompiles GSettings schemas in the composed image
- Pushes the composed image to GHCR and runs the local testsuite wrapper with `suites: common`

This is the pre-merge gate for common-layer changes, so regressions can fail before merge instead of waiting for post-merge E2E.
In branch protection today it is still an advisory/non-required signal; `build.yml` remains the required merge check.

Use a stable downstream base for this PR-time compose gate. The moving `:testing`
stream belongs in `promotion-candidate-e2e.yml`; using it here makes unrelated
downstream churn (for example missing CLI tools in the current testing image)
fail `common` PRs that only change the shared layer.

## Promotion-candidate feedback loop

**File:** `.github/workflows/promotion-candidate-e2e.yml`

- Runs weekly on Tuesdays before the downstream Bluefin promotion workflows
- Tests the exact candidate tags used for promotion from common's side:
  - `ghcr.io/projectbluefin/bluefin:testing`
  - `ghcr.io/projectbluefin/bluefin:lts-testing`
- Runs `smoke,common` to add a boot/basic-usage signal on top of the shared-layer checks
- Uses the same local testsuite wrapper as PR/post-merge workflows, so the testsuite SHA stays aligned

This is **not** a full installer gate. It is the smallest safe repo-local improvement common can make without editing downstream image repos or installer pipelines.

## Known CI caveats and quarantines

- `brew-setup.service` is masked in CI, so Homebrew-installed CLI tools are not present unless explicitly provisioned during the job
- `testsuite#210` tracks the `bash -lc` PATH mismatch affecting `zsh`/`fish` checks in the CI user environment
- GNOME Software scenarios are intentionally `@quarantine` after `testsuite#258`; they should not be treated as active software-store coverage
- Bazaar coverage is currently a `@pending` placeholder tied to the same gap
- `ujust report --confirm` scenario (`system_health.feature`) is `@quarantine` — the `--confirm` mode is not implemented in any current image variant; the step skip-detection used the wrong error string. See testsuite PR #259. Re-enable when `report --confirm` lands in the image Justfile.

## Reading a Promotion Candidate E2E failure

The `notify-on-failure` job files a bare `ci: promotion candidate E2E failed` issue with
no diagnosis, so triage starts from the run. Two steps get you the real cause fast —
do not read the raw job log top to bottom, it is ~23k lines and mostly `git fetch` noise.

```bash
RUN=<run id>
# 1. Which jobs failed and at which step.
gh api repos/projectbluefin/common/actions/runs/$RUN/jobs \
  --jq '.jobs[] | select(.conclusion=="failure") | .name, (.steps[] | select(.conclusion=="failure") | .name)'

# 2. results.json from the metadata artifact has the per-step assertion messages.
#    `gh run download` is not available to the agent; fetch + unzip via the API.
curl -sL -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/projectbluefin/common/actions/artifacts/<id>/zip" -o a.zip
python3 -c "import zipfile;zipfile.ZipFile('a.zip').extractall('a')"
```

Then walk `results.json` for `steps[].result.error_message`. `gh run view --log-failed`
alone is not enough: the behave runner container's stdout is not in the job log, so
assertion text only exists in the artifact.

### Triage order for the 2026-09-29 run (#1285)

Not every failing scenario is fixable in `common`. Split them by owner before starting:

| Failure | Owner | Notes |
|---|---|---|
| `ujust bios-info` / `logs-this-boot` / `check-local-overrides` / shared-scripts scenario all exit 1 with `error: unknown start of token '.'` on `default.just:33` | **bluefin-lts** (not `common`) | `common`'s `main` `default.just` parses and `just --list` on it is clean, so the bytes in the image are not the bytes in this repo. The reported column (`:60`) does not line up with `main` either — column 60 there is the `o` of `--format`, because the `/usr/bin/podman` prefix from #950 shifted the placeholder to column 67. Column 60 only lands on `.` for a pre-#950 line after something collapses `{{{{`→`{{`. So the image holds a copy of this file that is at least seven weeks stale *and* has been through a brace-collapsing step. Ask the LTS image owners where `usr/share/ublue-os/just/default.just` comes from; fixing `common` main does not change it. See "Go templates in justfile recipes" below for the rule the fix here enforces. |
| `flatpak remotes --system` → `opening repo /var/lib/flatpak/repo: No such file or directory` on `lts-testing` | bluefin-lts | Missing system Flatpak installation in the LTS image, not the shared layer. |
| `GNOME extension "..." is enabled` with `state=6` / `state=99` | testsuite | The suite's own `local.d/00-ci-testing` dconf write replaces `enabled-extensions` with `['unsafe-mode@bluefin-test']`, so per-extension `ExtensionState` assertions cannot pass. See [`../dconf-consistency.md`](../dconf-consistency.md). |

## Go templates in justfile recipes

`just` lexes a recipe body before handing it to the shell, and a bare Podman/Docker Go
template placeholder (`--format "{{.Repository}}"`) is not a valid token. One of them
aborts the parse of the **entire** file:

```
error: unknown start of token '.'
 ——▶ default.just:33:60
```

Every recipe in that file then exits non-zero, including ones that have nothing to do
with the line that broke. It even fires inside a `#` comment, because comments in a
recipe body are lexed too.

**The escaping rules, which are asymmetric and easy to get wrong:**

| You want | Correct spelling | Why |
|---|---|---|
| a literal `{{` | `{{{{` | `just` de-escapes the doubled form; this is `just`'s own documented escape, not leftover Jinja escaping |
| a literal `}}` | `}}` | There is **no** `}}}}` escape — outside an interpolation, `}}` is already literal, so `}}}}` reaches the shell as two stray braces |

`clean-system` in `default.just` had `--format "{{{{.Repository}}}}:{{{{.Tag}}}}  {{{{.ID}}}}"`,
which is the second row of that table applied to the wrong side — a close brace that
needs no escape was escaped anyway. The file parsed, and every column printed with a
trailing `}}`. The recipe now omits `--format` entirely: the default `podman image ls`
table already shows repository, tag, image ID and size, so the placeholder (escaped or
not) buys nothing here.

`tests/test_justfile_syntax.bats` gates this across every `*.just` under
`system_files/` and `bluefin-branding/`: no *unescaped* Go-template placeholder
(`{{.`, `{{ .Repository }}`, `{{json .}}`, ...), no `}}}}`, and every file must parse
with `just --list`. The escaped
spelling `{{{{.` stays legal — a suite test pins that, so the gate cannot drift into
banning `just`'s own escape. Gate 1 matches the placeholder shapes directly, so it
costs nothing in CI; it is deliberately not exhaustive — `{{- .X }}`, `{{$x}}` and
`{{ end }}` also abort the parse and are left to gate 3, which is why the header
comment says so. Gate 3 (`just --list`) is the backstop for anything the pattern
misses and `skip`s when `just` is not installed. The suite is registered in the
`test:` recipe (`just test`); the matching `Run bats (justfile brace syntax gate)`
step in `.github/workflows/unit-tests.yml` is still to land — that workflow names
each bats file explicitly and never calls `just test`, so until the step lands the
gate only runs locally. `just check`'s existing `just --fmt --check` already covers
the "parses as written" half, and the bats suite is what names the failure mode.

One trap when reproducing a reported column number: `just` points at the offending
token in the file **as it parses**, so if a consumer downstream collapses braces
before `just` ever sees the file, the column will not match this repo. Check the
column against `main` before assuming this repo shipped the bad bytes.

## Testsuite SHA pin

`common/.github/workflows/run-testsuite.yml` pins the testsuite SHA for all repo-local callers. When the pin lags behind `main`, quarantined scenarios may run and cause spurious failures. `common` has Renovate configured (`renovate.json`) but the testsuite SHA pin may need manual updates when testsuite fixes land — check `chore(deps): update` Renovate PRs.

## Red Flags

- Using `:testing` as the compose base for `pr-e2e.yml` (causes false failures from unrelated downstream churn).
- A `workflow_run` trigger fix pushed only to `testing` (default-branch constraint means it has no effect until it reaches `main`).
- The `promote-to-testing` job running on branches other than `main` (double-promotion risk).
- An unanchored `--certificate-identity-regexp` wildcard in cosign verify.
- A bare, unescaped Go-template placeholder (`{{.`, `{{ .Repository }}`, `{{json .}}`) in any `*.just` recipe (see "Go templates in justfile recipes"), and a `}}}}` anywhere in one.

## Verification

- [ ] `pr-e2e.yml` uses a stable (not `:testing`) base image.
- [ ] `run-testsuite.yml` SHA pin matches the testsuite commit being relied on.
- [ ] Promotion `promote-to-testing` job is gated on `head_branch == 'main'`.
- [ ] cosign identity regexp is anchored with `^...$`.
- [ ] `bats tests/test_justfile_syntax.bats` passes if any `*.just` changed.

## References

| File | Description |
|---|---|
| [`references/promotion-patterns.md`](references/promotion-patterns.md) | `promote-to-testing` job pattern, TOCTOU guard, cosign verify anchoring, and cosign install on GHA runners. |
| [`references/never-stall-design.md`](references/never-stall-design.md) | Promotion gate never-stall design: E2E on testing branch, feedback trigger, jq selector, and bluefin bootstrap. |
