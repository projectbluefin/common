#!/usr/bin/env bats
# Tests for system_files/shared/etc/pwquality.conf
#
# Covers issue #1281: the initial-setup "weak password" indicator never turned
# green for a maximally complex password. libpwquality (which GNOME Initial
# Setup and bootc-installer drive that indicator from) reads this file, so the
# test pins the settings that make the indicator reflect a real password.
#
# Run: bats tests/test_pwquality.bats

PWQUALITY_CONF="$BATS_TEST_DIRNAME/../system_files/shared/etc/security/pwquality.conf.d/10-pwquality.conf"

# Read the value of a `key = value` line from the config, ignoring comments and
# blank lines. Echoes nothing if the key is absent.
_conf_value() {
    local key="$1"
    awk -v k="$key" '
        { line=$0; sub(/#.*/, "", line)
          n=split(line, a, "=")
          if (n < 2) next
          kk=a[1]; vv=a[2]
          gsub(/^[ \t]+|[ \t]+$/, "", kk)
          gsub(/^[ \t]+|[ \t]+$/, "", vv)
          if (kk == k) print vv }
    ' "${PWQUALITY_CONF}"
}

@test "pwquality.conf exists in the shared system files" {
    [ -f "${PWQUALITY_CONF}" ]
}

@test "dictcheck is disabled so complex passwords are not rejected on the dictionary" {
    [ "$(_conf_value dictcheck)" = "0" ]
}

@test "minclass is set to 3 so a normal complex password reads as strong" {
    [ "$(_conf_value minclass)" = "3" ]
}

@test "minlen is a sane minimum of 8 characters" {
    [ "$(_conf_value minlen)" = "8" ]
}

@test "maxrepeat and maxsequence are set to sane values" {
    [ "$(_conf_value maxrepeat)" = "3" ]
    [ "$(_conf_value maxsequence)" = "3" ]
}

@test "the config has no trailing whitespace and ends with a newline" {
    run bash -c "
        f='${PWQUALITY_CONF}'
        grep -nE ' +\$' \"\${f}\" && exit 1
        [ -n \"\$(tail -c1 \"\${f}\")\" ] && exit 2
        exit 0
    "
    [ "${status}" -eq 0 ]
}
