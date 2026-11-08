from pathlib import Path
import configparser
import hashlib

DESCRIPTOR_PATH = (
    Path(__file__).parent.parent
    / "system_files/shared/usr/share/flatpak/remotes.d/flatpark.flatpakrepo"
)
FILTER_PATH = (
    Path(__file__).parent.parent
    / "system_files/shared/usr/share/flatpak/flatpark.filter"
)
SERVICE_PATH = (
    Path(__file__).parent.parent
    / "system_files/shared/usr/lib/systemd/system/flatpark-filter-copy.service"
)
PRESET_PATH = (
    Path(__file__).parent.parent
    / "system_files/shared/usr/lib/systemd/system-preset/02-flatpak-appstream-refresh.preset"
)

EXPECTED_DESCRIPTOR_SHA256 = (
    "16964493b6a989ec48d008276c62663bca29ed4d5a265c846235d89d1e0fa726"
)
EXPECTED_FILTER_SHA256 = (
    "d5fb7e1ef7eca22f3184a22e2789b47dd1f92ac140fb4a345c6f6be0b130970f"
)


def test_flatpark_files_integrity():
    assert DESCRIPTOR_PATH.is_file(), f"Missing descriptor: {DESCRIPTOR_PATH}"
    assert FILTER_PATH.is_file(), f"Missing filter: {FILTER_PATH}"

    desc_sha = hashlib.sha256(DESCRIPTOR_PATH.read_bytes()).hexdigest()
    assert (
        desc_sha == EXPECTED_DESCRIPTOR_SHA256
    ), f"Descriptor checksum mismatch: {desc_sha} != {EXPECTED_DESCRIPTOR_SHA256}"

    filter_sha = hashlib.sha256(FILTER_PATH.read_bytes()).hexdigest()
    assert (
        filter_sha == EXPECTED_FILTER_SHA256
    ), f"Filter checksum mismatch: {filter_sha} != {EXPECTED_FILTER_SHA256}"


def test_flatpark_descriptor_structure():
    cp = configparser.ConfigParser()
    cp.read(DESCRIPTOR_PATH)
    assert cp.has_section("Flatpak Repo")
    section = cp["Flatpak Repo"]
    assert section.get("Title") == "FlatPark"
    assert section.get("Url") == "https://dl.flatpark.org/"
    assert section.get("Homepage") == "https://flatpark.org"
    assert section.get("Filter") == "/usr/share/flatpak/flatpark.filter"
    assert "GPGKey" in section
    assert len(section.get("GPGKey")) > 100


def test_flatpark_filter_entries():
    lines = [
        line.strip()
        for line in FILTER_PATH.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ]
    assert len(lines) == 10
    assert "deny app/com.google.Chrome/*" in lines
    for line in lines:
        assert line.startswith("deny app/")
        assert line.endswith("/*")


def test_flatpark_filter_copy_service():
    # Sandboxed stores read the filter from libflatpak's repo/<remote>.filter fallback.
    text = SERVICE_PATH.read_text()
    # Without this guard, creating repo/ early leaves flatpak unable to open the repo.
    assert "ConditionPathExists=/var/lib/flatpak/repo/config" in text
    assert (
        "ExecStart=/usr/bin/install -m 0644 /usr/share/flatpak/flatpark.filter "
        "/var/lib/flatpak/repo/flatpark.filter"
    ) in text
    assert "RemainAfterExit=yes" in text  # stops PathExists= from re-triggering
    path_unit = SERVICE_PATH.with_suffix(".path").read_text()
    assert "PathExists=/var/lib/flatpak/repo/config" in path_unit
    assert "enable flatpark-filter-copy.path" in PRESET_PATH.read_text().splitlines()
