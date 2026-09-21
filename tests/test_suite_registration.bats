#!/usr/bin/env bats
# Drift gate for the Justfile `test` recipe.
#
# A suite that no runner names is a suite that never runs. This gate asserts
# that every tests/test_*.bats and tests/test_*.py file is either named in the
# Justfile `test` recipe or declared excluded in the comment block above it,
# using the form:
#
#     # <file> is excluded — <reason>
#
# Run: bats tests/test_suite_registration.bats

setup() {
    JUSTFILE="$BATS_TEST_DIRNAME/../Justfile"
    TESTS_DIR="$BATS_TEST_DIRNAME"
    export JUSTFILE TESTS_DIR
}

# Lines of the `test` recipe body, plus the comment block directly above it.
recipe_block() {
    awk '
        /^test:/ { in_recipe = 1; print; next }
        in_recipe && /^[[:space:]]+/ { print; next }
        in_recipe { exit }
        /^#/ { print; next }
        { next }
    ' "$JUSTFILE"
}

registered_suites() {
    recipe_block | grep -v '^#' | grep -oE 'tests/test_[A-Za-z0-9_]+\.(bats|py)' | sed 's#^tests/##' | sort -u
}

excluded_suites() {
    recipe_block | grep -oE '^# test_[A-Za-z0-9_]+\.(bats|py) is excluded' \
        | grep -oE 'test_[A-Za-z0-9_]+\.(bats|py)' | sort -u
}

present_suites() {
    find "$TESTS_DIR" -maxdepth 1 -type f \
        \( -name 'test_*.bats' -o -name 'test_*.py' \) -printf '%f\n' | sort -u
}

@test "registration: the Justfile test recipe is parseable and non-empty" {
    run registered_suites
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [ "$(printf '%s\n' "$output" | wc -l)" -gt 20 ]
}

@test "registration: every suite in tests/ is registered or declared excluded" {
    local unaccounted=()
    local registered excluded suite
    registered="$(registered_suites)"
    excluded="$(excluded_suites)"

    while read -r suite; do
        if printf '%s\n' "$registered" | grep -qxF "$suite"; then
            continue
        fi
        if printf '%s\n' "$excluded" | grep -qxF "$suite"; then
            continue
        fi
        unaccounted+=("$suite")
    done < <(present_suites)

    if [ "${#unaccounted[@]}" -ne 0 ]; then
        printf 'suite never runs — add it to the Justfile `test` recipe or declare it excluded: %s\n' \
            "${unaccounted[@]}" >&2
    fi
    [ "${#unaccounted[@]}" -eq 0 ]
}

@test "registration: every registered suite exists on disk" {
    local missing=()
    local suite
    while read -r suite; do
        [ -f "$TESTS_DIR/$suite" ] || missing+=("$suite")
    done < <(registered_suites)

    if [ "${#missing[@]}" -ne 0 ]; then
        printf 'Justfile test recipe names a suite that does not exist: %s\n' "${missing[@]}" >&2
    fi
    [ "${#missing[@]}" -eq 0 ]
}

@test "registration: every exclusion names a suite that exists on disk" {
    local stale=()
    local suite
    while read -r suite; do
        [ -f "$TESTS_DIR/$suite" ] || stale+=("$suite")
    done < <(excluded_suites)

    if [ "${#stale[@]}" -ne 0 ]; then
        printf 'exclusion comment names a suite that no longer exists: %s\n' "${stale[@]}" >&2
    fi
    [ "${#stale[@]}" -eq 0 ]
}

@test "registration: every exclusion states a reason" {
    local reasonless=()
    local line
    while read -r line; do
        case "$line" in
            *"is excluded — "?*) ;;
            *) reasonless+=("$line") ;;
        esac
    done < <(recipe_block | grep -E '^# test_[A-Za-z0-9_]+\.(bats|py) is excluded')

    if [ "${#reasonless[@]}" -ne 0 ]; then
        printf 'exclusion without a reason: %s\n' "${reasonless[@]}" >&2
    fi
    [ "${#reasonless[@]}" -eq 0 ]
}

@test "registration: this gate is itself registered" {
    run registered_suites
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF 'test_suite_registration.bats'
}

@test "registration: test_image_repo.bats is registered" {
    run registered_suites
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF 'test_image_repo.bats'
}
