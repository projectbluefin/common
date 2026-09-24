#!/usr/bin/env bash
# Check every shared Brewfile against real Homebrew metadata. This syncs declared
# taps but never installs formulae/casks. It is networked, not part of just check.

main() (
    set -euo pipefail
    if [[ $# -gt 1 ]]; then
        echo "Usage: $0 [brewfile-directory]" >&2
        exit 2
    fi
    root="${1:-system_files/shared/usr/share/ublue-os/homebrew}"
    if [[ ! -d "${root}" ]]; then
        printf 'Brewfile directory does not exist: %s\n' "${root}" >&2
        exit 2
    fi
    if ! command -v brew >/dev/null; then
        echo "Homebrew is required to validate Brewfiles." >&2
        exit 2
    fi

    workdir=$(mktemp -d)
    trap 'rm -rf -- "${workdir}"' EXIT
    # Materialize discovery so find/sort failures cannot become an empty success.
    find "${root}" -type f -iname '*.Brewfile' -print0 | sort -z > "${workdir}/files"
    mapfile -d '' -t brewfiles < "${workdir}/files"
    if [[ ${#brewfiles[@]} -eq 0 ]]; then
        printf 'No Brewfiles found in %s\n' "${root}" >&2
        exit 2
    fi

    # Sync the complete tap set first: otherwise bare-name ambiguity depends on
    # which Brewfile find happens to visit first. Preserve declared trust flags.
    sed -n '/^[[:space:]]*tap[[:space:]]/p' "${brewfiles[@]}" | sort -u > "${workdir}/taps.Brewfile"
    if [[ -s "${workdir}/taps.Brewfile" ]]; then
        echo "Syncing declared taps from:"
        printf '  %s\n' "${brewfiles[@]}"
        sed 's/^/  /' "${workdir}/taps.Brewfile"
        if brew bundle --file="${workdir}/taps.Brewfile" > "${workdir}/output" 2>&1; then
            echo "Tap setup passed."
        else
            rc=$?
            printf 'FAIL: tap setup (exit %s). Package checks were not run.\n' "${rc}" >&2
            printf 'Command: brew bundle --file=%q\n' "${workdir}/taps.Brewfile" >&2
            sed 's/^/  /' "${workdir}/output" >&2
            exit 1
        fi
    fi

    # The repository uses literal brew/cask declarations, not computed Ruby.
    # Reject malformed declarations rather than silently skipping them.
    double_entry='^[[:space:]]*(brew|cask)[[:space:]]+"([^"]+)"([[:space:]]*,.*|[[:space:]]*(#.*)?)$'
    single_entry="^[[:space:]]*(brew|cask)[[:space:]]+'([^']+)'([[:space:]]*,.*|[[:space:]]*(#.*)?)$"
    declaration='^[[:space:]]*(brew|cask)([^[:alnum:]_]|$)'
    checked=0
    failed=0
    for brewfile in "${brewfiles[@]}"; do
        printf '\nBrewfile: %s\n' "${brewfile}"
        line_number=0
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line_number=$((line_number + 1))
            if [[ "${line}" =~ ${double_entry} || "${line}" =~ ${single_entry} ]]; then
                type="${BASH_REMATCH[1]}"
                name="${BASH_REMATCH[2]}"
                [[ "${type}" != brew ]] || type=formula
                checked=$((checked + 1))
                # Pass names as data, never interpolate them into bash -c.
                # Serial checks keep each error adjacent to its source location.
                if brew info "--${type}" -- "${name}" > "${workdir}/output" 2>&1; then
                    printf 'PASS: %s:%s: %s %s\n' "${brewfile}" "${line_number}" "${type}" "${name}"
                else
                    rc=$?
                    failed=$((failed + 1))
                    printf 'FAIL: %s:%s: %s %s (exit %s)\n' "${brewfile}" "${line_number}" "${type}" "${name}" "${rc}" >&2
                    printf 'Command: brew info --%s -- %q\n' "${type}" "${name}" >&2
                    sed 's/^/  /' "${workdir}/output" >&2
                fi
            elif [[ "${line}" =~ ${declaration} ]]; then
                failed=$((failed + 1))
                printf 'FAIL: %s:%s: expected a quoted literal brew/cask name: %s\n' "${brewfile}" "${line_number}" "${line}" >&2
            fi
        done < "${brewfile}"
    done
    printf '\nValidation complete: %s Brewfiles, %s package checks, %s failures.\n' "${#brewfiles[@]}" "${checked}" "${failed}"
    [[ "${failed}" -eq 0 ]]
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
