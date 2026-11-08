# vim: set ft=make :

# bonedigger version v0.2.0
BONEDIGGER_VERSION := "v0.2.0"

export BONEDIGGER_BRAND := "🫐 Bluefin Bug Report"

# Collect a previewed, privacy-respecting report and create an issue directly with gh.
[group('System')]
report *args:
    BONEDIGGER_VERSION="{{ BONEDIGGER_VERSION }}" \
    BONEDIGGER_BRAND="${BONEDIGGER_BRAND}" \
    /usr/libexec/bonedigger-report {{ args }}
