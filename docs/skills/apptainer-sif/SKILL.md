---
name: apptainer-sif
version: "1.1"
last_updated: "2026-09-13"
id: apptainer-sif
one_line_purpose: Build, distribute, and execute Apptainer SIF container appliances.
entry_point: docs/skills/apptainer-sif/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: [brew-lifecycle]
tags: [apptainer, sif, containers, brew, kvm]
description: >-
  Build, distribute, and execute Apptainer SIF container appliances via Homebrew
  wrappers. Use when working with SIF image creation, apptainer execution,
  AppArmor unprivileged userns profiles, or brew CLI wrappers.
metadata:
  type: procedure
  context7-sources:
    - /apptainer/apptainer
    - /homebrew/brew
---

# apptainer-sif — Apptainer SIF Appliance Architecture and Packaging

> **This skill documents `projectbluefin/review`, not this repo.** Every file
> path below lives in `projectbluefin/review` or in
> `ublue-os/homebrew-experimental-tap`. `projectbluefin/common` has no `bin/`,
> no `Formula/`, no SIF build, and no Apptainer dependency. Do not run any
> command here expecting it to resolve against this checkout.
>
> It lives in `common` because `docs/skills/` is the factory-wide skill
> catalogue that `docs/SKILL.md` routes agents through, and two skills in that
> catalogue depend on it: [`review-appliance.md`](../review-appliance.md)
> declares `dependencies: [apptainer-sif, …]` and
> [`pr-review/SKILL.md`](../pr-review/SKILL.md) links to it. Splitting it into
> `review` would break that routing.

Project Bluefin distributes its maintainer and contributor review tooling as an
Apptainer SIF (Singularity Image Format) appliance wrapped in Homebrew-installed
host launchers, so it runs rootless, without a daemon, under unprivileged user
namespaces.

---

## Naming — three different things, easily confused

| Name | What it is | Where |
|---|---|---|
| `bluefin` | Host launcher script. The review UI is the `bluefin review` **subcommand**. | `projectbluefin/review:bin/bluefin` |
| `bluefin-contribute` | Host launcher for the contributor worker | `projectbluefin/review:bin/bluefin-contribute` |
| `bluefin-review` | In-image binary, and the XDG state dir `~/.local/state/bluefin-review/` | `projectbluefin/review:image/bin/bluefin-review` |
| `bluefin-review.sif` | The built appliance artifact; also `$BLUEFIN_REVIEW_SIF` | built in CI, pulled on demand |

There is **no `bluefin-review` host command.** The Homebrew formula
`bluefin-contributor-tools` installs exactly two executables, `bluefin` and
`bluefin-contribute`. Do not rename the in-image binary or the state path to
match the host command — they are deliberately different.

---

## When to Use

- Building Apptainer SIF images from OCI images or Docker archives.
- Packaging and wrapping SIF appliances with a Homebrew formula.
- Writing or debugging the host launchers in `projectbluefin/review:bin/`.
- Configuring AppArmor unprivileged-userns profiles for Apptainer on a host that restricts them (Ubuntu 24.04+).
- Passing credentials into a SIF container without leaking them into `argv`.
- Managing bind mounts and the isolated state home.

## When NOT to Use

- Multi-stage OCI builds for the OS image → [`containerfile/SKILL.md`](../containerfile/SKILL.md).
- Adding OS-managed CLI tools or casks to Bluefin images → [`brew-lifecycle/SKILL.md`](../brew-lifecycle/SKILL.md).
- Anything in `projectbluefin/common`. This skill has no bearing on what `common` ships.

---

## Architecture

A SIF is a single-file, immutable, read-only executable container image. It
runs without a background daemon and enforces rootless execution.

```text
Host (Linux/Darwin)
  ├── Homebrew formula: bluefin-contributor-tools → bin/bluefin, bin/bluefin-contribute
  ├── Launcher: checks KVM, resolves tokens, auto-pulls the SIF, configures binds
  └── SIF appliance: rootless, unprivileged userns, isolated state home
```

---

## 1. Converting OCI images to SIF in CI

Owned by `projectbluefin/review:.github/workflows/` — specifically
`publish-appliance.yml`, `publish-contribute.yml`, and that repo's own
`validate.yml`. None of these exist in `common`.

```bash
# Export the OCI image to a docker-archive
podman save --format docker-archive -o "${RUNNER_TEMP}/appliance-${ARCH}.tar" appliance:smoke

# Build the SIF from the archive
apptainer build --force "${RUNNER_TEMP}/bluefin-review-${UNAME}.sif" \
  "docker-archive:${RUNNER_TEMP}/appliance-${ARCH}.tar"
chmod 0755 "${RUNNER_TEMP}/bluefin-review-${UNAME}.sif"

rm -f "${RUNNER_TEMP}/appliance-${ARCH}.tar"
```

Smoke-test the result immediately — a SIF that builds but cannot exec is a
silent failure:

```bash
apptainer exec "$sif" /usr/bin/omp --version
apptainer exec "$sif" /usr/bin/tmux -V
```

## 2. Distributing via Homebrew

The formula is `ublue-os/homebrew-experimental-tap:Formula/bluefin-contributor-tools.rb`:

```bash
brew install ublue-os/experimental-tap/bluefin-contributor-tools
```

It installs `bin/bluefin` and `bin/bluefin-contribute`, warns about the
Apptainer and SIF prerequisites, and exercises the CLIs during `brew test`.

## 3. Launcher contract

The host wrappers must hold to six rules:

1. **Auto-pull fallback.** With no local repo SIF and no `$BLUEFIN_REVIEW_SIF`,
   pull over Apptainer's native OCI support:
   ```bash
   image_uri="${BLUEFIN_REVIEW_IMAGE:-docker://ghcr.io/projectbluefin/review:stable}"
   apptainer pull --force "$sif" "$image_uri"
   ```
2. **No argv credential leaks.** Apptainer inherits the host environment, so
   `export` `GH_TOKEN`/`GITHUB_TOKEN` in the launcher process and let them pass
   through. **Never** use `--env KEY=value` — that puts the secret in `ps` and
   `/proc/$PID/cmdline`.
3. **Fail-fast credential resolution.** If no token is exported, try
   `gh auth token`, then `~/.omp/agent/agent.db`. If everything fails, exit with
   an actionable error rather than letting a headless session hang on a prompt.
4. **Isolated state home.** `--home "${runtime_home}:/home/bluefin"`, so
   container writes never touch the user's real `$HOME`. Each run otherwise
   gets a fresh `$HOME` and loses `gh auth login` state.
5. **Config passthrough.** Bind only what is needed (`.gitconfig`,
   `.config/gh`, `.config/hive`, `.omp`), read-only where possible.
6. **KVM verification.** Check `${BLUEFIN_KVM_DEVICE:-/dev/kvm}` before
   launching sandboxed subagents.

## 4. AppArmor profile for unprivileged user namespaces

**Host workstation setup — not image content.** Nothing in any Project Bluefin
image ships AppArmor policy; the OS images are Fedora/CentOS bootc builds using
SELinux. This step applies only to a contributor's own Ubuntu 24.04+ machine,
where `kernel.apparmor_restrict_unprivileged_userns=1` blocks Apptainer.

Deploy `/etc/apparmor.d/apptainer` permitting `userns` for
`/usr/**/bin/apptainer` and `/home/linuxbrew/.linuxbrew/**/bin/apptainer`
(plus the matching `starter` binaries), then reload:

```bash
sudo systemctl reload apparmor
# or
sudo apparmor_parser -r /etc/apparmor.d/apptainer
```

---

## Red Flags

- Passing tokens as `--env TOKEN=...` to `apptainer run`/`exec` — exposes them in the process list.
- Relying on an interactive `gh auth login` prompt inside a headless worker.
- Running a SIF under `sudo` when unprivileged execution works.
- Writing to the host `$HOME` instead of `--home "${runtime_home}:/home/bluefin"`.
- Skipping the `/dev/kvm` check before a nested-virtualization workload.
- Referring to a `bluefin-review` host command — it does not exist; it is `bluefin review`.
- Treating any path in this skill as resolvable inside `projectbluefin/common`.

---

## Verification

Run these **in a `projectbluefin/review` checkout**, not here:

- [ ] `apptainer --version` reports a working runtime.
- [ ] `bash -n bin/bluefin bin/bluefin-contribute` passes.
- [ ] `tests/contribute-contract.sh` passes — it asserts tokens travel by environment and never via `--env`.
- [ ] `apptainer exec "$sif" <binary> --version` runs cleanly against the built SIF.
- [ ] On an Ubuntu 24.04+ host, launching produces no `permission denied` or user-namespace error.
