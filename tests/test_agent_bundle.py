"""Coverage for the shipped on-device agent bundle.

`scripts/generate_skill_index.py` copies every `scope: on-device` skill into
`system_files/shared/usr/share/ublue-os/agent/`, which ships inside every
image. That bundle IS an artifact, so its generation, drift detection, and
self-healing cleanup are tested here. Doc formatting is deliberately not a
gate (see docs/skills/ci-tooling/SKILL.md) — nothing else tests these paths.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
GENERATE_SKILL_INDEX = REPO_ROOT / "scripts/generate_skill_index.py"


def load_generate_skill_index():
    spec = importlib.util.spec_from_file_location(
        "generate_skill_index", GENERATE_SKILL_INDEX
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def redirect_to(mod, repo_root: Path) -> None:
    """Point the module at a throwaway tree. Every path derives from these two
    names, so nothing else needs patching."""
    mod.REPO_ROOT = repo_root
    mod.SKILLS_DIR = repo_root / "docs" / "skills"


def write_skill(path: Path, *, scope: str | None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"id: {path.stem}",
        f"name: {path.stem}",
        f'one_line_purpose: "{path.stem} purpose"',
        f"entry_point: docs/skills/{path.name}",
        "category: reference",
        "status: active",
        "tags: [docs]",
        f'description: "{path.stem} description"',
        'version: "1.0"',
        'last_updated: "2026-08-01"',
    ]
    if scope:
        lines.append(f"scope: {scope}")
    lines += ["metadata:", "  type: reference"]
    path.write_text("---\n" + "\n".join(lines) + "\n---\n\nBody\n")


def bundle_dir(repo_root: Path) -> Path:
    return repo_root / "system_files/shared/usr/share/ublue-os/agent"


def on_device_tree(tmp_path: Path) -> Path:
    """alpha + beta ship on-device; gamma does not."""
    skills = tmp_path / "docs" / "skills"
    write_skill(skills / "alpha.md", scope="on-device")
    write_skill(skills / "beta.md", scope="on-device")
    write_skill(skills / "gamma.md", scope=None)
    return tmp_path


def run(mod, monkeypatch: pytest.MonkeyPatch, flag: str) -> int:
    monkeypatch.setattr(sys, "argv", ["generate_skill_index.py", flag])
    return mod.main()


def test_write_bundle_ships_only_on_device_skills(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo_root = on_device_tree(tmp_path)
    mod = load_generate_skill_index()
    redirect_to(mod, repo_root)

    assert run(mod, monkeypatch, "--write") == 0

    index = json.loads((bundle_dir(repo_root) / "index.json").read_text())
    assert [s["id"] for s in index["skills"]] == ["alpha", "beta"]
    assert index["skills"][0]["entry_point"] == "skills/alpha.md"

    bundle = bundle_dir(repo_root)
    assert (bundle / "skills/alpha.md").exists()
    assert (bundle / "skills/beta.md").exists()
    assert not (bundle / "skills/gamma.md").exists()

    # The banner must land below the YAML front matter, or the shipped copy
    # stops parsing as a skill on the device.
    text = (bundle / "skills/alpha.md").read_text()
    assert "ON-DEVICE EDITION" in text
    assert text.index("---\n") < text.index("ON-DEVICE EDITION")
    assert mod.FRONTMATTER_RE.match(text) is not None

    # A fresh --write is check-clean.
    assert run(mod, monkeypatch, "--check") == 0


def test_check_fails_when_on_device_skill_not_shipped(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    repo_root = on_device_tree(tmp_path)
    mod = load_generate_skill_index()
    redirect_to(mod, repo_root)
    assert run(mod, monkeypatch, "--write") == 0

    (bundle_dir(repo_root) / "skills/beta.md").unlink()

    assert run(mod, monkeypatch, "--check") == 1
    assert "is stale" in capsys.readouterr().err


def test_check_fails_on_source_edit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    repo_root = on_device_tree(tmp_path)
    mod = load_generate_skill_index()
    redirect_to(mod, repo_root)
    assert run(mod, monkeypatch, "--write") == 0

    alpha = repo_root / "docs" / "skills" / "alpha.md"
    alpha.write_text(alpha.read_text().replace("Body", "Edited"))

    assert run(mod, monkeypatch, "--check") == 1
    assert "is stale" in capsys.readouterr().err


def test_write_bundle_removes_stale_copy(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # A skill that loses `scope: on-device` must not leave an orphaned copy
    # behind that --check would then refuse to clear.
    repo_root = on_device_tree(tmp_path)
    mod = load_generate_skill_index()
    redirect_to(mod, repo_root)
    assert run(mod, monkeypatch, "--write") == 0
    assert (bundle_dir(repo_root) / "skills/beta.md").exists()

    beta = repo_root / "docs" / "skills" / "beta.md"
    beta.write_text(beta.read_text().replace("scope: on-device\n", ""))

    assert run(mod, monkeypatch, "--write") == 0
    assert not (bundle_dir(repo_root) / "skills/beta.md").exists()
    assert run(mod, monkeypatch, "--check") == 0


def test_malformed_on_device_skill_exits_cleanly(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    # A missing required key must be a one-line error, not a traceback in CI.
    repo_root = on_device_tree(tmp_path)
    mod = load_generate_skill_index()
    redirect_to(mod, repo_root)

    alpha = repo_root / "docs" / "skills" / "alpha.md"
    alpha.write_text(
        alpha.read_text().replace('one_line_purpose: "alpha purpose"\n', "")
    )

    assert run(mod, monkeypatch, "--check") == 1
    assert "missing front-matter key" in capsys.readouterr().err


def test_committed_bundle_is_current() -> None:
    # The real checkout must ship a bundle that matches its sources.
    mod = load_generate_skill_index()
    assert mod.check_bundle() == []


@pytest.mark.parametrize("notes", [
    "# Notes\n\nscope: on-device\n",
    "---\n- a\n- b\n---\n",
    "---\ndescription: [unfinished\n---\n\nscope: on-device\n",
])
def test_unscoped_notes_cannot_block_or_change_bundle(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, notes: str
) -> None:
    mod = load_generate_skill_index()
    redirect_to(mod, on_device_tree(tmp_path))
    assert run(mod, monkeypatch, "--write") == 0
    bundle = bundle_dir(tmp_path)
    before = {p.relative_to(bundle): p.read_bytes() for p in bundle.rglob("*") if p.is_file()}
    (tmp_path / "docs/skills/notes.md").write_text(notes)

    assert run(mod, monkeypatch, "--check") == 0
    assert run(mod, monkeypatch, "--write") == 0
    assert {p.relative_to(bundle): p.read_bytes() for p in bundle.rglob("*") if p.is_file()} == before


@pytest.mark.parametrize("damage", ["invalid-yaml", "missing-delimiter"])
def test_broken_declared_skill_cannot_be_silently_removed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, damage: str
) -> None:
    mod = load_generate_skill_index()
    redirect_to(mod, on_device_tree(tmp_path))
    assert run(mod, monkeypatch, "--write") == 0
    bundle = bundle_dir(tmp_path)
    before = {p.relative_to(bundle): p.read_bytes() for p in bundle.rglob("*") if p.is_file()}
    alpha = tmp_path / "docs/skills/alpha.md"
    if damage == "invalid-yaml":
        alpha.write_text(alpha.read_text().replace('description: "alpha description"', 'description: [unfinished'))
    else:
        alpha.write_text(alpha.read_text().replace("\n---\n", "\n", 1))

    assert run(mod, monkeypatch, "--check") == 1
    assert run(mod, monkeypatch, "--write") == 1
    assert {p.relative_to(bundle): p.read_bytes() for p in bundle.rglob("*") if p.is_file()} == before
