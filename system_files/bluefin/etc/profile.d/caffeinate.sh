# shellcheck shell=bash
# Prevent system sleep while a long-running task completes.
# Usage: caffeinate              — prevent sleep indefinitely (Ctrl+C to release)
#        caffeinate sleep 3600   — prevent sleep for 1 hour
caffeinate() {
    if [ $# -eq 0 ]; then
        systemd-inhibit --what=idle --who=caffeinate --why="User requested" --mode=block sleep infinity
    else
        systemd-inhibit --what=idle --who=caffeinate --why="User requested" --mode=block "$@"
    fi
}
