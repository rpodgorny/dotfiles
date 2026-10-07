# Deploy loop for a target

There is more than one target. The loop below is the same everywhere; what
changes per target is the column in the table. Establish the column before
deploying, and never assume the last target's values.

## Targets

Each target needs: the shell you reach it through, the HA host with its unit
name and config path, the host the hardware hangs off, and how files get across.

| | hajenka | bydlicoin (the van) |
|---|---|---|
| **HA host** | rpi400, rootful podman, container `hass_hajenka`, unit `hass-hajenka`, config `/docker_volumes/hass_hajenka` → `/config` | Arch aarch64, rootful podman, container `hass_bydlicoin`, unit `hass-bydlicoin`, config `/docker_volumes/hass_bydlicoin` → `/config`. Restart ~25 s |
| **Hardware** | pokuston, a separate box: USB M-Bus master on `/dev/ttyUSB0`. 423 MB RAM, no swap, install nothing on it | Truma iNet X panel `50:98:93:FF:B4:D1`, a **public** address, bonded to hci0 (built-in bcm43438). hci1 is a TP-Link UB500; it and the ESP32 proxy are `disabled_by: user` on purpose — see the note below |
| **Shells** | tmux sessions `rpi400` and `mbus`; no direct ssh from the workstation to either | a root shell in one window of the working tmux session; ssh by name does not resolve and key auth to `bydlicoin.podgorny.cz` is refused |
| **Transfer** | push, chunked base64 through the tmux pane | same; a public HTTP drop is refused by the sandbox classifier, so do not plan on the pull route |

**Never re-enable a disabled adapter entry to make a target work.** On the van
the proxy and the USB dongle are disabled deliberately: a local adapter is a
configuration `hass-truma-inetx` is meant to support, so a failure there is a
bug to diagnose, not a setup to correct. Ask before touching that config.

Add a column when you work on a target that has none, and keep site-specific
detail there rather than in the prose below. If the target has a shell only
inside a tmux session, `tmux ls` is the first command of the session, because
the sessions that exist are the access you have, and a window already running
something is not a window to type into. Otherwise use ssh and ignore every tmux
instruction here.

## Getting files there

Two shapes, picked by what the target can reach:

- **Push through a tmux pane** when there is no ssh and no route in. Chunked
  base64, below.
- **Let the target pull** when it can reach your machine over the network. One
  command each side, no chunking, and it works in either direction — run the
  server on whichever end holds the file.

```bash
# workstation, in the directory holding the tarball
pgrep -f "http.server 8899" >/dev/null || \
  (nohup python3 -m http.server 8899 --bind :: > /tmp/srv.log 2>&1 &)

# target
curl -fsS -o /tmp/mb.tgz http://duo.podgorny.cz:8899/mb.tgz && md5sum /tmp/mb.tgz
```

`--bind ::` is not optional when either host resolves to public IPv6 only, and
a v6 address is often the only reason an inbound connection works at all — a
target behind CGNAT has no reachable IPv4. Compare the md5 against the local
file every time. The guard on the server matters more than it looks: a second
`http.server` on a bound port dies quietly and the next `curl` serves the
previous run's file.

### Push through a tmux pane

No scp. Pipe a tarball through the tmux pane as chunked base64 — chunks must
stay well under the tty line limit. Three things about driving a pane this way:
`capture-pane` returns only the visible screen and scrollback, so a `clear` in
the command destroys the evidence; long output goes to a file on the target and
is read back in pieces; and a long-running loop piped through `tail` buffers
until it exits, so poll a file instead.

Two more that cost time on the van. Redirect *every* command to a per-run file
and read that back bounded: one long line (a single HA log entry listing every
integration, a BlueZ cache of thousands of MACs) pushes the start marker out of
the scrollback and the result cannot be recovered at all — and a fixed output
filename makes `cat` of it truncate the very file being read. And send commands
as **one line joined with `;`**: a multi-line `{ ... }` block sent in a single
`send-keys` can hang the pane mid-block, needing a `C-c` to get the prompt back.

```bash
tar czf mb.tgz -C <repo>/custom_components <domain>
base64 -w0 mb.tgz > mb.b64 && split -b 800 -d -a 3 mb.b64 chunk_
tmux send-keys -t <pane> 'rm -f /tmp/mb.b64' Enter
for f in chunk_*; do
  tmux send-keys -t <pane> "printf '%s' '$(cat $f)' >> /tmp/mb.b64" Enter; sleep 0.3
done
```

`<pane>`, `<config>`, `<unit>` and `<container>` below come from the target's
column. Filling them from memory is how code lands in the other site's config
directory. Decode on the far side and **compare sha256 against the local
file** — this has never silently corrupted, but it is one `grep -c` to prove.

```bash
sudo rm -rf <config>/custom_components/<domain>
sudo tar xzf /tmp/mb.tgz -C <config>/custom_components
sudo systemctl restart <unit>
```

Restart takes ~60 s (the unit stops the container with `-t 60` so the recorder
can flush). Then check:

```bash
sudo grep -i <domain> <config>/home-assistant.log | grep -icE "error|traceback"
```

Zero is the pass. `We found a custom integration <domain> which has not been
tested` is the normal load message, not a problem.

## Bridging the hardware

Test protocol code on a real machine and keep the target dumb: bridge the serial
port over TCP rather than installing a toolchain on it. That box OOM-kills a
`pip install` after ten minutes.

pokuston has no socat and no ser2net, and `pacman -Sy` on Arch is
partial-upgrade territory on a box that small. Use a stdlib-only python bridge
(`termios` for 2400 8E1, one client at a time) dropped in `/tmp` and run under
`nohup`. It survives disconnect but **not a reboot** — nothing restarts it.

## Long jobs must outlive the shell

A shell over a flaky uplink drops, and mosh over a mobile link drops often.
Anything longer than a few seconds runs under its own transient unit, not in the
pane:

```bash
systemd-run --unit=<name> --collect /root/<script>.sh
systemctl is-active <name>          # and later: journalctl -u <name>
```

`--collect` clears the unit when it exits, so the same name is reusable on the
next attempt instead of failing as already-loaded.

## Verifying without the UI

Config entries cannot be created from a shell without an auth token, so the
user drives the UI. Everything else is inspectable:

```bash
# the protocol module runs standalone inside the container
sudo podman exec <container> python /config/custom_components/<domain>/api.py <args>

# what actually got created
sudo python3 -c "import json; from collections import Counter; \
  e=json.load(open('<config>/.storage/core.entity_registry'))['data']['entities']; \
  m=[x for x in e if x['platform']=='<domain>']; print(len(m), Counter(x['original_device_class'] for x in m))"
```

Parse a **captured frame** rather than reading live hardware when checking
decode logic in the container — a second reader contends with the coordinator
for the port.

**Stop HA before any bus test that needs exclusive access**, and tell the user,
because it leaves a gap in their history.

## Ask the recorder what went stale, and when

Faster than grepping the log, and it works for any integration. Query
`states` joined to `states_meta` for `MAX(last_updated_ts)` per entity, sorted
ascending, and print anything older than an hour:

```python
# podman exec -i <ha> python3 -   (open READ-ONLY: a diagnostic must never
# corrupt live history)
c = sqlite3.connect('file:/config/home-assistant_v2.db?mode=ro', uri=True)
q = """SELECT sm.entity_id, MAX(s.last_updated_ts) t
       FROM states s JOIN states_meta sm ON s.metadata_id = sm.metadata_id
       GROUP BY sm.entity_id ORDER BY t"""
```

The timestamps are the diagnosis: entities dying *together* means one cause,
minutes apart means several. This is also how you tell "the integration is
broken" from "one device fell off" without touching the UI.

Same query with `WHERE sm.entity_id LIKE '%<domain>%'` answers "is my
integration writing at all", and the row **count** per entity shows whether a
sensor is updating or merely present.

## Validating `configuration.yaml`

`yaml.safe_load` **cannot** parse HA config — it dies on the `!include` tag and
reports a syntax error that does not exist. Use HA's own checker:

```bash
podman exec <ha> python -m homeassistant --script check_config -c /config
```

Exit 0 is the pass. Related trap: removing every entry under `logger:` →
`logs:` leaves a childless `logs:` key, which the logger schema rejects and
which stops HA loading. Collapse the whole block to `logger:` +
`  default: info` instead.
