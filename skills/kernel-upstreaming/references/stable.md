# Getting a commit into stable

Rules live in `Documentation/process/stable-kernel-rules.rst` in the tree. This
file holds what they leave out, learned from a companion patch that took a month
and two extra mails to reach stable.

## Decide the tags when you post

`Cc: stable@vger.kernel.org` in the commit message is the cheap route: the stable
team picks the commit up by itself once it reaches mainline, with no mail from
you. A later mail costs a round trip with a busy maintainer.

Tag by what the series does together, not by what each patch does alone. A patch
that fixes nothing live yet still needs the tag if a later patch in the series
exposes the bug it closes. For patch2 depending on patch1, tag **both**. The
series note in the rules only spares you from listing patch1 as a prerequisite
if patch1 is itself marked.

Leaving a tag off does not keep a commit out of stable. AUTOSEL scans mainline
and took the second patch of a two-patch series without the untagged first,
which produced a regression in a released kernel. Backports by AUTOSEL carry
`Signed-off-by: Sasha Levin`. To really hold a commit back, use
`Cc: <stable+noautosel@kernel.org> # reason`.

Commits sent as one series can still reach Linus in different cycles, one through
the fixes tree and one through the next tree. After any part of a series lands,
check each stable branch for the rest:

```sh
git log --oneline <stable-tag> --grep='<subject>' -- <path>
```

Done when every series member is either in that branch or known not to apply.

## Request by mail once it is in mainline

Confirm the commit is in Linus's tree first. Stable refuses anything else.
Before it lands, name a commit by its subject or lore Message-ID, because a
next-tree hash is unknown to the stable team and the tree gets force-updated.

The mail stands alone. Maintainers answer a huge volume and do not reread the
thread, so a reply four weeks later must repeat everything even if it is threaded.
"Please queue this" with a commit id drew "I have no context here". The version
that got "now queued up" a quarter of an hour later had, in about 25 lines:

- the mainline commit id and subject,
- the bug in two or three sentences: what the user sees, and since which release,
- how it got there, naming the stable commit that exposed it,
- why the commit has no `Cc: stable`, if it has none, since that is the first
  question asked,
- the `Fixes:` line it would carry,
- the exact series to queue it for, and which series do not need it,
- what you checked: a clean cherry-pick onto the current tags, and how long you
  have run it.

Keep `stable@vger.kernel.org` on the Cc alongside the maintainer and the list. A
private mail to Greg is not a request to the stable team. Send with `send-reply.py`.

Read the words as the stable team means them. "Why is it not cc: stable?" is about
the **commit trailer**. Check the commit before assuming the mail's Cc was wrong.

## Check the outcome

Lore replies arrive across lists, so fetch the whole thread rather than one
list's view:

```sh
b4 mbox -o <dir> -f '<message-id>'
```

"Queued" is checkable. Look in the queue, then in the tags:

```sh
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git <dir>
grep -lri "<subject>" <dir>/queue-*
git ls-remote --tags https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git 'refs/tags/v<x.y>.*'
```

Queue files are quilt patches with no `diff --git` line, so `git patch-id` prints
nothing for them. Compare the changed lines with the mainline commit instead:

```sh
sed -n '/^--- a\//,$p' <queue-file> | grep -E '^[-+]' | grep -vE '^(---|\+\+\+)' > queued
git show <commit> --format= | grep -E '^[-+]' | grep -vE '^(---|\+\+\+)' > mainline
diff queued mainline
```

Done when the commit is in a released tag of every series you asked for. Until
then it can still be dropped in review.
