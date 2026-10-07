#!/usr/bin/env bash
# Triage lint findings as pre-existing or introduced since the last release tag.
# Usage: triage-lint.sh <file>[:<line>] [<file>[:<line>] ...]
# Prints one verdict line per location. Exits 1 if any location is not PRE-EXISTING.
set -uo pipefail

if [ "$#" -eq 0 ]; then
    echo "usage: triage-lint.sh <file>[:<line>] [...]" >&2
    exit 2
fi

last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$last_tag" ]; then
    echo "UNKNOWN      (no prior tag - nothing to compare against)"
    exit 1
fi
echo "baseline: $last_tag"

introduced=0
for loc in "$@"; do
    file=${loc%%:*}
    line=${loc#"$file"}
    line=${line#:}
    line=${line%%:*}

    if [ ! -e "$file" ]; then
        echo "UNKNOWN      $loc  (file not found from $PWD)"
        introduced=1
        continue
    fi

    if ! git cat-file -e "$last_tag:$file" 2>/dev/null; then
        echo "INTRODUCED   $loc  (file added since $last_tag)"
        introduced=1
        continue
    fi

    if [ -z "$line" ]; then
        if [ -n "$(git log --oneline "$last_tag..HEAD" -- "$file")" ] \
           || ! git diff --quiet -- "$file"; then
            echo "INTRODUCED   $loc  (no line number, and file changed since $last_tag)"
            introduced=1
        else
            echo "PRE-EXISTING $loc  (no line number, file untouched since $last_tag)"
        fi
        continue
    fi

    sha=$(git blame -L "$line,$line" --porcelain -- "$file" 2>/dev/null | head -1 | cut -d' ' -f1)
    case "$sha" in
        "")
            echo "UNKNOWN      $loc  (blame failed - line may not exist)"
            introduced=1
            ;;
        0000000000000000000000000000000000000000)
            echo "INTRODUCED   $loc  (uncommitted working-tree change)"
            introduced=1
            ;;
        *)
            touched=$(git log -1 --format='%h %ad %s' --date=short "$sha")
            if git merge-base --is-ancestor "$sha" "$last_tag" 2>/dev/null; then
                echo "PRE-EXISTING $loc  last touched by $touched"
            else
                echo "INTRODUCED   $loc  last touched by $touched"
                introduced=1
            fi
            ;;
    esac
done

exit $introduced
