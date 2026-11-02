#!/usr/bin/bash
# Acceptance-evidence admission gate.
#
# Admits a promotion candidate only when its acceptance evidence exists, passed,
# and was captured against THIS exact image digest. It never treats a missing,
# failed, or stale (old-image) observation as a pass: admission is blocked until
# real evidence exists, and a blocked record names the repair task that owns it.
#
# This is the consumer side of the acceptance-evidence contract. The runner
# (owner-provided, outside this repo) produces the signed exact-image evidence;
# it boots the exact candidate, runs the install/update/rollback/guest checks,
# and writes the signed record this gate reads. It needs no credentials, no
# network, and no Utah access, so it runs in ordinary CI.
#
# Evidence record (JSON):
#   {
#     "check":       "composefs-boot",   # which acceptance check this proves
#     "status":      "pass",             # "pass" | "fail" | "missing"
#     "image_digest":"sha256:...",       # exact image the evidence was captured on
#     "repair_task": "projectbluefin/utah#938"  # owner of a failed/missing record
#   }
#
# Usage: admit-evidence.sh <candidate-digest> [evidence-file]
#   <candidate-digest>  signed exact-candidate digest to admit (sha256:...)
#   [evidence-file]     JSON evidence record (defaults to stdin)
# Exit 0 = admit, 1 = block, 2 = bad usage. Prints exactly one human-readable line.

set -euo pipefail

usage() {
    printf '%s\n' "usage: $(basename "$0") <candidate-digest> [evidence-file]" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
[[ -n "${1:-}" ]] || usage

candidate_digest="$1"
evidence_source="${2:-/dev/stdin}"

command -v jq >/dev/null 2>&1 || { printf '%s\n' "block: jq is required" >&2; exit 1; }

# A candidate is only admitted on evidence captured against its own digest.
if [[ ! -r "${evidence_source}" ]] || [[ ! -s "${evidence_source}" ]]; then
    printf 'block: no acceptance evidence captured for this candidate\n' >&2
    exit 1
fi

evidence="$(cat "${evidence_source}")"

# A record that is not valid JSON cannot be trusted as evidence.
if ! printf '%s' "${evidence}" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "block: acceptance evidence is not valid JSON" >&2
    exit 1
fi

status="$(printf '%s' "${evidence}" | jq -r '.status // "missing"')"
image_digest="$(printf '%s' "${evidence}" | jq -r '.image_digest // ""')"
repair_task="$(printf '%s' "${evidence}" | jq -r '.repair_task // ""')"
check="$(printf '%s' "${evidence}" | jq -r '.check // "acceptance check"')"

# Never pass a record that did not pass.
if [[ "${status}" != "pass" ]]; then
    printf 'block: %s evidence status is "%s", not pass\n' "${check}" "${status}" >&2
    [[ -n "${repair_task}" ]] || printf '%s\n' "block: names no owning repair task" >&2
    exit 1
fi

# Never pass evidence captured on an older image than the candidate.
if [[ "${image_digest}" != "${candidate_digest}" ]]; then
    printf 'block: %s evidence is for an older image ("%s") but candidate is "%s"\n' \
        "${check}" "${image_digest}" "${candidate_digest}" >&2
    [[ -n "${repair_task}" ]] || printf '%s\n' "block: names no owning repair task" >&2
    exit 1
fi

printf 'admit: %s evidence passed for exact candidate "%s"\n' "${check}" "${candidate_digest}"
exit 0
