"""Regression checks for Bazaar curated config structure."""

from pathlib import Path

import yaml


ROOT = Path(__file__).parent.parent
CURATED = ROOT / "system_files/bluefin/etc/bazaar/curated.yaml"
BAZAAR = ROOT / "system_files/bluefin/etc/bazaar/bazaar.yaml"


def _load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_curated_uses_new_schema_shape():
    """Validate curated.yaml uses the new Bazaar schema (PR #1655 'Rework Curated System').

    Old schema used css + rows[].sections[].category. New schema uses rows[] with
    banner/section/articles/featured-carousel row types.
    """
    data = _load_yaml(CURATED)

    assert isinstance(data, dict)
    assert "css" not in data, "css block removed in new schema"
    assert "rows" in data
    assert isinstance(data["rows"], list)
    assert len(data["rows"]) > 0

    known_row_types = {"banner", "section", "articles", "featured-carousel"}
    has_section = False

    for row in data["rows"]:
        assert isinstance(row, dict)
        assert len(row) == 1
        row_type = next(iter(row))
        assert row_type in known_row_types, f"Unknown row type: {row_type}"

        if row_type == "section":
            has_section = True
            section = row["section"]
            assert isinstance(section, dict)
            assert "title" in section
            assert "appids" in section
            appids = section["appids"]
            assert isinstance(appids, dict)
            assert "list" in appids
            assert isinstance(appids["list"], list)

        if row_type == "banner":
            banner = row["banner"]
            assert isinstance(banner, dict)
            assert "image" in banner
            image = banner["image"]
            # Banner images must be PNG (never JXL) to prevent Bazaar crashes
            for uri_field in ("uri", "light-uri", "dark-uri"):
                if uri_field in image:
                    assert not image[uri_field].endswith(".jxl"), \
                        f"Banner {uri_field} must not use JXL format"
                    assert image[uri_field].endswith(".png") or image[uri_field].startswith("http"), \
                        f"Banner {uri_field} should be PNG or https URL"

    assert has_section, "curated.yaml must have at least one section row"


def test_bazaar_config_valid():
    data = _load_yaml(BAZAAR)

    assert "curated-config-paths" in data


def test_article_markdown_avoids_raw_html_card_layouts():
    """Bazaar's Markdown renderer does not reliably render raw HTML div/flexbox
    card layouts (see article-devtools.md regression, common#issue "dx page busted").
    Articles must stick to plain Markdown (tables, lists, links) instead.
    """
    bazaar_dir = ROOT / "system_files/bluefin/etc/bazaar"
    article_files = sorted(bazaar_dir.glob("article-*.md"))
    assert article_files, "expected at least one Bazaar article markdown file"

    # <div> layout containers and inline "style=" attributes are what broke
    # article-devtools.md (a raw HTML flexbox card-wall). A single bare <img>
    # tag (e.g. a screenshot in article-bluefin-notes.md) is fine.
    banned_html_fragments = ("<div", "style=\"")
    placeholder_markers = ("lorem ipsum",)

    for article in article_files:
        text = article.read_text(encoding="utf-8")
        lowered = text.lower()

        for fragment in banned_html_fragments:
            assert fragment not in lowered, (
                f"{article.name} contains raw HTML ({fragment!r}); "
                "use plain Markdown tables/lists instead"
            )

        for marker in placeholder_markers:
            assert marker not in lowered, (
                f"{article.name} still contains placeholder text ({marker!r})"
            )
