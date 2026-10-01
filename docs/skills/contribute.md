---
name: contribute
version: "1.0"
last_updated: "2026-09-27"
id: contribute
one_line_purpose: Operate the ujust contribute podman alias for the Hive contributor appliance.
entry_point: docs/skills/contribute.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [contribute, hive, podman, krun, gvisor, just]
description: >-
  ujust contribute aliases to a podman-run invocation of
  projectbluefin/contribute defaulting to the projectbluefin Hive. Use when
  working on the recipe, its isolation-tier warning, or its resource limits.
metadata:
  type: reference
---

# contribute — `ujust contribute`

## What this is

`ujust contribute` (projectbluefin/common#1277) is a thin podman alias for the
[`projectbluefin/contribute`](https://github.com/projectbluefin/contribute)
appliance (`ghcr.io/projectbluefin/contribute:stable`), defaulting to
projectbluefin's own hosted Hive hub. It does not clone a checkout or vendor
upstream's `bin/hive-contribute` launcher script — those require a host
toolchain (`git`, `node`, `jq`) this recipe does not need.

File: `system_files/shared/usr/share/ublue-os/just/shared.just` — shared
across bluefin, bluefin-lts, aurora, and dakota (all consumers of
`shared.just`).

## Behavior

- **Podman required.** Fails fast (exit 127) with a clear message if `podman`
  is absent.
- **Registration required.** Reads `${HOME}/.config/hive/contributor.env` (the
  same path upstream's `bin/hive-contribute` writes). If missing, fails with a
  pointer to upstream's registration flow rather than trying to reimplement
  it — registration needs `git`/`node`/`jq`, which this recipe does not
  require for the common case of an already-registered contributor.
- **Isolation tier is a warning, never a hard gate.** Probes
  `podman --runtime=krun info` and `/dev/kvm` readability/writability. When
  both are available it launches with `--runtime=krun` (hardware-isolated KVM
  microVM). When either is unavailable — this is a per-image capability, not a
  universal one — it prints a WARNING to stderr and still launches with the
  standard rootless podman container boundary. It never refuses to run.
- **Foreground-only.** `--interactive --tty`, no `--detach`. Ctrl-C stops it.
- **Resource limits are always enforced**, never optional: `--memory` (default
  `4g`) with `--memory-swap` pinned to the same value, and `--cpus` (default
  `2`) — matching upstream's contributor envelope
  (`contributor_memory_limit_gib` / `contributor_cpu_limit`).
- **GitHub token forwarded by name.** Resolved from `GH_TOKEN`, `GITHUB_TOKEN`,
  or `gh auth token --hostname github.com`, in that order; exported and passed
  to the container as `--env GH_TOKEN` (name only, so the value never appears
  in podman's argv).
- **Image provenance verified before launch.** The recipe pulls the image,
  runs `gh attestation verify oci://<pulled digest> --repo projectbluefin/contribute`,
  and launches with `--pull=never`. A failed check refuses to launch; a host
  without `gh` warns and runs unverified. `HIVE_CONTRIBUTE_NO_VERIFY=1` skips
  the check (outage escape hatch).
- **Default hub.** `wss://hosted-projectbluefin-knuckle-gjvq.hive.hivecommons.dev/api/contribute/ws`
  — projectbluefin's own hosted Hive (see
  [`hive-automerge.md`](hive-automerge.md) for the same host). Override with
  `HIVE_CONTRIBUTE_HUB`.

## Overridable environment variables

| Variable | Default |
|---|---|
| `HIVE_CONTRIBUTE_IMAGE` | `ghcr.io/projectbluefin/contribute:stable` |
| `HIVE_CONTRIBUTE_HUB` | projectbluefin's hosted Hive (see above) |
| `HIVE_CONTRIBUTE_MEMORY` | `4g` |
| `HIVE_CONTRIBUTE_CPUS` | `2` |
| `HIVE_CONTRIBUTE_REGISTRATION` | `${HOME}/.config/hive/contributor.env` |
| `HIVE_CONTRIBUTE_NO_VERIFY` | `0` (set `1` to skip provenance verification) |

## Verification

```bash
bats tests/test_shared_just.bats
```

`tests/test_shared_just.bats` extracts the `contribute:` recipe body verbatim
(no `just` interpolation in it) and runs it against stubbed `podman`/`gh`
binaries, covering: missing podman, missing registration, the krun
warn-and-continue path, enforced memory/cpu limits, foreground-only flags, and
GH token forwarding.

## When NOT to use this doc

- Registering a machine with a Hive for the first time — that is upstream
  `projectbluefin/contribute`'s `hive-contribute setup` flow, not this recipe.
- Packaging a `bluefin contribute` Homebrew command — tracked separately in
  projectbluefin/common#1102, blocked on a `ublue-os/homebrew-tap` formula
  that does not exist yet.
