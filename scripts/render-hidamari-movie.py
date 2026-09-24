#!/usr/bin/env python3
"""Render the Bluefin Hidamari looping wallpaper movie.

Generates the original, seamless-loop WebM (VP9) video shipped for the
Hidamari video-wallpaper engine (io.github.jeffshee.Hidamari):

    system_files/bluefin/usr/share/backgrounds/bluefin/bluefin-hidamari.webm

The animation is fully original — layered deep-ocean gradient waves with
rising glow specks in Bluefin's blue/teal palette — so no third-party
wallpaper licensing applies (the Wallpaper Engine workshop item named in
the tracking issue carries no redistribution license).

Every temporal component is periodic over t in [0, 1) using integer
harmonic counts, so frame(t = 1.0) == frame(t = 0.0) and the loop is
seamless. Only per-frame dither grain differs; it reads as film grain.

Usage:
    python3 scripts/render-hidamari-movie.py --output <path.webm> \
        [--width 1920] [--height 1080] [--fps 24] [--seconds 12] \
        [--crf 34] [--dither 1.4]

Requires: python3 with numpy, and an ffmpeg binary with libvpx-vp9 on
PATH (or pointed at via the FFMPEG env var). Pillow is used to write a
preview PNG when --preview-frame is given.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, replace

import numpy as np

DEFAULT_OUTPUT = (
    "system_files/bluefin/usr/share/backgrounds/bluefin/bluefin-hidamari.webm"
)

# Color stops for the palette LUT: (position, RGB). Deep-ocean navy rising
# through Bluefin teal to a soft cyan highlight.
PALETTE_STOPS = [
    (0.00, (4, 12, 26)),
    (0.35, (10, 34, 58)),
    (0.65, (18, 74, 92)),
    (0.88, (64, 160, 158)),
    (1.00, (198, 236, 233)),
]

# Bubbles rising through the frame: (x0, y0, sigma_px, amplitude, drift phase).
BUBBLE_COUNT = 56


@dataclass(frozen=True)
class Config:
    """Render configuration. All fields are deterministic."""

    width: int = 1920
    height: int = 1080
    fps: int = 24
    seconds: int = 12
    crf: int = 34
    dither: float = 1.4
    seed: int = 1158  # tracking issue number


def make_bubbles(cfg: Config, count: int = BUBBLE_COUNT) -> np.ndarray:
    """Deterministic bubble seed table, shape (count, 5)."""
    rng = np.random.default_rng(cfg.seed)
    return np.stack(
        [
            rng.uniform(0.0, 1.0, count),  # x0 (fraction of width)
            rng.uniform(0.0, 1.0, count),  # y0 (fraction of height)
            rng.uniform(1.6, 4.2, count),  # gaussian sigma in pixels
            rng.uniform(0.10, 0.34, count),  # peak amplitude
            rng.uniform(0.0, 1.0, count),  # horizontal drift phase
        ],
        axis=1,
    )


def bubble_alpha(bubbles: np.ndarray, t: float) -> np.ndarray:
    """Per-bubble brightness envelope at time t (fraction of the loop).

    Each bubble rises exactly one frame height per loop, fading in from
    the bottom and out at the top, so the wrap is invisible.
    """
    p = np.mod(bubbles[:, 1] - t, 1.0)
    return np.sin(np.pi * p) ** 0.7 * bubbles[:, 3]


def luminance(cfg: Config, bubbles: np.ndarray, t: float) -> np.ndarray:
    """Render the normalized luminance field for one frame, t in [0, 1)."""
    w, h = cfg.width, cfg.height
    two_pi = 2.0 * np.pi
    aspect = w / h

    # Normalized spatial coordinates, pre-scaled by 2*pi so spatial
    # frequencies below are plain cycle counts.
    y = np.linspace(0.0, two_pi, h, dtype=np.float32)[:, None]
    x = np.linspace(0.0, two_pi * aspect, w, dtype=np.float32)[None, :]

    # Layered slow-drifting waves; temporal phases run 1..2 cycles per
    # loop so the field is exactly periodic.
    waves = (
        0.45 * np.sin(0.9 * x + 0.7 * y + two_pi * 1.0 * t)
        + 0.30 * np.sin(1.6 * x - 1.1 * y + two_pi * 2.0 * t + 1.3)
        + 0.20 * np.sin(2.6 * x + 2.0 * y + two_pi * 1.0 * t + 4.1)
    )

    # Vertical base gradient: brighter surface light above, abyss below.
    lum = 0.40 - 0.22 * (y / two_pi)

    # Wave modulation.
    lum = lum + 0.15 * waves

    # Faint slanting light rays from the surface.
    rays = np.maximum(np.sin(1.3 * x + two_pi * 1.0 * t + 0.6), 0.0)
    lum = lum + 0.16 * rays * (1.0 - y / two_pi) ** 2

    # Rising glow specks. Each rises exactly one height per loop.
    px = (x / two_pi) * w  # pixel x per column
    py = (y / two_pi) * h  # pixel y per row
    glow = np.zeros((h, w), dtype=np.float32)
    alpha = bubble_alpha(bubbles, t)
    for i in range(bubbles.shape[0]):
        x0, _, sigma, _amp, phase = bubbles[i]
        cx = (x0 + 0.012 * np.sin(two_pi * (t + phase))) * w
        cy = np.mod(bubbles[i, 1] - t, 1.0) * h
        # Wrap vertically so bubbles crossing an edge stay whole.
        dy = np.abs(py - cy)
        dy = np.minimum(dy, h - dy)
        dx = np.abs(px - cx)
        dx = np.minimum(dx, w - dx)
        r2 = dx * dx + dy * dy
        glow += alpha[i] * np.exp(-r2 / (2.0 * sigma * sigma))
    lum = lum + glow

    # Slow global "breathing", one cycle per loop.
    lum = lum * (1.0 + 0.04 * np.sin(two_pi * t))

    return np.clip(lum, 0.0, 1.0)


def palette_lut() -> np.ndarray:
    """256-entry RGB palette built from PALETTE_STOPS."""
    pos = np.array([s[0] for s in PALETTE_STOPS])
    stops = np.array([s[1] for s in PALETTE_STOPS], dtype=np.float32)
    xs = np.linspace(0.0, 1.0, 256)
    lut = np.stack(
        [np.interp(xs, pos, stops[:, c]) for c in range(3)], axis=1
    )
    return lut.astype(np.float32)


def vignette(cfg: Config) -> np.ndarray:
    """Center-weighted falloff mask, shape (h, w), values in (0, 1]."""
    h, w = cfg.height, cfg.width
    yy = np.linspace(-1.0, 1.0, h, dtype=np.float32)[:, None]
    xx = np.linspace(-1.0, 1.0, w, dtype=np.float32)[None, :]
    r2 = (xx * xx + yy * yy) / 2.0
    return 1.0 - 0.32 * np.clip(r2, 0.0, 1.0)


def frame_rgb(
    cfg: Config,
    bubbles: np.ndarray,
    t: float,
    lut: np.ndarray,
    vig: np.ndarray,
    frame_index: int = 0,
) -> np.ndarray:
    """Render one frame as a uint8 (h, w, 3) RGB array."""
    lum = luminance(cfg, bubbles, t) * vig
    idx = np.clip((lum * 255.0).astype(np.int32), 0, 255)
    rgb = lut[idx]
    if cfg.dither > 0.0:
        rng = np.random.default_rng(cfg.seed + 7919 + frame_index)
        noise = (rng.random(rgb.shape, dtype=np.float32) - 0.5) * (
            2.0 * cfg.dither
        )
        rgb = rgb + noise
    return np.clip(rgb, 0, 255).astype(np.uint8)


def loop_frames(cfg: Config) -> int:
    return cfg.fps * cfg.seconds


def ffmpeg_path() -> str:
    return os.environ.get("FFMPEG", "ffmpeg")


def render_movie(cfg: Config, out_path: str) -> None:
    """Pipe every frame into ffmpeg and encode a seamless VP9 WebM."""
    ff = shutil.which(ffmpeg_path())
    if ff is None:
        sys.exit(
            f"error: ffmpeg not found (set FFMPEG=/path/to/ffmpeg); "
            f"needs libvpx-vp9"
        )

    bubbles = make_bubbles(cfg)
    lut = palette_lut()
    vig = vignette(cfg)
    n = loop_frames(cfg)

    cmd = [
        ff,
        "-y",
        "-f", "rawvideo",
        "-pix_fmt", "rgb24",
        "-s", f"{cfg.width}x{cfg.height}",
        "-framerate", str(cfg.fps),
        "-i", "-",
        "-an",
        "-c:v", "libvpx-vp9",
        "-b:v", "0",
        "-crf", str(cfg.crf),
        "-deadline", "good",
        "-cpu-used", "4",
        "-row-mt", "1",
        "-tile-columns", "2",
        "-pix_fmt", "yuv420p",
        out_path,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    assert proc.stdin is not None
    try:
        for f in range(n):
            t = f / n
            frame = frame_rgb(cfg, bubbles, t, lut, vig, frame_index=f)
            proc.stdin.write(frame.tobytes())
    finally:
        proc.stdin.close()
        if proc.wait() != 0:
            sys.exit(f"error: ffmpeg failed with exit code {proc.returncode}")


def preview_frame(cfg: Config, t: float, out_path: str) -> None:
    """Write a single frame as PNG (requires Pillow)."""
    try:
        from PIL import Image
    except ImportError:
        sys.exit("error: Pillow required for --preview-frame")
    bubbles = make_bubbles(cfg)
    lut = palette_lut()
    vig = vignette(cfg)
    frame = frame_rgb(cfg, bubbles, t, lut, vig)
    Image.fromarray(frame).save(out_path)


def parse_args(argv: list[str]) -> argparse.Namespace:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--output", default=DEFAULT_OUTPUT)
    ap.add_argument("--width", type=int, default=Config.width)
    ap.add_argument("--height", type=int, default=Config.height)
    ap.add_argument("--fps", type=int, default=Config.fps)
    ap.add_argument("--seconds", type=int, default=Config.seconds)
    ap.add_argument("--crf", type=int, default=Config.crf)
    ap.add_argument("--dither", type=float, default=Config.dither)
    ap.add_argument(
        "--preview-frame",
        type=float,
        default=None,
        metavar="T",
        help="render one frame at loop fraction T to <output>.png and exit",
    )
    return ap.parse_args(argv)


def main(argv: list[str]) -> None:
    args = parse_args(argv)
    cfg = Config(
        width=args.width,
        height=args.height,
        fps=args.fps,
        seconds=args.seconds,
        crf=args.crf,
        dither=args.dither,
    )
    if args.preview_frame is not None:
        preview_frame(cfg, args.preview_frame, args.output + ".png")
        print(f"preview written: {args.output}.png")
        return
    render_movie(cfg, args.output)
    size = os.path.getsize(args.output)
    print(f"wrote {args.output}: {size / 1_048_576:.2f} MiB, "
          f"{loop_frames(cfg)} frames @ {cfg.fps} fps")


if __name__ == "__main__":
    main(sys.argv[1:])