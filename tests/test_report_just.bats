#!/usr/bin/env bats
# Tests for the `ujust report` recipe in 60-report.just: a missing
# bluefin-report-wrapper must produce a clear message and a non-zero exit.

REPORT_JUST="${BATS_TEST_DIRNAME}/../system_files/bluefin/usr/share/ublue-os/just/60-report.just"

setup() {
    WORKDIR="$(mktemp -d)"
    SCRIPT="${WORKDIR}/report.sh"
    awk '
        /^report \*args:$/ { in_recipe=1; next }
        in_recipe && /^    #!\/usr\/bin\/bash$/ { found=1; print "#!/usr/bin/env bash"; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); gsub(/\{\{ args \}\}/, "\"$@\""); print }
    ' "$REPORT_JUST" > "$SCRIPT"
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$WORKDIR"
}

@test "report: missing wrapper prints install hint and exits non-zero" {
    BLUEFIN_REPORT_WRAPPER="${WORKDIR}/absent" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not installed"* ]]
    [[ "$output" == *"brew-preinstall"* ]]
}

@test "report: present wrapper is executed with the given args" {
    printf '#!/usr/bin/env bash\necho "wrapper:$*"\n' > "${WORKDIR}/wrapper"
    chmod +x "${WORKDIR}/wrapper"
    BLUEFIN_REPORT_WRAPPER="${WORKDIR}/wrapper" run "$SCRIPT" --foo
    [ "$status" -eq 0 ]
    [ "$output" = "wrapper:--foo" ]
}
