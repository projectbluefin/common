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
# tag_exists_in_ghcr / tags_exist_in_ghcr (registry token + manifest HEAD)
# ---------------------------------------------------------------------------

TOKEN = "anonymous-test-token"


def _response(body=b"", status=200):
    """Build a mock urllib context-manager response."""
    mock_resp = MagicMock()
    mock_resp.status = status
    mock_resp.read.return_value = body
    mock_resp.__enter__ = lambda s: s
    mock_resp.__exit__ = MagicMock(return_value=False)
    return mock_resp


def _token_response(token=TOKEN):
    """A 200 from ghcr.io/token."""
    return _response(json.dumps({"token": token}).encode())


def _found():
    """A 200 from a manifest HEAD."""
    return _response()


def _http_error(code, hdrs=None):
    return urllib.error.HTTPError(url="", code=code, msg="", hdrs=hdrs, fp=None)


def _url(call):
    target = call.args[0]
    return target if isinstance(target, str) else target.full_url


class TestTagExistsInGhcr:
    def test_returns_true_when_tag_found(self):
        with patch(
            "urllib.request.urlopen", side_effect=[_token_response(), _found()]
        ) as mock_urlopen:
            assert tag_exists_in_ghcr("bluefin", "stable") is True
            assert mock_urlopen.call_count == 2

    def test_returns_false_when_tag_missing(self):
        with patch(
            "urllib.request.urlopen", side_effect=[_token_response(), _http_error(404)]
        ):
            assert tag_exists_in_ghcr("bluefin", "nonexistent") is False

    @pytest.mark.parametrize("code", [403, 404])
    def test_returns_false_when_image_missing(self, code):
        """GHCR denies an anonymous token for an unknown image with 403."""
        with patch(
            "urllib.request.urlopen", side_effect=_http_error(code)
        ) as mock_urlopen:
            assert tag_exists_in_ghcr("nonexistent-image", "latest") is False
            assert mock_urlopen.call_count == 1

    def test_requests_token_then_heads_manifest(self):
        with patch(
            "urllib.request.urlopen", side_effect=[_token_response(), _found()]
        ) as mock_urlopen:
            tag_exists_in_ghcr("bluefin-lts", "testing")
        token_call, head_call = mock_urlopen.call_args_list
        assert _url(token_call) == (
            "https://ghcr.io/token?scope=repository:projectbluefin/bluefin-lts:pull"
        )
        req = head_call.args[0]
        assert req.get_method() == "HEAD"
        assert req.full_url == (
            "https://ghcr.io/v2/projectbluefin/bluefin-lts/manifests/testing"
        )
        assert req.get_header("Authorization") == f"Bearer {TOKEN}"
        accept = req.get_header("Accept")
        assert "application/vnd.oci.image.index.v1+json" in accept
        assert "application/vnd.oci.image.manifest.v1+json" in accept
        assert "application/vnd.docker.distribution.manifest.list.v2+json" in accept
        assert "application/vnd.docker.distribution.manifest.v2+json" in accept
        for call in (token_call, head_call):
            assert call.kwargs["timeout"] == _mod.REQUEST_TIMEOUT_SECONDS

    def test_re_raises_non_transient_http_error(self):
        with patch(
            "urllib.request.urlopen", side_effect=[_token_response(), _http_error(422)]
        ):
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")

    def test_401_raises_http_error(self):
        """401 is an authentication error and must raise immediately rather than retry."""
        with patch(
            "urllib.request.urlopen", side_effect=[_token_response(), _http_error(401)]
        ) as mock_urlopen:
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")
            assert mock_urlopen.call_count == 2

    def test_403_without_rate_limit_header_raises_http_error(self):
        """403 on a manifest without rate limit headers is a permission error."""
        hdrs = {"x-ratelimit-remaining": "4676"}
        with patch(
            "urllib.request.urlopen",
            side_effect=[_token_response(), _http_error(403, hdrs)],
        ) as mock_urlopen:
            with pytest.raises(urllib.error.HTTPError):
                tag_exists_in_ghcr("bluefin", "stable")
            assert mock_urlopen.call_count == 2

    def test_transient_5xx_retries_then_returns_none(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=[_token_response()] + [_http_error(500)] * 4,
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            # One token request, then MAX_RETRIES=3 retries + the first HEAD.
            assert mock_urlopen.call_count == 5
            assert mock_sleep.call_count == 3

    def test_transient_token_errors_exhausted_return_none(self, capsys):
        with patch(
            "urllib.request.urlopen", side_effect=[_http_error(503)] * 4
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert _mod.tags_exist_in_ghcr("bluefin", {"stable", "lts"}) == {
                "stable": None, "lts": None
            }
            assert mock_urlopen.call_count == 4
            assert mock_sleep.call_count == 3
        assert "skipping existence check" in capsys.readouterr().out

    @pytest.mark.parametrize(
        "error",
        [
            _http_error(403, {"x-ratelimit-remaining": "0"}),
            _http_error(403, {"retry-after": "1"}),
            _http_error(429),
        ],
        ids=["403-remaining-0", "403-retry-after", "429"],
    )
    def test_transient_rate_limit_recovers_on_retry(self, error):
        with patch(
            "urllib.request.urlopen",
            side_effect=[_token_response(), error, _found()],
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is True
            assert mock_urlopen.call_count == 3
            assert mock_sleep.call_count == 1

    def test_rate_limited_token_request_recovers_on_retry(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=[_http_error(429), _token_response(), _http_error(404)],
        ), patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "nonexistent") is False

    def test_dropped_connection_recovers_on_retry(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=[
                http.client.RemoteDisconnected(
                    "Remote end closed connection without response"
                ),
                _token_response(),
                _found(),
            ],
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is True
            assert mock_urlopen.call_count == 3
            assert mock_sleep.call_count == 1

    def test_persistent_network_error_returns_none(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=urllib.error.URLError("Temporary failure in name resolution"),
        ) as mock_urlopen, patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            assert mock_urlopen.call_count == 4

    def test_truncated_token_body_recovers_on_retry(self):
        """IncompleteRead from resp.read() (connection dropped mid-body) retries."""
        truncated = _response()
        truncated.read.side_effect = http.client.IncompleteRead(
            partial=b'{"tok', expected=128
        )
        with patch(
            "urllib.request.urlopen",
            side_effect=[truncated, _token_response(), _found()],
        ) as mock_urlopen, patch("time.sleep") as mock_sleep:
            assert tag_exists_in_ghcr("bluefin", "stable") is True
            assert mock_urlopen.call_count == 3
            assert mock_sleep.call_count == 1

    def test_persistent_truncated_token_body_returns_none(self):
        truncated = _response()
        truncated.read.side_effect = http.client.IncompleteRead(
            partial=b'{"tok', expected=128
        )
        with patch(
            "urllib.request.urlopen", return_value=truncated
        ) as mock_urlopen, patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            assert mock_urlopen.call_count == 4

    @pytest.mark.parametrize(
        "body",
        [b"<html>proxy error</html>", b'{"message": "unexpected"}', b"[]", b'{"token": ""}'],
        ids=["not-json", "no-token", "not-object", "empty-token"],
    )
    def test_unusable_token_body_returns_none(self, body):
        """A 200 token response without a usable token retries, then reports unknown."""
        with patch(
            "urllib.request.urlopen", return_value=_response(body)
        ) as mock_urlopen, patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
            assert mock_urlopen.call_count == 4

    @pytest.mark.parametrize("failure", ["connect", "wrapped", "read"])
    def test_timeout_recovers_on_retry(self, failure):
        if failure == "read":
            error = _token_response()
            error.read.side_effect = TimeoutError("read timed out")
        elif failure == "wrapped":
            error = urllib.error.URLError(TimeoutError("connect timed out"))
        else:
            error = TimeoutError("connect timed out")
        with patch(
            "urllib.request.urlopen",
            side_effect=[error, _token_response(), _found()],
        ), patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is True

    @pytest.mark.parametrize("failure", ["connect", "wrapped", "read"])
    def test_persistent_timeout_is_unknown_not_missing(self, failure, capsys):
        if failure == "read":
            response = _token_response()
            response.read.side_effect = TimeoutError("read timed out")
            kwargs = {"return_value": response}
        elif failure == "wrapped":
            kwargs = {"side_effect": urllib.error.URLError(TimeoutError("connect timed out"))}
        else:
            kwargs = {"side_effect": TimeoutError("connect timed out")}
        with patch("urllib.request.urlopen", **kwargs), patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
        assert "skipping existence check" in capsys.readouterr().out

    def test_head_timeout_is_unknown_not_missing(self, capsys):
        with patch(
            "urllib.request.urlopen",
            side_effect=[_token_response()] + [TimeoutError("timed out")] * 4,
        ), patch("time.sleep"):
            assert tag_exists_in_ghcr("bluefin", "stable") is None
        assert "skipping existence check" in capsys.readouterr().out

    def test_one_token_request_per_image_then_one_head_per_tag(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=[_token_response(), _found(), _http_error(404), _found()],
        ) as mock_urlopen:
            assert _mod.tags_exist_in_ghcr("bluefin", {"first", "second", "third"}) == {
                "first": True, "second": False, "third": True
            }
        urls = [_url(call) for call in mock_urlopen.call_args_list]
        assert urls == [
            "https://ghcr.io/token?scope=repository:projectbluefin/bluefin:pull",
            "https://ghcr.io/v2/projectbluefin/bluefin/manifests/first",
            "https://ghcr.io/v2/projectbluefin/bluefin/manifests/second",
            "https://ghcr.io/v2/projectbluefin/bluefin/manifests/third",
        ]

    def test_partial_results_survive_later_transient_error(self):
        with patch(
            "urllib.request.urlopen",
            side_effect=[_token_response(), _found()]
            + [urllib.error.URLError("offline")] * 4,
        ), patch("time.sleep"):
            assert _mod.tags_exist_in_ghcr("bluefin", {"first", "second"}) == {
                "first": True, "second": None
            }

    def test_stalled_response_body_times_out(self, monkeypatch):
        release = Event()

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                body = json.dumps({"token": TOKEN}).encode()
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
        monkeypatch.setattr(_mod, "REGISTRY_URL", f"http://127.0.0.1:{server.server_port}")
        monkeypatch.setattr(_mod, "REQUEST_TIMEOUT_SECONDS", 0.025)
        monkeypatch.setattr(_mod, "MAX_RETRIES", 0)
        thread.start()
        try:
            assert tag_exists_in_ghcr("bluefin", "stable") is None
        finally:
            release.set()
            server.shutdown()
            thread.join()
            server.server_close()


class _FakeRegistry(BaseHTTPRequestHandler):
    """Answers like ghcr.io did when probed on 2026-11-14 (see the PR)."""

    images = {
        "bluefin": {"stable": "application/vnd.oci.image.manifest.v1+json"},
        "bluefin-lts": {"testing": "application/vnd.oci.image.index.v1+json"},
    }

    def _send(self, code, content_type="application/json", body=b"", headers=()):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def do_GET(self):
        image = self.path.split("repository:projectbluefin/", 1)[-1].rsplit(":", 1)[0]
        if not self.path.startswith("/token?") or image not in self.images:
            self._send(403, body=b'{"errors":[{"code":"DENIED"}]}')
            return
        self._send(200, body=json.dumps({"token": f"{TOKEN}-{image}"}).encode())

    def do_HEAD(self):
        _, _, _, image, _, tag = self.path.split("/", 5)
        auth = self.headers.get("Authorization")
        if auth is None:
            self._send(401, headers=[("WWW-Authenticate", 'Bearer realm="token"')])
            return
        if auth != f"Bearer {TOKEN}-{image}":
            self._send(403, "text/plain; charset=utf-8")
            return
        content_type = self.images.get(image, {}).get(tag)
        # GHCR 404s an existing tag when the Accept header does not list its type.
        if content_type is None or content_type not in self.headers.get("Accept", ""):
            self._send(404)
            return
        self._send(200, content_type)

    def log_message(self, *args):
        pass


@pytest.fixture
def fake_registry(monkeypatch):
    server = HTTPServer(("127.0.0.1", 0), _FakeRegistry)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setattr(_mod, "REGISTRY_URL", f"http://127.0.0.1:{server.server_port}")
    try:
        yield
    finally:
        server.shutdown()
        thread.join()
        server.server_close()


class TestAgainstFakeRegistry:
    """Real urllib requests against a local registry, no mocks."""

    def test_single_manifest_tag_exists(self, fake_registry):
        assert tag_exists_in_ghcr("bluefin", "stable") is True

    def test_multi_arch_index_tag_exists(self, fake_registry):
        assert tag_exists_in_ghcr("bluefin-lts", "testing") is True

    def test_unknown_tag_is_missing(self, fake_registry):
        assert tag_exists_in_ghcr("bluefin", "no-such-tag") is False

    def test_unknown_image_is_missing(self, fake_registry):
        assert tag_exists_in_ghcr("no-such-image", "latest") is False

    def test_rejected_token_raises(self, fake_registry):
        """GHCR answers a bad bearer token with a plain 403: an auth error, not missing."""
        with pytest.raises(urllib.error.HTTPError) as excinfo:
            _mod._manifest_exists("bluefin", "stable", "wrong-token")
        assert excinfo.value.code == 403


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
        with patch("urllib.request.urlopen", side_effect=[_token_response(), _found()]):
            assert main(tmp_path) == 0

    def test_main_missing_tag_returns_one(self, tmp_path, capsys):
        (tmp_path / ".github/workflows").mkdir(parents=True)
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/bluefin:nonexistent-tag\n"
        )
        with patch(
            "urllib.request.urlopen", side_effect=[_token_response(), _http_error(404)]
        ):
            assert main(tmp_path) == 1
        output = capsys.readouterr().out
        assert "do not exist in GHCR" in output
        assert "guide.md:1" in output

    def test_main_missing_image_returns_one(self, tmp_path):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/no-such-image:latest\n"
        )
        with patch("urllib.request.urlopen", side_effect=_http_error(403)):
            assert main(tmp_path) == 1

    def test_main_transient_error_warns_and_passes(self, tmp_path, capsys):
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/guide.md").write_text(
            "ghcr.io/projectbluefin/bluefin:stable\n"
        )
        with patch(
            "urllib.request.urlopen", side_effect=urllib.error.URLError("offline")
        ), patch("time.sleep"):
            assert main(tmp_path) == 0
        output = capsys.readouterr().out
        assert "skipped, GHCR unreachable" in output
        assert "Validated 0 of 1" in output


def test_main_requests_one_token_per_image(tmp_path, capsys):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs/guide.md").write_text(
        "ghcr.io/projectbluefin/bluefin:first\n"
        "ghcr.io/projectbluefin/bluefin:second\n"
        "ghcr.io/projectbluefin/bluefin:third\n"
    )
    with patch(
        "urllib.request.urlopen",
        side_effect=[_token_response(), _found(), _found(), _found()],
    ) as urlopen:
        assert main(tmp_path) == 0
    token_calls = [c for c in urlopen.call_args_list if "/token?" in _url(c)]
    assert len(token_calls) == 1
    assert urlopen.call_count == 4
    output = capsys.readouterr().out
    assert all(f"bluefin:{tag}" in output for tag in ("first", "second", "third"))
