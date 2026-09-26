#!/usr/bin/env bats
# Tests for the Bluefin Agent Mode AI tools bundle.
#
# Asserts the required inventory in both directions so additions and removals
# cannot silently drift: every required tool must be present, and the retired
# RamaLama package must be absent. Pure content assertions — no real Homebrew.
#
# Oh My Pi is intentionally NOT asserted yet: the packaged formula lands in
# ublue-os/homebrew-tap#686, after which the brew line and this assertion are
# added in the same follow-up.
#
# Run: bats tests/test_ai_tools_brewfile.bats

BREWFILE="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/homebrew/ai-tools.Brewfile"

@test "ai-tools bundle installs llmman as the local inference runtime" {
    grep -qFx 'tap "llmmanorg/tap"' "${BREWFILE}"
    grep -qFx 'brew "llmmanorg/tap/llmman"' "${BREWFILE}"
}

@test "ai-tools bundle installs the read-only linux-mcp-server diagnostics tool" {
    grep -qFx 'brew "ublue-os/tap/linux-mcp-server"' "${BREWFILE}"
}

@test "ai-tools bundle installs Goose as the GUI troubleshooting client" {
    grep -qFx 'cask "ublue-os/tap/goose-linux"' "${BREWFILE}"
}

@test "ai-tools bundle installs Jan as the chat application" {
    grep -qFx 'flatpak "ai.jan.Jan"' "${BREWFILE}"
}

@test "ai-tools bundle no longer installs retired RamaLama" {
    run grep -nw 'ramalama' "${BREWFILE}"
    [ "${status}" -ne 0 ]
}

@test "ai-tools bundle stays user-scoped with no privileged install route" {
    run grep -nE 'sudo' "${BREWFILE}"
    [ "${status}" -ne 0 ]
}
