# Tracking a posted patch

## Where the verdict lands

Two machines answer before any human does, and both outrank a quiet inbox.

The subsystem CI replies to the list roughly 40 minutes after a post with a
pass/fail table. A red result on an apply or build test means the patch is
ignored until it is fixed, so read that before waiting on a reviewer.

`patchwork-bot+bluetooth@kernel.org` mails again when a patch is applied.
Patchwork is also what the maintainer works from, so a patch missing there was
never really received:

- <https://patchwork.kernel.org/project/bluetooth/list/?submitter=you@example.com>
- <https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git/log/>

Fastest answer to "did it land": `git fetch <remote>` and grep the log.

## A red apply result is not always your patch

The first thing the BlueZ CI runs is `pre-ci_am`, from
[`BluezTestBot/action-patchwork-to-pr`](https://github.com/BluezTestBot/action-patchwork-to-pr)
(`pw-to-pr.py`). For each patch in the series it does an unauthenticated
`requests.get(patch['mbox'])` against patchwork and then `git am` on whatever
came back. Its `cmd_run()` throws stdout away when the command fails and mails
only stderr, and `git am` prints `Patch is empty.` on **stdout**.

So an apply-failure mail whose `----- Output -----` section is **empty** is the
tell that the bot never got a patch to apply. A real conflict puts
`error: patch failed:` on stderr and you would be reading it.

Three checks, in order, before touching anything:

1. **Did the base move?**

   ```sh
   git fetch <remote>
   git log --oneline <base-commit>..<remote>/master
   ```

2. **Re-apply exactly what the list received.** Not the local branch — the mail,
   fetched back out of the archive:

   ```sh
   curl -A 'git/2.47' 'https://lore.kernel.org/<list>/<message-id>/raw' -o /tmp/p.eml
   git worktree add --detach /tmp/am <base-commit>
   git -C /tmp/am am /tmp/p.eml
   ```

   For a series, pull `t.mbox.gz` and feed the patches in order. Try the
   reverse order too; see the ordering section below for why.

3. **Is everyone else failing?**

   ```sh
   curl -s 'https://patchwork.kernel.org/api/1.2/patches/?project=bluetooth&since=<iso-date>&order=-date'
   curl -s 'https://patchwork.kernel.org/api/1.2/patches/<id>/checks/'
   ```

   Several unrelated submitters red on `pre-ci_am` inside the same window means
   the bot, not you. **Do not resend.** A resend fails identically and burns a
   version number; others have done it.

### 2026-09-08: patchwork put /mbox/ behind a login

`patchwork.kernel.org` began redirecting `/project/<project>/patch/<id>/mbox/`
to `/user/login/?next=...`. The bot has no credentials, saved the HTML sign-in
page as the `.patch`, and `git am` answered `Patch is empty.` Every series
posted to linux-bluetooth from roughly 2026-09-07 13:00 UTC failed `pre-ci_am`
with a blank Output, kernel and BlueZ userspace alike. Last green before it was
patch 14794690, 2026-09-06 23:37.

Whether it is still broken:

```sh
curl -sSL -o /dev/null -w '%{url_effective}\n' \
  'https://patchwork.kernel.org/project/bluetooth/patch/<message-id>/mbox/'
```

A `/user/login/` URL back means the bot still cannot fetch patches.

## Patchwork decides the order your series is applied in

Patchwork normally numbers a series from the `n/m` in each subject, and gets it
right even when the mails arrive out of order. The 2026-09-08
`le-connect-on-air-addr` series is a counterexample: series 1160052 lists
`[2/2]` before `[1/2]`, which is the order the mails arrived in.

That order is what the CI applies and what a maintainer pulls. These two
patches happen to touch disjoint files, so `git am` survives it, but the first
commit then uses a struct member the second one adds — a build break at the
first commit and a broken bisect.

Check it after every post; it costs one request:

```sh
curl -s 'https://patchwork.kernel.org/api/1.2/series/<sid>/' | python3 -c \
  'import json,sys; [print(p["id"], p["name"]) for p in json.load(sys.stdin)["patches"]]'
```

Why patchwork mis-numbered that one is not pinned down. Two things separated it
from series that ordered correctly, and both are worth removing:

- The delivery order bore no relation to the send order. Four messages went
  into one SMTP session sequentially as cover-less fix, cover, `1/2`, `2/2`;
  kernel.org received `2/2` 23:21:26, `1/2` 23:21:34, the standalone fix
  23:24:13, and the cover last at 23:24:57. One SMTP session sending
  sequentially guarantees nothing about arrival; the relay reorders freely and
  can hold a message for minutes.
- The `Subject:` headers were folded onto a continuation line, because
  `git format-patch` wraps a long subject and the mailer passed it through.

Send the cover first and pause a few seconds between messages so the relay has
no room to reorder, or use `b4 send --use-web-endpoint`, which posts straight
into public-inbox and never touches a relay.

## Reading lore from a script

The lore web UI sits behind Anubis and returns a 403 bot interstitial to
fetchers, `curl` and agent web tools alike. The Atom and mbox endpoints are
not gated:

```sh
curl -A 'git/2.47' 'https://lore.kernel.org/linux-bluetooth/?q=f:you@example.com&x=A'
curl -A 'git/2.47' 'https://lore.kernel.org/linux-bluetooth/<message-id>/t.mbox.gz'
```

Indexing lags acceptance by a few minutes. A thread missing right after a send
means propagation, not rejection.

Other mirrors, and what they are good for:

- `patchwork.kernel.org` REST API: reliable, structured, the CI verdict.
- `bugzilla.kernel.org` REST API: reliable.
- `marc.info` full-text: matching is loose and OR-ish, so a zero-hit result
  there is weak evidence of anything.

## Known flakes

These fail on unrelated grounds and have not blocked acceptance. Chasing them
wastes a session:

- `mgmt-tester` "Read Exp Feature", 1 of 501.
- `mesh-tester` "Send cancel" 1 and 2, timeouts.

## Collecting review trailers

When reviewers reply with `Reviewed-by:`, `Acked-by:` or `Tested-by:`, pull
them out of the list and onto the commits rather than retyping them:

```sh
b4 trailers -u
```

It matches replies to the series by Message-ID and rewrites the commits in
place, so run it on the submission branch and re-check the mirror afterwards.

## Rerolling to v2

`b4 send` already bumped the series revision when it sent v1, so the next send
goes out as v2 on its own. Before it does:

```sh
b4 prep --edit-cover        # add the "Changes in v2" block
b4 prep --compare-to v1     # range-diff against what you actually sent
```

Then run the whole send flow again from the rebase. A mangled patch, a stale
base, and review feedback all mean a new posting rather than a reply.

`b4 prep --show-revision` says which revision you are on, and
`b4 send --resend vN` retransmits a version that was lost in the post.

## Saying thanks

When a series lands, `b4 ty -l` lists what is ready to be thanked for and
`b4 ty -s <n>` writes the reply.
