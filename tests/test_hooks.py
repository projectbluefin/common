"""Tests for system_files/bluefin/etc/bazaar/hooks.py

Hooks are invoked by Bazaar with environment variables set. Each hook
returns a response string on stdout. We test the state machine logic by
setting the relevant env vars and capturing the printed response.
"""

import importlib.util
import io
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

HOOKS_PATH = (
    Path(__file__).parent.parent
    / "system_files/bluefin/etc/bazaar/hooks.py"
)


def _load_hooks(env: dict) -> str:
    """Execute hooks.py under a given environment, return stdout."""
    resp, _ = _load_hooks_with_mock(env)
    return resp


def _load_hooks_with_mock(env: dict) -> tuple[str, list]:
    """Execute hooks.py under a given environment, return stdout and Popen calls."""
    env_defaults = {
        "BAZAAR_HOOK_INITIATED_UNIX_STAMP": "0",
        "BAZAAR_HOOK_INITIATED_UNIX_STAMP_USEC": "0",
        "BAZAAR_HOOK_ID": "",
        "BAZAAR_HOOK_TYPE": "",
        "BAZAAR_HOOK_WAS_ABORTED": "",
        "BAZAAR_HOOK_DIALOG_ID": "",
        "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "",
        "BAZAAR_APPID": "",
        "BAZAAR_TS_APPID": "",
        "BAZAAR_TS_TYPE": "",
        "BAZAAR_HOOK_STAGE": "",
        "BAZAAR_HOOK_STAGE_IDX": "",
    }
    env_defaults.update(env)

    buf = io.StringIO()
    popen_calls = []

    with patch.dict(os.environ, env_defaults, clear=True):
        with patch("subprocess.Popen") as mock_popen:
            mock_popen.return_value = MagicMock()
            mock_popen.side_effect = lambda args, **kwargs: (popen_calls.append(args), MagicMock())[1]
            spec = importlib.util.spec_from_file_location("hooks", HOOKS_PATH)
            mod = importlib.util.module_from_spec(spec)
            old_stdout = sys.stdout
            sys.stdout = buf
            try:
                spec.loader.exec_module(mod)
            except SystemExit:
                pass
            finally:
                sys.stdout = old_stdout

    return buf.getvalue().strip(), popen_calls


# ---------------------------------------------------------------------------
# JetBrains hook
# ---------------------------------------------------------------------------

class TestJetbrainsHook:
    def test_setup_install_jetbrains_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.jetbrains.IntelliJIdea",
        })
        assert resp == "ok"

    def test_setup_install_pycharm_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.jetbrains.PyCharm-Community",
        })
        assert resp == "ok"

    def test_setup_install_android_studio_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.google.AndroidStudio",
        })
        assert resp == "ok"

    def test_setup_non_jetbrains_returns_pass(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "org.gnome.Calculator",
        })
        assert resp == "pass"

    def test_setup_update_returns_pass(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "update",
            "BAZAAR_TS_APPID": "com.jetbrains.IntelliJIdea",
        })
        assert resp == "pass"

    def test_setup_dialog_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup-dialog",
        })
        assert resp == "ok"

    def test_teardown_dialog_run_ujust_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "run-ujust",
        })
        assert resp == "ok"

    def test_teardown_dialog_run_devmode_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "run-devmode",
        })
        assert resp == "ok"

    def test_teardown_dialog_other_returns_abort(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "cancel",
        })
        assert resp == "abort"

    def test_catch_returns_abort(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "catch",
        })
        assert resp == "abort"

    def test_teardown_returns_deny(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"

    def test_action_spawns_ujust_install_toolbox(self):
        resp, calls = _load_hooks_with_mock({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "run-ujust",
        })
        assert resp == ""
        assert len(calls) == 1
        cmd = " ".join(calls[0])
        assert "ujust install-jetbrains-toolbox" in cmd
        assert "io.github.kolunmi.Bazaar" in cmd

    def test_action_spawns_ujust_devmode(self):
        resp, calls = _load_hooks_with_mock({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "run-devmode",
        })
        assert resp == ""
        assert len(calls) == 1
        cmd = " ".join(calls[0])
        assert "ujust devmode" in cmd
        assert "io.github.kolunmi.Bazaar" in cmd


# ---------------------------------------------------------------------------
# Brew-installed IDE hooks (VSCode, VSCodium, Zed)
# ---------------------------------------------------------------------------

IDE_CASES = [
    ("vscode", "com.visualstudio.code", "com.vscodium.codium", "ublue-os/tap/visual-studio-code-linux"),
    ("vscodium", "com.vscodium.codium", "com.visualstudio.code", "ublue-os/tap/vscodium-linux"),
    ("zed", "dev.zed.Zed", "org.mozilla.firefox", "ublue-os/tap/zed-linux"),
]


@pytest.mark.parametrize("hook_id,appid,other_appid,brew_pkg", IDE_CASES)
class TestIDEHook:
    def test_setup_install_returns_ok(self, hook_id, appid, other_appid, brew_pkg):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == "ok"

    def test_setup_other_app_returns_pass(self, hook_id, appid, other_appid, brew_pkg):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": other_appid,
        })
        assert resp == "pass"

    @pytest.mark.parametrize("stage,dialog_response,expected", [
        ("setup-dialog", None, "ok"),
        ("teardown-dialog", "download", "ok"),
        ("teardown-dialog", "run-devmode", "ok"),
        ("teardown-dialog", "cancel", "abort"),
        ("catch", None, "abort"),
        ("teardown", None, "deny"),
    ])
    def test_stage_response(self, hook_id, appid, other_appid, brew_pkg, stage, dialog_response, expected):
        env = {"BAZAAR_HOOK_ID": hook_id, "BAZAAR_HOOK_STAGE": stage}
        if dialog_response:
            env["BAZAAR_HOOK_DIALOG_RESPONSE_ID"] = dialog_response
        assert _load_hooks(env) == expected

    def test_action_download_spawns_brew(self, hook_id, appid, other_appid, brew_pkg):
        resp, calls = _load_hooks_with_mock({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "download",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == ""
        assert len(calls) == 1
        cmd = " ".join(calls[0])
        assert "brew tap ublue-os/tap" in cmd
        assert "brew trust ublue-os/tap" in cmd
        assert f"brew install --cask {brew_pkg}" in cmd

    def test_action_run_devmode_spawns_devmode(self, hook_id, appid, other_appid, brew_pkg):
        resp, calls = _load_hooks_with_mock({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "run-devmode",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == ""
        assert len(calls) == 1
        assert "ujust devmode" in " ".join(calls[0])


# ---------------------------------------------------------------------------
# Unknown hook ID
# ---------------------------------------------------------------------------

class TestUnknownHook:
    def test_unknown_hook_returns_pass(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "unknown-hook-xyz",
            "BAZAAR_HOOK_STAGE": "setup",
        })
        assert resp == "pass"
