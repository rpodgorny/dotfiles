#!/usr/bin/env bash
# Prints the last tag and the commit list since that tag.
# If no prior tag exists, prints FIRST_RELEASE and the full history.
set -euo pipefail

last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$last_tag" ]; then
    echo "FIRST_RELEASE: no prior tag found"
    echo "--- commits (all history) ---"
    git log --oneline
else
    echo "LAST_TAG: $last_tag"
    echo "--- commits since $last_tag ---"
    git log --oneline "$last_tag..HEAD"
fi
