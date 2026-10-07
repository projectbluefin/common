# bonedigger — Full Loop & Component Reference

Part of [bonedigger](../SKILL.md) — the closed improvement loop, per-component responsibilities, integration status, and template sync.

## The full loop

bonedigger and kubestellar-bot together form the closed improvement loop that drives Bluefin 2.0:

```
user runs ujust report
  └─ bonedigger agent collects selected diagnostics
       └─ scrubs PII on-device and previews the payload
            └─ creates a structured issue in the owning repo
                 └─ human accepts implementation under that repo's contract
                      └─ Hive coordinates eligible, assigned work
                           └─ dispatches agent to implement fix
                                └─ PR opened where changed code is owned
                                     └─ merged → delivery → verification
                                          └─ better bonedigger
                                               └─ loop
```

## bonedigger - what it does

bonedigger has two functions:

1. **ujust report intake** - detects the diagnostic signature of an issue filed
   via `ujust report` on a live system
2. **Confirmation tracking** - records `ujust report --confirm` counts on the
   issue so triage can see how many machines are affected. Confirmations are
   evidence for a human priority call, not a label transition.

**Packaging note:** in common, keep `ujust report` as a thin recipe wrapper in
`system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` and put the
real shell implementation in `/usr/libexec/bonedigger-report`. Keep the
`BONEDIGGER_VERSION` line in the Justfile because Renovate watches that path.

### Creating a report

`ujust report` begins by asking the user's intent: report a bug, get help,
request a feature, or confirm an existing issue. Help points to Bluefin
Discussions without creating an issue. Feature requests always target
`projectbluefin/common`; bugs use the image mapping below and show that target
before collecting data.

Bug reports collect a short title, description, and reproduction steps, then
offer zero or more bounded smart-log profiles: desktop/graphics, sleep/crash,
update/boot, networking, Flatpak/application, and Hardware. The baseline
report is at most 64 KiB; each profile is at most 500 KiB and all selected
profiles total at most 2 MiB. Collection is an allowlist of targeted commands,
and journal output uses the on-device redaction functions. OTel capture is
not part of this flow.

Every bug-report baseline also includes a compact hardware overview (CPU
model, GPU identity, memory, disk model and size, and network interface
list) so a maintainer can see the machine the bug came from without the user
having to opt in to a profile (`common#1338`).

Every payload is previewed locally. Submission requires explicit consent,
uses `gh issue create` rather than a browser form, and offers final-submission
automation preferences (`Human interaction only`, `Machine analysis is welcome`, or `No preference`).
GitHub silently drops labels requested by reporters without repository triage
access, so the client also records a validated
`automation-preference` marker in the issue body, including `none` when
normal triage is selected (legacy submissions used `bonedigger-queue-preference`).
The write-enabled Bonedigger intake workflow initializes current stages and preserves preferences.
Selected smart logs are
published to a public gist only after that preview and consent. `gh` is
required and authenticated; if it is absent, the user can consent to
`brew install gh`. Failed or declined submissions retain a draft and print its
exact `ujust report --resume …` command. The visible `ujust report` report
heading remains the intake compatibility marker rather than making issue
creation depend on a label.

Common uses its own intake and acceptance contract: do not request retired
numbered queue labels there. Machine-analysis consent does not accept
implementation; the server initializes current stages and preserves preferences.
Legacy `bonedigger-queue-preference` markers on existing reports remain preference
data, not active queue labels. See [`label-workflow.md`](../../label-workflow.md).

### Confirm an existing issue

Use `ujust report --confirm <issue-number-or-url>` when the current system is
affected by an existing issue. This mode previews and posts a lightweight
fingerprint (image, version/digest, kernel, architecture, and failed units)
with `gh issue comment`. It does not collect OTel data, create a gist, or
derive an identifier from `machine-id`. A positive issue number uses the
booted image's normal routing: Bluefin LTS goes to
`projectbluefin/bluefin-lts`, regular Bluefin to `projectbluefin/bluefin`,
Dakota to `projectbluefin/dakota`, and unknown variants to
`projectbluefin/common`. A GitHub issue URL uses its repository and issue
number directly.

Issue numbers must be positive integers. In a terminal, the exact comment is
shown and requires confirmation before posting; non-interactive use posts after
printing the preview. A signed-in GitHub CLI is required (`gh auth login`);
QR login is intentionally out of scope.

## bonedigger — what it does NOT do

bonedigger does not own trusted issue acceptance or the shared lifecycle engine.
Opted-in Common and ChairLift call `projectbluefin/actions`' shared lifecycle
through managed `@v1`; Hive supplies assignment and scheduling. The historical
bonedigger `lifecycle.yml` remains at the full commit SHAs pinned by `bluefin`,
`bluefin-lts`, `dakota`, and `knuckle` for their report-intake integrations.
See § Integration status below.

See [`label-workflow.md`](../../label-workflow.md) for the full lifecycle reference.

## kubestellar-bot - what it does

kubestellar-bot is the implementation agent layer. It:
- Monitors eligible work under each repository's contract; `3-clanker-queue`
  applies only where that local queue is used, not to opted-in Common or ChairLift.
- Dispatches agents to claim and implement fixes
- Manages the PR lifecycle from claim → ship
- Reports progress back to the hive dashboard

kubestellar-bot does NOT make design or security decisions. Those hit a human gate. See [`human-gates.md`](../../human-gates.md).

## Integration status

The historical factory report-intake callers retain the bonedigger workflow:

| Workflow | Location | Called by | Purpose |
|---|---|---|---|
| bonedigger slim | `projectbluefin/bonedigger/.github/workflows/lifecycle.yml` (removed from `main`; retained at each caller's pinned SHA) | `bluefin`, `bluefin-lts`, `dakota`, `knuckle` via `bonedigger.yml` | ujust-report intake, confirmation tracking and priority escalation, agent donation fast-track |

`bonedigger#40` (2026-09-29) deleted `lifecycle.yml` from `main`.
The `bonedigger.yml` callers above are
**retention pins**: a `workflow_call` ref resolves at the pinned commit, so
`lifecycle.yml@d530767` (tag `v1`) and `lifecycle.yml@9c5faf6` still run. Because
the file no longer exists on `main`, those pins cannot be bumped forward.

Internal `projectbluefin/` workflow refs otherwise use managed `@main` or `@v1` — **not SHA
pins**. SHA pins on internal refs caused repeated `startup_failure` cascades when
pins drifted; the pre-commit floating-tag guard already exempts
`projectbluefin/*`. The `bonedigger.yml` lifecycle retention pins above are the
one deliberate exception. See [`ci-tooling.md`](../../ci-tooling/SKILL.md) §
Internal refs.

Common's `issue-lifecycle.yml` calls the shared Actions runtime; preserve that
caller rather than adding a second engine or assuming ownership from a filename.

bonedigger's `sync-templates.yml` continues to propagate issue templates to factory repos.

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates from `bonedigger/templates/` to factory repos.

Requires `MERGERAPTOR_APP_ID` (var) and `MERGERAPTOR_PRIVATE_KEY` (secret) on
the bonedigger repo. Use the mergeraptor app token rather than a PAT.
