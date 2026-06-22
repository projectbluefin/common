"""Tests for scripts/check-oci-refs.py

The script is importable after its refactor (check_ublue_refs, collect_tag_refs,
tag_exists_in_ghcr, and main are all callable functions). Tests exercise the
logic in-process so coverage.py can instrument them.
"""

import importlib.util
import json
import urllib.error
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

SCRIPT_PATH = Path(__file__).parent.parent / "scripts/check-oci-refs.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("check_oci_refs", SCRIPT_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_mod = _load_module()
check_ublue_refs = _mod.check_ublue_refs
collect_tag_refs = _mod.collect_tag_refs
tag_exists_in_ghcr = _mod.tag_exists_in_ghcr
main = _mod.main


# ---------------------------------------------------------------------------
# check_ublue_refs
# ---------------------------------------------------------------------------

class TestCheckUblueRefs:
    def test_clean_repo_returns_no_violations(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        violations = check_ublue_refs(tmp_path)
        assert violations == []

    def test_detects_ublue_os_ref_in_workflow(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text("image: ghcr.io/ublue-os/base:latest\n")
        violations = check_ublue_refs(tmp_path)
        assert len(violations) == 1
        assert "ublue-os" in violations[0]

    def test_allows_known_upstream_akmods_nvidia(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text(
            "COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:latest /tmp/rpms .\n"
        )
        violations = check_ublue_refs(tmp_path)
        assert violations == []

    def test_allows_known_upstream_akmods_extra(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text(
            "COPY --from=ghcr.io/ublue-os/akmods-extra:latest /tmp/rpms .\n"
        )
        violations = check_ublue_refs(tmp_path)
        assert violations == []

    def test_allows_wallpapers_upstream(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text(
            "COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest /tmp .\n"
        )
        violations = check_ublue_refs(tmp_path)
        assert violations == []

    def test_detects_ublue_ref_in_docs(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "Pull from ghcr.io/ublue-os/base\n"
        )
        violations = check_ublue_refs(tmp_path)
        assert len(violations) == 1

    def test_skips_docs_factory_dir(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs/factory").mkdir(parents=True)
        (tmp_path / "docs/factory/README.md").write_text(
            "ghcr.io/ublue-os/something\n"
        )
        violations = check_ublue_refs(tmp_path)
        assert violations == []

    def test_skips_specs_dir(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "specs").mkdir()
        (tmp_path / "specs/foo.md").write_text("ghcr.io/ublue-os/old\n")
        violations = check_ublue_refs(tmp_path)
        assert violations == []

    def test_detects_violation_in_agents_md(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        (tmp_path / "AGENTS.md").write_text("see ghcr.io/ublue-os/old-image\n")
        violations = check_ublue_refs(tmp_path)
        assert len(violations) == 1

    def test_reports_line_number(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text("line1\nline2\nghcr.io/ublue-os/foo\n")
        violations = check_ublue_refs(tmp_path)
        assert ":3:" in violations[0]


# ---------------------------------------------------------------------------
# collect_tag_refs
# ---------------------------------------------------------------------------

class TestCollectTagRefs:
    def test_no_refs_empty_docs(self, tmp_path):
        (tmp_path / "docs").mkdir()
        refs = collect_tag_refs(tmp_path)
        assert refs == {}

    def test_collects_image_tag_ref(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "Use ghcr.io/projectbluefin/bluefin:stable\n"
        )
        refs = collect_tag_refs(tmp_path)
        assert "bluefin:stable" in refs

    def test_skips_sha256_tags(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "Digest ghcr.io/projectbluefin/bluefin:sha256-abc123\n"
        )
        refs = collect_tag_refs(tmp_path)
        assert refs == {}

    def test_collects_multiple_distinct_refs(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/bluefin:stable\n"
            "ghcr.io/projectbluefin/bluefin-lts:lts\n"
        )
        refs = collect_tag_refs(tmp_path)
        assert "bluefin:stable" in refs
        assert "bluefin-lts:lts" in refs

    def test_records_file_and_line_location(self, tmp_path):
        (tmp_path / "docs").mkdir()
        doc = tmp_path / "docs/guide.md"
        doc.write_text("ghcr.io/projectbluefin/bluefin:stable\n")
        refs = collect_tag_refs(tmp_path)
        locs = refs["bluefin:stable"]
        assert len(locs) == 1
        assert "guide.md:1" in locs[0]

    def test_collects_from_agents_md(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "AGENTS.md").write_text(
            "ghcr.io/projectbluefin/dakota:latest\n"
        )
        refs = collect_tag_refs(tmp_path)
        assert "dakota:latest" in refs

    def test_deduplicates_same_ref_across_lines(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/bluefin:stable\n"
            "ghcr.io/projectbluefin/bluefin:stable\n"
        )
        refs = collect_tag_refs(tmp_path)
        assert len(refs["bluefin:stable"]) == 2


# ---------------------------------------------------------------------------
# tag_exists_in_ghcr
# ---------------------------------------------------------------------------

def _mock_urlopen(tags):
    """Build a mock urllib context-manager returning one version with given tags."""
    data = json.dumps([
        {"metadata": {"container": {"tags": tags}}}
    ]).encode()
    mock_resp = MagicMock()
    mock_resp.read.return_value = data
    mock_resp.__enter__ = lambda s: s
    mock_resp.__exit__ = MagicMock(return_value=False)
    return mock_resp


class TestTagExistsInGhcr:
    def test_returns_true_when_tag_found(self):
        with patch("urllib.request.urlopen", return_value=_mock_urlopen(["stable", "latest"])):
            assert tag_exists_in_ghcr("bluefin", "stable") is True

    def test_returns_false_when_tag_missing(self):
        with patch("urllib.request.urlopen", return_value=_mock_urlopen(["other-tag"])):
            assert tag_exists_in_ghcr("bluefin", "nonexistent") is False

    def test_returns_false_on_404(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.HTTPError(
                url="", code=404, msg="Not Found", hdrs=None, fp=None
            ),
        ):
            assert tag_exists_in_ghcr("nonexistent-image", "latest") is False

    def test_re_raises_non_404_http_error(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.HTTPError(
                url="", code=500, msg="Server Error", hdrs=None, fp=None
            ),
        ):
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")

    def test_returns_false_on_empty_versions_list(self):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b"[]"
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        with patch("urllib.request.urlopen", return_value=mock_resp):
            assert tag_exists_in_ghcr("bluefin", "stable") is False


# ---------------------------------------------------------------------------
# main (integration)
# ---------------------------------------------------------------------------

class TestMain:
    def test_main_clean_repo_returns_zero(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        assert main(tmp_path) == 0

    def test_main_ublue_violation_returns_one(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text("image: ghcr.io/ublue-os/base\n")
        (tmp_path / "docs").mkdir()
        assert main(tmp_path) == 1

    def test_main_valid_tag_returns_zero(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/bluefin:stable\n"
        )
        with patch("urllib.request.urlopen", return_value=_mock_urlopen(["stable"])):
            assert main(tmp_path) == 0

    def test_main_missing_tag_returns_one(self, tmp_path):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/bluefin:nonexistent-tag\n"
        )
        with patch("urllib.request.urlopen", return_value=_mock_urlopen(["stable"])):
            assert main(tmp_path) == 1
