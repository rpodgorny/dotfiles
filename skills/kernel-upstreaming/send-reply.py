#!/usr/bin/env python3
"""Send one plain-text reply file (headers, blank line, body) over SMTP.

The body is passed through byte for byte; only From/Date/Message-ID are
added. Threading headers already in the file are preserved, which is the
whole reason this exists: b4 sends series, not replies, and send-patches.py
drops In-Reply-To/References to build its own thread.
"""
import argparse, email.utils, os, smtplib, ssl, subprocess, sys
from urllib.parse import unquote, urlsplit

def git_config(key, default=None):
    r = subprocess.run(['git', 'config', '--get', key], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else default

def credentials(server, user):
    path = os.path.expanduser('~/.git-credentials')
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            u = urlsplit(line)
            if u.hostname == server and unquote(u.username or '') == user:
                return unquote(u.password or '')
    sys.exit('no credential for %s / %s in ~/.git-credentials' % (server, user))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('file')
    ap.add_argument('--from', dest='sender')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--reflect', action='store_true',
                    help='deliver only to the sender, real To/Cc headers kept')
    a = ap.parse_args()

    sender = a.sender or '%s <%s>' % (git_config('user.name'), git_config('user.email'))
    server = git_config('sendemail.smtpServer')
    port = int(git_config('sendemail.smtpServerPort', '587'))
    user = git_config('sendemail.smtpUser')

    raw = open(a.file, 'rb').read()
    head, _, body = raw.partition(b'\n\n')
    lines = head.split(b'\n')

    # recipients from the file's own To:/Cc: (continuation lines included)
    rcpts, cur = [], None
    for ln in lines:
        if ln[:1] in (b' ', b'\t') and cur:
            cur += b' ' + ln.strip()
            continue
        if cur:
            rcpts += [x.strip() for x in cur.split(b':', 1)[1].split(b',') if x.strip()]
            cur = None
        if ln.lower().startswith((b'to:', b'cc:')):
            cur = ln
    if cur:
        rcpts += [x.strip() for x in cur.split(b':', 1)[1].split(b',') if x.strip()]
    rcpts = [r.decode().split('<')[-1].rstrip('>').strip() for r in rcpts]

    msgid = email.utils.make_msgid(domain=sender.split('@')[-1].rstrip('>'))
    out = [b'From: ' + sender.encode(),
           b'Date: ' + email.utils.formatdate(localtime=True).encode(),
           b'Message-ID: ' + msgid.encode(),
           b'MIME-Version: 1.0',
           b'Content-Type: text/plain; charset="utf-8"',
           b'Content-Transfer-Encoding: 8bit'] + lines
    msg = b'\r\n'.join(out) + b'\r\n\r\n' + body.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')

    envelope = [git_config('user.email')] if a.reflect else rcpts
    print('From:      %s' % sender)
    print('Envelope:  %s' % ', '.join(envelope))
    print('Headers To/Cc: %s' % ', '.join(rcpts))
    print('Message-ID: %s' % msgid)
    print('Bytes: %d' % len(msg))
    if a.dry_run:
        print('--- DRY RUN, nothing sent ---')
        sys.stdout.write(msg.decode().replace('\r\n', '\n'))
        return

    pw = credentials(server, user)
    s = smtplib.SMTP(server, port, timeout=30)
    s.ehlo(); s.starttls(context=ssl.create_default_context()); s.ehlo()
    s.login(user, pw)
    s.sendmail(git_config('user.email'), envelope, msg)
    s.quit()
    print('SENT%s' % (' (REFLECT: delivered only to you)' if a.reflect else ''))

main()
