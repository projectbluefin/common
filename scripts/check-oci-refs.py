#!/usr/bin/env python3
"""Validate OCI image references in workflow files and docs against GHCR.

Two checks:
  1. No ghcr.io/ublue-os/ references remain anywhere (org migration is complete).
  2. Every ghcr.io/projectbluefin/IMAGE:TAG reference in docs/ resolves to a
     real tag that exists in GHCR.

Check 2 asks the registry directly: one anonymous pull-token request per
image, then one manifest HEAD per tag. No GitHub token is needed.

Source of truth for valid image names and tags:
  projectbluefin/bluefin  → .github/workflows/execute-release.yml
  projectbluefin/bluefin-lts → .github/workflows/execute-release.yml
  projectbluefin/dakota   → .github/workflows/execute-release.yml

Do not update the allowed list below from memory. Read the workflow files.
"""
from pathlib import Path
import http.client
import json
import re
import sys
import time
import urllib.request
import urllib.error

# HTTP statuses that indicate transient infrastructure failures or rate limits,
# where retrying makes sense. 401 and non-rate-limit 403 are excluded as auth/permission
# failures are non-transient.
TRANSIENT_HTTP_STATUSES = {429, 500, 502, 503, 504}
MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 2
REQUEST_TIMEOUT_SECONDS = 30  # Per-request socket timeout.


# Registry v2 API. Existence is one HEAD on the manifest, which costs the same
# no matter how many tags an image has. The images are public, so the check
# uses an anonymous pull token: that is what a user pulling a documented ref
# gets, and it keeps the CI token out of the request.
REGISTRY_URL = "https://ghcr.io"
GHCR_NAMESPACE = "projectbluefin"
# Without an Accept header GHCR answers 404 even for tags that exist. List the
# index types too so multi-arch tags resolve.
MANIFEST_ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])


class UnexpectedResponseError(ValueError):
    """A 200 from the token endpoint whose JSON body carries no token."""


# ── Check 1: no ublue-os refs ────────────────────────────────────────────────
# The org migration from ublue-os to projectbluefin is complete.
# ghcr.io/ublue-os/ must not appear in workflow files or docs.
UBLUE_PATTERN = re.compile(r"ghcr\.io/ublue-os/")
# Legitimate read-only upstream ublue-os sources that are not migration targets.
# These are build-time or upstream kernel dependencies, not projectbluefin images.
UBLUE_ALLOWED_UPSTREAMS = {
    "ghcr.io/ublue-os/akmods-nvidia-open",         # upstream NVIDIA kernel modules
    "ghcr.io/ublue-os/akmods-extra",               # upstream extra kernel modules
}

UBLUE_SKIP_DIRS = {"docs/factory"}

# ── Check 2: all projectbluefin image:tag refs in docs exist in GHCR ─────────
TAG_PATTERN = re.compile(
    r"ghcr\.io/projectbluefin/([a-zA-Z0-9_/-]+):([a-zA-Z0-9._-]+)"
)


def check_ublue_refs(root=None):
    """Check 1: scan for ghcr.io/ublue-os/ refs that should have been migrated.

    Returns a list of violation strings (empty = clean).
    """
    root = Path(root) if root is not None else Path(".")
    violations = []
    paths = (
        list((root / ".github/workflows").rglob("*.yml"))
        + list((root / ".github/workflows").rglob("*.yaml"))
        + list((root / "docs").rglob("*.md"))
        + [root / "AGENTS.md"]
    )
    for path in paths:
        rel = path.as_posix()
        if any(rel.startswith(str(root / d)) for d in UBLUE_SKIP_DIRS):
            continue
        try:
            text = path.read_text()
        except FileNotFoundError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if UBLUE_PATTERN.search(line):
                if any(allowed in line for allowed in UBLUE_ALLOWED_UPSTREAMS):
                    continue
                violations.append(f"{path}:{lineno}: {line.strip()}")
    return violations


def collect_tag_refs(root=None):
    """Check 2: collect ghcr.io/projectbluefin/IMAGE:TAG refs from docs.

    Returns dict mapping "image:tag" -> [location strings].
    """
    root = Path(root) if root is not None else Path(".")
    refs: dict[str, list[str]] = {}
    paths = list((root / "docs").rglob("*.md")) + [root / "AGENTS.md"]
    for path in paths:
        try:
            text = path.read_text()
        except FileNotFoundError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in TAG_PATTERN.finditer(line):
                image, tag = m.group(1), m.group(2)
                if tag.startswith("sha256"):
                    continue
                # Skip template/placeholder tags used in docs examples.
                if (
                    tag.endswith("-")
                    or tag.endswith("_")
                    or any(c.isupper() for c in tag)
                    or "placeholder" in tag
                    or "number" in tag
                ):
                    continue
                key = f"{image}:{tag}"
                refs.setdefault(key, []).append(f"{path}:{lineno}")
    return refs


class RegistryUnavailable(Exception):
    """A registry request kept failing transiently through every retry."""

    def __init__(self, last_error):
        super().__init__(last_error)
        self.last_error = last_error


def _is_transient(error: urllib.error.HTTPError) -> bool:
    if error.code in TRANSIENT_HTTP_STATUSES:
        return True
    if error.code == 403 and error.headers is not None:
        # Treat 403 as transient only if rate-limit headers confirm it.
        rem = error.headers.get("x-ratelimit-remaining")
        retry_after = error.headers.get("retry-after")
        return (rem is not None and rem.strip() == "0") or retry_after is not None
    return False


def _with_retries(request_once):
    """Run request_once(), retrying transient failures with backoff.

    Non-transient HTTP errors (404, 401, plain 403, 422, ...) are raised to the
    caller, which decides what they mean. RegistryUnavailable is raised once
    the retries are used up.
    """
    last_error = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            return request_once()
        except urllib.error.HTTPError as e:
            if not _is_transient(e):
                raise
            last_error = e
        except (
            urllib.error.URLError,
            ConnectionError,
            TimeoutError,
            http.client.HTTPException,
            json.JSONDecodeError,
            UnexpectedResponseError,
        ) as e:
            # Dropped connections, resets, DNS/socket timeouts, bodies cut off
            # mid-transfer (IncompleteRead), and malformed token bodies never
            # reach an HTTP status; retry them like a 5xx.
            last_error = e
        if attempt < MAX_RETRIES:
            time.sleep(RETRY_BACKOFF_SECONDS * (2 ** attempt))
    raise RegistryUnavailable(last_error)


def _pull_token(image: str) -> str:
    """Fetch an anonymous pull token for one image (one request)."""
    url = (
        f"{REGISTRY_URL}/token?scope=repository:"
        f"{GHCR_NAMESPACE}/{urllib.request.quote(image, safe='/')}:pull"
    )
    with urllib.request.urlopen(url, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
        body = json.loads(resp.read())
    token = body.get("token") if isinstance(body, dict) else None
    if not isinstance(token, str) or not token:
        raise UnexpectedResponseError("token response has no token")
    return token


def _manifest_exists(image: str, tag: str, token: str) -> bool:
    """HEAD one manifest. True on 2xx; HTTP errors (404 included) raise."""
    req = urllib.request.Request(
        f"{REGISTRY_URL}/v2/{GHCR_NAMESPACE}/"
        f"{urllib.request.quote(image, safe='/')}/manifests/"
        f"{urllib.request.quote(tag, safe='')}",
        method="HEAD",
    )
    req.add_header("Accept", MANIFEST_ACCEPT)
    req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
        return 200 <= resp.status < 300


def _describe(error) -> str:
    if isinstance(error, urllib.error.HTTPError):
        return f"HTTP {error.code}"
    return f"{type(error).__name__}: {error}"


def tags_exist_in_ghcr(image: str, wanted: set[str]):
    """Return {tag: True | False | None} for the requested tags of one image.

    True means the tag exists, False means it does not (or the image does not
    exist at all), and None means GHCR could not be reached after retries.
    Costs one token request per image plus one manifest HEAD per tag.
    """
    try:
        token = _with_retries(lambda: _pull_token(image))
    except urllib.error.HTTPError as e:
        if e.code in (403, 404):
            # GHCR answers an anonymous token request for an image that does
            # not exist (or is not public) with 403 DENIED.
            return {tag: False for tag in wanted}
        raise
    except RegistryUnavailable as e:
        print(
            f"  \u26a0 GHCR token endpoint returned {_describe(e.last_error)} for "
            f"{image} after {MAX_RETRIES + 1} attempts -- skipping existence "
            "check for its refs (transient error, not a ref regression)."
        )
        return {tag: None for tag in wanted}

    results = {}
    for tag in sorted(wanted):
        try:
            results[tag] = _with_retries(lambda: _manifest_exists(image, tag, token))
        except urllib.error.HTTPError as e:
            if e.code != 404:
                raise
            results[tag] = False
        except RegistryUnavailable as e:
            print(
                f"  \u26a0 GHCR registry returned {_describe(e.last_error)} for "
                f"{image}:{tag} after {MAX_RETRIES + 1} attempts -- skipping "
                "existence check for this ref (transient error, not a ref regression)."
            )
            results[tag] = None
    return results


def tag_exists_in_ghcr(image: str, tag: str):
    """Return True, False, or None for one tag."""
    return tags_exist_in_ghcr(image, {tag})[tag]


def main(root=None):
    """Run both OCI ref checks. Returns exit code (0 = clean, 1 = violations)."""
    if root is None:
        root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")

    violations = check_ublue_refs(root)
    if violations:
        print("\nERROR: ghcr.io/ublue-os/ references found. The org migration is complete.")
        print("All runtime image refs must use ghcr.io/projectbluefin/.\n")
        for v in violations:
            print(f"  {v}")
        return 1

    refs = collect_tag_refs(root)
    if not refs:
        print("✓ No projectbluefin image:tag refs found in docs.")
        return 0

    image_tags = {}
    for key in refs:
        image, tag = key.rsplit(":", 1)
        image_tags.setdefault(image, set()).add(tag)

    missing = []
    skipped = []
    results = {}
    for image, tags in sorted(image_tags.items()):
        print(f"Checking ghcr.io/projectbluefin/{image}...")
        results[image] = tags_exist_in_ghcr(image, tags)
    for key, locations in sorted(refs.items()):
        image, tag = key.rsplit(":", 1)
        exists = results[image][tag]
        if exists is None:
            # Transient GHCR API error after retries — don't fail the build
            # over a registry hiccup, but don't silently claim it's fine.
            print(f"  ⚠ ghcr.io/projectbluefin/{key} (skipped, GHCR unreachable)")
            skipped.append(key)
            continue
        status = "✅" if exists else "❌"
        print(f"  {status} ghcr.io/projectbluefin/{key}")
        if not exists:
            for loc in locations:
                print(f"       referenced at: {loc}")
            missing.append(key)

    if skipped:
        print(
            "\nWARNING: GHCR packages API was unreachable (transient error) for "
            f"{len(skipped)} ref(s); their existence could not be verified this run:\n"
            + "\n".join(f"  ghcr.io/projectbluefin/{s}" for s in skipped)
        )

    if missing:
        print(
            "\nERROR: The following image:tag refs in docs do not exist in GHCR:\n"
            + "\n".join(f"  ghcr.io/projectbluefin/{m}" for m in missing)
            + "\n\nRead execute-release.yml and build-image-testing.yml in each repo"
            "\nbefore writing image names or tags. Do not use training data."
            "\nSee docs/skills/image-registry.md#verification for the exact commands."
        )
        return 1

    if skipped:
        print(
            f"\n✓ Validated {len(refs) - len(skipped)} of {len(refs)} image:tag refs against GHCR "
            f"({len(skipped)} skipped due to transient errors)."
        )
    else:
        print(f"\n✓ All {len(refs)} image:tag refs validated against GHCR.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
