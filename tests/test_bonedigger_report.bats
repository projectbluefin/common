#!/usr/bin/env bats

setup() {
    export BONEDIGGER_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/bonedigger-report"
    export UBLUE_IMAGE_REPO_BIN="$BATS_TEST_DIRNAME/../system_files/shared/usr/libexec/ublue-image-repo"
    export WORKDIR="$BATS_TEST_DIRNAME/.bonedigger-report-test-${BATS_TEST_NUMBER}-${$}"
    export HOME="$WORKDIR/home"
    export XDG_STATE_HOME="$WORKDIR/state"
    export XDG_RUNTIME_DIR="$WORKDIR/runtime"

    mkdir -p "$WORKDIR/bin" "$HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
}

teardown() {
    rm -rf "$WORKDIR"
}

@test "scrub_kernel_log redacts MAC, IP, UUID, and home paths" {
    run bash -c 'source "$1"; printf "%s\n" "$2" | scrub_kernel_log' _ \
        "$BONEDIGGER_SCRIPT" \
        "Device 00:1A:2B:3C:4D:5E from 192.168.1.100 on /home/alice/ UUID 123e4567-e89b-12d3-a456-426614174000"

    [ "$status" -eq 0 ]
    [ "$output" = "Device [MAC-REDACTED] from [IP-REDACTED] on /home/[REDACTED]/ UUID [UUID-REDACTED]" ]
}

@test "scrub_journal_log redacts user variables and email addresses" {
    run bash -c 'source "$1"; printf "%s\n" "$2" | scrub_journal_log' _ \
        "$BONEDIGGER_SCRIPT" "USER=jorge contacted jorge@example.com"

    [ "$status" -eq 0 ]
    [ "$output" = "USER=[REDACTED] contacted [REDACTED-email]" ]
}

@test "bug routing maps Bluefin-family, Dakota-family, and unknown images" {
    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin latest
    [ "$output" = "projectbluefin/bluefin" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin lts-42
    [ "$output" = "projectbluefin/bluefin-lts" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin-lts-hwe stable
    [ "$output" = "projectbluefin/bluefin-lts" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" bluefin-nvidia stable
    [ "$output" = "projectbluefin/bluefin" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" dakota latest
    [ "$output" = "projectbluefin/dakota" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" dakota-nvidia stable
    [ "$output" = "projectbluefin/dakota" ]

    run bash -c 'source "$1"; IMAGE_NAME="$2"; IMAGE_TAG="$3"; route_issue_repo; printf "%s" "$BUG_REPO"' _ \
        "$BONEDIGGER_SCRIPT" unknown latest
    [ "$output" = "projectbluefin/common" ]
}

@test "image info prefers booted image reference over stale build metadata" {
    printf '%s\n' '{"image-name":"bluefin","image-tag":"latest","image-ref":"ghcr.io/projectbluefin/bluefin:latest","image-flavor":"main"}' \
        > "$WORKDIR/stale-image-info.json"

    run bash -c '
        source "$1"
        BOOTC_JSON='{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota:stable"}}}}}'
        IMAGE_INFO_FILE="$2"
        read_image_info
        printf "%s|%s|%s" "$IMAGE_NAME" "$IMAGE_TAG" "$IMAGE_REF"
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/stale-image-info.json"

    [ "$status" -eq 0 ]
    [ "$output" = "dakota|stable|ghcr.io/projectbluefin/dakota:stable" ]
}

@test "image info falls back when no booted image is reported" {
    printf '%s\n' '{"image-name":"bluefin","image-tag":"latest","image-ref":"ghcr.io/projectbluefin/bluefin:latest","image-flavor":"main"}' \
        > "$WORKDIR/stale-image-info.json"

    run bash -c '
        source "$1"
        BOOTC_JSON='{"status":{"booted":null}}'
        IMAGE_INFO_FILE="$2"
        read_image_info
        printf "%s|%s" "$IMAGE_NAME" "$IMAGE_TAG"
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/stale-image-info.json"

    [ "$status" -eq 0 ]
    [ "$output" = "bluefin|latest" ]
}

@test "queue choices map to at most one supported queue label" {
    run bash -c 'source "$1"; queue_label_for_choice "$2"' _ \
        "$BONEDIGGER_SCRIPT" "Submit to the clanker queue for machine analysis"
    [ "$status" -eq 0 ]
    [ "$output" = "3-clanker-queue" ]

    run bash -c 'source "$1"; queue_label_for_choice "$2"' _ \
        "$BONEDIGGER_SCRIPT" "I only want human interaction"
    [ "$status" -eq 0 ]
    [ "$output" = "3-human-queue" ]

    run bash -c 'source "$1"; queue_label_for_choice "$2"' _ \
        "$BONEDIGGER_SCRIPT" "No queue preference"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "queue selection records one workflow-readable routing preference" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
case "$1" in
    choose) printf 'Submit to the clanker queue for machine analysis\n' ;;
    style) exit 0 ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    : > "$WORKDIR/draft/queue-label.txt"
    printf '%s\n' \
        '## Bluefin report' \
        '<!-- bonedigger-queue-preference: 3-human-queue -->' \
        > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        choose_queue_preference
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ "$(< "$WORKDIR/draft/queue-label.txt")" = "3-clanker-queue" ]
    [ "$(grep -cF '<!-- bonedigger-queue-preference: 3-clanker-queue -->' "$WORKDIR/draft/issue.md")" -eq 1 ]
    ! grep -qF '<!-- bonedigger-queue-preference: 3-human-queue -->' "$WORKDIR/draft/issue.md"
}

@test "no queue preference still records ujust report intake" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
case "$1" in
    choose) printf 'No queue preference\n' ;;
    style) exit 0 ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    : > "$WORKDIR/draft/queue-label.txt"
    printf '## Bluefin report\n' > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        choose_queue_preference
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ -z "$(< "$WORKDIR/draft/queue-label.txt")" ]
    grep -qF '<!-- bonedigger-queue-preference: none -->' "$WORKDIR/draft/issue.md"
}

@test "network smart logs are redacted and bounded" {
    cat << 'EOF' > "$WORKDIR/bin/journalctl"
#!/usr/bin/bash
for _ in $(seq 1 80); do
    printf 'USER=jorge peer 192.168.1.8 MAC AA:BB:CC:DD:EE:FF /home/alice/private\n'
done
EOF
    cat << 'EOF' > "$WORKDIR/bin/nmcli"
#!/usr/bin/bash
printf 'wlan0:wifi:connected\n'
EOF
    chmod +x "$WORKDIR/bin/journalctl" "$WORKDIR/bin/nmcli"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        collect_profile Networking "$2/networking.md" 512
        grep -Fq "[IP-REDACTED]" "$2/networking.md"
        grep -Fq "[MAC-REDACTED]" "$2/networking.md"
        grep -Fq "USER=[REDACTED]" "$2/networking.md"
        ! grep -Fq "192.168.1.8" "$2/networking.md"
        test "$(wc -c < "$2/networking.md")" -le 512
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
}

@test "selected profile bundle is capped at two MiB" {
    cat << 'EOF' > "$WORKDIR/bin/journalctl"
#!/usr/bin/bash
for _ in $(seq 1 16000); do
    printf 'warning USER=jorge peer 192.168.1.8\n'
done
EOF
    chmod +x "$WORKDIR/bin/journalctl"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        BOOTC_STATUS="booted"
        SELECTED_PROFILES=(
            "Desktop / graphics"
            "Sleep / crash"
            "Update / boot"
            Networking
            "Flatpak / application"
        )
        collect_profiles
        total=0
        for file in "${PROFILE_FILES[@]}"; do
            bytes="$(wc -c < "$file")"
            test "$bytes" -le $((500 * 1024))
            total=$((total + bytes))
        done
        test "$total" -le $((2 * 1024 * 1024))
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR"

    [ "$status" -eq 0 ]
}

@test "persist_local_copy skips missing report files and keeps available copies" {
    mkdir -p "$WORKDIR/draft"
    printf 'summary\n' > "$WORKDIR/draft/issue.md"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    export DRAFT_DIR="$WORKDIR/draft"
    export LOCAL_REPORT_ROOT="$WORKDIR/state/ujust-report"

    run bash -c 'source "$1"; persist_local_copy' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(cat "$LOCAL_REPORT_ROOT/last/summary.md")" = "summary" ]
    [ ! -e "$LOCAL_REPORT_ROOT/last/journal.txt" ]
}

@test "issue creation uses direct gh arguments and one queue label" {
    cat << 'EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$CALLS_FILE"
if [[ "$1" == issue ]]; then
    printf 'https://github.com/projectbluefin/bluefin/issues/99\n'
fi
EOF
    chmod +x "$WORKDIR/bin/gh"
    export CALLS_FILE="$WORKDIR/gh-calls"
    mkdir -p "$WORKDIR/draft"
    printf 'projectbluefin/bluefin\n' > "$WORKDIR/draft/repo.txt"
    printf '3-clanker-queue\n' > "$WORKDIR/draft/queue-label.txt"
    printf 'Short title\n' > "$WORKDIR/draft/title.txt"
    printf '## 🫐 Bluefin Bug Report\n' > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        create_issue
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/projectbluefin/bluefin/issues/99" ]
    grep -qF "issue create --repo projectbluefin/bluefin --title Short title --body-file $WORKDIR/draft/issue.md --label 3-clanker-queue" "$CALLS_FILE"
    [ "$(grep -o -- '--label' "$CALLS_FILE" | wc -l)" -eq 1 ]
}

@test "confirmation accepts a GitHub issue URL and posts no device identifier" {
    cat << 'EOF' > "$WORKDIR/bin/systemctl"
#!/usr/bin/bash
printf 'failed-example.service loaded failed failed\n'
EOF
    cat << 'EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$CALLS_FILE"
if [[ "$1" == api ]]; then
    printf 'https://github.com/projectbluefin/dakota/issues/42#issuecomment-123\n'
fi
EOF
    chmod +x "$WORKDIR/bin/systemctl" "$WORKDIR/bin/gh"
    export CALLS_FILE="$WORKDIR/gh-calls"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        parse_confirm_target "https://github.com/projectbluefin/dakota/issues/42#comment" projectbluefin/common
        IMAGE_REF="ghcr.io/projectbluefin/dakota"
        IMAGE_TAG="latest"
        BOOTED_DIGEST="sha256:abc123"
        confirm_report "$CONFIRM_ISSUE" "$CONFIRM_REPO"
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Will post to: https://github.com/projectbluefin/dakota/issues/42"* ]]
    [[ "$output" == *"Digest: sha256:abc123"* ]]
    [[ "$output" != *"Device ID"* ]]
    grep -qF "issue comment 42 --repo projectbluefin/dakota --body" "$CALLS_FILE"
    grep -qF "https://github.com/projectbluefin/dakota/issues/42#issuecomment-123" <<< "$output"
}

@test "confirmation rejects invalid issue identifiers" {
    run bash -c 'source "$1"; parse_confirm_target "$2" projectbluefin/common' _ \
        "$BONEDIGGER_SCRIPT" 0
    [ "$status" -eq 1 ]
    [[ "$output" == *"issue-number-or-url"* ]]

    run bash -c 'source "$1"; parse_confirm_target "$2" projectbluefin/common' _ \
        "$BONEDIGGER_SCRIPT" "https://github.com/projectbluefin/common/issues/0"
    [ "$status" -eq 1 ]
}

@test "confirmation accepts a positive issue number for the routed repository" {
    run bash -c '
        source "$1"
        parse_confirm_target "$2" projectbluefin/bluefin-lts
        printf "%s|%s" "$CONFIRM_REPO" "$CONFIRM_ISSUE"
    ' _ "$BONEDIGGER_SCRIPT" 73

    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin-lts|73" ]
}

@test "declining submission preserves the draft and resume command" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
if [[ "$1" == confirm ]]; then
    exit 1
fi
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    printf '\n' > "$WORKDIR/draft/queue-label.txt"
    printf 'Short title\n' > "$WORKDIR/draft/title.txt"
    printf '## 🫐 Bluefin Bug Report\n' > "$WORKDIR/draft/issue.md"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        PROFILE_FILES=()
        submit_draft
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ -f "$WORKDIR/draft/issue.md" ]
    [[ "$output" == *"Resume with: ujust report --resume $WORKDIR/draft"* ]]
}

@test "cancelling final queue selection preserves the bug draft" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == choose ]] && exit 1
EOF
    chmod +x "$WORKDIR/bin/gum"
    mkdir -p "$WORKDIR/draft"
    printf 'projectbluefin/common\n' > "$WORKDIR/draft/repo.txt"
    : > "$WORKDIR/draft/queue-label.txt"
    printf 'Short title\n' > "$WORKDIR/draft/title.txt"
    printf '## 🫐 Bluefin Bug Report\n' > "$WORKDIR/draft/issue.md"
    : > "$WORKDIR/draft/bug-report.txt"

    run env PATH="$WORKDIR/bin:$PATH" bash -c '
        source "$1"
        DRAFT_DIR="$2"
        PROFILE_FILES=()
        submit_draft
    ' _ "$BONEDIGGER_SCRIPT" "$WORKDIR/draft"

    [ "$status" -eq 0 ]
    [ -f "$WORKDIR/draft/issue.md" ]
    [[ "$output" == *"Submission was cancelled before selecting a queue preference."* ]]
    [[ "$output" == *"Resume with: ujust report --resume $WORKDIR/draft"* ]]
}

@test "feature requests draft against projectbluefin common" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
case "$1" in
    input)
        case "$*" in
            *"Short title"*) printf 'Improve the desktop\n' ;;
            *) printf 'Please add a useful setting.\n' ;;
        esac
        ;;
    confirm) exit 1 ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum"

    run env PATH="$WORKDIR/bin:$PATH" XDG_STATE_HOME="$XDG_STATE_HOME" \
        bash -c '
            source "$1"
            start_feature_request
            cat "$DRAFT_ROOT"/draft-*/repo.txt
        ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"projectbluefin/common"* ]]
}

@test "missing gh requests Homebrew installation before failing safely" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == confirm ]]
EOF
    cat << 'EOF' > "$WORKDIR/bin/brew"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$BREW_CALLS"
EOF
    chmod +x "$WORKDIR/bin/gum" "$WORKDIR/bin/brew"
    export BREW_CALLS="$WORKDIR/brew-calls"

    run env PATH="$WORKDIR/bin" BREW_CALLS="$BREW_CALLS" /usr/bin/bash -c '
        source "$1"
        ensure_gh_ready
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 1 ]
    grep -qFx 'install gh' "$BREW_CALLS"
}

@test "unauthenticated gh offers browser sign-in" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
[[ "$1" == confirm ]]
EOF
    cat << 'EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$GH_CALLS"
case "$1 $2" in
    "auth status") exit 1 ;;
    "auth login") exit 0 ;;
esac
EOF
    chmod +x "$WORKDIR/bin/gum" "$WORKDIR/bin/gh"
    export GH_CALLS="$WORKDIR/gh-calls"

    run env PATH="$WORKDIR/bin:$PATH" GH_CALLS="$GH_CALLS" /usr/bin/bash -c '
        source "$1"
        ensure_gh_ready
    ' _ "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 1 ]
    grep -qFx 'auth login --web --skip-ssh-key' "$GH_CALLS"
}

@test "help intent does not collect diagnostics or create an issue" {
    cat << 'EOF' > "$WORKDIR/bin/gum"
#!/usr/bin/bash
if [[ "$1" == choose ]]; then
    printf 'Get help\n'
fi
EOF
    cat << 'EOF' > "$WORKDIR/bin/bootc"
#!/usr/bin/bash
printf 'bootc should not be called\n' >&2
exit 1
EOF
    chmod +x "$WORKDIR/bin/gum" "$WORKDIR/bin/bootc"

    run env PATH="$WORKDIR/bin:$PATH" HOME="$HOME" \
        XDG_STATE_HOME="$XDG_STATE_HOME" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        bash "$BONEDIGGER_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Bluefin Discussions"* ]]
    [[ "$output" == *"No issue was created."* ]]
    [[ "$output" != *"bootc should not be called"* ]]
}
