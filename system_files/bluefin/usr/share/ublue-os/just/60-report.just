# vim: set ft=make :

# Open the Report a Problem app (bluefin-report) to collect, review, and publish.
# Same launcher the shipped io.projectbluefin.Report.desktop entry uses: the
# wrapper puts Homebrew's gh on PATH.
[group('System')]
report *args:
    #!/usr/bin/bash
    WRAPPER="${BLUEFIN_REPORT_WRAPPER:-/home/linuxbrew/.linuxbrew/bin/bluefin-report-wrapper}"
    if [[ ! -x "$WRAPPER" ]]; then
        echo "The Report a Problem app is not installed yet ($WRAPPER not found)." >&2
        echo "Run 'ujust brew-preinstall' (or install it with 'brew install --cask bluefin-report'), then try again." >&2
        exit 1
    fi
    exec "$WRAPPER" {{ args }}
