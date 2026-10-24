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

EXPECTED_DESCRIPTOR_SHA256 = (
    "16964493b6a989ec48d008276c62663bca29ed4d5a265c846235d89d1e0fa726"
)
EXPECTED_FILTER_SHA256 = (
    "26a553620a18b4df26226c14d24eb38307a6beabf33942968992bc22c7d4a695"
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
    assert len(lines) == 9
    for line in lines:
        assert line.startswith("deny app/")
        assert line.endswith("/*")
