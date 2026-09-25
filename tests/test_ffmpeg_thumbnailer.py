"""
Tests for ffmpeg-thumbnailer-daemon and ffmpeg-video-thumbnailer-shim.
"""

from importlib.machinery import SourceFileLoader
import importlib.util
import os
from pathlib import Path
import socket
from unittest import mock

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
DAEMON_PATH = REPO_ROOT / "system_files/shared/usr/libexec/ffmpeg-thumbnailer/ffmpeg-thumbnailer-daemon"
SHIM_PATH = REPO_ROOT / "system_files/shared/usr/libexec/ffmpeg-thumbnailer/ffmpeg-video-thumbnailer-shim"


@pytest.fixture(scope="module")
def daemon_mod():
    loader = SourceFileLoader("daemon", str(DAEMON_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def shim_mod():
    loader = SourceFileLoader("shim", str(SHIM_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def test_daemon_handle_request_ping(daemon_mod):
    assert daemon_mod.handle_request(b"PING\n", []) == "OK"


def test_daemon_handle_request_invalid_verb(daemon_mod):
    assert "invalid request" in daemon_mod.handle_request(b"UNKNOWN\n", [])


def test_daemon_handle_request_missing_fds(daemon_mod):
    assert "expected input and output descriptors" in daemon_mod.handle_request(b"THUMB\t256\n", [])


def test_daemon_cmd_structure(daemon_mod):
    with mock.patch("subprocess.run") as mock_run:
        mock_run.return_value = mock.Mock(returncode=0)
        daemon_mod.run_container_ffmpeg("00:00:03", 256, 3, 4)
        assert mock_run.called
        cmd = mock_run.call_args[0][0]
        assert "timeout" in cmd
        assert "-threads" in cmd and "1" in cmd
        assert "--preserve-fd=3,4" in cmd[2]


def test_daemon_handle_request_valid_invocation(daemon_mod, tmp_path):
    in_file = tmp_path / "in.mp4"
    in_file.write_bytes(b"dummy")
    out_file = tmp_path / "out.png"

    in_fd = os.open(str(in_file), os.O_RDONLY)
    out_fd = os.open(str(out_file), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)

    try:
        with mock.patch.object(daemon_mod, "run_container_ffmpeg") as mock_ffmpeg:
            def fake_ffmpeg(seek, size, in_fd, out_fd):
                os.write(out_fd, b"\x89PNGfake")
                return True

            mock_ffmpeg.side_effect = fake_ffmpeg
            res = daemon_mod.handle_request(b"THUMB\t256\n", [in_fd, out_fd])
            assert res == "OK"
            assert out_file.read_bytes() == b"\x89PNGfake"
    finally:
        os.close(in_fd)
        os.close(out_fd)


def test_shim_uri_parsing_and_arg_forwarding(shim_mod, tmp_path):
    out_file = str(tmp_path / "out.png")
    with mock.patch("sys.argv", ["shim", "-s", "512", "file:///tmp/my%20video.mp4", out_file]):
        with mock.patch.object(shim_mod, "get_socket_path", return_value=None):
            with mock.patch.object(shim_mod, "fallback_local_ffmpeg") as mock_fallback:
                mock_fallback.return_value = True
                with pytest.raises(SystemExit) as exc:
                    shim_mod.main()
                assert exc.value.code == 0
                mock_fallback.assert_called_once_with("/tmp/my video.mp4", out_file, 512)
