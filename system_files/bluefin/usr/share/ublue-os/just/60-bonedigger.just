# vim: set ft=make :

# bonedigger version v0.2.0
BONEDIGGER_VERSION := "v0.2.0"

# Open the Report a Problem app (bluefin-report) to collect, review, and publish.
# Same launcher the shipped io.projectbluefin.Report.desktop entry uses: the
# wrapper puts Homebrew's gh on PATH.
[group('System')]
report *args:
    /home/linuxbrew/.linuxbrew/bin/bluefin-report-wrapper {{ args }}
