#!/usr/bin/env bats

setup() {
    command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
    ZSH_BIN="$(command -v zsh)"
    CONFIG_DIR="$BATS_TEST_DIRNAME/../system_files/bluefin/etc"
    TEST_HOME="$BATS_TEST_TMPDIR/home with spaces"
    mkdir -p "$TEST_HOME"
}

run_zsh() {
    # Keep the runner's dotfiles, XDG paths, and shell state out of the test.
    # TERM=dumb stands in for the terminal every real login has: Fedora's
    # /etc/zlogout runs `clear`, which prints "TERM environment variable not
    # set." when TERM is missing and nothing for a dumb terminal.
    run env -i HOME="$TEST_HOME" PATH="/usr/bin:/bin" LANG=C.UTF-8 TERM=dumb \
        "$ZSH_BIN" "$@"
}

assert_quiet() {
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "zsh: all shipped startup files have valid syntax" {
    local file
    for file in zshenv zshrc zlogin zsh/zprofile; do
        run_zsh -fn "$CONFIG_DIR/$file"
        assert_quiet
    done
}

@test "zshrc: a missing user script directory is silent" {
    run_zsh -fc 'source "$1"' zsh "$CONFIG_DIR/zshrc"
    assert_quiet
}

@test "zshrc: an empty user script directory is silent" {
    mkdir -p "$TEST_HOME/.zsh"
    run_zsh -fc 'source "$1"' zsh "$CONFIG_DIR/zshrc"
    assert_quiet
}

@test "zshrc: nested user scripts are sourced" {
    mkdir -p "$TEST_HOME/.zsh/a/b"
    printf 'export BLUEFIN_ZSH_TEST=nested\n' > "$TEST_HOME/.zsh/a/b/config.zsh"
    run_zsh -fc 'source "$1"; print -r -- "$BLUEFIN_ZSH_TEST"' zsh "$CONFIG_DIR/zshrc"
    [ "$status" -eq 0 ]
    [ "$output" = nested ]
}

@test "zlogin: a missing user script directory is silent" {
    run_zsh -fc 'source "$1"' zsh "$CONFIG_DIR/zlogin"
    assert_quiet
}

@test "zlogin: an empty user script directory is silent" {
    mkdir -p "$TEST_HOME/.zsh"
    run_zsh -fc 'source "$1"' zsh "$CONFIG_DIR/zlogin"
    assert_quiet
}

@test "zlogin: nested user scripts are compiled" {
    mkdir -p "$TEST_HOME/.zsh/a/b"
    printf ': nested script\n' > "$TEST_HOME/.zsh/a/b/config.zsh"
    # Bats captures the background subshell's output too, waiting for its pipe
    # to close before run returns. A status-only check would miss its errors.
    run_zsh -fc 'source "$1"' zsh "$CONFIG_DIR/zlogin"
    assert_quiet
    [ -s "$TEST_HOME/.zsh/a/b/config.zsh.zwc" ]
}

@test "zshenv: user bin precedes local bin and user dot-bin comes last" {
    run_zsh -fc 'PATH=/usr/bin:/bin; source "$1"; print -r -- "$PATH"' zsh "$CONFIG_DIR/zshenv"
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_HOME/bin:/usr/local/bin:/usr/bin:/bin:$TEST_HOME/.bin" ]
}

@test "zshenv: later global startup files remain enabled" {
    run_zsh -fc 'setopt rcs globalrcs; source "$1"; [[ -o globalrcs ]]' zsh "$CONFIG_DIR/zshenv"
    assert_quiet
}

require_installed_config() {
    [ "${ZSH_TEST_INSTALLED:-0}" = 1 ] || skip "run in the Fedora CI container with the overlay installed"
    # Fail, rather than skip, if the container did not install this checkout.
    local file
    for file in zshenv zshrc zlogin; do
        cmp "$CONFIG_DIR/$file" "/etc/$file"
    done
}

@test "Fedora zsh: interactive startup discovers the installed environment and user scripts" {
    require_installed_config
    mkdir -p "$TEST_HOME/.zsh/a/b"
    printf 'export BLUEFIN_ZSH_TEST=nested\n' > "$TEST_HOME/.zsh/a/b/config.zsh"
    # No source command or ZDOTDIR redirection: zsh must find /etc/zsh* itself.
    run_zsh -ic 'print -r -- "$SYSTEM:$ZSHCONFIG:$BLUEFIN_ZSH_TEST"; print -r -- "$PATH"'
    [ "$status" -eq 0 ]
    [ "$output" = "Linux:$TEST_HOME/.zsh:nested
$TEST_HOME/bin:/usr/local/bin:/usr/bin:/bin:$TEST_HOME/.bin" ]
}

@test "Fedora zsh: login startup discovers the installed rc and compiler" {
    require_installed_config
    mkdir -p "$TEST_HOME/.zsh/a/b"
    printf 'export BLUEFIN_ZSH_TEST=login\n' > "$TEST_HOME/.zsh/a/b/config.zsh"
    run_zsh -lic 'print -r -- "$BLUEFIN_ZSH_TEST"'
    [ "$status" -eq 0 ]
    [ "$output" = login ]
    [ -s "$TEST_HOME/.zsh/a/b/config.zsh.zwc" ]
}
