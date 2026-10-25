# Project Bluefin Factory

**This is an OS factory. The product is bootc OCI images.**

Org-level entry point for agents and maintainers working across the Project
Bluefin factory. Everything here is measured against the live org; nothing here
is aspirational. If a statement in this file cannot be traced to a file in a
checkout or to a GitHub API response, it is a bug — delete it.

## Reference read order

1. Target repo `AGENTS.md` — local authority, start here
2. This file — org map and what "on the factory workflow" actually means
3. [`agentic-model.md`](agentic-model.md) — cross-repo hard rules, branch targets, PR policy
4. Relevant `docs/skills/*` — lazy-load per task; [`docs/SKILL.md`](../SKILL.md) is the router

New or relocated agents follow [`factory-onboarding.md`](../skills/factory-onboarding.md):
verify the target repository first, attach `common` as a pinned shared-contract
sidecar, never let the sidecar override local authority.

## Operating principle

Humans approve design, security, and merge. Image build and promotion are
automated. **Triage is not** — it is human, and it is currently the bottleneck.

Triage state changes continuously. Query live factory status and work queue before planning:

```bash
# via the projectbluefin MCP server
get_factory_status()
get_work_queue()
```

## Mission and product boundary

- Factory org: `projectbluefin` — 52 repositories, 13 archived, **39 live**
- Product: bootc-based OCI images and the automation that builds, validates, and promotes them
- Shared layer repo: [`common`](https://github.com/projectbluefin/common)
- Production image registry: `ghcr.io/projectbluefin/*` — see [`image-registry.md`](../skills/image-registry.md)

### What consumes `common`

```text
common
  ├─→ bluefin       OCI layer  — Containerfile ARG COMMON_IMAGE=ghcr.io/projectbluefin/common:latest
  ├─→ bluefin-lts   OCI layer  — Justfile common_image, same ref
  ├─→ dakota        git source — elements/bluefin/common.bst, pinned ref, plus 2 carried patches
  └─→ iso           git clone at build time, for Brewfiles
```

`dakota` consumes `common` through BuildStream, not through the OCI layer, so
it is invisible to a `Containerfile`/`Justfile` grep. `elements/bluefin/common.bst`
declares `kind: git_repo`, `url: github:projectbluefin/common.git`, `track: main`,
pinned at an explicit `ref`, and installs `system_files/shared/usr` and
`system_files/bluefin/usr` into the image root. It also carries two local
patches against `common` (`patches/common/0001-fastfetch-install-date.patch`,
`0002-ghostty-dual-theme.patch`), each marked to be dropped once `common`
ships the behaviour upstream. Those patches are a standing fork risk: a change
to `common`'s fastfetch layout or Ghostty theming can break `dakota`'s build
without touching anything `dakota` owns.

```bash
gh api "repos/projectbluefin/dakota/contents/elements/bluefin/common.bst?ref=testing" \
  --jq .content | base64 -d
```

### Propagation is manual

`bluefin` and `bluefin-lts` each ship `.github/workflows/track-common.yml`,
which skopeo-inspects `ghcr.io/projectbluefin/common:latest`, compares against
`image-versions.yml`, and opens a `chore(deps): update common digest` PR against
`testing`. Its only triggers are `repository_dispatch: [common-updated]` and
`workflow_dispatch`.

**Nothing in `common` sends that dispatch.** A grep of `.github/workflows/`
returns no `repository_dispatch` sender. In practice the only live trigger is a
human running the workflow by hand, so downstream pickup of a `common` change
is manual despite looking event-driven.

### Pipeline repos

| Repo | Role |
|---|---|
| `common` | Shared OCI layer and cross-repo factory documentation |
| `bluefin` | Mainline image streams |
| `bluefin-lts` | LTS image streams, built on CentOS |
| `dakota` | BuildStream pipeline — "the buildstream for making Bluefin" |
| `dakota-iso` | Bootable UEFI live ISO for Dakota (fork of `tuna-os/dakota-iso`, fully managed) |
| `iso` | Bluefin installation media |
| `actions` | Shared GitHub Actions and 16 reusable workflows |
| `testsuite` | Cloud-native QA pipeline — Argo Workflows, KubeVirt, qecore/behave |
| `lab` | A second QA pipeline with near-identical description to `testsuite` |
| `review` | Review appliance and Hive contributor worker |
| `bonedigger` | `ujust report` intake and issue-lifecycle bot |
| `knuckle` | Flatcar/CoreOS homelab deployment TUI; also hosts the hosted-Hive runbook at `docs/HIVE-DEPLOYMENT.md` |

`lab` and `testsuite` are two live QA pipelines whose descriptions barely
differ. Which one gates which promotion is not recorded anywhere in this repo.
That is an open question, not a documented design.

### Repos the factory docs do not cover

`documentation`, `website`, `server`, `utah`, `utah-packages`, `bluespeed`,
`fsdk-containers`, `finpilot`, `bluefin-bling`, `chairlift`,
`renovate-config`, `housekeeping`, `hive-lore`, `.github`, `.project`, and the
GNOME-extension forks. Several are heavily automated. Their absence from the
factory docs is a documentation gap, not evidence that they are out of scope.

Three specific corrections to long-standing claims:

- `knuckle` is a Flatcar/CoreOS homelab deployment TUI, **not** a bootc installer.
- `housekeeping` is live and public, described as "org-wide maintenance
  workflows", and ships **zero workflows**. It is an empty shell, not a
  "deprecated placeholder".
- `hive-lore` is **not** Hive infrastructure. It is video-credit copy for a
  YouTube series, and its own `AGENTS.md` declares its stated purpose "obsolete
  and revoked".

### Archived — never document these as live

`bluefinctl`, `homebrew-bluefinctl`, `bootc-installer`, `fisherman`,
`bluefin-mcp`, `testhub`, `bluefin-coreos-test`, `bluefin-coreos-test-again`,
`dakota-old`, `brew`, `testfin`, `wolfifin`, `wolfi-gnome`.

`bluefinctl` and its Homebrew tap were retired on 2026-09-13. It shipped in no
image, `chairlift` replaces it, and `common`'s `brew-preinstall` uninstalls it
from existing systems automatically. The guards that keep it out are documented
in [`brew-lifecycle/SKILL.md`](../skills/brew-lifecycle/SKILL.md) — do not
delete them as dead references.

### Forks

11 live repos are forks. Fork status says nothing about management: `chairlift`
(`frostyard/chairlift`) and `dakota-iso` (`tuna-os/dakota-iso`) are forks and
are among the most conformant repos in the org.

The six GNOME-extension forks — `gnome-shell-extension-caffeine`,
`gnome-shell-extension-gsconnect`, `gradia-capture`, `search-light`,
`custom-command-menu`, `bazaar-companion` — are on **no consumption path**.
`common` enables those extensions by their *upstream* UUIDs and submodules
`custom-command-list@storageb.github.com` directly from
`github.com/StorageB/custom-command-menu.git`. The org forks are bypassed
entirely. Do not treat them as factory repos.

## What "on the factory workflow" means

A repository is on the workflow when it has all of:

1. The seven canonical workflow-state labels — [`label-workflow.md`](../skills/label-workflow.md)
2. `AGENTS.md` at the repo root — the local authority
3. `.github/copilot-instructions.md` — a thin pointer, not duplicated policy
4. `.github/CODEOWNERS`
5. An issue form under `.github/ISSUE_TEMPLATE/`

Measure it; do not assume it:

```bash
python3 scripts/factory-conformance.py          # full matrix
python3 scripts/factory-conformance.py --gaps   # worst offenders first
python3 scripts/factory-conformance.py --json   # machine-readable
```

Adoption is measured dynamically via `scripts/factory-conformance.py`. Do not rely on historical snapshot tables; run the script against target repositories to evaluate current conformance before assuming workflow-state labels, `AGENTS.md`, or `CODEOWNERS` are configured.

### Nothing enforces it

`projectbluefin/actions` ships
`.github/workflows/reusable-design-enforcement.yml` — "Enforce the seven-label
issue and review workflow". It is the only automation in the org that
implements the label contract.

**Exactly one repository calls it: `projectbluefin/finpilot`**
(`.github/workflows/label-enforcement.yml`). Not `bluefin`, not `dakota`, not
`common` itself.

```bash
gh search code --owner projectbluefin "reusable-design-enforcement" \
  --json repository,path --jq '.[]|"\(.repository.nameWithOwner) \(.path)"'
```

So the seven-label workflow is documented in `common`, enforced in one repo,
and partially adopted in sixteen more. The enforcement mechanism already
exists and is simply not wired up — that is the cheapest available lever on
factory conformance, and it is a one-file change per repo.

### Issue forms are not uniform either

`common` and `chairlift` ship one form. `bluefin`, `bluefin-lts`, `dakota`, and
`knuckle` each ship five (`bug-report`, `config`, `feature-request`,
`help-this-project`, `pin`). Any doc describing "a single issue form per repo"
as the factory standard is describing two repos.

Note that `config.yml` is the template-chooser config, not a form. Counting it
as a deprecated legacy template has caused repeated confusion.

There are **no org-wide inherited defaults** to fall back on:
`projectbluefin/.github` ships zero issue templates and zero workflow
templates, so every per-repo gap above is a real gap. It does ship its own
`AGENTS.md`, which is a *competing* org contract — it never mentions the seven
labels, triagers, or CODEOWNERS. Reconciling the two contracts is unfinished
work.

Gaps become GitHub issues, not rows in this file.

## Label reality

The seven canonical labels are **workflow-state** labels. They are not the only
labels, and claiming otherwise has been a recurring source of drift. Live repos
also run, undocumented until now:

- `agent/*` role routing — `architect`, `quality`, `security`, `ci-maintainer`, `scanner`, `contributor`, `strategist`
- Classification — `quality`, `testing`, `tech-debt`, `architecture`
- Operational — `lgtm`, `automerge`, `chore/deps`, `needs-human`
- Hive routing — `hive/hosted-projectbluefin-knuckle-gjvq`

`documentation` (70 labels) and `website` (41) run a different dialect
altogether: `queue/*`, `needs-human/*`, `size:*`, `priority/p*`. `lab` (79
labels) runs both systems at once. Full per-repo sets:
[`label-workflow.md`](../skills/label-workflow.md).

## Merge gates

For `common`, enforced by ruleset `main — merge queue` (id 17513003), active,
**zero bypass actors**, with classic branch protection absent:

- 2 required approving reviews
- `require_code_owner_review: false` — **CODEOWNERS assigns reviewers; it does not gate merges**
- 3 required status checks: `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)`
- Merge queue, squash-only, `ALLGREEN` grouping, 90-minute check timeout

Nobody can push directly to `main`; there is no doc-only exception. Every change requires a PR through the merge queue.

A docs-only PR merges without friction: `build.yml` ignores markdown and doc paths (`*.md`, `docs/**`, `AGENTS.md`), so the Build checks are skipped and `validate` is the required check that runs.

Merge settings are **not** uniform across the org. Squash-only with
delete-branch-on-merge holds for `common`, `bluefin`, `bluefin-lts`, `dakota`,
`review`, and `knuckle`. `actions`, `testsuite`, and `iso` also allow merge
commits and rebase; `testsuite` and `iso` do not delete branches on merge.

There is **no** `factory-operations` environment. `bluefin`, `bluefin-lts`, and
`dakota` each have environments named `copilot` and `production`, and
`production` has **zero protection rules**. Claims of a two-human environment
gate on promotion are unfounded; the two-approval gate that does exist is the
ruleset on `main`.

### Branch protection across the org

Branch protection varies by repository. Classic branch protection (`branches/<default>/protection`) returns 404 when rulesets govern the branch, so always probe `repos/<repo>/rulesets`:

```bash
gh api repos/projectbluefin/<repo>/rulesets --jq '.[] | select(.enforcement=="active") | .name'
```

Two repos without ruleset protection carry notable blast radius:

- `branding` is a git submodule of `common` and sits in the image build path.
- `renovate-config` holds the GitHub App token with `Contents: Read & Write`
  and `autodiscover` across `projectbluefin/*`.

For both, the lever is a ruleset on `main`. A CODEOWNERS file buys reviewer
routing only — `require_code_owner_review` is `false` wherever it has been
measured, so CODEOWNERS never gates a merge anywhere in this org.

## Factory parity

Parity is live state. A hand-maintained table drifts and a generated one is a
table nobody regenerates, so ask GitHub:

```bash
python3 scripts/factory-conformance.py --gaps
```

Swap in any path you care about:

```bash
for repo in common bluefin bluefin-lts dakota actions testsuite review; do
  printf '%-14s ' "$repo"
  gh api "repos/projectbluefin/$repo/contents/.pre-commit-config.yaml" \
    >/dev/null 2>&1 && echo yes || echo "--"
done
```

## Open gaps

Tracked as GitHub issues, never in this file.

```bash
# Awaiting triage across the factory
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

Protocol for filing factory issues:
[`factory-improvement/SKILL.md`](../skills/factory-improvement/SKILL.md).

## Sensitive paths (require maintainer review)

- All repos: `.github/workflows/`, `Justfile`, `build_files/`
- `dakota` only: `elements/`
- `review` only: `image/`, `deploy/`
