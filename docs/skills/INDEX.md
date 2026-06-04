# docs/skills — Index

Agent skill docs for the `projectbluefin/common` repo.

| File | What it covers |
|---|---|
| [governance.md](governance.md) | Triagers role, CODEOWNERS sentinel pattern, sync workflow, branch protection matrix |
| [hive-review.md](hive-review.md) | `~/src/hive-status` — session start, P0/P1 triage, hive label taxonomy |
| [queue-dashboard.md](queue-dashboard.md) | queue.projectbluefin.io — PR tiers, merge ruleset (2 approvals), refresh cadence |
| [e2e-ci.md](e2e-ci.md) | Pre/post-merge E2E CI for common — composed PR gate, post-merge common suite, masked brew setup, quarantined scenarios |
| [onboarding.md](onboarding.md) | Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos |
| [submodule-boundary.md](submodule-boundary.md) | What is/isn't editable in this repo — `system_files/shared/` is read-only (aurorafin-shared submodule), `system_files/bluefin/` is editable |
| [dconf-consistency.md](dconf-consistency.md) | GSettings override ↔ dconf lock file parity rules — must edit both files together for locked settings |
| [image-registry.md](image-registry.md) | ublue-os vs projectbluefin org split for OCI publishing — production images still at `ghcr.io/ublue-os/` |
