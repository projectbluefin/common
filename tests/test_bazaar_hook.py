"""Tests for system_files/bluefin/usr/libexec/bazaar-hook

bazaar-hook is a Python script invoked by Bazaar with environment variables set.
It intercepts JetBrains and VSCode Flatpak installations and redirects them to
native Linux packages via brew / ujust. Tests exercise the state-machine logic
by injecting env vars and capturing stdout, the same pattern used for hooks.py.
"""

import importlib.machinery
import importlib.util
import io
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

HOOK_PATH = (
    Path(__file__).parent.parent
    / "system_files/bluefin/usr/libexec/bazaar-hook"
)


def _run_hook(env: dict) -> str:
    """Execute bazaar-hook under a given environment, return stdout."""
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

    # bazaar-hook has no .py extension; supply the loader explicitly
    loader = importlib.machinery.SourceFileLoader("bazaar_hook", str(HOOK_PATH))
    spec = importlib.util.spec_from_loader("bazaar_hook", loader)

    with patch.dict(os.environ, env_defaults, clear=True):
        with patch("subprocess.Popen") as mock_popen:
            mock_popen.return_value = MagicMock()
            mod = importlib.util.module_from_spec(spec)
            old_stdout = sys.stdout
            buf = io.StringIO()
            sys.stdout = buf
            try:
                spec.loader.exec_module(mod)
            except SystemExit:
                pass
            finally:
                sys.stdout = old_stdout

    return buf.getvalue().strip()


def _run_hook_with_mock(env: dict) -> tuple:
    """Like _run_hook but also returns the Popen mock for action-stage tests."""
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

    loader = importlib.machinery.SourceFileLoader("bazaar_hook", str(HOOK_PATH))
    spec = importlib.util.spec_from_loader("bazaar_hook", loader)

    popen_calls = []
    with patch.dict(os.environ, env_defaults, clear=True):
        with patch("subprocess.Popen") as mock_popen:
            mock_popen.return_value = MagicMock()
            mock_popen.side_effect = lambda args, **kwargs: (popen_calls.append(args), MagicMock())[1]
            mod = importlib.util.module_from_spec(spec)
            old_stdout = sys.stdout
            buf = io.StringIO()
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
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.jetbrains.IntelliJIdea",
        })
        assert resp == "ok"

    def test_setup_install_pycharm_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.jetbrains.PyCharm",
        })
        assert resp == "ok"

    def test_setup_install_android_studio_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.google.AndroidStudio",
        })
        assert resp == "ok"

    def test_setup_non_jetbrains_returns_pass(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "org.gnome.Calculator",
        })
        assert resp == "pass"

    def test_setup_direct_mapped_jetbrains_app_returns_pass(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.jetbrains.CLion",
        })
        assert resp == "pass"

    def test_setup_dialog_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "setup-dialog",
        })
        assert resp == "ok"

    def test_teardown_dialog_run_ujust_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "run-ujust",
        })
        assert resp == "ok"

    def test_teardown_dialog_other_returns_abort(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "cancel",
        })
        assert resp == "abort"

    def test_catch_returns_abort(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "catch",
        })
        assert resp == "abort"

    def test_action_spawns_ujust_and_returns_empty(self):
        resp, popen_calls = _run_hook_with_mock({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "action",
        })
        assert resp == ""
        assert len(popen_calls) == 1
        assert "ujust install-jetbrains-toolbox" in " ".join(popen_calls[0])

    def test_teardown_returns_deny(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "jetbrains-toolbox",
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"


# ---------------------------------------------------------------------------
# VSCode / VSCodium hook
# ---------------------------------------------------------------------------

class TestCodeHook:
    def test_setup_install_vscode_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.visualstudio.code",
        })
        assert resp == "ok"

    def test_setup_install_codium_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "com.vscodium.codium",
        })
        assert resp == "ok"

    def test_setup_non_code_returns_pass(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "org.mozilla.firefox",
        })
        assert resp == "pass"

    def test_setup_dialog_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "setup-dialog",
        })
        assert resp == "ok"

    def test_teardown_dialog_download_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "download",
        })
        assert resp == "ok"

    def test_teardown_dialog_other_returns_abort(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "teardown-dialog",
            "BAZAAR_HOOK_DIALOG_RESPONSE_ID": "cancel",
        })
        assert resp == "abort"

    def test_catch_returns_abort(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "catch",
        })
        assert resp == "abort"

    def test_action_vscode_spawns_brew_and_returns_empty(self):
        resp, popen_calls = _run_hook_with_mock({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": "com.visualstudio.code",
        })
        assert resp == ""
        assert len(popen_calls) == 1
        assert "visual-studio-code-linux" in " ".join(popen_calls[0])

    def test_action_codium_spawns_brew_and_returns_empty(self):
        resp, popen_calls = _run_hook_with_mock({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": "com.vscodium.codium",
        })
        assert resp == ""
        assert len(popen_calls) == 1
        assert "vscodium-linux" in " ".join(popen_calls[0])

    def test_teardown_returns_deny(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "code",
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"


# ---------------------------------------------------------------------------
# Zed hook
# ---------------------------------------------------------------------------

class TestZedHook:
    def test_setup_install_zed_returns_ok(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "zed",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "dev.zed.Zed",
        })
        assert resp == "ok"

    def test_setup_non_zed_returns_pass(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "zed",
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "org.mozilla.firefox",
        })
        assert resp == "pass"

    def test_action_zed_spawns_brew_and_returns_empty(self):
        resp, popen_calls = _run_hook_with_mock({
            "BAZAAR_HOOK_ID": "zed",
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": "dev.zed.Zed",
        })
        assert resp == ""
        assert len(popen_calls) == 1
        assert "zed-linux" in " ".join(popen_calls[0])
        assert "ublue-os/experimental-tap" in " ".join(popen_calls[0])

    def test_teardown_returns_deny(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "zed",
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"


# ---------------------------------------------------------------------------
# GUI cask hooks
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "hook_id,appid,cask,tap",
    [
        ("emacs", "org.gnu.emacs", "emacs-app-linux", "ublue-os/experimental-tap"),
        ("clion", "com.jetbrains.CLion", "clion-linux", "ublue-os/experimental-tap"),
        ("datagrip", "com.jetbrains.DataGrip", "datagrip-linux", "ublue-os/experimental-tap"),
        ("goland", "com.jetbrains.GoLand", "goland-linux", "ublue-os/experimental-tap"),
        ("intellij", "com.jetbrains.IntelliJ-IDEA-Community", "intellij-idea-linux", "ublue-os/experimental-tap"),
        ("phpstorm", "com.jetbrains.PhpStorm", "phpstorm-linux", "ublue-os/experimental-tap"),
        ("pycharm", "com.jetbrains.PyCharm-Community", "pycharm-linux", "ublue-os/experimental-tap"),
        ("rider", "com.jetbrains.Rider", "rider-linux", "ublue-os/experimental-tap"),
        ("rubymine", "com.jetbrains.RubyMine", "rubymine-linux", "ublue-os/experimental-tap"),
        ("rustrover", "com.jetbrains.RustRover", "rustrover-linux", "ublue-os/experimental-tap"),
        ("webstorm", "com.jetbrains.WebStorm", "webstorm-linux", "ublue-os/experimental-tap"),
        ("opencode-desktop", "ai.opencode.opencode", "opencode-desktop-linux", "ublue-os/experimental-tap"),
        ("lm-studio", "ai.lmstudio.lm-studio", "lm-studio-linux", "ublue-os/tap"),
    ],
)
class TestGuiCaskHooks:
    def test_setup_install_returns_ok(self, hook_id, appid, cask, tap):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == "ok"

    def test_action_spawns_expected_cask(self, hook_id, appid, cask, tap):
        resp, popen_calls = _run_hook_with_mock({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == ""
        assert len(popen_calls) == 1
        args = " ".join(popen_calls[0])
        assert cask in args
        assert tap in args

    def test_teardown_returns_deny(self, hook_id, appid, cask, tap):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"


# ---------------------------------------------------------------------------
# CLI editor hooks (Neovim, Helix, vim, micro)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "hook_id,appid,formula",
    [
        ("neovim", "io.neovim.nvim", "nvim"),
        ("helix", "com.helix_editor.Helix", "helix"),
        ("vim", "org.vim.Vim", "vim"),
        ("micro", "io.github.zyedidia.micro", "micro"),
    ],
)
class TestCliEditorHooks:
    def test_setup_install_returns_ok(self, hook_id, appid, formula):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == "ok"

    def test_setup_non_matching_returns_pass(self, hook_id, appid, formula):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "setup",
            "BAZAAR_TS_TYPE": "install",
            "BAZAAR_TS_APPID": "org.mozilla.firefox",
        })
        assert resp == "pass"

    def test_action_spawns_formula_and_returns_empty(self, hook_id, appid, formula):
        resp, popen_calls = _run_hook_with_mock({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "action",
            "BAZAAR_TS_APPID": appid,
        })
        assert resp == ""
        assert len(popen_calls) == 1
        assert formula in " ".join(popen_calls[0])

    def test_teardown_returns_deny(self, hook_id, appid, formula):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": hook_id,
            "BAZAAR_HOOK_STAGE": "teardown",
        })
        assert resp == "deny"


# ---------------------------------------------------------------------------
# Unknown hook ID
# ---------------------------------------------------------------------------

class TestUnknownHook:
    def test_unknown_hook_id_returns_pass(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "unknown-hook-xyz",
            "BAZAAR_HOOK_STAGE": "setup",
        })
        assert resp == "pass"

    def test_empty_hook_id_returns_pass(self):
        resp = _run_hook({
            "BAZAAR_HOOK_ID": "",
            "BAZAAR_HOOK_STAGE": "setup",
        })
        assert resp == "pass"
