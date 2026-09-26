"""Tests for Project Bluefin GitHub Actions Security Baseline conformance."""

import subprocess
import sys
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent
SCRIPT = ROOT / "scripts/check-actions-security.py"
WORKFLOWS_DIR = ROOT / ".github/workflows"
DOC = ROOT / "ACTIONS-SECURITY.md"


def test_repo_workflows_conform_to_security_baseline():
    """All repository workflows in .github/workflows must pass the security baseline check."""
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(WORKFLOWS_DIR), "--strict"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Baseline check failed:\n{result.stdout}\n{result.stderr}"
    assert "0 error(s)" in result.stdout


def test_actions_security_doc_exists_and_covers_required_pillars():
    """ACTIONS-SECURITY.md must exist and document the four core pillars."""
    assert DOC.exists(), "ACTIONS-SECURITY.md must exist at repo root"
    content = DOC.read_text(encoding="utf-8")

    # Pillar 1: top-level permissions: {}
    assert "permissions: {}" in content
    assert "Pillar 1" in content or "permissions" in content.lower()

    # Pillar 2: SHA pinning
    assert "40-character" in content or "commit SHA" in content
    assert "Pillar 2" in content or "pinning" in content.lower()

    # Pillar 3: pull_request_target
    assert "pull_request_target" in content
    assert "Pillar 3" in content or "pull_request_target" in content

    # Pillar 4: release-asset checksum verification
    assert "SHA-256" in content or "checksum" in content.lower()
    assert "Pillar 4" in content or "checksum" in content.lower()


def test_scanner_detects_missing_top_level_permissions(tmp_path: Path):
    """The scanner must flag workflows that lack top-level permissions."""
    wf = tmp_path / "bad-permissions.yml"
    wf.write_text("""
name: Test Workflow
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
""")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "Missing top-level 'permissions:' declaration" in result.stdout


def test_scanner_detects_floating_action_tag(tmp_path: Path):
    """The scanner must flag external actions using floating tags."""
    wf = tmp_path / "floating-tag.yml"
    wf.write_text("""
name: Test Workflow
on: [push]
permissions: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
""")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "must be pinned to a full 40-character commit SHA" in result.stdout


def test_scanner_detects_dangerous_pr_target_checkout(tmp_path: Path):
    """The scanner must flag untrusted PR head checkouts in pull_request_target."""
    wf = tmp_path / "dangerous-pr-target.yml"
    wf.write_text("""
name: PR Target Workflow
on: pull_request_target
permissions: {}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          ref: ${{ github.event.pull_request.head.sha }}
""")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "Dangerous untrusted PR checkout detected" in result.stdout


def test_scanner_detects_forbidden_top_level_write_permissions(tmp_path: Path):
    """The scanner must flag top-level write-all or write scope permissions."""
    wf = tmp_path / "write-all.yml"
    wf.write_text("""
name: Write All Workflow
on: [push]
permissions: write-all
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
""")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(tmp_path), "--strict"],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "forbidden" in result.stdout.lower() or "violates" in result.stdout.lower()
