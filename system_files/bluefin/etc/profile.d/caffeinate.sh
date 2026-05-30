# Prevent system sleep while a long-running task completes.
# Usage: caffeinate [duration]
# Example: caffeinate sleep 3600   # prevent sleep for 1 hour
alias caffeinate='systemd-inhibit --what=idle --who=caffeinate --why="User requested" --mode=block'
