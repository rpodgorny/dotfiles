#!/usr/bin/env bash
# Lists README/docs files containing the given old version string (excluding CHANGELOG/CHANGES/HISTORY).
# Report-only — never fails.
# Usage: docs-check.sh <old-version>
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <old-version>" >&2
    exit 2
fi

git grep -l -F "$1" -- \
    'README*' \
    'docs/**' \
    '*.md' \
    ':!CHANGELOG.md' \
    ':!CHANGES.md' \
    ':!HISTORY.md' \
    ':!changelog.md' \
    ':!changes.md' \
    ':!history.md' \
    || echo "(no stale version references found)"
