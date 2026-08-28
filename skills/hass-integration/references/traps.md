# Traps already paid for

Each of these cost real debugging time. All fail *silently* or look like a
different problem entirely.

## A blocking-import warning after a failed platform import is collateral

`Detected blocking call to import_module ... inside the event loop` next to a
platform that failed to import is **not** a second bug, and not a slow
dependency. Read the thread names in order:

```
ERROR   (ImportExecutor_0)  exception importing ...sensor   <- correct, off-loop
WARNING                     blocking call to import_module
ERROR   (MainThread)        exception importing ...sensor   <- the retry
```

HA imports platforms in the import executor (`import_executor` defaults to
true). A failed import is dropped from `sys.modules`, so the retry takes the
event-loop branch and trips the blocking detector. Fix the import error and the
warning goes with it.

Do **not** "fix" it by deferring a heavy third-party import into a function.
HA's guidance is that module-level imports are preferred precisely because it
arranges for them to happen off-loop; moving one inside a method relocates the
cost (measured: 128 ms for `cryptography`) from the executor into the live
event loop on first use. And an import reached from the integration's own
`__init__.py` is already loaded before any platform sees it.

## Source-inspecting a module means it is never executed

Where a table lives in a platform file that imports Home Assistant, the tests
read it as *source* rather than importing it. That catches a missing
translation key — and hides everything the interpreter would have caught. A
hand-rebuilt import list dropped one name used by a single row, and the suite,
hassfest and the HACS action all passed because **not one of them imports the
module**. On a live instance the failure is total: the platform raises at
import and the whole integration fails to set up.

Whenever the tests cannot import a module, add a static check that every name
it uses is imported or defined in it — a miniature pyflakes over the AST:

```python
bound = set(dir(builtins)) | {"__name__", "__file__", "annotations"}
# collect ImportFrom / Import / def / class / assignment / arg targets
used = {n.id for n in ast.walk(tree)
        if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
assert not (used - bound)
```

Moving code between modules is exactly when this bites, because that is when
the import list gets rewritten by hand.

## aiohttp quotes cookie values; some servers cannot read that

The hardest failure in this family to diagnose. `aiohttp` wraps cookie values
containing `+`, `/` or `=` in double quotes. Azure B2C's encrypted
`x-ms-cpim-*` cookies are full of those characters, so it fails to decrypt its
**own** cookie and answers the login POST with a bare `400 Bad Request` — no
error code, no message, nothing naming cookies. `requests` never quoted them,
which is the only reason a blocking version works where its async port does
not.

```python
aiohttp.ClientSession(cookie_jar=aiohttp.CookieJar(quote_cookie=False))
```

Suspect this whenever a `requests` → `aiohttp` port gets an unexplained 4xx on
a cookie-bearing request. Build the session inside the client, refuse one that
quotes, and pin it with a test — nothing else in the stack will say a word.

## aiohttp honours cookie paths; requests' jar lookup did not

`session.cookies.get("X")` searched every cookie regardless of path.
`cookie_jar.filter_cookies(URL)` returns only what *that URL* would send, so a
cookie scoped to `/Site/RemoteWeb/<uuid>/web` is invisible from the site root.
Filter at the URL the cookie belongs to, not at the origin.

## A cookie-based login must not share Home Assistant's session

`async_get_clientsession` is shared across integrations. A login that keeps its
state in cookies needs `async_create_clientsession`, or its auth cookies land in
the same jar as everything else's.

## Sleeping in an async client stalls the whole instance

A TOTP helper that waits for the next 30-second window is harmless behind
`async_add_executor_job` and catastrophic once the client is async: `time.sleep`
on the event loop freezes every other integration. Converting to async means
auditing every `time.sleep`, not only the I/O.

## The port has one owner

A coordinator holds its transport open for the life of the config entry.
Anything else that opens the same port gets:

- **serial device**: two masters garbling each other, half-working
- **serial-to-TCP bridge**: usually single-client, so the second connection is
  accepted into the backlog and never served — every read times out

Symptom seen: a reconfigure rescan reported **0 devices found** while the same
scan from a CLI found all 41. The give-away was on the bridge host:

```
ESTAB       ...:10001   # the coordinator, held open
CLOSE-WAIT  ...:10001   # the scan, 546 bytes stranded, never served
```

Fix: the config flow reuses `entry.runtime_data`'s transport object when the
entry is loaded (`ConfigEntryState.LOADED`), and the transport takes a lock per
*transaction* — not per method, or a ten-minute scan locks out polling.

## Translations do not reach the browser without a version bump

The frontend caches translations keyed by the integration's `version`. Editing
`strings.json` without bumping `manifest.json` leaves the old text on screen
forever; a hard reload does not clear it. Symptom: an edited progress message
still showing its previous wording after a full HA restart, while the file on
disk is provably new.

## `.storage` writes are debounced

Reading `.storage/core.entity_registry` right after a restart shows stale
device classes, icons and names for *minutes*. Do not conclude a change failed
from one fresh read — inspect a single entity, or wait and re-read. This
produced a false "the fix did not apply" once already.

## Do not trust a one-byte acknowledgement as a count

Specific to bus protocols with wildcard/broadcast addressing, and general in
shape. Where every matching device answers with the *same* byte:

- **colliding replies often still decode as one valid byte** — "got an ACK"
  means *at least one*, never *exactly one*. Believing it stops a search at a
  prefix still holding a dozen devices.
- **the same collision can decode as nothing** and look like an empty branch,
  pruning it. One bad probe lost nine devices at a stroke.
- **selection is sticky**: a failed select leaves the *previous* device
  selected, so the next request answers as that device, in a branch it does not
  belong to.

Fix: classify on the **large frame with a checksum**, not the small ack. Two
overlapping ~100-byte frames effectively never both pass CRC. Deselect before
each probe. Anything audible but undecodable is a collision, and only true
silence prunes. Add a contradiction check: a prefix that collided but yielded
no children is a lost probe, so re-walk it once with longer timeouts.

## A write can be acknowledged and then silently discarded

Where a protocol offers more than one way to write, devices routinely implement
only one — and answer the others with a perfectly valid acknowledgement.
NetKlima accepts Modbus function `0x10` (write multiple) and **acks and drops**
`0x06` (write single). The card moves, the log stays clean, the wire trace shows
a successful transaction, and the air conditioner never changes.

Worse than an error, because it survives code review and a packet capture.

Find it with a **read-back test that writes the value already there** — a no-op
on the hardware, so it is safe to run against a live system — through each
function code in turn, then read to see which one landed. Then hard-code the one
that works and leave *no code path* for the other, so it cannot be configured
wrong later. HA's built-in Modbus platform is the cautionary case: the right
function has to be selected per writable field through three differently-named
flags (`target_temp_write_registers`, a climate-level `write_registers`, and
wrapping an address in a list), and the default is the one that fails silently.

## Reconnect-on-failure must know whether it can reconnect

Closing the transport before a retry is correct for a real port: it clears the
half-open socket that a plain resend would keep talking into. It is fatal for
the injected transport this family's test pattern mandates — there is no recipe
to rebuild that one, so the first glitch kills the client permanently.

Track whether the client opened the transport itself, and only drop it when it
did. Caught by the test suite on the first simulated link glitch; it would have
reached hardware otherwise, and looked like a flaky bus.

## A sweep over a silent link must bail out early

Discovery terminates quickly only when "nothing here" and "nobody home" are
different answers. On a bus where an empty slot still *replies* — with an
"unknown" or "not read yet" status — silence means the link died, so count
consecutive transport failures and give up after a handful instead of serving
256 timeouts. Probing once before the sweep covers a link that was dead from the
start; this covers one that dies mid-sweep.

Note the corollary: if an empty slot and a not-yet-polled real device read
identically, discovery must union rather than replace.

## Read limits and write limits are different limits

"Write at most N registers, one device per write" says nothing about reads.
Batching reads was the difference between a 1.5-second scan and a 15-second one
on every single restart — but the device may still refuse a read that spans
record boundaries. Try the batch, fall back to per-record on any failure, and
test both paths, because in production only one of them ever runs.

## Discovery is never authoritative

However good it gets, ship an editable list before saving. Silently ending up
with a subset is worse than any amount of typing.

## Serial framing is not a preference

Get parity right or nothing answers at all, which looks exactly like a dead
bus. M-Bus is **2400 8E1** — even parity. `ser2net` spells it `2400e81`.

## pyserial gives you TCP for free

`serial_for_url("socket://host:port")` means a local port and a network bridge
are one code path. Do not write a transport class.

## Weak hardware bites during development

A 423 MB Raspberry Pi with no swap OOM-kills `pip install` after ten minutes.
Test protocol code on a real machine and keep the target dumb — bridge the
serial port over TCP rather than installing a toolchain on it.

## Unbounded retry buffers

The script this family of integrations replaced was OOM-killed because a failed
write kept its payload and retried forever, growing without limit. A
`DataUpdateCoordinator` gives you last-known-good for free: never accumulate,
never buffer, let the next poll be the retry.

## Validate the instrument before believing the measurement

A probe that returns nothing is not evidence until you have proved it can see
something known-good. Two real cases, hours apart:

- `btmgmt find` returned **0 devices on two healthy Bluetooth adapters**,
  because it asks for its own discovery session and Home Assistant already held
  one. Read naively, that says the hardware is dead.
- A `btmon` capture contained no device *names*, which "proved" a device
  broadcast none — until the obvious control was run: it contained no names for
  **any** device, including several that certainly advertise them. The capture
  was wrong, not the device.

Rule: every measurement carries a control. If the tool reports absence, point it
at something you know is present, in the same run. State the control in the
notes, because the next person will not repeat it.

## `disabled_by` lives in two registries

Enabling or disabling a device by editing `.storage` requires **both**
`core.config_entries` and `core.device_registry`. Setting only the config entry
leaves it enabled in that file and disabled in the UI ("The device is disabled
by config entry"), which looks like a working change and silently is not — it
invalidated a whole test round before anyone noticed.

Use the UI, which updates both. If you must edit offline, stop HA first (writes
are debounced anyway) and patch both files.

## A device your integration marked unavailable may never come back

Any consecutive-failure latch needs a route back that does not require an HA
restart. See `bluetooth.md`; the shape is general to anything with a "mark
unavailable after N failures" rule. Keep polling; clear on first success.

## A restart resets the counter, and the counter reframes the onset

Any failure counter that resets at startup makes a restart look like the cause.
Real case: a device's `polling failure #1` landed in the same second HA finished
restarting, so the restart got the blame. The rotated log showed the failures had
actually started **half an hour earlier**; the restart had only zeroed the count.

Two habits follow:

- Read the **rotated** log (`home-assistant.log.1`), not just the current one.
  HA truncates `home-assistant.log` on every start, so the evidence for anything
  that began before the restart is only in the rotated copy.
- When an incident brackets a restart, find the *first* failure in the previous
  instance before assigning cause.

## `RestartCount=0` does not mean Home Assistant did not restart

The official container image runs s6-overlay as PID 1, which supervises the HA
process — so **HA core can restart while the container never exits**. `podman
inspect --format '{{.RestartCount}}'` and `systemctl status` both stay clean
across it, and using them to rule out a restart is wrong.

What actually shows it:

```bash
journalctl -u <unit> | grep 'finish process exit code 100'   # 100 = HA asked to restart
ls -la <config>/home-assistant.log.1                          # rotated on every start
```
