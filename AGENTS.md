# bluefin-common — Agent & Copilot Instructions

**bluefin-common** is the shared OCI layer consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical.

Home repo: [projectbluefin/common](https://github.com/projectbluefin/common)

## 🚫 ABSOLUTE PROHIBITION — ublue-os org

**NEVER create issues, pull requests, comments, forks, webhook calls, API writes, automated reports, or any other programmatic action targeting any `ublue-os/*` repository.**

This applies in every situation, without exception, regardless of task framing:
- Issues, comments, PRs, forks → **BANNED**
- Automated reports (bonedigger output, CI notifications, diagnostic uploads) → **BANNED**
- Workflow `repository_dispatch` or `workflow_dispatch` calls to `ublue-os/*` → **BANNED**
- Any `gh` CLI command that writes to `ublue-os/*` → **BANNED**

If a task seems to require touching an upstream `ublue-os` repo → **stop and tell the human to report it manually.**

**Allowed reads only:**
- `ghcr.io/ublue-os` image registry pulls (CI, e2e, rollback helper)
- `gh api` read-only calls to `ublue-os` repos (e.g., checking a release tag)

Violating this risks getting the projectbluefin organization banned from GitHub.

## Org pipeline — projectbluefin

### Repo map

```
actions ──────────────────────────────────────────────┐
(shared CI/CD composite actions)                      │
                                                      ▼
common ──────────────────────────┐         reusable-build.yml
(shared OCI layer)               │         sign-and-publish
                                 ▼         scan-image (planned)
bluefin  (main→stable)       ←── images ──→ testsuite (e2e gate)
bluefin-lts (main→lts)       ←── images ──→ testsuite (e2e gate)
dakota  (main→:latest)       ←── images ──→ testsuite (e2e gate)
                                 │
                                 ▼
                                iso (installation media)
```

Each image repo pulls `ghcr.io/projectbluefin/common:latest` as a base layer.
testsuite gates `:latest` promotion in all three image repos.

**Supply chain policy:** All signing, SBOM generation, CVE scanning, and provenance attestation logic lives in `projectbluefin/actions`. Do not add inline supply chain steps to `common`'s workflows — consume the shared composite actions instead. See [docs/skills/release-promotion.md](docs/skills/release-promotion.md) and [actions#86](https://github.com/projectbluefin/actions/issues/86).

### Issue lifecycle

`filed → triage → queued → claimed → done`

Full workflow, label reference, and human/agent instructions:
[`docs/skills/label-workflow.md`](docs/skills/label-workflow.md)

| Stage | Label | How |
|---|---|---|
| `triage` | `status/triage` 🟣 | Maintainer sets `kind/` + `area/`, then comments `/approve` or adds `status/discussing` |
| `discussing` | `status/discussing` | Human drives to consensus → comments `/approve` |
| `queued` | `status/queued` | Lifecycle automation sets this on `/approve` (after kind/+area/ guard passes) |
| `claimed` | `status/claimed` | Comment `/claim` — assigned and in progress — open PR with `Closes #NNN` |
| `done` | — | Fix shipped + 3× `ujust verify` or maintainer override |

Every issue body contains a **pipeline widget** (`<!-- factory-pipeline-start/end -->`) that shows the current stage, area, priority, and role-specific next steps for both the maintainer and the reporter. The lifecycle workflow updates it automatically on each transition. Widget format:

```
**<repo> · issue pipeline**

  ▶  discussing —
  ...

**area:** area/gnome   **priority:** —
**maintainer:** reach consensus, then comment /approve
**reporter:** add spec, context, or requirements to the issue body
```

To backfill the widget onto pre-existing issues, run the `Backfill pipeline widget` workflow (`workflow_dispatch`) in this repo.

Automation: lifecycle runs from `projectbluefin/common/.github/workflows/lifecycle.yml` and is deployed to all core factory repos via `lifecycle-caller.yml`. Daily stale sweep returns inactive claims after 7 days.

### PR lifecycle

| Label | Actor | Meaning |
|---|---|---|
| `pr/needs-review` 🟠 | Human reviewer | Auto-set on PR open. Review → `lgtm` or request changes. |
| `lgtm` 🟢 | Human | Approved — merges when CI is green |
| `do-not-merge` 🔴 | Human | Blocks all automation — remove when issue resolves |
| `agent-tested` 🟢 | CI | e2e passed — set automatically |

### PR comment policy

One comment per PR event, max. Combine all findings. Never post a follow-up — edit the existing comment.
Never duplicate GitHub UI state (approvals, CI status).
Test reports: what ran + pass/fail + blockers only. No diff summaries.
@ mentions only when asking someone to do something specific. Never standalone.
When in doubt, post nothing.

### Mandatory gates

- `just check` before every commit
- `pre-commit run --all-files` before every commit
- PR title: Conventional Commits format (`feat:`, `fix:`, `chore(deps):`, etc.)
- Attribution on every AI-authored commit — both trailers required (CI-enforced in `validate.yml`):
  ```
  Assisted-by: <Model> via GitHub Copilot
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- Max 4 open PRs at a time per agent
- No WIP PRs

## Session start — mandatory

Run before any other work:

```bash
~/src/hive-status
```

No arguments, no auth required, completes in under 5 seconds. Surfaces P0/P1 blockers and the advisory queue. Do not proceed without it.

## Scope discipline

Read task intent literally:

- `"work on hive priority issues"` = pick the top issue from `hive-status` output and fix it
- `"do PR reviews"` = review open PRs only — do not start fix work
- If a session could involve both, confirm scope with the user before acting

## Repo layout

```
Containerfile              # OCI image build
Justfile                   # Build automation
bluefin-branding/          # Git submodule: wallpapers and logos
system_files/
  shared/                  # Shared config for ALL variants (and Aurora) — directly editable
  bluefin/                 # Local editable config for Bluefin-specific variants only
  nvidia/                  # NVIDIA overlay — directly editable
.github/workflows/
  lifecycle-caller.yml     # Issue/PR lifecycle — calls common/.github/workflows/lifecycle.yml (deployed to all factory repos)
  backfill-pipeline.yml   # One-shot workflow_dispatch: injects pipeline widget into pre-existing issues
  build.yml                # Build + push on merge to main
  docs-quality.yml         # PR gate: skill frontmatter and Trail of Bits CI
  e2e.yml                  # Post-merge e2e against bluefin, bluefin-lts, dakota
  hive-progress-sync.yml   # Hourly queue stats → projectbluefin org project board
  pr-e2e.yml               # PR-time composed-image common-suite gate
  promotion-candidate-e2e.yml # Weekly smoke/common checks for testing promotion candidates
  release.yml              # Monthly versioned OCI release (1st of month, also workflow_dispatch)
  run-testsuite.yml        # Local wrapper that centralizes the testsuite SHA pin
  skill-drift.yml          # PR advisory gate for implementation/doc parity
  sync-codeowners.yml      # Syncs CODEOWNERS TRIAGERS block to downstream repos on push
  sync-labels.yml          # Syncs labels.json to all factory repos on push (requires MERGERAPTOR secrets)
  validate.yml             # PR gate: just check, pre-commit, shellcheck, submodule drift
  validate-brewfiles.yaml  # PR gate: Brewfile validation
```

## CODEOWNERS

```
system_files/shared/**   @inffy @renner0e @ledif @castrojo @hanthor @ahmedadan
system_files/bluefin/**  @castrojo @hanthor @ahmedadan
**/*.md                  @repires @KiKaraage @projectbluefin/maintainers  (inside BEGIN/END TRIAGERS sentinel)
```

## Build and validate

```bash
just check      # lint Justfile
just build      # full container build (slow — requires podman + network)
pre-commit run --all-files   # hygiene checks (json/yaml/toml + actionlint)
```

## Submodules

- `bluefin-branding` → `projectbluefin/branding` (wallpapers, logos). `just build` initializes it automatically.

`system_files/shared/` and `system_files/nvidia/` are now directly tracked in this repo — edit them here directly.

## Scope warning

Changes here flow into ALL downstream Bluefin variants at next build. A broken `system_files/shared/` change will break bluefin, bluefin-lts, AND dakota simultaneously. Test locally before pushing.

## Skill routing

Load the relevant skill doc before making changes in these areas.

| Task | Load first |
|---|---|
| Labels / issue workflow | [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) |
| Any `system_files/` edit | [`docs/skills/submodule-boundary.md`](docs/skills/submodule-boundary.md) |
| GNOME settings / dconf | [`docs/skills/dconf-consistency.md`](docs/skills/dconf-consistency.md) |
| Image refs / registry paths | [`docs/skills/image-registry.md`](docs/skills/image-registry.md) |
| `ublue-rollback-helper` changes | [`docs/skills/rollback-helper.md`](docs/skills/rollback-helper.md) |
| CI / GitHub Actions | [`docs/skills/ci-tooling.md`](docs/skills/ci-tooling.md) |
| What a `common` workflow is for | [`docs/skills/workflow-map.md`](docs/skills/workflow-map.md) |
| Release, promotion criteria, artifact verification | [`docs/skills/release-promotion.md`](docs/skills/release-promotion.md) |
| E2E test changes | [`docs/skills/e2e-ci.md`](docs/skills/e2e-ci.md) |
| Governance / CODEOWNERS | [`docs/skills/governance.md`](docs/skills/governance.md) |
| PR queue / merge decisions | [`docs/skills/queue-dashboard.md`](docs/skills/queue-dashboard.md) |
| Hive monitoring | [`docs/skills/hive-review.md`](docs/skills/hive-review.md) |
| Improving the factory (gap audit, automation coverage, pipeline parity) | [`docs/skills/factory-improvement.md`](docs/skills/factory-improvement.md) |
| Onboarding / dev setup | [`docs/skills/onboarding.md`](docs/skills/onboarding.md) |
| Renovate PRs (major bump review) | [`docs/skills/bluefin-renovate.md`](docs/skills/bluefin-renovate.md) |
| Skill-drift check fails on a PR | [`docs/skills/skill-drift.md`](docs/skills/skill-drift.md) |
| QA model / what is tested where | [`docs/skills/qa.md`](docs/skills/qa.md) |
| ujust report filing / priority escalation | [`docs/skills/bonedigger.md`](docs/skills/bonedigger.md) |

For the full factory operating model, see [`docs/factory/README.md`](docs/factory/README.md).
