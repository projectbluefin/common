"""Tests for system_files/bluefin/etc/bazaar/hooks.py

Hooks are invoked by Bazaar with environment variables set. Each hook
returns a response string on stdout. We test the state machine logic by
setting the relevant env vars and capturing the printed response.
"""

import importlib.util
import io
import os
import sys
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

HOOKS_PATH = (
    Path(__file__).parent.parent
    / "system_files/bluefin/etc/bazaar/hooks.py"
)


def _load_hooks(env: dict) -> str:
    """Execute hooks.py under a given environment, return stdout."""
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

    with patch.dict(os.environ, env_defaults, clear=True):
        # Mock subprocess.Popen so spawn helpers don't actually launch processes
        with patch("subprocess.Popen") as mock_popen:
            mock_popen.return_value = MagicMock()
            spec = importlib.util.spec_from_file_location("hooks", HOOKS_PATH)
            mod = importlib.util.module_from_spec(spec)
            # Redirect sys.stdout during exec so print() is captured
            old_stdout = sys.stdout
            sys.stdout = buf
            try:
                spec.loader.exec_module(mod)
            except SystemExit:
                pass
            finally:
                sys.stdout = old_stdout

    return buf.getvalue().strip()


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

    def test_action_spawns_ujust_and_returns_empty(self):
        with patch("subprocess.Popen") as mock_popen:
            mock_popen.return_value = MagicMock()
            resp = _load_hooks({
                "BAZAAR_HOOK_ID": "jetbrains-toolbox",
                "BAZAAR_HOOK_STAGE": "action",
            })
        assert resp == ""


# ---------------------------------------------------------------------------
# Code (VSCode/VSCodium) hook
# ---------------------------------------------------------------------------

class TestCodeHook:
    def test_setup_install_vscode_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.visualstudio.code",
        })
        assert resp == "ok"

    def test_setup_install_codium_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.vscodium.codium",
        })
        assert resp == "ok"

    def test_setup_non_code_returns_pass(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "org.mozilla.firefox",
        })
        assert resp == "pass"

    def test_setup_dialog_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup-dialog",
        })
        assert resp == "ok"

    def test_teardown_dialog_download_returns_ok(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "download",
        })
        assert resp == "ok"

    def test_teardown_dialog_other_returns_abort(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "cancel",
        })
        assert resp == "abort"

    def test_catch_returns_abort(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "catch",
        })
        assert resp == "abort"

    def test_teardown_returns_deny(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"

    def test_action_vscode_returns_empty(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": "com.visualstudio.code",
        })
        assert resp == ""

    def test_action_codium_returns_empty(self):
        resp = _load_hooks({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": "com.vscodium.codium",
        })
        assert resp == ""


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
