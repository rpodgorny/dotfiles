#!/usr/bin/env bash
# Lists files containing the given old version string, excluding lockfiles and changelogs.
# Usage: find-stray-versions.sh <old-version>
# Manually inspect each hit — only update references that mean "current version", not historical mentions.
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <old-version>" >&2
    exit 2
fi

git grep -l -F "$1" -- \
    ':!Cargo.lock' \
    ':!package-lock.json' \
    ':!poetry.lock' \
    ':!uv.lock' \
    ':!pnpm-lock.yaml' \
    ':!yarn.lock' \
    ':!CHANGELOG.md' \
    ':!CHANGES.md' \
    ':!HISTORY.md' \
    ':!changelog.md' \
    ':!changes.md' \
    ':!history.md' \
    || echo "(no matches)"
