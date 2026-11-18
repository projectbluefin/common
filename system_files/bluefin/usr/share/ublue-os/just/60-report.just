# vim: set ft=make :

# Open the Report a Problem app (bluefin-report) to collect, review, and publish.
# Same launcher the shipped io.projectbluefin.Report.desktop entry uses: the
# wrapper puts Homebrew's gh on PATH.
[group('System')]
report *args:
    /home/linuxbrew/.linuxbrew/bin/bluefin-report-wrapper {{ args }}
