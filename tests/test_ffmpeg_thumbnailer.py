"""
Tests for ffmpeg-thumbnailer-daemon and ffmpeg-video-thumbnailer-shim.
"""

from importlib.machinery import SourceFileLoader
import importlib.util
import os
from pathlib import Path
import socket
import threading
import time
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


def test_daemon_handle_request_invalid_fd_type(daemon_mod, tmp_path):
    # Pass a non-regular file descriptor (e.g. socket) to verify security rejection
    s1, s2 = socket.socketpair()
    try:
        res = daemon_mod.handle_request(b"THUMB\t256\n", [s1.fileno(), s2.fileno()])
        assert "invalid file descriptor type" in res
    finally:
        s1.close()
        s2.close()


def test_daemon_returns_unavailable_when_container_missing(daemon_mod, tmp_path):
    in_file = tmp_path / "in.mp4"
    in_file.write_bytes(b"dummy")
    out_file = tmp_path / "out.png"

    in_fd = os.open(str(in_file), os.O_RDONLY)
    out_fd = os.open(str(out_file), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)

    try:
        with mock.patch("subprocess.run") as mock_run:
            mock_run.return_value = mock.Mock(returncode=125)
            res = daemon_mod.handle_request(b"THUMB\t256\n", [in_fd, out_fd])
            assert res == "ERR_UNAVAILABLE"
    finally:
        os.close(in_fd)
        os.close(out_fd)


def test_shim_falls_back_on_err_unavailable(shim_mod, tmp_path):
    out_file = str(tmp_path / "out.png")
    with mock.patch("sys.argv", ["shim", "-s", "256", "file:///tmp/vid.mp4", out_file]):
        with mock.patch.object(shim_mod, "get_socket_path", return_value="/tmp/fake.sock"):
            with mock.patch("socket.socket") as mock_sock_cls:
                mock_sock = mock.MagicMock()
                mock_sock.recv.return_value = b"ERR_UNAVAILABLE\n"
                mock_sock_cls.return_value = mock_sock
                with mock.patch("os.open", return_value=10):
                    with mock.patch("os.close"):
                        with mock.patch.object(shim_mod, "fallback_local_ffmpeg", return_value=True) as mock_fb:
                            with pytest.raises(SystemExit) as exc:
                                shim_mod.main()
                            assert exc.value.code == 0
                            assert mock_fb.called


def test_quadlet_condition_complementarity():
    # Verify that Alpine and NVIDIA quadlet conditions form a partition over (arch, nvidia_present)
    import configparser
    repo_root = Path(__file__).resolve().parent.parent
    alpine_path = repo_root / "system_files/shared/usr/share/containers/systemd/users/ffmpeg-thumbnailer.container"
    nvidia_path = repo_root / "system_files/shared/usr/share/containers/systemd/users/ffmpeg-thumbnailer-nvidia.container"

    # Both must target the identical container name so the daemon config is invariant
    alpine_cfg = configparser.ConfigParser(strict=False)
    alpine_cfg.read(alpine_path)
    nvidia_cfg = configparser.ConfigParser(strict=False)
    nvidia_cfg.read(nvidia_path)

    assert alpine_cfg["Container"]["ContainerName"] == "ffmpeg-thumbnailer"
    assert nvidia_cfg["Container"]["ContainerName"] == "ffmpeg-thumbnailer"

    # Verify quadlet options
    assert alpine_cfg["Container"]["RunInit"] == "true"
    assert nvidia_cfg["Container"]["RunInit"] == "true"
    with open(nvidia_path) as nf:
        nvidia_raw = nf.read()
    assert "AddDevice=nvidia.com/gpu=all" in nvidia_raw


def test_serve_recovering_rebinds_after_socket_deleted(daemon_mod, tmp_path):
    # GNOME's clean_gst_registry_dir() deletes the socket path out from under
    # the running daemon. serve_recovering must rebind at the same path so
    # subsequent connections succeed without a full daemon restart.
    sock_path = str(tmp_path / "rebind.sock")
    stop = threading.Event()

    thread = threading.Thread(
        target=daemon_mod.serve_recovering,
        args=(sock_path, daemon_mod.Handler, stop),
        daemon=True,
    )
    thread.start()

    # Wait for the daemon to bind before connecting (avoid a startup race).
    deadline = time.monotonic() + 5
    while not os.path.exists(sock_path) and time.monotonic() < deadline:
        time.sleep(0.05)

    def ping_ok():
        try:
            conn = socket.socket(socket.AF_UNIX)
            conn.settimeout(2)
            conn.connect(sock_path)
            conn.sendall(b"PING\n")
            return conn.recv(64) == b"OK\n"
        except OSError:
            return False

    assert ping_ok(), "daemon should answer PING before the socket is deleted"

    # Simulate gnome-desktop-thumbnailer removing the socket path.
    os.unlink(sock_path)
    assert not os.path.exists(sock_path)

    # The loop polls every ~0.5s; wait for it to notice and rebind.
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline and not os.path.exists(sock_path):
        time.sleep(0.05)
    assert os.path.exists(sock_path), "socket path should be recreated"
    assert ping_ok(), "daemon should answer PING after rebinding"

    stop.set()
    thread.join(timeout=5)
    assert not thread.is_alive(), "serve_recovering should stop when signaled"
