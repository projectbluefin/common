# shellcheck shell=bash
# Prevent the system from sleeping, like macOS caffeinate.
# Usage: caffeinate              — hold indefinitely (Ctrl+C to release)
#        caffeinate sleep 3600   — hold while command runs
caffeinate() {
    if [ $# -eq 0 ]; then
        echo "Preventing system sleep. Press Ctrl+C to allow sleep again."
        systemd-inhibit \
            --what=sleep:idle:handle-lid-switch \
            --who=caffeinate \
            --why="User requested no sleep" \
            sleep infinity
    else
        systemd-inhibit \
            --what=sleep:idle \
            --who=caffeinate \
            --why="Running: $*" \
            "$@"
    fi
}
