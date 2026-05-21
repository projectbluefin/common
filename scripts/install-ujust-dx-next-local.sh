#!/usr/bin/env bash
# Compatibility wrapper — use scripts/dx-next-dev.sh link
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dx-next-dev.sh" link "$@"
