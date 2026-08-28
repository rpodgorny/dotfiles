#!/usr/bin/env bash
# Preflight gates for /release.
# Exit codes:
#   0 = hard gates pass and working tree is clean — proceed
#   1 = a HARD gate failed (wrong branch, or behind a remote) — stop
#   2 = hard gates pass but the working tree is DIRTY — soft gate: the caller
#       must surface the changes, judge severity, and ask the user whether to
#       stop or skip-and-continue. Does NOT block on its own.
# Hard gates:
#   1. Current branch is master or main
#   2. Branch not behind origin (ahead is fine; behind or diverged is not),
#      and not behind asterix/upstream master|main if those remotes exist
# Soft gate:
#   3. Working tree clean (dot-prefixed paths like .claude/ are always ignored)
set -euo pipefail

branch=$(git branch --show-current)
if [ "$branch" != "master" ] && [ "$branch" != "main" ]; then
    echo "FAIL: must be on master or main (currently on '$branch')"
    exit 1
fi

# Check we're in sync with each relevant remote. origin is required; asterix and
# upstream are checked only if configured. For the extra remotes, compare against
# whichever of the current branch / master / main actually exists there (forks
# often track an upstream that renamed master -> main or vice versa).
synced=()

git fetch --quiet origin "$branch"
behind=$(git rev-list --count "HEAD..origin/$branch")
if [ "$behind" != "0" ]; then
    ahead=$(git rev-list --count "origin/$branch..HEAD")
    echo "FAIL: behind origin/$branch by $behind (ahead $ahead). Pull/rebase first."
    exit 1
fi
synced+=("origin/$branch")

for remote in asterix upstream; do
    git remote | grep -qx "$remote" || continue

    if ! git fetch --quiet "$remote"; then
        echo "FAIL: could not fetch from $remote"
        exit 1
    fi

    rbranch=""
    for cand in "$branch" master main; do
        if git rev-parse --verify --quiet "refs/remotes/$remote/$cand" >/dev/null; then
            rbranch="$cand"
            break
        fi
    done
    [ -n "$rbranch" ] || continue

    behind=$(git rev-list --count "HEAD..$remote/$rbranch")
    if [ "$behind" != "0" ]; then
        ahead=$(git rev-list --count "$remote/$rbranch..HEAD")
        echo "FAIL: behind $remote/$rbranch by $behind (ahead $ahead). Merge it first."
        exit 1
    fi
    synced+=("$remote/$rbranch")
done

# Soft gate: working-tree cleanliness. Dot-prefixed paths (.claude/ etc.) are
# local tooling state and always ignored. Anything else is surfaced — but does
# NOT hard-fail here; the caller judges severity and asks the user. Porcelain
# columns: first = staged, second = unstaged; '??' = untracked.
dirty=$(git status --porcelain --ignore-submodules=untracked | grep -v '^.. \.' || true)
if [ -n "$dirty" ]; then
    echo "DIRTY: working tree has uncommitted changes (excluding dot-prefixed paths):"
    echo "$dirty"
    echo "(soft gate) hard gates OK: on $branch, in sync with ${synced[*]}"
    exit 2
fi

echo "OK: clean tree, on $branch, in sync with ${synced[*]}"
