"""Regression checks for Bazaar curated config structure."""

from pathlib import Path

import yaml


ROOT = Path(__file__).parent.parent
CURATED = ROOT / "system_files/bluefin/etc/bazaar/curated.yaml"
BAZAAR = ROOT / "system_files/bluefin/etc/bazaar/bazaar.yaml"


def _load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_curated_uses_legacy_schema_shape():
    data = _load_yaml(CURATED)

    assert isinstance(data, dict)
    assert "css" in data
    assert "rows" in data
    assert isinstance(data["rows"], list)
    assert len(data["rows"]) > 0

    for row in data["rows"]:
        assert isinstance(row, dict)
        assert len(row) == 1
        assert "sections" in row
        sections = row["sections"]
        assert isinstance(sections, list)
        for section in sections:
            assert isinstance(section, dict)
            assert "category" in section
            category = section["category"]
            assert "title" in category
            assert "appids" in category
            assert isinstance(category["appids"], list)

            # Banners must be PNG (never JXL) to prevent stable Bazaar 0.8.2 crashes on Gnome runtimes
            if "light-banner" in category:
                assert category["light-banner"].endswith(".png")
                assert not category["light-banner"].endswith(".jxl")
            if "dark-banner" in category:
                assert category["dark-banner"].endswith(".png")
                assert not category["dark-banner"].endswith(".jxl")


def test_bazaar_config_valid():
    data = _load_yaml(BAZAAR)

    assert "curated-config-paths" in data
