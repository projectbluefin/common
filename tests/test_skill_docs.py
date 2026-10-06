from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
CHECK_DOC_LINKS = REPO_ROOT / "scripts/check-doc-links.sh"
CHECK_SKILL_INDEX = REPO_ROOT / "scripts/check-skill-index.sh"
GENERATE_SKILL_INDEX = REPO_ROOT / "scripts/generate_skill_index.py"


def run_script(
    interpreter: str, script: Path, cwd: Path
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [interpreter, str(script)],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def write_skill(path: Path, *, frontmatter: str, body: str = "Body\n") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        textwrap.dedent(
            f"""\
            ---
            {frontmatter.rstrip()}
            ---

            {body.rstrip()}
            """
        )
    )


def load_generate_skill_index():
    spec = importlib.util.spec_from_file_location(
        "generate_skill_index", GENERATE_SKILL_INDEX
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def make_catalog_schema() -> dict:
    entry_schema = {
        "type": "object",
        "required": [
            "id",
            "name",
            "one_line_purpose",
            "entry_point",
            "category",
            "status",
            "tags",
            "description",
            "version",
            "last_updated",
        ],
        "properties": {
            "id": {"type": "string"},
            "name": {"type": "string"},
            "one_line_purpose": {"type": "string"},
            "entry_point": {"type": "string"},
            "category": {"type": "string"},
            "status": {"type": "string"},
            "tags": {"type": "array"},
            "description": {"type": "string"},
            "version": {"type": "string"},
            "last_updated": {"type": "string"},
            "doc_type": {"type": "string"},
        },
        "additionalProperties": True,
    }
    return {
        "type": "object",
        "required": ["generated_at", "schema_version", "skills"],
        "properties": {
            "generated_at": {"type": "string"},
            "schema_version": {"type": "string"},
            "skills": {"type": "array", "items": entry_schema},
        },
        "additionalProperties": False,
    }


def patch_skill_index_paths(mod, repo_root: Path) -> None:
    skills_dir = repo_root / "docs" / "skills"
    mod.REPO_ROOT = repo_root
    mod.SKILLS_DIR = skills_dir
    mod.SCHEMA_PATH = skills_dir / "index.schema.json"
    mod.INDEX_PATH = skills_dir / "index.json"


def make_skill_tree(tmp_path: Path) -> Path:
    repo_root = tmp_path
    skills_dir = repo_root / "docs" / "skills"
    skills_dir.mkdir(parents=True)

    write_skill(
        skills_dir / "zeta.md",
        frontmatter="""
            id: zeta
            name: zeta
            one_line_purpose: "Zeta purpose"
            entry_point: docs/skills/zeta.md
            category: reference
            status: active
            tags: [shell, docs]
            description: >
              Zeta skill description
            version: "1.0"
            last_updated: "2026-08-01"
            metadata:
              type: reference
        """,
    )
    write_skill(
        skills_dir / "alpha" / "SKILL.md",
        frontmatter="""
            id: alpha
            name: alpha
            one_line_purpose: "Alpha purpose"
            entry_point: docs/skills/alpha/SKILL.md
            category: test-authoring
            status: active
            tags: [shell, docs]
            description: Alpha skill description
            version: "1.0"
            last_updated: "2026-08-01"
            metadata:
              type: reference
        """,
    )
    (skills_dir / "index.schema.json").write_text(
        json.dumps(make_catalog_schema(), indent=2) + "\n"
    )
    return repo_root


def test_check_doc_links_passes_with_complete_catalog(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    skills = docs / "skills"
    skills.mkdir(parents=True)

    (skills / "alpha.md").write_text("alpha\n")
    (skills / "beta").mkdir()
    (skills / "beta" / "SKILL.md").write_text("beta\n")
    (docs / "SKILL.md").write_text(
        "[Alpha](skills/alpha.md)\n[Beta](skills/beta/SKILL.md)\n"
    )

    result = run_script("python3", CHECK_DOC_LINKS, tmp_path)

    assert result.returncode == 0
    assert result.stdout == ""
    assert result.stderr == ""


def test_check_doc_links_reports_missing_link(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    skills = docs / "skills"
    skills.mkdir(parents=True)

    (docs / "guide.md").write_text("[Missing](missing.md)\n")

    result = run_script("python3", CHECK_DOC_LINKS, tmp_path)

    assert result.returncode == 1
    assert "broken link in docs/guide.md -> missing.md" in result.stdout


VALID_FRONTMATTER = """
            id: demo
            name: demo
            one_line_purpose: Demo purpose
            entry_point: docs/skills/demo.md
            category: meta
            status: active
            tags: [docs]
            description: Demo description
            version: "1.0"
            last_updated: "2026-08-01"
            metadata:
              type: reference
"""


def run_catalog(mod, monkeypatch: pytest.MonkeyPatch, mode: str) -> int:
    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", mode])
    try:
        return mod.main()
    except SystemExit as e:  # validate_catalog exits on schema errors
        return e.code


@pytest.mark.parametrize(
    ("frontmatter", "body", "expected"),
    [
        (None, "", "no YAML front matter found"),
        (VALID_FRONTMATTER.replace("name: demo", "name: Demo"), "", "does not match id"),
        (VALID_FRONTMATTER.split("            metadata:")[0], "", "'doc_type' is a required property"),
        (VALID_FRONTMATTER.replace("Demo description", "x" * 257), "", "is too long"),
        (VALID_FRONTMATTER, "line\n" * 500, "hard max 500"),
    ],
    ids=["no-front-matter", "name-id-mismatch", "no-metadata-type", "long-description", "over-500-lines"],
)
def test_generate_skill_index_rejects_invalid_skill(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    frontmatter: str | None,
    body: str,
    expected: str,
) -> None:
    skills_dir = tmp_path / "docs" / "skills"
    skills_dir.mkdir(parents=True)
    skill = skills_dir / "demo.md"
    if frontmatter is None:
        skill.write_text("# no front matter\n")
    else:
        write_skill(skill, frontmatter=frontmatter)
        skill.write_text(skill.read_text() + body)
    (skills_dir / "index.schema.json").write_text(
        (REPO_ROOT / "docs/skills/index.schema.json").read_text()
    )
    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, tmp_path)

    assert run_catalog(mod, monkeypatch, "--check") == 1
    assert expected in capsys.readouterr().err


def test_generate_skill_index_warns_over_soft_line_budget(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    skills_dir = tmp_path / "docs" / "skills"
    write_skill(skills_dir / "demo.md", frontmatter=VALID_FRONTMATTER)
    (skills_dir / "demo.md").write_text((skills_dir / "demo.md").read_text() + "line\n" * 200)
    (skills_dir / "index.schema.json").write_text(
        (REPO_ROOT / "docs/skills/index.schema.json").read_text()
    )
    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, tmp_path)

    assert run_catalog(mod, monkeypatch, "--write") == 0
    assert "soft max 200" in capsys.readouterr().err


def test_check_skill_index_passes_with_complete_links(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    skills = docs / "skills"
    (skills / "nested").mkdir(parents=True)
    (skills / "alpha.md").write_text("alpha\n")
    (skills / "nested" / "SKILL.md").write_text("nested\n")
    (docs / "SKILL.md").write_text(
        "[Alpha](skills/alpha.md)\n[Nested](skills/nested/SKILL.md)\n"
    )

    result = run_script("bash", CHECK_SKILL_INDEX, tmp_path)

    assert result.returncode == 0
    assert result.stdout == ""
    assert result.stderr == ""


def test_check_skill_index_reports_missing_flat_and_nested_links(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    skills = docs / "skills"
    (skills / "nested").mkdir(parents=True)
    (skills / "alpha.md").write_text("alpha\n")
    (skills / "nested" / "SKILL.md").write_text("nested\n")
    (docs / "SKILL.md").write_text("# empty table\n")

    result = run_script("bash", CHECK_SKILL_INDEX, tmp_path)

    assert result.returncode == 1
    assert "error: docs/SKILL.md is missing a link to skills/alpha.md" in result.stdout
    assert (
        "error: docs/SKILL.md is missing a link to skills/nested/SKILL.md"
        in result.stdout
    )


def test_generate_skill_index_round_trip(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    repo_root = make_skill_tree(tmp_path)
    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, repo_root)

    catalog = mod.build_catalog()
    assert [skill["id"] for skill in catalog["skills"]] == ["alpha", "zeta"]
    mod.validate_catalog(catalog)

    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--write"])
    assert mod.main() == 0

    index_path = repo_root / "docs" / "skills" / "index.json"
    md_path = repo_root / "docs" / "skills" / "index.md"
    assert index_path.exists()
    assert md_path.exists()

    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--check"])
    assert mod.main() == 0


def test_generate_skill_index_check_tolerates_stale_generated_at(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A `--check` run must not fail purely because `generated_at` no longer
    matches today's date. Real-world PR CI runs on a different calendar day
    than the last regeneration on main, and that alone is not staleness.
    """
    repo_root = make_skill_tree(tmp_path)
    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, repo_root)

    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--write"])
    assert mod.main() == 0

    index_path = repo_root / "docs" / "skills" / "index.json"
    md_path = repo_root / "docs" / "skills" / "index.md"

    # Simulate calendar drift: back-date the committed files without
    # touching any skill content.
    data = json.loads(index_path.read_text())
    data["generated_at"] = "2020-01-01"
    index_path.write_text(json.dumps(data, indent=2) + "\n")
    md_text = md_path.read_text().replace(
        f"Generated: {mod.date.today().isoformat()}", "Generated: 2020-01-01"
    )
    md_path.write_text(md_text)

    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--check"])
    assert mod.main() == 0


def test_generate_skill_index_check_still_fails_on_real_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """A genuine content change without regeneration must still fail
    `--check` — the date-drift tolerance must not weaken this protection.
    """
    repo_root = make_skill_tree(tmp_path)
    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, repo_root)

    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--write"])
    assert mod.main() == 0

    # Modify a skill doc's front matter without regenerating the index.
    zeta_path = repo_root / "docs" / "skills" / "zeta.md"
    zeta_path.write_text(
        zeta_path.read_text().replace("Zeta purpose", "Totally different purpose")
    )

    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--check"])
    assert mod.main() == 1
    captured = capsys.readouterr()
    assert "index.json is stale" in captured.err


def test_generate_skill_index_rejects_missing_entry_point(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    repo_root = tmp_path
    skills_dir = repo_root / "docs" / "skills"
    skills_dir.mkdir(parents=True)
    write_skill(
        skills_dir / "broken.md",
        frontmatter="""
            id: broken
            name: Broken skill
            one_line_purpose: Broken purpose
            category: test-authoring
            status: active
            tags: [docs]
            description: Broken skill description
            version: "1.0"
            last_updated: "2026-08-01"
        """,
    )
    (skills_dir / "index.schema.json").write_text(
        json.dumps(make_catalog_schema(), indent=2) + "\n"
    )

    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, repo_root)
    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", "--check"])

    assert mod.main() == 1
    captured = capsys.readouterr()
    assert "missing required front-matter key(s)" in captured.err


def test_skill_catalog_schema_category_enum() -> None:
    schema_path = REPO_ROOT / "docs/skills/index.schema.json"
    schema = json.loads(schema_path.read_text())
    categories = schema["$defs"]["skill"]["properties"]["category"]["enum"]
    expected = ["ci-ops", "test-authoring", "meta", "platform", "product"]
    assert categories == expected


def test_all_repo_skills_validate_against_schema() -> None:
    mod = load_generate_skill_index()
    catalog = mod.build_catalog()
    mod.validate_catalog(catalog)


def test_generate_skill_index_accepts_widened_categories(tmp_path: Path) -> None:
    repo_root = tmp_path
    skills_dir = repo_root / "docs" / "skills"
    skills_dir.mkdir(parents=True)
    write_skill(
        skills_dir / "platform-skill.md",
        frontmatter="""
            id: platform-skill
            name: platform-skill
            one_line_purpose: Platform purpose
            entry_point: docs/skills/platform-skill.md
            category: platform
            status: active
            tags: [platform]
            description: Platform skill description
            version: "1.0"
            last_updated: "2026-09-23"
            metadata:
              type: reference
        """,
    )
    write_skill(
        skills_dir / "product-skill.md",
        frontmatter="""
            id: product-skill
            name: product-skill
            one_line_purpose: Product purpose
            entry_point: docs/skills/product-skill.md
            category: product
            status: active
            tags: [product]
            description: Product skill description
            version: "1.0"
            last_updated: "2026-09-23"
            metadata:
              type: reference
        """,
    )
    schema_text = (REPO_ROOT / "docs/skills/index.schema.json").read_text()
    (skills_dir / "index.schema.json").write_text(schema_text)

    mod = load_generate_skill_index()
    patch_skill_index_paths(mod, repo_root)
    catalog = mod.build_catalog()
    mod.validate_catalog(catalog)
    assert [s["category"] for s in catalog["skills"]] == ["platform", "product"]
