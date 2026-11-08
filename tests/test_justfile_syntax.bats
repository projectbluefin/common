#!/usr/bin/env bats
# Justfile syntax gate.
#
# `just` lexes a recipe body before handing it to the shell, and a bare Go-template
# placeholder such as podman's `--format "{{.Repository}}"` is not a valid token.
# A single one aborts the parse of the WHOLE file with
#
#     error: unknown start of token '.'
#     --> default.just:33:60
#
# which takes down every unrelated recipe in the same justfile.
#
# `just`'s escaping is asymmetric, which is the whole point of these gates:
#   `{{{{`  is the escape for a literal `{{`  -> de-escaped by just. Legal.
#   `}}}}`  is NOT an escape. Outside an interpolation `}}` is already literal,
#           so `}}}}` reaches the shell as two stray braces.
#
# So the three gates are:
#   1. no `*.just` file contains an UNESCAPED Go-template placeholder
#      (`{{.`, `{{ .`, `{{json .}}`, ...). The escaped spelling `{{{{.` is legal
#      and deliberately allowed — see the "{{{{ literal-brace escape is
#      accepted" test below.
#   2. no `*.just` file contains `}}}}`
#   3. every `*.just` file actually parses with `just --list`
#
# Gate 3 is the backstop: it fails on any other way of breaking a justfile, not
# just the brace shapes above. Gate 1 and 2 name the failure mode; both walk the
# discovered file list one file at a time and treat a grep *error* as a failure,
# so a missing file can never read as "no match".
#
# Run: bats tests/test_justfile_syntax.bats

setup() {
    # Absolute REPO_ROOT: bats may be invoked from any directory, and the
    # discovered paths must be readable no matter what the caller's cwd is.
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    JUSTFILES="$(cd "${REPO_ROOT}" && find system_files bluefin-branding -name '*.just' -type f 2>/dev/null | sed "s|^|${REPO_ROOT}/|" | sort)"
    # The gate patterns live here, once, and are referenced by both the gate and
    # the pin test below. A second copy in the test would let someone loosen the
    # gate while the test kept passing against its own copy, which is the same
    # class of vacuous check this suite exists to catch.
    PLACEHOLDER_RE='(^|[^{])\{\{[[:space:]]*(\.|[A-Za-z_][A-Za-z0-9_]*[[:space:]]+\.)'
    CLOSE_BRACE_RE='\}\}\}\}'
    export REPO_ROOT JUSTFILES PLACEHOLDER_RE CLOSE_BRACE_RE
}

have_just() {
    command -v just >/dev/null 2>&1
}

# Assert no file in ${JUSTFILES} matches the given grep pattern.
#
# ${JUSTFILES} is a newline-joined list, so it must be walked one file at a
# time: quoting it hands `grep` a single (nonexistent) filename, which exits 2
# ("No such file or directory") and reads as "clean" under a `-ne 0` check.
# A grep *error* is a failure here, never a pass, and no match must be exactly
# status 1.
assert_no_justfile_matches() {
    local pattern="$1" f status found=1
    while IFS= read -r f; do
        [ -n "${f}" ] || continue
        [ -r "${f}" ] || { printf 'UNREADABLE %s\n' "${f}" >&2; return 1; }
        grep -Eq "${pattern}" "${f}"
        status=$?
        case "${status}" in
            0) printf 'MATCH %s (%s)\n' "${f}" "${pattern}" >&2; found=0 ;;
            1) : ;;
            *) printf 'GREP ERROR %s (%s) status=%s\n' "${f}" "${pattern}" "${status}" >&2; return 1 ;;
        esac
    done <<< "${JUSTFILES}"
    [ "${found}" -eq 1 ]
}

@test "justfile gate: test fixtures were discovered" {
    [ -n "${JUSTFILES}" ]
    # The file that regressed in #1285 must be part of the gate.
    run grep -Fx "${REPO_ROOT}/system_files/shared/usr/share/ublue-os/just/default.just" <<< "${JUSTFILES}"
    [ "${status}" -eq 0 ]
}

@test "justfile gate: no justfile contains an unescaped Go-template brace placeholder" {
    # A Go template placeholder is `{{` followed by something that starts a
    # field/function reference — a leading dot, optionally spaced, or an
    # identifier pipeline that ends in a dot (`{{ .Repository }}`, `{{json .}}`).
    # All of those abort the `just` parse; matching on the dot rather than on
    # `[A-Za-z_]` keeps legal just interpolations (`{{ args }}`,
    # `{{ source_directory() }}`) out of the net.
    #
    # The leading `(^|[^{])` is what keeps just's own `{{{{` literal-brace
    # escape out of the net too: in `{{{{.Repository}}` the `{{.` is preceded
    # by `{`, so it does not match. That spelling is legal (it de-escapes to
    # `{{.Repository}}`) and is what the escape test below asserts. Only the
    # bare, unescaped form is banned here.
    #
    # NOT exhaustive, by design and by cost: `{{- .X }}` (a trim marker), `{{$x}}`
    # and `{{ end }}` also abort the `just` parse and do not match this pattern.
    # Gate 3 (`just --list`) is what catches those, and `just check`'s
    # `--fmt --check` in validate.yml covers the same ground in CI. Do not read
    # this regex as the definition of a valid justfile — it names the two
    # shapes seen in the wild.
    run assert_no_justfile_matches "${PLACEHOLDER_RE}"
    [ "${status}" -eq 0 ]
}

@test "justfile gate: no justfile contains the non-existent }}}} escape" {
    # `{{{{` IS just's escape for a literal `{{`. `}}}}` is not an escape for
    # anything: `}}` outside an interpolation is already literal, so the doubled
    # form reaches the shell verbatim and the recipe prints stray braces after
    # every column. That was the live bug in `clean-system` on main.
    run assert_no_justfile_matches "${CLOSE_BRACE_RE}"
    [ "${status}" -eq 0 ]
}

@test "justfile gate: the no-match helper is not vacuous" {
    # Negative control. If the grep walk ever regresses to passing the file list
    # as one quoted filename (grep exits 2, reads as clean), the two gates above
    # pass no matter what is in a justfile. Plant a violation in a throwaway
    # list and require the helper to catch it.
    local planted="${BATS_TEST_TMPDIR}/planted.just"
    printf 'probe:\n    echo "{{.Repository}}}}"\n' > "${planted}"
    local saved="${JUSTFILES}"
    JUSTFILES="${planted}"
    run assert_no_justfile_matches "${CLOSE_BRACE_RE}"
    [ "${status}" -ne 0 ]
    JUSTFILES="${saved}"
    run assert_no_justfile_matches "${CLOSE_BRACE_RE}"
    [ "${status}" -eq 0 ]
}

@test "justfile gate: the placeholder gate bans the bare form and allows the escape" {
    # Pins the asymmetry the gate is built on, so neither half can drift:
    # `{{.Repository}}` is the spelling that breaks the parse and must fail;
    # `{{{{.Repository}}` is just's documented escape and must pass.
    local dir="${BATS_TEST_TMPDIR}/pattern"
    mkdir -p "${dir}"
    local saved="${JUSTFILES}"

    printf 'probe:\n    echo "{{.Repository}}"\n' > "${dir}/bare.just"
    JUSTFILES="${dir}/bare.just"
    run assert_no_justfile_matches "${PLACEHOLDER_RE}"
    [ "${status}" -ne 0 ]

    # Spaced and piped spellings abort the parse just the same and must be
    # caught by the same gate.
    printf 'probe:\n    echo "{{ .Repository }}"\n' > "${dir}/spaced.just"
    JUSTFILES="${dir}/spaced.just"
    run assert_no_justfile_matches "${PLACEHOLDER_RE}"
    [ "${status}" -ne 0 ]

    printf 'probe:\n    echo "{{json .}}"\n' > "${dir}/piped.just"
    JUSTFILES="${dir}/piped.just"
    run assert_no_justfile_matches "${PLACEHOLDER_RE}"
    [ "${status}" -ne 0 ]

    # Legal just interpolations must not trip it.
    printf 'probe arg:\n    echo "{{ arg }} {{ source_directory() }}"\n' > "${dir}/legal.just"
    JUSTFILES="${dir}/legal.just"
    run assert_no_justfile_matches "${PLACEHOLDER_RE}"
    [ "${status}" -eq 0 ]

    printf 'probe:\n    echo "{{{{.Repository}}"\n' > "${dir}/escaped.just"
    JUSTFILES="${dir}/escaped.just"
    run assert_no_justfile_matches "${PLACEHOLDER_RE}"
    [ "${status}" -eq 0 ]

    JUSTFILES="${saved}"
}

@test "justfile gate: just's own {{{{ literal-brace escape is accepted" {
    # Guards against this suite growing a rule that forbids the legitimate
    # escape. If a future justfile legitimately needs a literal `{{`, this test
    # fails so the rule is revisited rather than silently tightened.
    if ! have_just; then
        skip "just is not installed in this environment"
    fi
    local out
    printf 'probe:\n    echo "{{{{.Repository}}:{{{{.Tag}}  {{{{.ID}}"\n' > "${BATS_TEST_TMPDIR}/probe.just"
    out="$(just --justfile "${BATS_TEST_TMPDIR}/probe.just" --dry-run probe 2>&1)"
    # Correct spelling de-escapes to a clean podman format string ...
    grep -Fq 'echo "{{.Repository}}:{{.Tag}}  {{.ID}}"' <<< "${out}"
    # ... and never leaves a stray `}}` behind, which is what `}}}}` did.
    run grep -F '}}}}' <<< "${out}"
    [ "${status}" -ne 0 ]
}

@test "justfile gate: every justfile parses with just --list" {
    if ! have_just; then
        skip "just is not installed in this environment"
    fi
    local failed=0 f out
    while IFS= read -r f; do
        if ! out="$(cd "${REPO_ROOT}" && just --justfile "${f}" --list 2>&1)"; then
            printf 'PARSE FAIL %s\n%s\n' "${f}" "${out}" >&2
            failed=1
        fi
    done <<< "${JUSTFILES}"
    [ "${failed}" -eq 0 ]
}

@test "justfile gate: default.just keeps its recipes after the format fix" {
    if ! have_just; then
        skip "just is not installed in this environment"
    fi
    local listing
    listing="$(cd "${REPO_ROOT}" && just --justfile system_files/shared/usr/share/ublue-os/just/default.just --list 2>&1)"
    # Every recipe the E2E suites invoke by name, plus the one the fix touched.
    local recipe
    for recipe in clean-system check-local-overrides logs-this-boot logs-last-boot bios-info; do
        run grep -Eq "^    ${recipe}([[:space:]]|$)" <<< "${listing}"
        [ "${status}" -eq 0 ]
    done
}
