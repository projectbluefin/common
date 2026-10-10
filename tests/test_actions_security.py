"""Tests for Project Bluefin GitHub Actions Security Baseline conformance."""

import importlib.util
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


@pytest.mark.parametrize(
    "ref_expression",
    [
        "${{ github.head_ref }}",
        "${{ github.event.pull_request.head.ref }}",
        "${{ github.event.pull_request.head.sha }}",
        "${{ github.event.pull_request.head.repo.full_name }}",
    ],
)
def test_scanner_detects_all_untrusted_pr_head_expressions(tmp_path: Path, ref_expression: str):
    """Every untrusted PR-head expression must be flagged, including github.head_ref."""
    wf = tmp_path / "pwn-request.yml"
    wf.write_text(f"""
name: PR Target Workflow
on: pull_request_target
permissions: {{}}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          ref: {ref_expression}
""")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "Dangerous untrusted PR checkout detected" in result.stdout


def test_scanner_allows_head_ref_outside_pr_target(tmp_path: Path):
    """github.head_ref in a plain pull_request workflow is not a privileged-context risk."""
    wf = tmp_path / "plain-pr.yml"
    wf.write_text("""
name: PR Workflow
on: pull_request
permissions: {}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          ref: ${{ github.head_ref }}
""")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout


@pytest.mark.parametrize(
    "permissions_block",
    [
        "permissions: write-all",
        "permissions:\n  contents: write",
        "permissions:\n  contents: read\n  packages: write\n  id-token: write",
    ],
)
def test_scanner_detects_forbidden_top_level_write_permissions(tmp_path: Path, permissions_block: str):
    """The scanner must flag top-level write-all or write scope permissions."""
    wf = tmp_path / "write-scope.yml"
    wf.write_text(f"""
name: Write Scope Workflow
on: [push]
{permissions_block}
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


PINNED_SHA = "3d3c42e5aac5ba805825da76410c181273ba90b1"


def _run(workflows_dir: Path, *extra: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--workflows-dir", str(workflows_dir), *extra],
        capture_output=True,
        text=True,
    )


def _load_scanner():
    spec = importlib.util.spec_from_file_location("check_actions_security", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def scanner():
    return _load_scanner()


@pytest.fixture
def fallback_scanner():
    """The scanner with PyYAML unavailable, so the line-based parser runs."""
    mod = _load_scanner()
    mod.yaml = None
    return mod


def _messages(issues) -> list[tuple[str, str]]:
    return [(i.severity, i.message) for i in issues]


@pytest.mark.parametrize(
    "permissions_block",
    [
        "permissions: {}",
        "permissions: read-all",
        "permissions:\n  contents: read\n  pull-requests: none",
    ],
)
def test_scanner_accepts_fail_closed_top_level_permissions(tmp_path: Path, permissions_block: str):
    """'{}', 'read-all' and a read/none-only mapping are the allowed top-level forms."""
    (tmp_path / "ok.yml").write_text(f"""
name: OK
on: [push]
{permissions_block}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
""")
    result = _run(tmp_path, "--strict")
    assert result.returncode == 0, result.stdout
    assert "Scanned 1 workflow(s): 0 error(s), 0 warning(s)." in result.stdout


def test_scanner_names_every_write_scope_in_a_top_level_mapping(tmp_path: Path, scanner):
    wf = tmp_path / "w.yml"
    wf.write_text("""
on: push
permissions:
  contents: read
  packages: write
  id-token: write
jobs: {}
""")
    msgs = _messages(scanner.check_workflow_file(wf))
    assert len(msgs) == 1
    severity, message = msgs[0]
    assert severity == "ERROR"
    assert "(id-token: write, packages: write)" in message
    assert "contents" not in message


def test_scanner_flags_action_without_any_ref(tmp_path: Path):
    (tmp_path / "noref.yml").write_text("""
on: [push]
permissions: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout
""")
    result = _run(tmp_path)
    assert result.returncode == 1
    assert "External action 'actions/checkout' must be pinned" in result.stdout
    assert "(found ref '')" in result.stdout


@pytest.mark.parametrize("short_ref", ["3d3c42e", PINNED_SHA + "0", "main"])
def test_scanner_rejects_refs_that_are_not_exactly_a_40_char_sha(tmp_path: Path, short_ref: str):
    (tmp_path / "short.yml").write_text(f"""
on: [push]
permissions: {{}}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@{short_ref} # v7
""")
    result = _run(tmp_path)
    assert result.returncode == 1
    assert f"(found ref '{short_ref}')" in result.stdout


def test_scanner_reports_line_number_of_offending_uses(tmp_path: Path):
    wf = tmp_path / "lines.yml"
    wf.write_text(
        "on: [push]\n"
        "permissions: {}\n"
        "jobs:\n"
        "  build:\n"
        "    runs-on: ubuntu-latest\n"
        "    steps:\n"
        f"      - uses: actions/checkout@{PINNED_SHA} # v7\n"
        "      - uses: actions/setup-python@v5\n"
    )
    result = _run(tmp_path)
    assert result.returncode == 1
    assert f"ERROR: [{wf}:8] External action 'actions/setup-python'" in result.stdout
    assert f"{wf}:7" not in result.stdout


def test_sha_pin_without_version_comment_is_a_warning_not_an_error(tmp_path: Path):
    (tmp_path / "nocomment.yml").write_text(f"""
on: [push]
permissions: {{}}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@{PINNED_SHA}
""")
    result = _run(tmp_path)
    assert result.returncode == 0, result.stdout
    assert "WARNING:" in result.stdout
    assert "missing a human-readable version comment" in result.stdout
    assert "Scanned 1 workflow(s): 0 error(s), 1 warning(s)." in result.stdout


def test_strict_mode_turns_the_missing_version_comment_warning_into_a_failure(tmp_path: Path):
    (tmp_path / "nocomment.yml").write_text(f"""
on: [push]
permissions: {{}}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@{PINNED_SHA}
""")
    result = _run(tmp_path, "--strict")
    assert result.returncode == 1
    assert "Scanned 1 workflow(s): 1 error(s), 1 warning(s)." in result.stdout


@pytest.mark.parametrize(
    "uses",
    [
        "./.github/workflows/reusable.yml",
        "./.github/actions/local",
        "projectbluefin/actions/.github/workflows/reusable.yml@main",
        "projectbluefin/common@v1",
    ],
)
def test_local_and_first_party_uses_are_exempt_from_sha_pinning(tmp_path: Path, uses: str):
    (tmp_path / "exempt.yml").write_text(f"""
on: [push]
permissions: {{}}
jobs:
  call:
    uses: {uses}
""")
    result = _run(tmp_path, "--strict")
    assert result.returncode == 0, result.stdout


def test_first_party_exemption_is_an_owner_match_not_a_substring(tmp_path: Path):
    """A lookalike owner (projectbluefin-evil/...) must still be pinned."""
    (tmp_path / "lookalike.yml").write_text("""
on: [push]
permissions: {}
jobs:
  call:
    uses: projectbluefin-evil/actions/.github/workflows/x.yml@main
""")
    result = _run(tmp_path)
    assert result.returncode == 1
    assert "External action 'projectbluefin-evil/actions/.github/workflows/x.yml'" in result.stdout


@pytest.mark.parametrize(
    "on_block",
    [
        "on: [push, pull_request_target]",
        "on:\n  pull_request_target:\n    types: [opened, synchronize]",
    ],
)
def test_scanner_detects_pr_target_in_list_and_mapping_triggers(tmp_path: Path, on_block: str):
    (tmp_path / "prt.yml").write_text(f"""
name: PR Target
{on_block}
permissions: {{}}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{{{ github.head_ref }}}}"
""")
    result = _run(tmp_path)
    assert result.returncode == 1
    assert "Dangerous untrusted PR checkout detected" in result.stdout


def test_scanner_reports_yaml_parse_errors_and_skips_other_checks(tmp_path: Path, scanner):
    wf = tmp_path / "broken.yml"
    wf.write_text("on: push\n  x: [\nuses: actions/checkout@v4\n")
    msgs = _messages(scanner.check_workflow_file(wf))
    assert len(msgs) == 1
    assert msgs[0][0] == "ERROR"
    assert msgs[0][1].startswith("YAML parse error:")


def test_scanner_scans_yaml_extension_and_ignores_other_files(tmp_path: Path):
    (tmp_path / "a.yml").write_text("on: push\npermissions: {}\njobs: {}\n")
    (tmp_path / "b.yaml").write_text("on: push\njobs: {}\n")
    (tmp_path / "notes.txt").write_text("on: push\njobs: {}\n")
    result = _run(tmp_path)
    assert result.returncode == 1
    assert "Scanned 2 workflow(s): 1 error(s), 0 warning(s)." in result.stdout
    assert "b.yaml" in result.stdout
    assert "notes.txt" not in result.stdout


def test_empty_workflows_dir_passes(tmp_path: Path):
    result = _run(tmp_path, "--strict")
    assert result.returncode == 0
    assert "Scanned 0 workflow(s): 0 error(s), 0 warning(s)." in result.stdout


def test_missing_workflows_dir_is_an_error(tmp_path: Path):
    missing = tmp_path / "nope"
    result = _run(missing)
    assert result.returncode == 1
    assert f"Error: {missing} is not a directory" in result.stderr


# --- Line-based fallback parser (PyYAML unavailable) ---


@pytest.mark.parametrize(
    ("permissions_block", "expected"),
    [
        ("permissions: {}", None),
        ("permissions: read-all", None),
        ("permissions:\n  # read only\n\n  contents: read\n  pull-requests: none", None),
        ("permissions: write-all", "Top-level 'permissions: write-all' is forbidden"),
        ("permissions:\n  contents: read\n  packages: write", "non-read scopes (packages: write)"),
        ("jobs_only: true", "Missing top-level 'permissions:' declaration"),
    ],
)
def test_fallback_parser_classifies_top_level_permissions(
    tmp_path: Path, fallback_scanner, permissions_block: str, expected: str | None
):
    wf = tmp_path / "w.yml"
    wf.write_text(f"on: push\n{permissions_block}\njobs:\n  a:\n    permissions:\n      contents: write\n")
    msgs = _messages(fallback_scanner.check_workflow_file(wf))
    if expected is None:
        assert msgs == []
    else:
        assert len(msgs) == 1
        assert expected in msgs[0][1]


def test_fallback_parser_ignores_job_level_permissions_when_no_top_level_block(tmp_path: Path, fallback_scanner):
    """Only a column-0 'permissions:' counts as the workflow's top-level declaration."""
    wf = tmp_path / "w.yml"
    wf.write_text("on: push\njobs:\n  a:\n    permissions: {}\n")
    msgs = _messages(fallback_scanner.check_workflow_file(wf))
    assert len(msgs) == 1
    assert "Missing top-level 'permissions:' declaration" in msgs[0][1]


@pytest.mark.parametrize(
    "on_block",
    [
        "on: pull_request_target",
        "on:\n  pull_request_target:\n    types: [opened]",
        "on:\n  pull_request_target:",
    ],
)
def test_fallback_parser_detects_pr_target_checkout(tmp_path: Path, fallback_scanner, on_block: str):
    wf = tmp_path / "w.yml"
    wf.write_text(f"{on_block}\npermissions: {{}}\njobs:\n  a:\n    steps:\n      - run: echo ${{{{ github.head_ref }}}}\n")
    msgs = _messages(fallback_scanner.check_workflow_file(wf))
    assert any("Dangerous untrusted PR checkout" in m for _, m in msgs), msgs


def test_fallback_parser_does_not_flag_head_ref_on_plain_pull_request(tmp_path: Path, fallback_scanner):
    wf = tmp_path / "w.yml"
    wf.write_text("on: pull_request\npermissions: {}\njobs:\n  a:\n    steps:\n      - run: echo ${{ github.head_ref }}\n")
    assert fallback_scanner.check_workflow_file(wf) == []


@pytest.mark.xfail(
    strict=True,
    reason="fallback parser misses pull_request_target in a flow-sequence 'on:' list",
)
def test_fallback_parser_detects_pr_target_in_flow_list_trigger(tmp_path: Path, fallback_scanner):
    wf = tmp_path / "w.yml"
    wf.write_text("on: [push, pull_request_target]\npermissions: {}\njobs:\n  a:\n    steps:\n      - run: echo ${{ github.head_ref }}\n")
    msgs = _messages(fallback_scanner.check_workflow_file(wf))
    assert any("Dangerous untrusted PR checkout" in m for _, m in msgs), msgs


@pytest.mark.xfail(
    strict=True,
    reason="USES_RE keeps YAML quotes, so a quoted SHA-pinned 'uses:' is reported as unpinned",
)
def test_quoted_sha_pinned_uses_is_accepted(tmp_path: Path, scanner):
    wf = tmp_path / "w.yml"
    wf.write_text(f'on: push\npermissions: {{}}\njobs:\n  a:\n    steps:\n      - uses: "actions/checkout@{PINNED_SHA}" # v7\n')
    assert scanner.check_workflow_file(wf) == []
