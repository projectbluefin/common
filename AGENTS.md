# projectbluefin/common — Agent & Copilot Instructions

**common** is the shared OCI layer consumed by all Bluefin image variants **and the canonical
coordination hub for the entire OS factory.** Changes to `system_files/` propagate to
`bluefin`, `bluefin-lts`, and `dakota`. Stay surgical on OCI changes.

> **Agent entry point:** When starting any projectbluefin task, read this file first.
> Full skill docs: [`docs/skills/INDEX.md`](docs/skills/INDEX.md)
> Factory operating model: [`docs/factory/agentic-model.md`](docs/factory/agentic-model.md)

---

## The Factory — 5 repos, one agentic whole

| Repo | Role | Default PR target |
|---|---|---|
| [bluefin](https://github.com/projectbluefin/bluefin) | Fedora-based desktop image (main + nvidia) | `testing` (never `main`) |
| [bluefin-lts](https://github.com/projectbluefin/bluefin-lts) | CentOS-based LTS variant | `main` (`main→lts` promotion) |
| [common](https://github.com/projectbluefin/common) | Shared OCI layer + org brain | `main` |
| [dakota](https://github.com/projectbluefin/dakota) | CoreOS-model image (BuildStream 2) | `testing` (never `main`) |
| [knuckle](https://github.com/projectbluefin/knuckle) | Flatcar TUI installer | `main` |

All five share: squash-only merge, same label taxonomy, same pre-commit hooks, same issue
templates, and this AGENTS.md org pipeline section.

### Data flow

```
common (shared OCI layer + org brain)
  │
  ├─→ bluefin  (main → testing → stable)  ──→ testsuite (e2e gate)
  ├─→ bluefin-lts (main → lts)            ──→ testsuite (e2e gate)
  └─→ dakota   (main → testing → latest)  ──→ testsuite (e2e gate)
                                                    │
                                                    └─→ iso (installation media)
                                                         └─→ knuckle (installer)
```

Each image repo pulls `ghcr.io/projectbluefin/common:latest` as a base layer.

### Adjacent projects (outside factory scope)

Do not pull these into factory planning, hive cycles, or project board items.

| Repo | Purpose |
|---|---|
| [testing-lab](https://github.com/projectbluefin/testing-lab) | QA pipeline — Argo Workflows + KubeVirt + behave/dogtail smoke tests |
| [bluespeed](https://github.com/projectbluefin/bluespeed) | CNCF homelab reference — OTel + Loki + Prometheus + KubeVirt |

---

## Agent operating rules (hard)

- **Read this file first.** Every factory repo has an AGENTS.md — read it before touching the repo.
- **No castrojo fork.** Push branches directly to `projectbluefin/<repo>`, open PRs with
  `gh pr create --repo projectbluefin/<repo>`. No fork.
- **Attribution on every AI commit:** `Assisted-by: <Model> via <Tool>` — exactly one trailer.
- **Squash only.** Never merge-commit or rebase-merge.
- **`just check` before every commit.**
- **Max 4 open PRs per agent at once.**
- **No WIP PRs.**
- **common changes are amplified.** A broken `system_files/shared/` change breaks bluefin,
  bluefin-lts, AND dakota simultaneously. Test locally before pushing.

---

## Skill routing

Find the right skill doc in [`docs/skills/`](docs/skills/) before starting any factory task.

| Task | Skill file |
|---|---|
| Build, validate, open a PR | [`bluefin-build.md`](docs/skills/bluefin-build.md) |
| CI failure triage | [`bluefin-ci.md`](docs/skills/bluefin-ci.md) |
| Package add/remove/update | [`bluefin-packages.md`](docs/skills/bluefin-packages.md) |
| LTS-specific work | [`bluefin-lts.md`](docs/skills/bluefin-lts.md) |
| ISO build or promotion | [`bluefin-iso.md`](docs/skills/bluefin-iso.md) |
| Release / stream tags | [`bluefin-release.md`](docs/skills/bluefin-release.md) |
| Renovate PRs | [`bluefin-renovate.md`](docs/skills/bluefin-renovate.md) |
| Security / COPR / cosign | [`bluefin-security.md`](docs/skills/bluefin-security.md) |
| Variant matrix questions | [`bluefin-variants.md`](docs/skills/bluefin-variants.md) |
| Any dakota `.bst` work | [`dakota-buildstream.md`](docs/skills/dakota-buildstream.md) |
| Dakota CI failure | [`dakota-ci.md`](docs/skills/dakota-ci.md) |
| Dakota add package | [`dakota-add-package.md`](docs/skills/dakota-add-package.md) |
| Dakota remove package | [`dakota-remove-package.md`](docs/skills/dakota-remove-package.md) |
| Dakota update refs | [`dakota-update-refs.md`](docs/skills/dakota-update-refs.md) |
| Dakota build failure | [`dakota-debugging.md`](docs/skills/dakota-debugging.md) |
| Dakota orientation | [`dakota-overview.md`](docs/skills/dakota-overview.md) + [`dakota-agent-quickstart.md`](docs/skills/dakota-agent-quickstart.md) |
| Knuckle QA | [`knuckle-qa.md`](docs/skills/knuckle-qa.md) |
| Knuckle release | [`knuckle-release.md`](docs/skills/knuckle-release.md) |
| Hive triage / P0/P1 work | [`hive.md`](docs/skills/hive.md) |
| Governance / CODEOWNERS | [`governance.md`](docs/skills/governance.md) |
| Full index | [`docs/skills/INDEX.md`](docs/skills/INDEX.md) |

---

## Issue lifecycle

```
filed → approved → queued → claimed → done
```

| Stage | How |
|---|---|
| `filed` | Issue opened |
| `approved` | Maintainer adds `status/approved` or comments `/approve` |
| `queued` | `queue/agent-ready` label added |
| `claimed` | Agent comments `/claim` — gets assigned, removed from pool |
| `done` | Fix shipped + verified |

No PR activity in 7 days returns a claimed issue to the queue automatically.

### Finding work

```bash
# P0 blockers — start here
gh search issues --label "hive/p0" --owner projectbluefin --state open

# P1 this-cycle
gh search issues --label "hive/p1" --owner projectbluefin --state open

# Ready for pickup
gh search issues --label "queue/agent-ready" --owner projectbluefin --state open
```

---

## Hive label taxonomy

All 5 factory repos share this label set. Use `hive/` labels to find hive-tracked work.

### Hive priority (dynamic — reset each cycle)

| Label | Color | Meaning |
|---|---|---|
| `hive/p0` | 🔴 `#d93f0b` | Release blocker — fix before next promotion |
| `hive/p1` | 🟠 `#e4a117` | Must land this cycle |

`hive/p0` ≠ `priority/p0`: the former is the hive formation actively tracking a blocker
*right now*. An issue can carry both.

### Queue labels

| Label | Meaning |
|---|---|
| `queue/agent-ready` | Ready for an agent to pick up |
| `queue/claimed` | Agent has claimed this issue |
| `queue/hold` | Do not merge/close yet |
| `agent/blocked` | Agent blocked — needs human input |

### Priority labels (static backlog)

| Label | Meaning |
|---|---|
| `priority/p0` | Repo-level blocker |
| `priority/p1` | Must land soon |
| `priority/p2` | Backlog |

### Source labels

| Label | Meaning |
|---|---|
| `source:agent` | Filed or created by an agent |
| `source:manual` | Filed by a human |
| `source:gha` | Filed by GitHub Actions |

### Hive sync workflows

| Repo | Workflow | Schedule |
|---|---|---|
| `dakota` | `hive-status-sync.yml` | `:00 hourly` |
| `bluefin` | `hive-progress-sync.yml` | `:15 hourly` |
| `common` | `hive-progress-sync.yml` | `:20 hourly` |
| `knuckle` | `hive-progress-sync.yml` | `:30 hourly` |
| `bluefin-lts` | `hive-progress-sync.yml` | `:45 hourly` |

All post to the org project board at https://todo.projectbluefin.io.
`PROJECT_TOKEN` secret required in each repo.

---

## Org project board

**URL:** https://todo.projectbluefin.io → https://github.com/orgs/projectbluefin/projects/2

| Field | Options |
|---|---|
| Status | Todo / In Progress / Blocked / Backlog / Done |
| Priority | P0 (release blocker) / P1 (this cycle) / P2 (backlog) |
| Size | XS / S / M / L / XL |
| Component | Core OS / Dakota / Installer / Homelab / Dev Experience / Documentation / Infrastructure |

**Component → repo mapping:**
- **Core OS** — bluefin, common, bluefin-lts
- **Dakota** — dakota
- **Installer** — knuckle, iso
- **Documentation** — projectbluefin/documentation, website
- **Homelab** — bluespeed, MCP servers *(adjacent — outside factory scope)*

**API gotchas:**
- `updateProjectV2Field` needs `singleSelectOptions` (not `singleSelectOptionUpdates`)
- Cannot rename Status options via API — use the UI
- `addSubIssue` works cross-org ✓; errors with "may only have one parent" = already parented
- Use Python + `--input -` + `json.dumps` for mutations with complex query strings

---

## PR comment policy

One comment per PR event, max. Combine all findings. Never post a follow-up — edit the
existing comment instead.
Never duplicate GitHub UI state (approvals, CI status).
Test reports: what ran + pass/fail + blockers only. No diff summaries.
`@` mentions only when asking someone to do something specific. Never standalone.
When in doubt, post nothing.

---

## Mandatory gates

- `just check` before every commit
- PR title: Conventional Commits format (`feat:`, `fix:`, `chore(deps):`, etc.)
- Attribution on every AI-authored commit: `Assisted-by: <Model> via <Tool>`
- Max 4 open PRs at a time per agent
- No WIP PRs

---

## This repo (common) layout

```
Containerfile              # OCI image build
Justfile                   # Build automation
system_files/
  shared/                  # Config applied to ALL Bluefin variants (and Aurora)
  bluefin/                 # Config applied to Bluefin-specific variants only
docs/
  factory/                 # Factory operating model, migration status, gap analysis
  skills/                  # Agent skill docs — canonical source for all factory skills
.github/workflows/
  build.yml                # Build + push on merge to main
  e2e.yml                  # Post-merge e2e against bluefin, bluefin-lts, dakota
  validate-just.yml        # PR gate: just check
  validate-brewfiles.yaml  # PR gate: Brewfile validation
```

## CODEOWNERS

```
system_files/shared/**   @inffy @renner0e @ledif @castrojo @hanthor @ahmedadan
system_files/bluefin/**  @castrojo @hanthor @ahmedadan
```

## Build and validate

```bash
just check      # lint Justfile (mandatory pre-commit gate)
just build      # full container build (slow — requires podman + network)
pre-commit run --all-files   # hygiene checks (json/yaml/toml + actionlint)
```

## Submodule

`bluefin-branding` → projectbluefin/branding (wallpapers, logos). `just build` initializes it.
