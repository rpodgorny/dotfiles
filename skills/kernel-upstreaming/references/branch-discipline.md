# Branch discipline

For a tree that carries patches in flight and also builds a kernel that
actually runs somewhere. The problem it solves: the same fix exists twice, on
different bases, and the two copies drift.

## Naming

Four rules hold the layout together.

1. A branch meant for submission has **`for-upstream`** in its name. Nothing
   else does.
2. A **deployed** branch (`van/<topic>`, `pi/<topic>`, whatever the machine is
   called) **mirrors** its `for-upstream/<topic>` exactly: same diff, same
   commit message, only the base differs. Change one, change the other in the
   same sitting.
3. Once a patch is merged, its branch moves to `upstreamed/<topic>` and holds
   the exact merged commit, including the maintainer's own
   `Signed-off-by:`. A later local "improvement" there conflicts the next time
   the deployed branch rebases onto a kernel that already contains it. A
   merged topic's deployed branch mirrors `upstreamed/` instead, and keeps
   carrying the patch until a released kernel contains it.
4. `scrap/*` is dead experiments. It exists so that a superseded branch has
   somewhere to go other than deletion or the working set.

Bases differ on purpose. `for-upstream/*` tracks the maintainer tree
(`bt-next/master` for Bluetooth). Deployed branches track the stable tag the
machine boots, and rebasing them onto mainline breaks the build that runs.

## An integration branch

Where a machine runs several topics at once, an octopus merge of the topic
branches plus any machine-only commits gives one build:

```sh
git checkout --detach <deployed>/<first-topic>
git merge --no-ff <deployed>/<other-topic> <deployed>/<another>
git cherry-pick <machine-only commits>
git branch -f <deployed>/integration HEAD
```

Nothing is developed on the integration branch; it is rebuilt from the topic
branches whenever one changes. Machine-only commits, a debug log line on a hot
path being the usual case, live here and are never submitted.

## b4 must not move the tip

b4's default cover-letter strategy, `commit`, stores the cover letter in an
empty commit at the head of the series. That changes the submission branch's
tip and its commit list, so the mirror check below reports DIVERGED for a
branch whose actual patches are untouched.

Set `b4.prep-cover-strategy = branch-description` in any tree with mirrored
branches. The cover letter then lives in the git branch description, the
commits stay byte-identical to their mirror, and `b4 prep --enroll` leaves the
tip exactly where it found it.

## Proving the copies still match

Different bases mean different line numbers, so compare patch-ids rather than
diffs. `--stable` ignores line numbers, so the different bases produce no
false mismatch:

```sh
for p in <topic> <topic>; do
  a=$(git log --format=%H <deployed-base>..<deployed>/$p | while read c; do
        git show $c | git patch-id --stable | cut -d' ' -f1; done | sort | md5sum)
  b=$(git log --format=%H <remote>/master..for-upstream/$p | while read c; do
        git show $c | git patch-id --stable | cut -d' ' -f1; done | sort | md5sum)
  ma=$(git log --format=%B <deployed-base>..<deployed>/$p | md5sum)
  mb=$(git log --format=%B <remote>/master..for-upstream/$p | md5sum)
  printf "%-24s diff:%s msg:%s\n" "$p" \
    "$([ "$a" = "$b" ] && echo OK || echo DIVERGED)" \
    "$([ "$ma" = "$mb" ] && echo OK || echo DIVERGED)"
done
```

Run it after every rebase of a `for-upstream` branch. A merged topic has no
`for-upstream` counterpart, so compare its deployed branch against
`upstreamed/<topic>` instead; those must stay byte-identical.

## Credentials in a synced tree

A tree living under syncthing, Dropbox or any replicated directory replicates
everything written into it, and one stray `git add -A` puts it in a commit.
Keep SMTP passwords and tokens outside that directory:
`~/.git-credentials`, mode 0600, read by git's `store` helper. Set
`sendemail.smtpUser` in git config and leave `sendemail.smtpPass` unset, so a
second plaintext copy never lands in `~/.gitconfig`.
