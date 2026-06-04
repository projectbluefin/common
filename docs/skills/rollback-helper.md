---
name: rollback-helper
description: "ublue-rollback-helper TUI state machine — three-way coordinated arrays, LTS branches, and registry path derivation."
---

# rollback-helper

`system_files/bluefin/usr/bin/ublue-rollback-helper` is an interactive TUI that lets users switch Bluefin variants and channels. It contains a **three-way coordinated state machine** that is easy to break by editing only one of the three moving parts.

## The three arrays that must change together

When adding or removing a variant or channel, you **must** update all three of these in the same commit:

```bash
declare -a IMAGES      # image names available for rebase
declare -a CHANNELS    # channels available for that image
filter="..."           # regex used to list date-tagged builds in skopeo
```

The LTS/non-LTS branch (`if grep -qe "lts" <<< "${IMAGE_TAG}"`) creates two independent sets of all three arrays. Editing only `IMAGES` while leaving `CHANNELS` or `filter` stale produces broken runtime behavior — the wrong tags are offered or no tags are found.

## Registry path derivation

The image registry is **not hardcoded** — it is derived at runtime:

```bash
IMAGE_VENDOR="$(jq -r '."image-vendor"' < /usr/share/ublue-os/image-info.json)"
IMAGE_REGISTRY="ghcr.io/${IMAGE_VENDOR}"
```

`image-vendor` is set during the build via `00-image-info.sh`. Do not hardcode `ghcr.io/ublue-os` or `ghcr.io/projectbluefin` here — it must remain dynamic until the org migration is complete.

## LTS vs non-LTS branch semantics

| | LTS mode | non-LTS mode |
|---|---|---|
| Triggered by | `IMAGE_TAG` contains "lts" | otherwise |
| IMAGES | `bluefin bluefin-dx bluefin-gdx` | `bluefin bluefin-dx bluefin-nvidia-open bluefin-dx-nvidia-open` |
| CHANNELS | `lts lts-hwe` (gdx: `lts` only) | `stable stable-daily latest` |
| filter | `lts.[0-9]{8}` | `${channel_selected}.[0-9]{8}` |

## Adding a new variant — checklist

- [ ] Add image name to the correct `IMAGES` array (LTS or non-LTS branch)
- [ ] Verify `CHANNELS` for that image are correct in the same branch
- [ ] Update the `filter` regex to match the new channel's date-tag format
- [ ] Test `list_tags "$filter"` output against the live registry
- [ ] Run `shellcheck` (CI gate: `validate.yml`)

## Testing guidance

`gum` and `skopeo` are runtime dependencies. To unit-test the branching logic:

```bash
# Mock gum to always select first option
gum() { echo "$4"; }   # crude mock — replace with bats-mock for real coverage
export -f gum

# Mock skopeo to return known tag list
skopeo() { printf 'stable.20240101\nstable.20240108\n'; }
export -f skopeo
```

Full BATS coverage is tracked in issue [#469](https://github.com/projectbluefin/common/issues/469).

## ShellCheck exception

CI runs `shellcheck -e SC2207 system_files/bluefin/usr/bin/ublue-rollback-helper`. SC2207 is suppressed because the `valid_tags` array is populated via `$()` word-splitting intentionally. Do not remove this exception.
