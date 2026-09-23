"""Regression checks for Bazaar curated config structure."""

from pathlib import Path

import yaml

ROOT = Path(__file__).parent.parent
CURATED = ROOT / "system_files/bluefin/etc/bazaar/curated.yaml"
BAZAAR = ROOT / "system_files/bluefin/etc/bazaar/bazaar.yaml"


def _load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_curated_uses_modern_schema_shape():
    data = _load_yaml(CURATED)

    assert isinstance(data, dict)
    assert "css" not in data  # modern schema does not use root css block
    assert "rows" in data
    assert isinstance(data["rows"], list)
    assert len(data["rows"]) > 0

    section_titles = []
    for row in data["rows"]:
        assert isinstance(row, dict)
        if "banner" in row:
            banner = row["banner"]
            assert "image" in banner
            img = banner["image"]
            assert "light-uri" in img
            assert "dark-uri" in img
            # Shipped Bazaar 0.9.x natively loads .jxl banners
            assert img["light-uri"].endswith(".jxl")
            assert img["dark-uri"].endswith(".jxl")
        elif "section" in row:
            section = row["section"]
            assert "title" in section
            assert "appids" in section
            assert "list" in section["appids"]
            assert isinstance(section["appids"]["list"], list)
            title = section["title"]
            section_titles.append(title if isinstance(title, str) else title.get("en"))

    assert "Desktop Development" in section_titles
    assert "Cloud Native Development" in section_titles
    assert "AI and Machine Learning" in section_titles


def test_bazaar_config_valid():
    data = _load_yaml(BAZAAR)

    assert "curated-config-paths" in data
    assert "hooks" in data
    hook_ids = {h["id"] for h in data["hooks"]}
    expected_hooks = {
        "jetbrains-toolbox",
        "vscode",
        "vscodium",
        "zed",
    }
    assert expected_hooks.issubset(hook_ids)

    for hook in data["hooks"]:
        assert "when" in hook
        assert "check-appid-regex" in hook
        assert "dialogs" in hook
        for dialog in hook["dialogs"]:
            assert "options" in dialog
            option_ids = {opt["id"] for opt in dialog["options"]}
            assert "cancel" in option_ids
            assert "run-devmode" in option_ids
