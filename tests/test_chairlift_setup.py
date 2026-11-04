"""Exercise login eligibility with real GSettings and an isolated keyfile backend."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / "system_files/bluefin/usr/libexec/chairlift-setup"
WRAPPER = "/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper"
SCHEMA = "io.projectbluefin.chairlift.firstrun"
SCHEMA_XML = """<schemalist>
  <schema id="io.projectbluefin.chairlift.firstrun" path="/io/projectbluefin/chairlift/firstrun/">
    <key name="disposition" type="s"><default>'not-addressed'</default></key>
    <key name="completed-version" type="s"><default>''</default></key>
  </schema>
</schemalist>
"""


class ChairliftSetupTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(LAUNCHER.is_file(), "The first-login setup launcher is missing")
        self.workspace = tempfile.TemporaryDirectory(prefix="chairlift-setup-")
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        for name in ("home", "config", "runtime", "schemas", "empty-schemas"):
            (self.root / name).mkdir(mode=0o700)
        self.env = {
            **os.environ,
            "HOME": str(self.root / "home"),
            "USER": "bluefin-test",
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_RUNTIME_DIR": str(self.root / "runtime"),
            "GSETTINGS_BACKEND": "keyfile",
            "GSETTINGS_SCHEMA_DIR": str(self.root / "schemas"),
            "DBUS_SESSION_BUS_ADDRESS": "disabled:",
        }
        (self.root / "schemas" / "firstrun.gschema.xml").write_text(SCHEMA_XML)
        subprocess.run(
            ["glib-compile-schemas", "--strict", str(self.root / "schemas")],
            check=True,
            capture_output=True,
            text=True,
        )
        self.wrapper = self.root / "chairlift-wrapper"
        self.wrapper.write_text(
            '#!/bin/bash\nprintf "launched\\n" >> "$HOME/launches"\n'
            'exit "${LAUNCH_EXIT:-0}"\n'
        )
        self.wrapper.chmod(0o755)
        # Relocate only the installed executable path, as in test_brew_preinstall.bats.
        self.launcher = self.root / "chairlift-setup"
        self.launcher.write_text(LAUNCHER.read_text().replace(WRAPPER, str(self.wrapper)))
        self.launched = self.root / "home" / "launches"

    def setting(self, operation, key, *value):
        return subprocess.run(
            ["gsettings", operation, SCHEMA, key, *value],
            env=self.env,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def launch(self, **overrides):
        return subprocess.run(
            ["bash", str(self.launcher)],
            env={**self.env, **overrides},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_unsettled_user_is_prompted_without_recording_a_decision(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.launched.exists())
        self.assertEqual(self.setting("get", "disposition"), "'not-addressed'")
        self.assertEqual(self.setting("get", "completed-version"), "''")

    def test_completion_and_dismissal_prevent_later_login_prompts(self):
        for disposition in ("completed", "skipped"):
            with self.subTest(disposition=disposition):
                self.setting("set", "disposition", disposition)
                result = self.launch()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.launched.exists())
                self.assertEqual(self.setting("get", "disposition"), f"'{disposition}'")

    def test_legacy_completion_prevents_prompt_despite_unrecognized_disposition(self):
        self.setting("set", "disposition", "older-state")
        self.setting("set", "completed-version", "26.10.1")
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.launched.exists())

    def test_unrecognized_disposition_without_completion_is_still_unsettled(self):
        self.setting("set", "disposition", "older-state")
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.launched.exists())

    def test_failed_launch_leaves_setup_eligible_for_the_next_login(self):
        result = self.launch(LAUNCH_EXIT="17")
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertTrue(self.launched.exists())
        self.assertEqual(self.setting("get", "disposition"), "'not-addressed'")
        self.launched.unlink()
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.launched.exists())

    def test_missing_installation_does_not_consume_setup(self):
        self.wrapper.chmod(0o644)
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.launched.exists())
        self.assertEqual(self.setting("get", "disposition"), "'not-addressed'")
        self.wrapper.chmod(0o755)
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.launched.exists())

    def test_settings_read_failure_never_launches_or_records_a_skip(self):
        result = self.launch(GSETTINGS_SCHEMA_DIR=str(self.root / "empty-schemas"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.launched.exists())
        self.assertEqual(self.setting("get", "disposition"), "'not-addressed'")
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.launched.exists())

    def test_greeter_accounts_are_excluded_before_reading_settings(self):
        for username in ("gdm", "gdm-launch-environment"):
            with self.subTest(username=username):
                result = self.launch(
                    USER=username,
                    GSETTINGS_SCHEMA_DIR=str(self.root / "empty-schemas"),
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.launched.exists())

    def test_transient_greeter_home_is_excluded(self):
        result = self.launch(
            HOME="/run/gdm/home/transient-user",
            GSETTINGS_SCHEMA_DIR=str(self.root / "empty-schemas"),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.launched.exists())


if __name__ == "__main__":
    unittest.main()
