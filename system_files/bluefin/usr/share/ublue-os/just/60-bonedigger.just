# vim: set ft=make :

# bonedigger version v0.1.0
BONEDIGGER_VERSION := "v0.1.0"

# Override to send bug reports to a custom repo; leave unset to auto-detect from image-info.json.
# Feature requests always go to projectbluefin/common.
export BONEDIGGER_BRAND := "🫐 Bluefin Bug Report"

# Collect a privacy-respecting diagnostic report and offer to attach it to a new bug report.
[group('System')]
report:
    BONEDIGGER_VERSION="{{ BONEDIGGER_VERSION }}" \
    BONEDIGGER_BRAND="${BONEDIGGER_BRAND}" \
    /usr/libexec/bonedigger-report
