---
name: kernel-upstreaming
description: >
  Send Linux kernel patches to a subsystem mailing list with b4 and track what
  happens to them: enroll the branch, cover letter, auto-to-cc, checkpatch,
  send, then collect review trailers and reroll to v2. Covers AI-assistance
  trailers, keeping a submission branch and a deployed branch in sync, and
  reading the CI verdict on lore and patchwork. Use when posting, resending or
  revising a kernel patch or series, when chasing a patch already posted, when
  choosing stable tags or asking stable to take a commit, or when touching
  branches that carry patches meant for upstream.
---

# Kernel upstreaming

## Start with the tree's own notes

`MY_UPSTREAMING.md` at the root of the kernel tree holds that tree's state:
branch tips, remotes, recipients, and facts already established about the
hardware and the subsystem. It is untracked and listed in
`.git/info/exclude`. Read it before touching a branch, and update it whenever
what you do changes it.

This skill is the process. That file is the state. Keep each where it belongs.

## b4 runs the submission

[`b4`](https://b4.docs.kernel.org/) is kernel.org's own contributor tool and
does the whole send side: recipients from MAINTAINERS, per-patch checkpatch,
`base-commit` and `change-id` in the cover, threading, cryptographic
attestation, version rerolling, and pulling review trailers back into the
tree. Arch packages it as `b4`.

### One-time repo setup

```sh
git config b4.prep-cover-strategy branch-description
git config b4.prep-perpatch-check-cmd \
  "$(git rev-parse --show-toplevel)/scripts/checkpatch.pl -q --terse --no-summary --mailback --showfile --strict"
```

The cover strategy matters. b4's default, `commit`, stores the cover letter in
an empty commit at the head of the series, which changes the branch tip and
breaks any mirror of that branch. `branch-description` keeps it in the git
branch description, so the commits stay byte-identical to their mirror.

The check command matters because b4's built-in default omits `--strict`, and
the bar here is 0 errors, 0 warnings, 0 checks.

### The flow

**1. Rebase onto the maintainer tree.** `git fetch <remote>`, then rebase the
submission branch onto its HEAD. The list CI applies against live HEAD and
rejects whatever fails to apply, so a rebase from last week is worth nothing.
Check what moved underneath you first:

```sh
git log --oneline <old-base>..<remote>/master -- <the files you touch>
```

Empty output means the rebase is mechanical. Otherwise read those commits
before resolving anything.

**2. Enroll the branch.** Once per branch:

```sh
b4 prep --enroll <remote>/master
```

The branch name ends up inside every Message-ID and goes public with the post.
Name it after the topic.

**3. Write the cover letter.** `b4 prep --edit-cover`. Keep the prose in a file
in the tree as well, so a resend does not rewrite it from memory. A cover
letter earns its place by saying what the series does not establish: which
branches were measured on which hardware, and which are argued rather than
tested. `generated-content.rst` also wants a paragraph naming the tooling and
summarising the prompts.

**4. Recipients.** `b4 prep --auto-to-cc` reads MAINTAINERS and the commits'
own tags, so it picks up people a plain `get_maintainer.pl` run misses, the
author of a `Fixes:` commit among them. Review what it added and trim with
`b4 prep --edit-cover`.

**5. Check.** `b4 prep --check`. Every patch green.

**6. Build the subsystem.** b4 does not build. Build into a directory outside
the tree, which also keeps object files out of a synced or backed-up working
copy:

```sh
make O=<builddir> defconfig
./scripts/config --file <builddir>/.config -e <SUBSYSTEM_CONFIG>
make O=<builddir> olddefconfig
make O=<builddir> -j$(nproc) <subsystem/dir>/
```

Build every branch you are about to send, one at a time. Done when the touched
directory compiles with no new warnings.

**7. Look at what will go out.** `b4 send -o <dir>` writes the assembled `.eml`
files and sends nothing. Read the headers: threading, To/Cc, `base-commit`,
and that the trailers survived. `b4 send --reflect` goes one better and mails
the whole thing to you alone with the real To/Cc headers in place, which is
how you catch encoding damage before the list does.

**8. Send.** `b4 send`. It tags the sent revision and rerolls the series to the
next version by itself.

**9. Record what went out.** Put the root Message-ID of each submission into
`MY_UPSTREAMING.md` with the base commit and the date. That is what a resend,
a v2, or a "did this ever land" question starts from.

Send each submission separately when the patches are separate topics. A
standalone fix and a two-patch series are two branches and two threads.

## b4's cover template fails GitLint on a single-patch series

`b4`'s built-in cover template ends with sigdashes written as `--` followed by
**two** spaces (`b4/ez.py`, `DEFAULT_COVER_TEMPLATE`). Two spaces is not the
standard email signature marker, so nothing downstream treats it as one: the
line is linted like ordinary body text and GitLint fails the patch with
`B2 Line has trailing whitespace: "--  "`.

A multi-patch series hides this, because the block only reaches the cover
letter and covers are not linted. A **single-patch** series does not: b4 mixes
the cover into the patch itself, and the bad marker rides along.

There is no config key for the signature (`b4.send-signature` is not a real b4
setting). Override the whole template instead:

```sh
git config b4.prep-cover-template ~/.claude/skills/kernel-upstreaming/b4-cover-template.txt
```

`b4-cover-template.txt`, next to this file, is byte-identical to b4's default
except that the marker is `-- ` (one space) and the `Best regards,` line above
it is gone.

Keep the rest of the template exactly as b4 wrote it. `mixin_cover()` splits
the basement on `^---$` and drops any section matching its diffstat regex, so
gluing `${diffstat}` onto the following `---` silently deletes the
`base-commit:` and `change-id:` lines from the sent patch. Check for both in
the `b4 send -o` output before sending.

## Trailers

Policy lives in `Documentation/process/coding-assistants.rst` and
`Documentation/process/generated-content.rst`, both in the tree. Read them
when anything below is in doubt.

An assistant's contribution is recorded with one tag, directly above the final
`Signed-off-by:` with no blank line between:

```
Assisted-by: Claude:claude-opus-5
Signed-off-by: Radek Podgorny <radek@podgorny.cz>
```

Only a human signs off; `Signed-off-by:` certifies the DCO and belongs to the
person sending. `Co-authored-by:` is a non-standard signature that checkpatch
flags. `Co-developed-by:` requires a matching `Signed-off-by:` from that
party, which an assistant cannot give.

Write the bare model name. Brackets in `AGENT:MODEL [TOOL]` are reserved for
the optional tool list, so a model id that itself contains brackets, like
`claude-opus-5[1m]`, is misparsed. List tools only where they did something
beyond ordinary development; git, make, grep and checkpatch are basic
development tools and go unlisted.

## Signing and transport

b4 signs every message with [patatt](https://pypi.org/project/patatt/) and
refuses to send without a key. Set one up once:

```sh
patatt genkey            # prints the [patatt] block to add to ~/.gitconfig
```

Then publish the public half in the kernel.org keyring so the attestation
verifies for other people. `b4 send --no-sign` skips signing when the key is
not ready yet.

Two ways out to the list:

- **The web endpoint**, `b4 send --use-web-endpoint`, with
  `b4.send-endpoint-web = https://lkml.kernel.org/_b4_submit`. Authenticate
  once with `b4 send --web-auth-new`, then `b4 send --web-auth-verify <token>`
  from the mail you receive. This needs no SMTP account at all and lands in
  public-inbox immediately, which is the path to reach for when SMTP is the
  thing fighting you.
- **SMTP**, using git's own `sendemail.smtpServer`, `sendemail.smtpServerPort`,
  `sendemail.smtpEncryption` and `sendemail.smtpUser`. Keeps your `From:` and
  gets domain DKIM.

Confirm an SMTP endpoint by connecting to it rather than inferring it from MX
records. MX names the inbound exchanger, and the submission host is usually
somewhere else entirely:

```sh
python3 -c "import smtplib;s=smtplib.SMTP('<host>',587,timeout=15);print(s.ehlo()[1].decode());s.starttls();print(s.ehlo()[1].decode())"
```

Passwords belong in `~/.git-credentials`, mode 0600, read by git's `store`
helper. The entry is a URL, so it must name the host you actually connect to,
with `@` in the username percent-encoded:
`smtp://user%40example.com:<password>@smtp.example.com:587`.

`git send-email` also needs the Perl modules `IO::Socket::SSL`, `Net::SSLeay`
and `Authen::SASL`; without the first two it dies with "Unable to initialize
SMTP properly" before it authenticates. On Arch:
`sudo pacman -S --needed perl-io-socket-ssl perl-net-ssleay perl-authen-sasl`.

## Fallback mailer

`send-patches.py`, next to this file, mails `git format-patch` output over
SMTP with nothing but the Python standard library. It rewrites only envelope
headers, converts LF to CRLF, passes every body through **verbatim**, and
compares each assembled message against its source file before opening the
connection.

Reach for it when b4 cannot run: no patatt key and no web auth, a machine
without b4, or a set of `.patch` files that never came from a b4-tracked
branch.

```sh
python3 ~/.claude/skills/kernel-upstreaming/send-patches.py --dry-run \
  --to 'Marcel Holtmann <marcel@holtmann.org>' \
  --cc linux-bluetooth@vger.kernel.org \
  <outdir>/*.patch
```

The first file is the thread root and every later file replies to it flat, so
pass the cover letter first. Sending sequentially over one SMTP session is not
enough to fix the order the list sees: a relay can spread the messages over
minutes and deliver them out of order, and patchwork has ordered a series by
arrival because of it. Pause between messages, keep the cover first, and verify
the series order in patchwork afterwards. `Cc:` trailers in a commit message become real
recipients, which is how `Cc: stable@vger.kernel.org` reaches stable;
`--no-body-cc` turns that off. Host, port, user and recipients default to the
`sendemail.*` git config. `--password-env VAR` reads the password from the
environment instead of `~/.git-credentials`.

## Replying to a reviewer

b4 sends series, not replies, and `send-patches.py` drops
`In-Reply-To`/`References` to build its own thread, so neither can answer a
review mail. `send-reply.py`, next to this file, sends one plain-text file
whose own headers carry the threading:

```sh
python3 ~/.claude/skills/kernel-upstreaming/send-reply.py --dry-run reply.txt
python3 ~/.claude/skills/kernel-upstreaming/send-reply.py --reflect reply.txt
python3 ~/.claude/skills/kernel-upstreaming/send-reply.py reply.txt
```

The file is `To:`/`Cc:`/`Subject:`/`In-Reply-To:`/`References:`, a blank
line, then the body. Recipients come from its own To/Cc; From, Date and
Message-ID are added. `--reflect` delivers only to you with the real headers
intact, the same safety net as `b4 send --reflect`. Put your own address on the
Cc when you want a copy, since nothing adds it for you.

Take `In-Reply-To` from the mail being answered and make `References` the
whole chain that led to it. Send the reply *before* the new revision, with a
pause, so the relay cannot deliver them out of order.

## After sending

Read [`references/tracking.md`](references/tracking.md) for where the
**verdict** lands, collecting review trailers with `b4 trailers -u`, rerolling
to v2, and which test failures are known flakes worth ignoring.

Two things there are worth knowing before the first CI mail arrives:

- A `pre-ci_am` failure mail with an **empty** `----- Output -----` section is
  the bot failing to fetch your patch, not your patch failing to apply. Triage
  it before resending anything; a resend fails the same way.
- Patchwork, not your `From:` header, decides the order the series is applied
  in. Check it after every post.

## Stable

Read [`references/stable.md`](references/stable.md) before posting a patch that
fixes a bug or belongs to a series with dependencies, before any mail to
stable@vger.kernel.org, and when checking whether a commit was queued or released.
It covers choosing tags at posting time, the half-backport AUTOSEL can create, and
what a stable request must contain to get an answer on the first try.

## Branches that carry patches

Read [`references/branch-discipline.md`](references/branch-discipline.md)
before creating, rebasing or force-updating any branch in a tree that has
patches in flight. It covers the naming rules, keeping a submission branch and
a deployed branch in sync, and the patch-id check that proves they still
match.
