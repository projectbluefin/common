from pathlib import Path


def test_dx_article_is_tile_first_and_minimal():
    text = Path("system_files/bluefin/etc/bazaar/article-devtools.md").read_text(encoding="utf-8")

    assert text.startswith("# Developer Experience (DX)")
    assert "appstream://" in text
    assert "## IDEs" in text
    assert "## JetBrains" in text
    assert "## AI apps" in text

    assert "| Tool |" not in text
    assert "## CLI and CNCF tooling" not in text
    assert "## Recommended workflows" not in text
