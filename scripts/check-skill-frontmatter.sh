#!/usr/bin/env bash
# Validate front-matter and size budget for docs/skills/*.md
set -euo pipefail

MAX_DESC=256
MAX_SOFT=200
MAX_HARD=500
rc=0

shopt -s nullglob
skill_files=(docs/skills/*.md docs/skills/*/SKILL.md)
shopt -u nullglob

for f in "${skill_files[@]}"; do
    # index.md is a generated catalog mirror, not a skill page.
    [ "$(basename "$f")" = "index.md" ] && continue
    # Extract front-matter between the first two '---' lines
    fm=$(awk '
        BEGIN { in_fm=0 }
        /^---/ {
            if (in_fm) { exit }
            in_fm=1
            next
        }
        in_fm { print }
    ' "$f")

    if [ -z "$fm" ]; then
        echo "error: $f has no front-matter"
        rc=1
        continue
    fi

    # Here-strings, not pipes: `grep -q` exits on first match, and under
    # `pipefail` a SIGPIPE'd producer would make a matched key look missing.
    for key in name version last_updated tags description; do
        if ! grep -qE "^${key}:" <<<"$fm"; then
            echo "error: $f missing required key '$key'"
            rc=1
        fi
    done

    if ! grep -qE "^metadata:" <<<"$fm" || \
       ! grep -qE "^  type:" <<<"$fm"; then
        echo "error: $f missing metadata.type"
        rc=1
    fi

    # Description length (handle inline and folded styles)
    desc=$(awk '
        /^description:/ {
            desc=$0
            if ($0 ~ /: *[|>][+-]?$/) {
                getline
                while ($0 ~ /^ /) {
                    gsub(/^[[:space:]]+/, "")
                    desc=desc " " $0
                    getline
                }
            }
            print desc
            exit
        }
    ' "$f")

    desc_clean=$(printf '%s' "$desc" | sed -E \
        -e 's/^description:[[:space:]]*//' \
        -e 's/[[:space:]]*([|>][+-]?)[[:space:]]*$//' \
        -e 's/^["'\''"]|["'\''"]$//g' \
        -e 's/[[:space:]]+/ /g')

    len=${#desc_clean}
    if [ "$len" -gt "$MAX_DESC" ]; then
        echo "error: $f description is $len chars (max $MAX_DESC)"
        rc=1
    fi

    # Size budget — applies uniformly to every skill; oversized skills are
    # migrated to per-skill directories on sight (docs/skills/write-a-skill.md)
    lines=$(wc -l < "$f")
    base=$(basename "$f")
    if [ "$lines" -gt "$MAX_HARD" ]; then
        echo "error: $f is $lines lines (hard max $MAX_HARD)"
        rc=1
    elif [ "$lines" -gt "$MAX_SOFT" ]; then
        echo "warning: $f is $lines lines (soft max $MAX_SOFT)"
    fi
done

exit $rc
