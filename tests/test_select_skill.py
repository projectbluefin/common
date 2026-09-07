from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPT_PATH = Path(__file__).resolve().parent.parent / "scripts/select-skill.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("select_skill", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load_module()
tokenize = mod.tokenize
rank_skill = mod.rank_skill
select_skills = mod.select_skills
main = mod.main
DEFAULT_INDEX = mod.DEFAULT_INDEX


def test_tokenize_filters_stop_words_and_punctuation():
    tokens = tokenize("How to use the Bonedigger & Bazaar-curated tool?!")
    assert "the" not in tokens
    assert "to" not in tokens
    assert "bonedigger" in tokens
    assert "bazaar-curated" in tokens
    assert "tool" in tokens


def test_tokenize_empty_and_none():
    assert tokenize("") == []
    assert tokenize(None) == []


def test_rank_skill_weights():
    skill = {
        "id": "test-skill",
        "name": "Widget Manager",
        "tags": ["widget", "config"],
        "triggers": ["widget-fail"],
        "description": "Handles widget updates and sync.",
        "one_line_purpose": "Manage local widgets.",
    }

    # Name match: +10
    name_res = rank_skill(skill, ["manager"])
    assert name_res["score"] == 10

    # Tag match: +8
    tag_res = rank_skill(skill, ["config"])
    assert tag_res["score"] == 8
    assert "config" in tag_res["matched_tags"]

    # Trigger match: +6
    trigger_res = rank_skill(skill, ["widget-fail"])
    assert trigger_res["score"] == 6
    assert "widget-fail" in trigger_res["matched_triggers"]

    # Description match: +2
    desc_res = rank_skill(skill, ["updates"])
    assert desc_res["score"] == 2

    # Multiple matches accumulate
    combo_res = rank_skill(skill, ["manager", "config", "updates"])
    assert combo_res["score"] == 10 + 8 + 2


def test_select_skills_with_tmp_catalog(tmp_path: Path):
    catalog_file = tmp_path / "index.json"
    catalog_data = {
        "generated_at": "2026-09-07",
        "schema_version": "1.0",
        "skills": [
            {
                "id": "alpha",
                "name": "Alpha tool",
                "entry_point": "docs/skills/alpha.md",
                "one_line_purpose": "Alpha management",
                "tags": ["alpha", "first"],
                "description": "First skill in catalog",
            },
            {
                "id": "beta",
                "name": "Beta tool",
                "entry_point": "docs/skills/beta.md",
                "one_line_purpose": "Beta management",
                "tags": ["beta", "second"],
                "description": "Second skill in catalog",
            },
        ],
    }
    catalog_file.write_text(json.dumps(catalog_data))

    res = select_skills("first alpha", catalog_path=catalog_file)
    assert res["count"] == 1
    assert res["matches"][0]["id"] == "alpha"
    # "first" matches tag first (+8) and desc first (+2) = 10
    # "alpha" matches name (+10), tag alpha (+8), purpose alpha (+2) = 20
    # Total = 30
    assert res["matches"][0]["score"] == 30


def test_select_skills_missing_catalog(tmp_path: Path):
    missing_file = tmp_path / "nonexistent.json"
    with pytest.raises(FileNotFoundError):
        select_skills("anything", catalog_path=missing_file)


def test_select_skills_real_catalog():
    if not DEFAULT_INDEX.is_file():
        pytest.skip("docs/skills/index.json not found")
    res = select_skills("bazaar curated")
    assert res["count"] >= 1
    top = res["matches"][0]
    assert top["id"] == "bazaar"


def test_cli_main_json_output(capsys, tmp_path: Path):
    catalog_file = tmp_path / "index.json"
    catalog_data = {
        "generated_at": "2026-09-07",
        "schema_version": "1.0",
        "skills": [
            {
                "id": "test",
                "name": "Testing",
                "entry_point": "docs/skills/test.md",
                "one_line_purpose": "Testing CLI",
                "tags": ["testing"],
                "description": "A test skill",
            }
        ],
    }
    catalog_file.write_text(json.dumps(catalog_data))

    ret = main(["--json", "--catalog", str(catalog_file), "testing"])
    assert ret == 0
    captured = capsys.readouterr()
    parsed = json.loads(captured.out)
    assert parsed["count"] == 1
    assert parsed["matches"][0]["id"] == "test"


def test_cli_main_no_matches(capsys, tmp_path: Path):
    catalog_file = tmp_path / "index.json"
    catalog_file.write_text(json.dumps({"skills": []}))
    ret = main(["--catalog", str(catalog_file), "nonexistent-query"])
    assert ret == 0
    captured = capsys.readouterr()
    assert "No skills found" in captured.out
