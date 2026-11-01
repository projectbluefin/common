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
    #
    # Only literal tap declarations are collected: the taps file IS evaluated as
    # Ruby by `brew bundle` (Homebrew::Bundle::Dsl#process instance_evals it), so
    # a computed tap line — string interpolation (#{...}, #$var, #@var),
    # trailing code after a ';', or a modifier like `if system(...)` — would
    # execute in CI on a PR-controlled Brewfile. Reject anything that is not a
    # quoted literal and fail closed before `brew bundle` ever sees it. The only
    # accepted option is the documented trust flag.
    # Backslashes are rejected inside both quote styles: an escaped quote (\" or
    # \') ends the string later for Ruby than for these patterns, so a trailing
    # "# comment" would be parsed as code.
    tap_entry='^[[:space:]]*tap[[:space:]]+"[^#{}"\]+"([[:space:]]*,[[:space:]]*trusted:[[:space:]]*(true|false))?[[:space:]]*(#.*)?$'
    tap_single="^[[:space:]]*tap[[:space:]]+'[^'\\]+'([[:space:]]*,[[:space:]]*trusted:[[:space:]]*(true|false))?[[:space:]]*(#.*)?$"
    tap_declaration='^[[:space:]]*tap([^[:alnum:]_]|$)'
    # A tap declared trusted covers its items only in the Brewfile that declares
    # it: users run `brew bundle` on one file at a time.
    tap_trusted_double='^[[:space:]]*tap[[:space:]]+"([^"]+)"[[:space:]]*,[[:space:]]*trusted:[[:space:]]*true([[:space:]]|#|$)'
    tap_trusted_single="^[[:space:]]*tap[[:space:]]+'([^']+)'[[:space:]]*,[[:space:]]*trusted:[[:space:]]*true([[:space:]]|#|$)"
    declare -A trusted_taps=()
    : > "${workdir}/taps.Brewfile"
    for brewfile in "${brewfiles[@]}"; do
        line_number=0
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line_number=$((line_number + 1))
            if [[ "${line}" =~ ${tap_declaration} ]]; then
                if [[ "${line}" =~ ${tap_entry} || "${line}" =~ ${tap_single} ]]; then
                    printf '%s\n' "${line}" >> "${workdir}/taps.Brewfile"
                    if [[ "${line}" =~ ${tap_trusted_double} || "${line}" =~ ${tap_trusted_single} ]]; then
                        # Homebrew treats user/homebrew-repo and user/repo as one tap.
                        tap_name="${BASH_REMATCH[1],,}"
                        trusted_taps["${brewfile}|${tap_name/\/homebrew-//}"]=1
                    fi
                else
                    printf 'FAIL: %s:%s: expected a quoted literal tap declaration: %s\n' "${brewfile}" "${line_number}" "${line}" >&2
                    printf 'Validation complete: refusing to evaluate non-literal tap lines.\n' >&2
                    exit 1
                fi
            fi
        done < "${brewfile}"
    done
    sort -u "${workdir}/taps.Brewfile" -o "${workdir}/taps.Brewfile"
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
    # `trusted:` is accepted only once and only as the literal true or false,
    # the same strictness as tap lines. Comments are not options, but the
    # duplicate check reads the raw line: a "#" inside a Ruby string could
    # otherwise hide a later key that Ruby would honour.
    trusted_key=',[[:space:]]*trusted:'
    trusted_literal=',[[:space:]]*trusted:[[:space:]]*(true|false)[[:space:]]*(,|$)'
    trusted_true=',[[:space:]]*trusted:[[:space:]]*true[[:space:]]*(,|$)'
    qualified='^([^/]+)/([^/]+)/[^/]+$'
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
                raw_options="${BASH_REMATCH[3]}"
                options="${raw_options%%#*}"
                [[ "${type}" != brew ]] || type=formula
                checked=$((checked + 1))
                if [[ "${options}" =~ ${trusted_key} ]] \
                    && { [[ ! "${options}" =~ ${trusted_literal} ]] || [[ "${raw_options#*trusted:}" == *trusted:* ]]; }; then
                    failed=$((failed + 1))
                    printf 'FAIL: %s:%s: trusted: must be the literal true or false: %s\n' "${brewfile}" "${line_number}" "${line}" >&2
                    continue
                fi
                item_trusted=0
                [[ ! "${options}" =~ ${trusted_true} ]] || item_trusted=1
                # Homebrew 6+ refuses to load items from non-official taps
                # unless they are trusted. Say so instead of a generic
                # `brew info` failure.
                if [[ "${item_trusted}" -eq 0 && "${name,,}" =~ ${qualified} ]] \
                    && [[ "${BASH_REMATCH[1]}" != homebrew ]] \
                    && [[ -z "${trusted_taps["${brewfile}|${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"]:-}" ]]; then
                    failed=$((failed + 1))
                    printf 'FAIL: %s:%s: third-party %s %s needs trusted: true\n' "${brewfile}" "${line_number}" "${type}" "${name}" >&2
                    continue
                fi
                # Mirror `brew bundle`: grant trust only to the item the
                # Brewfile itself declares trusted.
                if [[ "${item_trusted}" -eq 1 ]] \
                    && ! brew trust "--${type}" -- "${name}" > "${workdir}/output" 2>&1; then
                    failed=$((failed + 1))
                    printf 'FAIL: %s:%s: could not trust %s %s\n' "${brewfile}" "${line_number}" "${type}" "${name}" >&2
                    sed 's/^/  /' "${workdir}/output" >&2
                    continue
                fi
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
