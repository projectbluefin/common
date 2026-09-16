# Containerfile — Build Stages

Part of [containerfile](../SKILL.md) — full stage definitions, wallpaper source caveat, and ujust completions.

## Build stages

The Containerfile uses four named stages:

```
FROM golang:alpine@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2 AS umotd-build
  └─ git clone projectbluefin/umotd@<COMMIT_SHA>
  └─ go build -ldflags="-s -w" -o /umotd

FROM golang:alpine@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2 AS uwelcome-build
  └─ git clone projectbluefin/uwelcome@<COMMIT_SHA>
  └─ go build -ldflags="-s -w" -o /uwelcome

FROM alpine:latest@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS build
  └─ downloads + builds artifacts into /out/{shared,bluefin}/
       ├─ wallpapers
       ├─ ujust completions (generated from just binary)
       ├─ game-devices-udev rules
       ├─ U2F udev rules
       ├─ COPY --from=umotd-build /umotd /out/shared/usr/bin/umotd
       └─ COPY --from=uwelcome-build /uwelcome /out/shared/usr/bin/uwelcome

FROM scratch AS ctx
  └─ COPY /system_files/* into layered paths
  └─ COPY --from=build /out/* into same paths
```

The final `ctx` stage is a scratch image — it contains only the file tree that downstream image builds overlay onto their base. There is no executable entry point.

**`umotd-build` / `uwelcome-build` stages — Go compilers for the banner pair:**

`umotd` (translatable MOTD tips) and `uwelcome` (the CLI welcome banner that
renders them) are two separate upstream projects, each built from source with
its own Go builder stage. Do NOT download a pre-built binary — use the builder
stage pattern:

```dockerfile
FROM docker.io/library/golang:alpine@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2 AS umotd-build
RUN apk add git && git clone https://github.com/projectbluefin/umotd /src && \
    git -C /src checkout <COMMIT_SHA>
WORKDIR /src
RUN go build -ldflags="-s -w" -o /umotd .
```

Then in the `build` stage: `COPY --from=umotd-build /umotd /out/shared/usr/bin/umotd`

When updating either version: find the target commit SHA on
`projectbluefin/umotd` or `projectbluefin/uwelcome` and update that stage's
`git -C /src checkout <COMMIT_SHA>` line. Do not use `--branch` or a tag —
git tags are mutable and bypass the immutable pin, even when the tag currently
points at the commit you want.

Resolve a release tag to the SHA to pin:

```bash
gh api repos/projectbluefin/uwelcome/git/refs/tags/v0.3.4 -q '.object.sha'
```

A tag-for-SHA swap is invisible to CI — the image still builds, because the tag
resolves to a real commit. Nothing but review catches it, so treat any
`checkout tags/...` or `--branch` in a diff as a blocking finding.

**Config split.** The two binaries read separate config files, both shipped from
`system_files/shared/`:

| File | Owner | Contents |
|---|---|---|
| `etc/uwelcome/config.json` | uwelcome | greeting, commands, links, color, which command supplies the motd |
| `etc/ublue-os/tags.json` | umotd | which thematic tip tags this image shows |

Command `desc` values and link `name` values in `config.json` are translation
keys, not free text — an unknown key renders as the raw identifier in the
banner. The valid sets are listed in each project's `docs/configuration.md`;
`tests/test_motd_integration.bats` pins both so a typo fails CI rather than
shipping.

---

## Wallpaper source caveat

**The wallpaper source is still `ghcr.io/ublue-os/bluefin-wallpapers-gnome`.**

```dockerfile
COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:e4d74fa741ce9ff03a6a60440a58c31cef6c0fc145182357d243580ba239f810 / /out/bluefin/usr/share
```

This is a build-time `COPY --from` image reference, not a runtime registry path. The production image tree lives in `ghcr.io/projectbluefin/`, but the wallpaper artwork still originates from the `ublue-os` artwork registry. This is intentional — the wallpapers are upstream artwork, not projectbluefin-owned infrastructure.

**Implication:** Updating the wallpaper source requires updating this SHA. The path `ghcr.io/ublue-os/bluefin-wallpapers-gnome` is NOT a violation of the ublue-os prohibition — it is a read-only upstream artwork source, not a write action to a ublue-os repo.

After copying, the wallpaper XML metadata paths are rewritten from `~/.local/share` to `/usr/share` to work correctly as system-installed assets:

```bash
sed -i 's|~\/\.local\/share|\/usr\/share|' *.xml
```

---

## ujust completions

The `ujust` shell completions are tailored files checked into `system_files/shared/` (bash, zsh, fish), completing `ujust` flags plus recipe names from `/usr/share/ublue-os/just/00-entry.just` via `just --summary`.
They are **not** generated from `just --completions`: Since `just` moved to dynamic `clap_complete` loader output, a build-time `sed s/just/ujust/` rename can no longer work. The real registration line (`complete ... just`) is emitted at TAB-time on the live system, past any build-time filter, and binds the wrong command name (projectbluefin/bluefin#1171).

Two rules follow from this:

- Never reintroduce a `just --completions | sed` generator step. The gate `RUN` in the `build` stage (content assertions on the checked-in files plus a no-shadow check against `/out/shared/...`) fails the build if the generator — or any other file at those paths — comes back.
- `UJUST_JUSTFILE` / `UJUST_FLAGS_FILE` override the entry-justfile path and the flags list in all three completions; they exist for `tests/test_ujust_completion.bats` which points them at sandbox files so the suite passes off-image. Flags live in exactly one place at `system_files/shared/usr/share/ublue-os/just/ujust-flags` (one per line). All three completions read it during TAB press.
