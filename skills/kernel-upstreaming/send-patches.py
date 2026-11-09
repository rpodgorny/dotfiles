#!/usr/bin/env python3
"""Mail `git format-patch` output to a kernel list without touching the bodies.

Every patch body is passed through byte for byte. Only envelope headers are
rewritten, and LF becomes CRLF because SMTP requires it. Each assembled
message is compared against its source file before anything is sent; a
mismatch aborts the whole run.

That is the entire point of this script. A mail client that reflows a body,
converts a tab, or eats a trailing space produces "error: corrupt patch at
line N" from the list CI, and the patch is ignored until it is resent.

Credentials come from ~/.git-credentials, the file git's `store` helper
reads, matched on the SMTP host. The password is never printed.

  send-patches.py --dry-run out/0001-*.patch
  send-patches.py --to 'A B <a@b.org>' --cc list@vger.kernel.org out/*.patch

With no --to/--cc, recipients come from sendemail.to / sendemail.cc in git
config. The first file is the thread root and every later file replies to it
flat, which is what --no-chain-reply-to gives you in git send-email.
"""
import argparse
import os
import re
import smtplib
import ssl
import subprocess
import sys
import time
from urllib.parse import unquote, urlsplit

DROP = {b'to:', b'cc:', b'date:', b'message-id:',
        b'in-reply-to:', b'references:'}


def git_config(key, default=None):
    r = subprocess.run(['git', 'config', '--get', key],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else default


def git_config_all(key):
    r = subprocess.run(['git', 'config', '--get-all', key],
                       capture_output=True, text=True)
    return [l for l in r.stdout.splitlines() if l.strip()] if r.returncode == 0 else []


def addr_only(s):
    return s.split('<')[-1].rstrip('>').strip()


def credentials(server, user, password_env):
    if password_env:
        pw = os.environ.get(password_env)
        if not pw:
            sys.exit('%s is not set in the environment' % password_env)
        return user, pw

    path = os.path.expanduser('~/.git-credentials')
    found = []
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line.startswith('smtp'):
                    continue
                u = urlsplit(line)
                if u.username and u.password:
                    found.append((u.hostname, unquote(u.username),
                                  unquote(u.password)))
    for host, u, pw in found:
        if host == server:
            return u, pw
    if found:
        print('note: no credential for %s, using the entry for %s'
              % (server, found[0][0]))
        return found[0][1], found[0][2]

    import getpass
    return user, getpass.getpass('SMTP password for %s: ' % user)


def split_patch(path):
    """(kept header lines, body bytes), with the mbox 'From <sha>' line gone."""
    raw = open(path, 'rb').read()
    head, sep, body = raw.partition(b'\n\n')
    if not sep:
        sys.exit('%s has no header/body separator' % path)
    lines = head.split(b'\n')
    if lines and lines[0].startswith(b'From ') and b'@' not in lines[0]:
        lines = lines[1:]

    kept = []
    for ln in lines:
        if ln[:1] in (b' ', b'\t') and kept:
            if kept[-1] is not None:            # continuation of a kept header
                kept.append(ln)
            continue                            # continuation of a dropped one
        name = ln.split(b':', 1)[0].lower() + b':'
        kept.append(None if name in DROP else ln)
    return [l for l in kept if l is not None], body


def body_cc(body):
    """Cc: trailers in the commit message, the way git send-email picks them up."""
    out = []
    for line in body.split(b'\n'):
        if line.startswith(b'---'):             # start of the diffstat
            break
        m = re.match(rb'^Cc:\s*(.+?)\s*$', line)
        if m:
            out.append(m.group(1).decode())
    return out


def build(path, sender, to, cc, msgid, in_reply_to, thread_root, use_body_cc):
    hdrs, body = split_patch(path)
    cc = list(cc)
    if use_body_cc:
        for a in body_cc(body):
            if addr_only(a) not in {addr_only(c) for c in cc}:
                cc.append(a)

    out = list(hdrs)
    out.append(b'To: ' + b',\n\t'.join(t.encode() for t in to))
    if cc:
        out.append(b'Cc: ' + b',\n\t'.join(c.encode() for c in cc))
    out.append(b'Date: ' + time.strftime('%a, %d %b %Y %H:%M:%S %z').encode())
    out.append(b'Message-ID: <' + msgid.encode() + b'>')
    if in_reply_to:
        out.append(b'In-Reply-To: <' + in_reply_to.encode() + b'>')
        out.append(b'References: <' + thread_root.encode() + b'>')
    out.append(b'MIME-Version: 1.0')
    out.append(b'Content-Transfer-Encoding: 8bit')
    out.append(b'X-Mailer: send-patches.py (format-patch body verbatim)')

    msg = b'\n'.join(out) + b'\n\n' + body
    crlf = msg.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')

    sent_body = crlf.partition(b'\r\n\r\n')[2]
    want = body.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    if sent_body != want:
        sys.exit('body would be altered for %s, refusing to send' % path)

    rcpt = sorted({addr_only(a) for a in to + cc} | {addr_only(sender)})
    return crlf, rcpt, cc


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('patches', nargs='+')
    ap.add_argument('--to', action='append', default=[])
    ap.add_argument('--cc', action='append', default=[])
    ap.add_argument('--from', dest='sender')
    ap.add_argument('--server')
    ap.add_argument('--port', type=int)
    ap.add_argument('--password-env', metavar='VAR',
                    help='read the password from this environment variable')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--no-body-cc', action='store_true',
                    help='ignore Cc: trailers in the commit messages')
    ap.add_argument('--no-thread', action='store_true',
                    help='send each patch as its own thread')
    a = ap.parse_args()

    sender = a.sender or '%s <%s>' % (git_config('user.name'),
                                      git_config('user.email'))
    server = a.server or git_config('sendemail.smtpserver')
    port = a.port or int(git_config('sendemail.smtpserverport', '587'))
    user = git_config('sendemail.smtpuser') or addr_only(sender)
    to = a.to or git_config_all('sendemail.to')
    cc = a.cc or git_config_all('sendemail.cc')

    if not server:
        sys.exit('no SMTP server: pass --server or set sendemail.smtpServer')
    if not to:
        sys.exit('no recipients: pass --to or set sendemail.to')

    stamp, pid = time.strftime('%Y%m%d%H%M%S'), os.getpid()
    domain = addr_only(sender).split('@')[-1]
    built, root = [], None
    for i, path in enumerate(a.patches):
        msgid = '%s.%d-%d-%s@%s' % (stamp, pid, i + 1, addr_only(sender).split('@')[0], domain)
        if i == 0:
            root = msgid
        irt = None if (i == 0 or a.no_thread) else root
        msg, rcpt, full_cc = build(path, sender, to, cc, msgid, irt, root,
                                   not a.no_body_cc)
        built.append((os.path.basename(path), msg, rcpt))

    for name, msg, rcpt in built:
        head = msg.partition(b'\r\n\r\n')[0].decode()
        print('=' * 72)
        print(name)
        show = False
        for l in head.split('\r\n'):
            if l[:1] not in (' ', '\t'):
                show = l.lower().startswith(
                    ('subject:', 'message-id:', 'in-reply-to:'))
            if show:
                print(' ', l)
        print('  rcpt:', ', '.join(rcpt))

    if a.dry_run:
        print('\ndry run, nothing sent')
        return

    u, pw = credentials(server, user, a.password_env)
    s = smtplib.SMTP(server, port, timeout=60)
    s.ehlo()
    s.starttls(context=ssl.create_default_context())
    s.ehlo()
    s.login(u, pw)
    for name, msg, rcpt in built:
        s.sendmail(addr_only(sender), rcpt, msg,
                   mail_options=['BODY=8BITMIME'])
        print('sent:', name)
        sys.stdout.flush()
    s.quit()


main()
