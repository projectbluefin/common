---
name: hidamari-wallpaper
version: "1.0"
last_updated: "2026-09-24"
id: hidamari-wallpaper
one_line_purpose: Regenerate and validate the Hidamari looping video-wallpaper asset.
entry_point: docs/skills/hidamari-wallpaper.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: [numpy, ffmpeg-libvpx-vp9]
tags: [hidamari, wallpaper, video, vp9, webm, backgrounds, system_files]
description: >-
  Regenerate, validate, or replace the Bluefin Hidamari video-wallpaper asset
  (bluefin-hidamari.webm) with scripts/render-hidamari-movie.py. Covers the
  seamless-loop invariants, size budget, and licensing constraint that the
  animation must stay original.
metadata:
  type: reference
---

# Hidamari video wallpaper — projectbluefin/common

## What ships

`system_files/bluefin/usr/share/backgrounds/bluefin/bluefin-hidamari.webm`
is a 1920x1080, 12 s, 24 fps VP9 (yuv420p, no audio) loop for the Hidamari
video-wallpaper engine (`io.github.jeffshee.Hidamari`). It is an original
render — layered ocean-gradient waves with rising glow specks in the Bluefin
palette — not a re-encode of third-party art.

## User setup and Flatpak visibility

The user-facing steps are in [Hidamari setup](../hidamari.md), linked from
the repository README. Keep that guide in sync if the asset path changes.
Hidamari reads its Local Video list from the XDG Videos directory’s
`Hidamari` subdirectory. The shipped `/usr/share/backgrounds` file must be
copied there: a symlink back into `/usr` does not make the target accessible
inside the Flatpak sandbox. Use `xdg-user-dir VIDEOS` to respect localized or
custom Videos paths, and quote the resulting path.

## Licensing constraint (do not skip)

The Wallpaper Engine workshop item named in the tracking issue carries **no
redistribution license**. Never vendor, re-encode, or derive the shipped
movie from workshop content. The asset must stay reproducible from
`scripts/render-hidamari-movie.py`, which generates original frames only. If
a licensed render is ever donated upstream, replace this constraint in the
same PR that changes the source.

## Regenerating the asset

```bash
# needs python3 + numpy, and an ffmpeg with libvpx-vp9 on PATH
# (or FFMPEG=/path/to/ffmpeg; a static build works fine)
python3 scripts/render-hidamari-movie.py                     # ~3 min, 1080p
python3 scripts/render-hidamari-movie.py --preview-frame 0.5 # one PNG frame
```

Tunables: `--width/--height/--fps/--seconds/--crf/--dither`. Defaults are the
shipped values (1080p, 24 fps, 12 s, crf 24, dither 1.4). Deterministic: the
same script and ffmpeg/libvpx version produces a byte-identical render.

## Invariants the tests enforce

`tests/test_render_hidamari_movie.py` (run via `just test` and the
unit-tests workflow) pins:

- **Seamless loop** — `luminance(t=0) == luminance(t=1)`; every temporal term
  uses integer harmonic counts. With `--dither 0` frames 0 and N are
  byte-identical; with grain on, the wrap may differ only by <= 4/255.
- **Determinism** — palette LUT and bubble seed table derive from
  `Config.seed`; changing the seed forks the animation.
- **Size budget** — shipped WebM stays under 4 MiB (OCI layer cost).
- **Format** — EBML magic and size budget.

When editing the generator, keep every temporal term an integer number of
cycles per loop or the wrap seam will drift and `test_loop_wrap_is_seamless`
will fail.

## Verify a rebuilt asset by hand

```bash
ffprobe -show_entries format=duration,size -of default=nw=1 bluefin-hidamari.webm
ffmpeg -v error -i bluefin-hidamari.webm -f null -   # must decode clean
```

## Related

- Epic: Wallpaper Enhancements (Damask, Hidamari, ChairLift bundles)
- ChairLift bundle for the engine lands via `video-wallpaper.Brewfile`
  (separate sub-issue; see `docs/skills/brew-lifecycle/` for the bundle-file
  conventions).
