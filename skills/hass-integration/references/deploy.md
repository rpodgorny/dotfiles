# Test rig and deploy loop

## The rig

| Host | Role |
|---|---|
| **rpi400** | Home Assistant, rootful podman, unit `hass-hajenka`, config at `/docker_volumes/hass_hajenka` → `/config` in the container |
| **pokuston** | Raspberry Pi with the hardware attached (USB M-Bus master on `/dev/ttyUSB0`). 423 MB RAM, no swap — do not install anything on it |

**There is no direct ssh from the workstation to either.** Shells are tmux
sessions (`rpi400`, `mbus` for pokuston); check `tmux ls` for what exists.

## Getting files there

No scp. Pipe a tarball through the tmux pane as chunked base64 — chunks must
stay well under the tty line limit:

```bash
tar czf mb.tgz -C <repo>/custom_components <domain>
base64 -w0 mb.tgz > mb.b64 && split -b 800 -d -a 3 mb.b64 chunk_
tmux send-keys -t rpi400 'rm -f /tmp/mb.b64' Enter
for f in chunk_*; do
  tmux send-keys -t rpi400 "printf '%s' '$(cat $f)' >> /tmp/mb.b64" Enter; sleep 0.3
done
```

Then decode on the far side and **compare sha256 against the local file** —
this has never silently corrupted, but it is one `grep -c` to prove.

```bash
sudo rm -rf /docker_volumes/hass_hajenka/custom_components/<domain>
sudo tar xzf /tmp/mb.tgz -C /docker_volumes/hass_hajenka/custom_components
sudo systemctl restart hass-hajenka
```

Restart takes ~60 s (the unit stops the container with `-t 60` so the recorder
can flush). Then check:

```bash
sudo grep -i <domain> /docker_volumes/hass_hajenka/home-assistant.log | grep -icE "error|traceback"
```

Zero is the pass. `We found a custom integration <domain> which has not been
tested` is the normal load message, not a problem.

## Bridging the hardware

pokuston has no socat and no ser2net, and `pacman -Sy` on Arch is
partial-upgrade territory on a box that small. Use a stdlib-only python bridge
(`termios` for 2400 8E1, one client at a time) dropped in `/tmp` and run under
`nohup`. It survives disconnect but **not a reboot** — nothing restarts it.

## Verifying without the UI

Config entries cannot be created from a shell without an auth token, so the
user drives the UI. Everything else is inspectable:

```bash
# the protocol module runs standalone inside the container
sudo podman exec hass_hajenka python /config/custom_components/<domain>/api.py <args>

# what actually got created
sudo python3 -c "import json; from collections import Counter; \
  e=json.load(open('/docker_volumes/hass_hajenka/.storage/core.entity_registry'))['data']['entities']; \
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
