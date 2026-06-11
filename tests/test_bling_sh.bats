#!/usr/bin/env bats

BLING_SCRIPT="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/bling/bling.sh"
BASH_BIN="$(command -v bash)"
WORKDIR=""
MOCKDIR=""
BASEBIN=""
CALL_LOG=""

setup() {
    WORKDIR="$BATS_TEST_DIRNAME/.tmp/test_bling_sh_${BATS_TEST_NUMBER}_$$"
    MOCKDIR="$WORKDIR/mockbin"
    BASEBIN="$WORKDIR/basebin"
    CALL_LOG="$WORKDIR/calls.log"

    mkdir -p "$MOCKDIR" "$BASEBIN" "$WORKDIR/home"
    ln -s "$(command -v basename)" "$BASEBIN/basename"
    ln -s "$(command -v readlink)" "$BASEBIN/readlink"
    ln -s "$(command -v sh)" "$BASEBIN/sh"
    : > "$CALL_LOG"
}

teardown() {
    rm -rf "$WORKDIR"
}

run_bling() {
    run env -i \
        PATH="$MOCKDIR:$BASEBIN" \
        HOME="$WORKDIR/home" \
        CALL_LOG="$CALL_LOG" \
        BLING_SCRIPT="$BLING_SCRIPT" \
        "$BASH_BIN" --noprofile --norc -c "$1"
}

assert_alias_defined() {
    local alias_name="$1"
    local expected="$2"

    run_bling 'source "$BLING_SCRIPT"; alias '"\"$alias_name\""' 2>/dev/null'
    [ "$status" -eq 0 ]
    [[ "$output" == *"$expected"* ]]
}

assert_alias_missing() {
    local alias_name="$1"

    run_bling 'source "$BLING_SCRIPT"; alias '"\"$alias_name\""' 2>/dev/null'
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

make_mock() {
    local name="$1"
    shift

    cat <<EOF_MOCK > "$MOCKDIR/$name"
#!/usr/bin/env sh
$*
EOF_MOCK
    chmod +x "$MOCKDIR/$name"
}

make_direnv_mock() {
    make_mock direnv '
printf "%s\\n" "direnv $1 $2" >> "$CALL_LOG"
if [ "$1" = "hook" ]; then
    printf "export DIRENV_INIT=1\\nexport DIRENV_SHELL=%s\\n" "$2"
fi
'
}

make_starship_mock() {
    make_mock starship '
printf "%s\\n" "starship $1 $2" >> "$CALL_LOG"
if [ "$1" = "init" ]; then
    printf "export STARSHIP_INIT=1\\nexport STARSHIP_SHELL=%s\\n" "$2"
fi
'
}

make_zoxide_mock() {
    make_mock zoxide '
printf "%s\\n" "zoxide $1 $2" >> "$CALL_LOG"
if [ "$1" = "init" ]; then
    printf "export ZOXIDE_INIT=1\\nexport ZOXIDE_SHELL=%s\\n" "$2"
fi
'
}

make_mise_mock() {
    make_mock mise '
printf "%s\\n" "mise $1 $2" >> "$CALL_LOG"
if [ "$1" = "activate" ]; then
    printf "export MISE_INIT=1\\nexport MISE_SHELL=%s\\n" "$2"
fi
'
}

@test "bling.sh sources only once when BLING_SOURCED is set" {
    make_direnv_mock
    make_starship_mock
    make_zoxide_mock
    make_mise_mock

    run_bling 'source "$BLING_SCRIPT"; source "$BLING_SCRIPT"; printf "%s" "$BLING_SOURCED"'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
    [ "$(grep -c '^direnv hook bash$' "$CALL_LOG")" -eq 1 ]
    [ "$(grep -c '^starship init bash$' "$CALL_LOG")" -eq 1 ]
    [ "$(grep -c '^zoxide init bash$' "$CALL_LOG")" -eq 1 ]
    [ "$(grep -c '^mise activate bash$' "$CALL_LOG")" -eq 1 ]
}

@test "bling.sh defines eza aliases when eza exists" {
    make_mock eza 'exit 0'

    assert_alias_defined ll "alias ll='eza -l --icons=auto --group-directories-first'"
    assert_alias_defined l. "alias l.='eza -d .*'"
    assert_alias_defined ls "alias ls='eza'"
    assert_alias_defined l1 "alias l1='eza -1'"
}

@test "bling.sh skips eza aliases when eza is missing" {
    assert_alias_missing ll
    assert_alias_missing l.
    assert_alias_missing ls
    assert_alias_missing l1
}

@test "bling.sh defines bat alias when bat exists" {
    make_mock bat 'exit 0'

    assert_alias_defined cat "alias cat='bat --style=plain --pager=never'"
}

@test "bling.sh skips bat alias when bat is missing" {
    assert_alias_missing cat
}

@test "bling.sh defines ug aliases when ug exists" {
    make_mock ug 'exit 0'

    assert_alias_defined grep "alias grep='ug'"
    assert_alias_defined egrep "alias egrep='ug -E'"
    assert_alias_defined fgrep "alias fgrep='ug -F'"
    assert_alias_defined xzgrep "alias xzgrep='ug -z'"
    assert_alias_defined xzegrep "alias xzegrep='ug -zE'"
    assert_alias_defined xzfgrep "alias xzfgrep='ug -zF'"
}

@test "bling.sh skips ug aliases when ug is missing" {
    assert_alias_missing grep
    assert_alias_missing egrep
    assert_alias_missing fgrep
    assert_alias_missing xzgrep
    assert_alias_missing xzegrep
    assert_alias_missing xzfgrep
}

@test "bling.sh initializes available shell hooks" {
    make_direnv_mock
    make_starship_mock
    make_zoxide_mock
    make_mise_mock

    run_bling 'source "$BLING_SCRIPT"; printf "%s|%s|%s|%s|%s|%s|%s|%s" "${DIRENV_INIT:-}" "${DIRENV_SHELL:-}" "${STARSHIP_INIT:-}" "${STARSHIP_SHELL:-}" "${ZOXIDE_INIT:-}" "${ZOXIDE_SHELL:-}" "${MISE_INIT:-}" "${MISE_SHELL:-}"'
    [ "$status" -eq 0 ]
    [ "$output" = "1|bash|1|bash|1|bash|1|bash" ]
    [ "$(grep -c '^direnv hook bash$' "$CALL_LOG")" -eq 1 ]
    [ "$(grep -c '^starship init bash$' "$CALL_LOG")" -eq 1 ]
    [ "$(grep -c '^zoxide init bash$' "$CALL_LOG")" -eq 1 ]
    [ "$(grep -c '^mise activate bash$' "$CALL_LOG")" -eq 1 ]
}

@test "bling.sh degrades gracefully when shell hook tools are missing" {
    run_bling 'source "$BLING_SCRIPT"; printf "%s|%s|%s|%s" "${DIRENV_INIT:-missing}" "${STARSHIP_INIT:-missing}" "${ZOXIDE_INIT:-missing}" "${MISE_INIT:-missing}"'
    [ "$status" -eq 0 ]
    [ "$output" = "missing|missing|missing|missing" ]
    [ ! -s "$CALL_LOG" ]
}
