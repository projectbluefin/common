#!/usr/bin/env bats
# Container trust configuration under system_files/shared/etc/containers.
#
# containers/image (podman, skopeo, bootc) only looks for cosign signatures on
# a registry scope that registries.d marks with `use-sigstore-attachments:
# true`. A policy.json `sigstoreSigned` entry whose scope has no such marker
# can never see a signature and rejects every pull. These tests keep the two
# files in step and make sure every image namespace this project publishes is
# marked, so a future enforcement entry has signatures to check.
#
# Run: bats tests/test_container_trust.bats

setup() {
    CONTAINERS_DIR="$BATS_TEST_DIRNAME/../system_files/shared/etc/containers"
    POLICY="$CONTAINERS_DIR/policy.json"
    REGISTRIES_D="$CONTAINERS_DIR/registries.d"
    export CONTAINERS_DIR POLICY REGISTRIES_D
}

# Registry scopes that registries.d marks as carrying sigstore attachments.
sigstore_scopes() {
    python3 - "$REGISTRIES_D" <<'PY'
import glob, os, sys
import yaml
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.yaml"))):
    with open(path) as fh:
        doc = yaml.safe_load(fh) or {}
    for scope, opts in (doc.get("docker") or {}).items():
        if (opts or {}).get("use-sigstore-attachments") is True:
            print(scope)
PY
}

@test "policy.json is valid JSON with a reject default" {
    run jq -e '.default[0].type == "reject"' "$POLICY"
    [ "$status" -eq 0 ]
}

@test "every sigstoreSigned scope in policy.json is marked in registries.d" {
    run jq -r '.transports.docker | to_entries[] | select(any(.value[]; .type == "sigstoreSigned")) | .key' "$POLICY"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    local marked scope
    marked="$(sigstore_scopes)"
    while IFS= read -r scope; do
        grep -qxF "$scope" <<<"$marked" || {
            echo "policy.json requires sigstore signatures for '$scope' but no registries.d file marks it with use-sigstore-attachments: true"
            return 1
        }
    done <<<"$output"
}

@test "ghcr.io/projectbluefin is marked for sigstore attachments" {
    run sigstore_scopes
    [ "$status" -eq 0 ]
    grep -qxF "ghcr.io/projectbluefin" <<<"$output"
}

@test "every registries.d file is a single-scope docker document" {
    local path
    for path in "$REGISTRIES_D"/*.yaml; do
        run python3 - "$path" <<'PY'
import sys, yaml
with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh)
assert set(doc) == {"docker"}, f"{sys.argv[1]}: top-level keys {sorted(doc)}"
assert len(doc["docker"]) == 1, f"{sys.argv[1]}: expected one scope"
PY
        [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    done
}
