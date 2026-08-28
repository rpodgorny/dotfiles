# BLE integrations

Everything here was paid for on `hass-truma-inetx` and on `renogy-ha` /
`renogy-ble`. BLE breaks assumptions that hold for every wired protocol: the
transport is chosen for you, it changes under you, and the device's identity
arrives in pieces that not every transport delivers.

## Never identify a device from advertisement data alone

Three independent ways this fails, all seen on real hardware:

**The name may live in the scan response, not the advertisement.** A passive
scan never sends `SCAN_REQ`, so it never sees it. The same device therefore has
a name on one transport and none on another, and HA falls back to the MAC —
`device.name` is then `14:9C:EF:03:68:81`. Any `name.startswith(...)` check
silently fails, and the error message names the MAC, which reads like a
different bug entirely.

**A manufacturer-data "company ID" can be per-device.** One Renogy battery
advertises company `0x9C14` — which is simply the first two bytes of its own
MAC (`14:9C:...`) read little-endian. The library hard-coded
`BATTERY_PRO_MANUFACTURER_ID = 0xE14C`, so that branch can never match that
unit. A constant that happens to work on the author's sample is not an ID.

**Advertising is not the same as being connectable.** A device can advertise
strongly and still refuse or fail every connection.

⇒ **Always fall back to the user-configured device type.** The config entry
already stores what the user picked; identification from the air is an
optimisation, not the source of truth. Without that fallback a device HA can
see becomes permanently unusable, and the log says only "unable to determine
variant".

## You do not choose the transport, and it changes

A device may be reachable through several scanners at once — local adapters and
any number of ESPHome Bluetooth proxies. **There is no per-device pinning**; no
`preferred_scanner`/`force_scanner` exists anywhere in `habluetooth` or the
`bluetooth` integration. HA scores every candidate path:

```
score = RSSI − (claimed RSSI advantage × previous_failures × 0.51)
```

Because the coefficient is 0.51, **two failures more than cancel any advantage,
however large**. Verified against logged scores: a path claiming +38 dB was
fully demoted by two failures.

Turn the arithmetic on with `logger: logs: habluetooth: debug`, which emits

```
<mac> - <name>: Found N connection path(s), preferred order: <scanner> (RSSI=..) (failures=..) (slots=../..) (score=..)
```

**What this means for integration code:** the same device may be served by a
proxy over WiFi one minute and a local radio the next, with completely
different latency. Do not tune timeouts to the path you happened to test on,
and do not assume connection cost is stable. `Found 1 connection path` where you
expected 2 means a scanner stopped hearing that device — worth logging.

## Failure state must not latch until the next HA restart

A library that marks a device unavailable after N consecutive failures needs a
path back that does **not** require restarting Home Assistant. Seen for real:
the radio recovered, the device advertised at −50 dBm, and the entity stayed
`unavailable` for 40 minutes until HA was restarted, because both the library's
consecutive-failure latch and the bluetooth manager's per-path failure counters
only reset at startup.

Keep polling a device you have marked unavailable, and clear the latch on the
first success.

## Resolvable private addresses rotate

BLE devices using RPAs change their address periodically. **Never key
`unique_id` on the MAC for those** — use whatever stable identity the protocol
exposes after connecting. HA resolves RPAs via the IRK, but your entity
registry entries must survive a rotation.

## Advertisement-only devices are a free diagnostic

Passive sensors (BTHome, ATC thermometers) need no connection; connectable
devices do. So:

- passive sensors updating, connectable ones failing ⇒ **connection layer**,
  not the radio, not range
- everything dead together ⇒ the adapter or the scanner is gone

That one distinction separates "the dongle went deaf" from "the integration
cannot connect" in about ten seconds, and it is the first thing to check.

## Adapters lie about their own health

`bluetoothctl show` reporting `Discovering: yes` proves nothing — a USB adapter
that has silently stopped delivering reports still says it. Twice in one day an
RTL8761B dongle reported `Discovering: yes` while returning zero advertisements
for hours.

If you need to check an adapter is really receiving, **`btmon -i hciN` is the
only honest probe**: it passively observes HCI traffic without competing for a
discovery session. `btmgmt find` requests its own session and returns **0
devices on a perfectly healthy adapter** while HA holds the scan — measured on
both adapters simultaneously.

Caveat that follows from it: `btmon` only sees reports while *something* is
scanning. Right after any adapter reset, HA has not resumed scanning yet, so a
healthy adapter reads 0. Never conclude "deaf" from a single sample taken just
after a reset.

## A healthy adapter is not a reachable device

These are different questions and the first does not answer the second. Real
case: a device was unreachable for 65 minutes while the adapter serving it
truthfully reported 20–50 advertising reports per 20 s — all from *other*
devices. A watchdog checking adapter health logged `OK` every two minutes
throughout, correctly.

The mechanism is a **half-open connection**: the adapter issues LE Create
Connection and never receives Connection Complete.

```
Failed to connect after 3 attempt(s): Timeout waiting for connect response
while connecting to <mac> after 20.0s, disconnect timed out: False
```

The peripheral now believes it *is* connected, so it stops advertising — **to
every receiver at once**, local adapters and proxies alike. That is the
confusing part: one adapter is at fault, but the device disappears from all of
them. Recognise it by:

- device vanishes from every scanner simultaneously while others are unaffected
- HA keeps one ghost path at `RSSI=-127` (the no-valid-RSSI sentinel, not a weak
  signal)
- every connection attempt times out rather than being refused
- `btmgmt --index N con` shows **nothing** — the host lost track of the link, the
  controller did not

Nothing heals it on its own:

- **Supervision timeout will not save you.** The 32 s spec cap applies to a
  *stale* link. One the local controller is still actively maintaining stays up
  indefinitely.
- **Restarting HA does not help.** Measured: a restart cleared every failure
  counter and the device stayed unreachable for another 65 minutes.
- **Only a controller reset clears it:** `btmgmt --index N power off; sleep 2;
  btmgmt --index N power on`. Device back in ~3 minutes.

⇒ If you watchdog a BLE setup, watch **named devices**, not only adapters. Grep
the same passive `btmon` capture for the MACs you care about — the count answers
"is the radio alive", the grep answers "is my device reachable", one capture, no
extra cost. Require two consecutive misses before acting, and never list a device
that only a proxy can hear: local adapters will never see it and you will reset
the radios forever.

## `hciN` indices are not stable

They swap across reboots — the onboard adapter was `hci0` one boot and `hci1`
the next on the same machine. Resolve adapters by MAC (`btmgmt --index N info`),
never by index. Note also that `/sys/class/bluetooth/hciN/address` does **not**
exist on every kernel, so reading the MAC from sysfs is not portable.

## Repairs are for problems only the user can fix

When the fault is physical — no proxy in range, an adapter that needs
replugging — raise a repair issue rather than logging into the void:

```python
ir.async_create_issue(hass, DOMAIN, ISSUE_KEY, is_fixable=False,
                      severity=ir.IssueSeverity.WARNING,
                      translation_key=ISSUE_KEY,
                      learn_more_url="https://...")
```

Two details that matter:

- **Fire once.** Compare the miss counter with `!=` against the threshold, not
  `>=`, or the issue is re-raised on every poll forever.
- **Only count a miss when the device was actually heard.** If the device is not
  advertising at all, the user's proxy setup is not the problem, and telling
  them to fix it sends them after the wrong thing.
