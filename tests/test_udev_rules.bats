#!/usr/bin/env bats
# Tests for system_files/shared/usr/lib/udev/rules.d
#
# Covers issue #1503: 92-viia.rules (now 70-viia.rules) matched every hidraw node and set
# MODE="0666", so any local uid could read raw keystrokes or drive FIDO keys.
# A device rule that grants a world-accessible mode must be scoped to a
# vendor/product; unscoped rules may only add the seat-local uaccess tag.
#
# Run: bats tests/test_udev_rules.bats

RULES_DIR="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/udev/rules.d"
VIIA_RULES="${RULES_DIR}/70-viia.rules"

# Print the rule lines (comments and blanks stripped) of a rules file.
_rule_lines() {
    grep -vE '^[[:space:]]*(#|$)' "$1"
}

@test "70-viia.rules exists in the shared system files" {
    [ -f "${VIIA_RULES}" ]
}

@test "70-viia.rules keeps the seat-local uaccess tag for usevia.app" {
    run _rule_lines "${VIIA_RULES}"
    [ "$status" -eq 0 ]
    [[ "$output" == *'KERNEL=="hidraw*"'* ]]
    [[ "$output" == *'TAG+="uaccess"'* ]]
}

@test "70-viia.rules does not set a MODE on every hidraw node" {
    run _rule_lines "${VIIA_RULES}"
    [ "$status" -eq 0 ]
    [[ "$output" != *'MODE'* ]]
}

@test "uaccess rules sort before systemd's 73-seat-late.rules" {
    local late=""
    local f
    for f in "${RULES_DIR}"/*.rules; do
        _rule_lines "$f" | grep -q 'TAG+="uaccess"' || continue
        [[ "$(basename "$f")" < "73-seat-late.rules" ]] || late+="$(basename "$f") "
    done
    if [ -n "$late" ]; then
        echo "uaccess tag set after 73-seat-late.rules (never applied): $late"
        return 1
    fi
}

@test "no rule grants a world-accessible mode without a vendor or product filter" {
    local offenders=""
    local f line
    for f in "${RULES_DIR}"/*.rules; do
        while IFS= read -r line; do
            [[ "$line" =~ MODE:?=\"0?[0-7][0-7][1-7]\" ]] || continue
            [[ "$line" == *'idVendor'* || "$line" == *'idProduct'* || "$line" == *'KERNELS=='* ]] && continue
            offenders+="$(basename "$f"): ${line}"$'\n'
        done < <(_rule_lines "$f")
    done
    if [ -n "$offenders" ]; then
        echo "world-accessible rules without a device filter:"
        echo "$offenders"
        return 1
    fi
}
