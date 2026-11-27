from pathlib import Path
import configparser
import re

PREINSTALL_DIR = (
    Path(__file__).parent.parent
    / "system_files/bluefin/usr/share/flatpak/preinstall.d"
)

# Apps the image guarantees on every install. Bazaar is preinstalled via its own
# file; the others come from the Flatpak preinstall manifests shipped with the image.
EXPECTED_APPS = {
    "io.github.kolunmi.Bazaar",
    "org.gnome.NautilusPreviewer",
    "org.gnome.Papers",
    "org.gnome.baobab",
}


def _preinstalls():
    """Map every [Flatpak Preinstall NAME] group to its parsed section."""
    apps = {}
    for path in sorted(PREINSTALL_DIR.glob("*.preinstall")):
        cp = configparser.ConfigParser()
        cp.read(path)
        for section in cp.sections():
            assert section.startswith(
                "Flatpak Preinstall "
            ), f"Unexpected section in {path.name}: {section}"
            app_id = section.removeprefix("Flatpak Preinstall ")
            assert re.fullmatch(
                r"[A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+", app_id
            ), f"Invalid app id in {path.name}: {app_id}"
            assert app_id not in apps, f"Duplicate preinstall for {app_id}"
            apps[app_id] = cp[section]
    return apps


def test_preinstall_dir_exists():
    assert PREINSTALL_DIR.is_dir(), f"Missing directory: {PREINSTALL_DIR}"


def test_expected_apps_are_preinstalled():
    apps = _preinstalls()
    assert EXPECTED_APPS <= set(apps), (
        f"Missing preinstalls: {sorted(EXPECTED_APPS - set(apps))}"
    )


def test_preinstall_apps_use_stable_branches_as_applications():
    apps = _preinstalls()
    for app_id, section in apps.items():
        assert section.get("Branch") == "stable", f"{app_id}: Branch must be stable"
        assert (
            section.getboolean("IsRuntime") is False
        ), f"{app_id}: IsRuntime must be false for applications"
