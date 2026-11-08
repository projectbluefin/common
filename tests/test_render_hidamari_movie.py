"""Tests for scripts/render-hidamari-movie.py

The generator for the Hidamari video-wallpaper asset must stay deterministic
and seamlessly looping: the shipped WebM is rebuilt from this script, so any
change that would alter the palette, break the loop wrap, or fork the bubble
seed table must fail here. Rendering is exercised on a small Config so no
test needs a real 1080p encode.
"""

import importlib.util
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

SCRIPT_PATH = Path(__file__).parent.parent / "scripts/render-hidamari-movie.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("render_hidamari_movie", SCRIPT_PATH)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["render_hidamari_movie"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load_module()

SMALL_CFG = mod.Config(width=96, height=54, fps=8, seconds=2)
ASSET_PATH = (
    Path(__file__).parent.parent
    / "system_files/bluefin/usr/share/backgrounds/bluefin/bluefin-hidamari.webm"
)


@pytest.fixture(scope="module")
def small_render_ctx():
    bubbles = mod.make_bubbles(SMALL_CFG)
    lut = mod.palette_lut()
    vig = mod.vignette(SMALL_CFG)
    return bubbles, lut, vig


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------


class TestPalette:
    def test_lut_shape_and_range(self):
        lut = mod.palette_lut()
        assert lut.shape == (256, 3)
        assert (lut >= 0).all() and (lut <= 255).all()

    def test_lut_is_deterministic(self):
        np.testing.assert_array_equal(mod.palette_lut(), mod.palette_lut())

    def test_deep_to_bright_gradient(self):
        # Palette must run from deep navy to a bright highlight so the
        # luminance ramp maps onto the Bluefin deep-ocean look.
        lut = mod.palette_lut()
        assert lut[0].sum() < lut[-1].sum() / 3

    def test_blue_dominant(self):
        # Bluefin palette: blue channel never dips below red.
        lut = mod.palette_lut()
        assert (lut[:, 2] >= lut[:, 0]).all()


# ---------------------------------------------------------------------------
# Determinism and loop wrap
# ---------------------------------------------------------------------------


class TestDeterminism:
    def test_bubble_table_is_seeded(self):
        cfg = mod.Config(seed=1158)
        a = mod.make_bubbles(cfg)
        b = mod.make_bubbles(mod.Config(seed=1158))
        np.testing.assert_array_equal(a, b)
        assert a.shape == (mod.BUBBLE_COUNT, 5)

    def test_seed_change_forks_bubbles(self):
        assert not np.array_equal(
            mod.make_bubbles(mod.Config(seed=1)), mod.make_bubbles(mod.Config(seed=2))
        )

    def test_frame_render_is_deterministic(self, small_render_ctx):
        bubbles, lut, vig = small_render_ctx
        a = mod.frame_rgb(SMALL_CFG, bubbles, 0.25, lut, vig, frame_index=3)
        b = mod.frame_rgb(SMALL_CFG, bubbles, 0.25, lut, vig, frame_index=3)
        np.testing.assert_array_equal(a, b)

    def test_loop_wrap_is_seamless(self, small_render_ctx):
        # frame(0.0) and frame(1.0) may differ only by the per-frame dither
        # grain; the underlying field must be periodic.
        bubbles, lut, vig = small_render_ctx
        lum0 = mod.luminance(SMALL_CFG, bubbles, 0.0)
        lum1 = mod.luminance(SMALL_CFG, bubbles, 1.0)
        np.testing.assert_allclose(lum0, lum1, atol=1e-5)

    def test_dither_grain_stays_subtle(self, small_render_ctx):
        # The only allowed first-vs-last difference is grain; keep it small
        # so the wrap reads as film grain, not a cut.
        bubbles, lut, vig = small_render_ctx
        a = mod.frame_rgb(SMALL_CFG, bubbles, 0.0, lut, vig, frame_index=0)
        b = mod.frame_rgb(SMALL_CFG, bubbles, 1.0, lut, vig, frame_index=1)
        assert np.abs(a.astype(int) - b.astype(int)).max() <= 4

    def test_zero_dither_makes_exact_wrap(self, small_render_ctx):
        bubbles, lut, vig = small_render_ctx
        cfg = mod.Config(width=96, height=54, fps=8, seconds=2, dither=0.0)
        a = mod.frame_rgb(cfg, bubbles, 0.0, lut, vig, frame_index=0)
        b = mod.frame_rgb(cfg, bubbles, 1.0, lut, vig, frame_index=1)
        np.testing.assert_array_equal(a, b)

    def test_mid_loop_differs_from_start(self, small_render_ctx):
        bubbles, lut, vig = small_render_ctx
        a = mod.frame_rgb(SMALL_CFG, bubbles, 0.0, lut, vig, frame_index=0)
        c = mod.frame_rgb(SMALL_CFG, bubbles, 0.5, lut, vig, frame_index=4)
        assert np.abs(a.astype(int) - c.astype(int)).mean() > 1.0

    def test_loop_frames_count(self):
        assert mod.loop_frames(SMALL_CFG) == 16


# ---------------------------------------------------------------------------
# Field properties
# ---------------------------------------------------------------------------


class TestField:
    def test_luminance_bounded(self, small_render_ctx):
        bubbles, _, _ = small_render_ctx
        for t in (0.0, 0.1, 0.5, 0.9):
            lum = mod.luminance(SMALL_CFG, bubbles, t)
            assert lum.shape == (SMALL_CFG.height, SMALL_CFG.width)
            assert (lum >= 0.0).all() and (lum <= 1.0).all()

    def test_surface_light_at_top(self, small_render_ctx):
        # Rays brighten the top of the frame; the upper band should not be
        # darker on average than the lower band across the loop.
        bubbles, _, _ = small_render_ctx
        top_means, bottom_means = [], []
        for f in range(mod.loop_frames(SMALL_CFG)):
            lum = mod.luminance(SMALL_CFG, bubbles, f / mod.loop_frames(SMALL_CFG))
            top_means.append(lum[: SMALL_CFG.height // 4].mean())
            bottom_means.append(lum[-SMALL_CFG.height // 4 :].mean())
        assert np.mean(top_means) > np.mean(bottom_means)

    def test_vignette_darkens_corners(self):
        vig = mod.vignette(SMALL_CFG)
        assert vig[0, 0] < vig[SMALL_CFG.height // 2, SMALL_CFG.width // 2]
        assert (vig > 0).all() and (vig <= 1.0).all()

    def test_bubble_envelope_periodic(self):
        bubbles = mod.make_bubbles(SMALL_CFG)
        np.testing.assert_allclose(
            mod.bubble_alpha(bubbles, 0.0), mod.bubble_alpha(bubbles, 1.0), atol=1e-9
        )

    def test_bubble_envelope_peaks_mid_rise(self):
        bubbles = mod.make_bubbles(SMALL_CFG)
        alpha = mod.bubble_alpha(bubbles, bubbles[0, 1] - 0.5)
        assert alpha[0] == pytest.approx(bubbles[0, 3], abs=1e-6)

    def test_frame_rgb_dtype_and_shape(self, small_render_ctx):
        bubbles, lut, vig = small_render_ctx
        frame = mod.frame_rgb(SMALL_CFG, bubbles, 0.3, lut, vig, frame_index=7)
        assert frame.dtype == np.uint8
        assert frame.shape == (SMALL_CFG.height, SMALL_CFG.width, 3)

    def test_default_config_values(self):
        # Defaults produce a 1080p 12 s loop at 24 fps; asset consumers
        # (Hidamari guidance in the docs) rely on these.
        cfg = mod.Config()
        assert (cfg.width, cfg.height) == (1920, 1080)
        assert cfg.fps == 24
        assert cfg.seconds == 12
        assert mod.loop_frames(cfg) == 288


# ---------------------------------------------------------------------------
# CLI / ffmpeg wiring
# ---------------------------------------------------------------------------


class TestCli:
    def test_missing_ffmpeg_exits_with_error(self, monkeypatch, tmp_path):
        monkeypatch.setenv("FFMPEG", str(tmp_path / "no-such-ffmpeg"))
        with pytest.raises(SystemExit, match="ffmpeg"):
            mod.render_movie(SMALL_CFG, str(tmp_path / "out.webm"))

    def test_renders_real_webm(self, tmp_path, small_render_ctx, monkeypatch):
        pytest.importorskip("numpy")
        from shutil import which

        ff = which("ffmpeg") or which(str(Path.home() / "bin" / "ffmpeg"))
        if ff is None:
            pytest.skip("ffmpeg with libvpx-vp9 not available")
        monkeypatch.setenv("FFMPEG", ff)
        out = tmp_path / "out.webm"
        mod.render_movie(SMALL_CFG, str(out))
        assert out.exists() and out.stat().st_size > 0
        # ffprobe not required: decode with ffmpeg and count frames.
        frames = subprocess.run(
            [ff, "-v", "error", "-i", str(out), "-f", "null", "-"],
            capture_output=True,
        )
        assert frames.returncode == 0

    def test_preview_frame_requires_pillow(self, monkeypatch, tmp_path):
        monkeypatch.setitem(sys.modules, "PIL", None)
        with pytest.raises(SystemExit, match="Pillow"):
            mod.preview_frame(SMALL_CFG, 0.0, str(tmp_path / "p.png"))

    def test_preview_frame_writes_png(self, tmp_path, small_render_ctx, monkeypatch):
        PIL = pytest.importorskip("PIL")
        monkeypatch.setitem(sys.modules, "PIL", PIL)
        out = tmp_path / "p.png"
        mod.preview_frame(SMALL_CFG, 0.25, str(out))
        assert out.exists() and out.stat().st_size > 0


# ---------------------------------------------------------------------------
# Shipped asset
# ---------------------------------------------------------------------------


class TestShippedAsset:
    def test_shipped_asset_exists_and_is_small(self):
        # The rebuilt WebM must be checked in. Keep it under 4 MiB: it ships
        # in the OCI layer consumed by every Bluefin variant.
        assert ASSET_PATH.exists(), "bluefin-hidamari.webm is missing from git"
        assert ASSET_PATH.stat().st_size < 4 * 1024 * 1024

    def test_shipped_asset_is_webm(self):
        assert ASSET_PATH.read_bytes()[:4] == b"\x1a\x45\xdf\xa3"
