# Initialize Homebrew for interactive fish sessions.
# Same graceful-fallback pattern as starship.fish: no-op until brew exists,
# so the first sessions after enabling brew (or before it installs) stay clean.
if status is-interactive; and test -x /home/linuxbrew/.linuxbrew/bin/brew
    # Explicit shell name, not auto-detection: brew's ps/PPID detection is
    # "known to fail under some sandboxes" and then falls back to $SHELL,
    # emitting POSIX export syntax that is a fish error at every shell start.
    /home/linuxbrew/.linuxbrew/bin/brew shellenv fish | source
end
