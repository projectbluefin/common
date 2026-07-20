#!/usr/bin/env bash
# Verify docs/SKILL.md task table links to every docs/skills/*.md file.
set -euo pipefail

SKILL_INDEX="docs/SKILL.md"
rc=0

for f in docs/skills/*.md; do
    base=$(basename "$f")
    if ! grep -qE "\[.*\]\(skills/${base}\)" "${SKILL_INDEX}"; then
        echo "error: ${SKILL_INDEX} is missing a link to skills/${base}"
        rc=1
    fi
done

exit $rc
