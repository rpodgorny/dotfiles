#!/usr/bin/env bash
# Classify every untracked path for /release step 1b.
#
# "Untracked" is not a synonym for "harmless". Each path is one of:
#   GHOST      was tracked, a commit deleted it, on-disk content is byte-identical
#              to the deleted version. A leftover that came back. Push to remove.
#   REVIVED    was tracked and deleted, but on-disk content DIFFERS. Could be real
#              new work, could be a stale copy. Needs a human answer.
#   LEFTOVER   a commit deleted files under this path, content compare unavailable
#              (directory, or the deleting commit has no usable parent).
#   NEW        never tracked. This is the "forgot to git add" class.
#   IGNORABLE  never tracked and matches a build/scratch pattern. Summarised, not
#              itemised.
#
# For GHOST/REVIVED/LEFTOVER/NEW it also prints two signals that extension
# guessing misses:
#   - tracked siblings: how many tracked files live in the same directory. A file
#     alone in a tracked directory is far more likely to be forgotten work.
#   - referenced by tracked source: git grep for the basename across tracked files
#     only, one line per matching file. Read the matched line, the path in it
#     may point somewhere else entirely.
#
# Nothing here is ignored by .gitignore; git is actively reporting these.
# Exits 0 always. This is evidence, not a gate.
set -uo pipefail

scratch_re='(^|/)(__pycache__|node_modules|\.venv|venv|\.tox|\.pytest_cache|\.mypy_cache|\.ruff_cache|htmlcov|\.coverage|dist|build|target)(/|$)|\.(pyc|pyo|log|tmp|swp|orig|rej|bak)$|\.egg-info(/|$)'

ignorable=()
found=0

emit_signals() {
    local p="$1" d n base
    d=$(dirname "$p")
    n=$(git ls-files "$d" 2>/dev/null | awk -v d="$d" '
        { i = match($0, /\/[^\/]*$/); dd = (i ? substr($0, 1, i-1) : "."); if (dd == d) c++ }
        END { print c+0 }')
    echo "          tracked siblings in $d/: $n"
    base=$(basename "$p")
    local refs
    # changelogs name every file that ever existed; they crowd out the real hit
    refs=$(git grep -n -F -- "$base" -- ':!CHANGELOG*' ':!HISTORY*' ':!NEWS*' 2>/dev/null \
        | grep -v -F -- "$p" | awk -F: '!seen[$1]++' | head -5)
    if [ -n "$refs" ]; then
        echo "          referenced by tracked source:"
        echo "$refs" | sed 's/^/            /' | cut -c1-160
    else
        echo "          not referenced by tracked source"
    fi
}

while IFS= read -r -d '' entry; do
    [ "${entry:0:2}" = "??" ] || continue
    p="${entry:3}"
    case "$p" in .*) continue ;; esac

    if [[ "$p" =~ $scratch_re ]]; then
        ignorable+=("$p")
        continue
    fi

    q="${p%/}"
    del=$(git log --all --diff-filter=D --format='%h|%ad|%s' --date=short -n1 -- "$q" 2>/dev/null)
    found=1

    if [ -z "$del" ]; then
        echo "NEW       $p"
        echo "          never tracked in any branch"
        emit_signals "$q"
        continue
    fi

    h="${del%%|*}"; rest="${del#*|}"; dt="${rest%%|*}"; subj="${rest#*|}"

    if [ -f "$q" ] && git show "$h^:$q" >/dev/null 2>&1; then
        if git show "$h^:$q" 2>/dev/null | diff -q - "$q" >/dev/null 2>&1; then
            echo "GHOST     $p"
            echo "          on-disk content is byte-identical to the deleted version"
        else
            echo "REVIVED   $p"
            echo "          on-disk content DIFFERS from the deleted version:"
            git show "$h^:$q" 2>/dev/null | diff - "$q" | head -6 | sed 's/^/            /'
        fi
    else
        echo "LEFTOVER  $p"
        echo "          content comparison unavailable (directory, or no parent commit)"
    fi
    echo "          deleted by $h $dt \"$subj\""
    [ -e "$q" ] && echo "          on-disk mtime: $(stat -c '%y' "$q" 2>/dev/null | cut -c1-16)"
    emit_signals "$q"
done < <(git status --porcelain -z --ignore-submodules=untracked)

if [ ${#ignorable[@]} -gt 0 ]; then
    echo "IGNORABLE (${#ignorable[@]}, not itemised): ${ignorable[*]}"
    echo "          none of these are in .gitignore; if they recur every release, add them"
fi

[ "$found" = 0 ] && [ ${#ignorable[@]} -eq 0 ] && echo "no untracked paths"
exit 0
