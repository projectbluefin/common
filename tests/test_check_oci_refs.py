"""Tests for scripts/check-oci-refs.py

The script is importable after its refactor (check_ublue_refs, collect_tag_refs,
tag_exists_in_ghcr, and main are all callable functions). Tests exercise the
logic in-process so coverage.py can instrument them.
"""

import importlib.util
import http.client
import json
import urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from threading import Event, Thread
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

    def test_flags_wallpapers_upstream_if_ublue(self, tmp_path):
        wf = tmp_path / ".github/workflows"
        wf.mkdir(parents=True)
        (wf / "build.yml").write_text(
            "COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest /tmp .\n"
        )
        violations = check_ublue_refs(tmp_path)
        assert len(violations) == 1

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

    def test_skips_placeholder_tags(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/common:e2e-pr-<N>-<sha>\n"
            "ghcr.io/projectbluefin/common:e2e-pr-N-sha\n"
            "ghcr.io/projectbluefin/common:e2e-pr-{pr_number}-{sha_short}\n"
        )
        refs = collect_tag_refs(tmp_path)
        assert refs == {}


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

    def test_re_raises_non_transient_http_error(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.HTTPError(
                url="", code=422, msg="Unprocessable Entity", hdrs=None, fp=None
            ),
        ):
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")

    def test_401_raises_http_error(self):
        """401 is an authentication error and must raise immediately rather than retry."""
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.HTTPError(
                url="", code=401, msg="Unauthorized", hdrs=None, fp=None
            ),
        ) as mock_urlopen:
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")
            assert mock_urlopen.call_count == 1

    def test_transient_5xx_retries_then_returns_none(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.HTTPError(
                url="", code=500, msg="Server Error", hdrs=None, fp=None
            ),
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            # MAX_RETRIES=3 retries + the initial attempt = 4 calls total.
            assert mock_urlopen.call_count == 4
            assert mock_sleep.call_count == 3

    def test_transient_403_rate_limit_recovers_on_retry(self):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b"[]"
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        hdrs = {"x-ratelimit-remaining": "0"}
        with patch(
            "urllib.request.urlopen",
            side_effect=[
                urllib.error.HTTPError(
                    url="", code=403, msg="Forbidden", hdrs=hdrs, fp=None
                ),
                mock_resp,
            ],
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is False
            assert mock_urlopen.call_count == 2
            assert mock_sleep.call_count == 1

    def test_403_without_rate_limit_header_raises_http_error(self):
        """403 without rate limit headers indicates missing scope/permission and must raise immediately."""
        hdrs = {"x-ratelimit-remaining": "4676"}
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.HTTPError(
                url="", code=403, msg="Forbidden", hdrs=hdrs, fp=None
            ),
        ) as mock_urlopen:
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")
            assert mock_urlopen.call_count == 1

    def test_truncated_body_recovers_on_retry(self):
        """IncompleteRead from resp.read() (connection dropped mid-body) retries."""
        truncated = MagicMock()
        truncated.read.side_effect = http.client.IncompleteRead(
            partial=b'[{"metadata":', expected=128
        )
        truncated.__enter__ = lambda s: s
        truncated.__exit__ = MagicMock(return_value=False)
        with patch(
            "urllib.request.urlopen",
            side_effect=[truncated, _mock_urlopen(["stable"])],
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is True
            assert mock_urlopen.call_count == 2
            assert mock_sleep.call_count == 1

    def test_persistent_truncated_body_returns_none(self):
        truncated = MagicMock()
        truncated.read.side_effect = http.client.IncompleteRead(
            partial=b'[{"metadata":', expected=128
        )
        truncated.__enter__ = lambda s: s
        truncated.__exit__ = MagicMock(return_value=False)
        with patch(
            "urllib.request.urlopen", return_value=truncated
        ) as mock_urlopen, patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            assert mock_urlopen.call_count == 4

    def test_malformed_json_body_returns_none(self):
        """A 200 with a body that is not JSON retries, then reports unknown."""
        garbage = MagicMock()
        garbage.read.return_value = b"<html>proxy error</html>"
        garbage.__enter__ = lambda s: s
        garbage.__exit__ = MagicMock(return_value=False)
        with patch(
            "urllib.request.urlopen", return_value=garbage
        ) as mock_urlopen, patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            assert mock_urlopen.call_count == 4

    def test_non_array_json_body_returns_none(self):
        """A 200 whose JSON body is an object, not a versions array, retries."""
        obj = MagicMock()
        obj.read.return_value = b'{"message": "unexpected"}'
        obj.__enter__ = lambda s: s
        obj.__exit__ = MagicMock(return_value=False)
        with patch(
            "urllib.request.urlopen", return_value=obj
        ) as mock_urlopen, patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            assert mock_urlopen.call_count == 4

    def test_returns_false_on_empty_versions_list(self):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b"[]"
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        with patch("urllib.request.urlopen", return_value=mock_resp):
            assert tag_exists_in_ghcr("bluefin", "stable") is False

    @pytest.mark.parametrize("failure", ["connect", "wrapped", "read"])
    def test_timeout_recovers_on_retry(self, failure):
        response = _mock_urlopen(["stable"])
        if failure == "read":
            response.read.side_effect = TimeoutError("read timed out")
            error = response
        elif failure == "wrapped":
            error = urllib.error.URLError(TimeoutError("connect timed out"))
        else:
            error = TimeoutError("connect timed out")
        with patch(
            "urllib.request.urlopen",
            side_effect=[error, _mock_urlopen(["stable"])],
        ), patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is True

    @pytest.mark.parametrize("failure", ["connect", "wrapped", "read"])
    def test_persistent_timeout_is_unknown_not_missing(self, failure, capsys):
        response = _mock_urlopen(["stable"])
        if failure == "read":
            response.read.side_effect = TimeoutError("read timed out")
            kwargs = {"return_value": response}
        elif failure == "wrapped":
            kwargs = {"side_effect": urllib.error.URLError(TimeoutError("connect timed out"))}
        else:
            kwargs = {"side_effect": TimeoutError("connect timed out")}
        with patch("urllib.request.urlopen", **kwargs), patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
        assert "skipping existence check" in capsys.readouterr().out

    def test_stalled_response_body_times_out(self, monkeypatch):
        release = Event()

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                body = b'[{"metadata":{"container":{"tags":["stable"]}}}]'
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                release.wait(1)
                try:
                    self.wfile.write(body)
                except BrokenPipeError:
                    pass

            def log_message(self, *args):
                pass

        server = HTTPServer(("127.0.0.1", 0), Handler)
        thread = Thread(target=server.serve_forever, daemon=True)
        real_urlopen = _mod.urllib.request.urlopen

        def local_urlopen(request, **kwargs):
            return real_urlopen(f"http://127.0.0.1:{server.server_port}/", **kwargs)

        monkeypatch.setattr(_mod, "REQUEST_TIMEOUT_SECONDS", 0.025)
        monkeypatch.setattr(_mod, "MAX_RETRIES", 0)
        monkeypatch.setattr(_mod.urllib.request, "urlopen", local_urlopen)
        thread.start()
        try:
            assert tag_exists_in_ghcr("bluefin", "stable") is None
        finally:
            release.set()
            server.shutdown()
            thread.join()
            server.server_close()


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
