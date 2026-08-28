---
name: hass-integration
description: >
  Conventions for Radek's hass-* Home Assistant integrations: an HA-free
  protocol module that doubles as a CLI dump tool, lookup-table entity
  modelling, tests against captured device frames, BLE specifics, and the HA
  traps already paid for. Use when creating a hass-* integration, adding
  entities or a platform to one, reviewing or debugging one against hardware,
  or preparing one for HACS.
---

# Home Assistant integrations, the way this repo family does it

Applies to `~/sync/projects/hass-*`. What the family *contains* comes from the
enumeration below, never from a list typed here. What it cannot tell you is
which repo to copy: `hass-meterbus` is the fullest example (protocol-scoped),
`hass-truma-inetx` the one for BLE and push (it ships its own dashboard card).

## Before touching more than one repo

**Enumerate, then fetch. Never work from a remembered list.**

```bash
gh repo list rpodgorny --limit 100 --json name --jq '.[].name' | grep hass   # source of truth
ls -d ~/sync/projects/hass-*                                                 # may disagree
for d in ~/sync/projects/hass-*; do git -C $d fetch -q origin &&
  printf '%-22s %s\n' "$(basename $d)" "$(git -C $d status -sb | head -1)"; done
```

Both halves have gone wrong in one sitting: a hardcoded three-name loop silently
skipped two repos, and three of five checkouts were behind their remote, one by
four commits. Stale checkouts duplicate work — a whole "bring this repo up to
standard" commit was written for changes that already existed upstream, and had
to be thrown away. A repo that looks like it is missing CI is usually one that
has not been pulled.

The family is not uniform, so let the commands report rather than assuming:
`hass-tplink-m7200` is on `master` while the rest are on `main`, a repo can have
no local clone at all, and `~/sync` and `~/syncthing/rpodgorny` are one tree seen
twice.

Read `references/traps.md` before debugging anything that "should work"; the
deploy loop for the test rig is in `references/deploy.md`. **For anything BLE,
read `references/bluetooth.md` first** — BLE breaks assumptions that hold for
every wired protocol: the transport is chosen for you, it changes under you, and
the device's identity arrives in pieces that not every transport delivers.

## Upstream skills — fetch, do not install

`home-assistant/core` ships its own agent skills. They are **deliberately not
installed here**: they are written for integrations living *inside* core, so
they would compete with this one on conventions that legitimately differ. Pull
them with WebFetch when a question is about HA's own contracts rather than this
repo family's habits.

| Fetch | Good for |
|---|---|
| [`ha-integration-knowledge/SKILL.md`](https://raw.githubusercontent.com/home-assistant/core/dev/.claude/skills/ha-integration-knowledge/SKILL.md) | HA's own integration conventions and reference integrations |
| [`platform-diagnostics.md`](https://raw.githubusercontent.com/home-assistant/core/dev/.claude/skills/ha-integration-knowledge/platform-diagnostics.md) · [`platform-repairs.md`](https://raw.githubusercontent.com/home-assistant/core/dev/.claude/skills/ha-integration-knowledge/platform-repairs.md) | Adding a diagnostics download or a repairs issue |
| [`ha-quality-scale-verify/SKILL.md`](https://raw.githubusercontent.com/home-assistant/core/dev/.claude/skills/ha-quality-scale-verify/SKILL.md) | Auditing against a quality-scale rule or tier, one rule at a time |
| [`ha-review/SKILL.md`](https://raw.githubusercontent.com/home-assistant/core/dev/.claude/skills/ha-review/SKILL.md) | What HA reviewers actually object to |

Individual quality-scale rules are fetchable directly, which is usually faster
than reading a whole skill:

```
https://raw.githubusercontent.com/home-assistant/developers.home-assistant/refs/heads/master/docs/core/integration-quality-scale/rules/{rule}.md
```
`{rule}` is e.g. `config-flow`, `entity-unique-id`, `parallel-updates`,
`entity-translations`, `icon-translations`, `runtime-data`.

**Where core's rules do not bind a custom integration**, prefer the local
convention and say why. Core forbids a user-configurable poll interval, for
instance; these repos ship one as an OptionsFlow, because the bus is shared
hardware whose sensible rate the *user* knows and the author does not. Treat
core's rules as informed argument, not as law — but never diverge silently.

## Before writing anything

1. **Search for prior art properly.** Search by *protocol*, by *vendor*, and by
   *the physical thing* — separately. HA core had `landisgyr_heat_meter` for
   heat meters and an M-Bus-shaped search never found it, because it speaks a
   serial Ultraheat cable. Check `home-assistant/core/homeassistant/components/`
   directly; reading a core integration's `sensor.py` beats reading its docs.
2. **Decide the scope boundary.** First ask whether it needs a repo at all:
   when someone already supports the device, upstream PRs beat a new
   integration — the Renogy BLE work was five PRs to `renogy-ble`/`renogy-ha`.
   Then, one integration per *protocol*, not per vendor, whenever the
   protocol's payloads are self-describing. Custom integrations cannot depend
   on each other (HACS does no dependency resolution) and a shared port has
   exactly one owner, so splitting by vendor creates problems that a lookup
   table solves for free. Split only when payloads are vendor-invented, as
   with BLE.
3. **Confirm what the product is actually called** — from the label on the box
   and the manual's title page, not from the vendor's headline product page.
   Vendor naming is routinely inconsistent. One case: the box read
   `netklima rtu`, the manual title page said *NetKlima RTU*, the website's
   main NetKlima page described a **different** variant with an Ethernet uplink
   and no Modbus at all, and the category listing filed the Modbus one under a
   third product's name. Check for a model-specific page and a model-specific
   logo — both existed and both settled it.
4. **Name it.** Repo `hass-<a>-<b>` → domain `<a>_<b>` → name `Pretty (qualifier)`.
   Vendor-scoped for a device (`hass-truma-inetx`), bare protocol for a
   protocol (`hass-meterbus`). Disambiguate if the name is crowded — wired
   M-Bus vs wireless.

   Get this right *before the first commit*. Renaming then is a find-and-replace
   across eight files plus `gh repo rename` (which rewrites the git remote
   itself, and GitHub redirects the old URL). Renaming after anyone has
   installed it is a config-entry migration, because the domain is the key.

## Layout

```
hass-<name>/
├── custom_components/<domain>/
│   ├── __init__.py          async_setup_entry / async_unload_entry, hub device
│   ├── api.py               protocol + transport. NO homeassistant imports.
│   ├── const.py             DOMAIN, LOGGER, CONF_*, defaults with reasons
│   ├── config_flow.py       + OptionsFlow
│   ├── coordinator.py       type XConfigEntry = ConfigEntry[XCoordinator]
│   ├── entity.py            base entity, DeviceInfo, availability
│   ├── sensor.py            (and other platforms)
│   ├── profiles.py          data → presentation table, if the device model warrants
│   ├── manifest.json        version, requirements, iot_class, integration_type
│   ├── strings.json         config + options + entity names
│   ├── icons.json           entity icons, only where they beat the device class
│   ├── translations/en.json byte-identical copy of strings.json
│   └── brand/               icon.png, icon@2x.png, icon.svg if one exists, original, ATTRIBUTION.md
├── tests/test_*.py          runnable with plain python3, no pytest
├── .github/workflows/validate.yml   hassfest + HACS + tests
├── hacs.json                name, content_in_root false, render_readme, homeassistant min
├── LICENSE                  GPL-3.0
├── README.md
└── .gitignore
```

## The rules that matter

Every rule here is applied, or waived in the commit body with the reason.

**`api.py` imports no Home Assistant.** It is blocking, plain Python, takes a
transport injection point for tests, and has a `_main()` so it runs standalone
as a dump/scan tool. This is what makes the protocol testable offline and
debuggable on the bench, and it is non-negotiable — every one of these repos
has needed it.

**Model with a table, not a hierarchy.** Read `references/entity-modelling.md`
before designing entities. When a protocol is self-describing,
map `(what the record says it is) → presentation` in a dict of frozen
dataclasses. Qualifiers (tariff, storage period, channel) decorate a row rather
than adding rows. Unmapped records are skipped, which drops serial numbers and
vendor blobs without a single special case. Adding hardware support = adding
rows.

**One transport object per config entry, with a lock per transaction.** The
coordinator holds the port for the entry's life. Anything else that wants the
bus — a rescan from the config flow — must reuse that object, never open a
second. See `references/traps.md`; this one fails silently and looks like an
empty bus.

**`unique_id` is forever.** `f"{device_identity}_{key}"` where identity comes
from the hardware (secondary address, serial, MAC) and never from a config
entry id or a scan position. If presentation needs to vary, add a separate
field — never reuse `key`.

**Gate availability on the device's own validity signal.** Where the protocol
carries per-device freshness or status, `available` reads it, and writes are
refused on it too — a device reporting invalid data usually discards writes
silently. Without this an entity serves its last known reading forever after
the hardware falls off the bus, which is indistinguishable from working. This
is exactly what HA's built-in Modbus platform does: it never checks the status
register it is polling right next to.

**One place builds the client from stored config.** The config flow and
`async_setup_entry` both need it, and spelled out in both they drift the day a
setting is added. `client_from(entry.data)` in `coordinator.py`, imported by
both.

**Comment the why, especially the trap.** Every non-obvious line explains the
failure it prevents, in prose, at the point of the decision. A comment that
restates the code is deleted. Deliberate shortcuts get a `ponytail:` marker
naming the ceiling and the upgrade path.

**Detection that depends on device-reported data needs a configured fallback.**
Whatever the device tells you about itself — model string, manufacturer ID,
advertised name — can be absent, per-unit, or transport-dependent. The config
entry already records what the user chose; treat that as the source of truth and
the device's own claim as an optimisation. Otherwise a device the integration
can plainly see becomes permanently unusable, with a log line that names an
address rather than a cause.

## Config flow shape

- `async_step_user` → `async_show_menu` when there is more than one way to
  connect (serial vs TCP bridge). Same data, different fields.
- **Probe fast before working slow.** A wrong port must fail in a second, not
  after a full discovery sweep.
- Long discovery → `async_show_progress` with a `progress_task`, and re-render
  by calling `hass.config_entries.flow.async_configure(flow_id=self.flow_id)`
  from the worker, throttled. Report facts that are always true (count so far,
  what is being tried) — never a percentage you cannot honestly compute.
- **Always leave an escape hatch.** Show what discovery found in an editable
  field before saving. Discovery that silently returns 35 of 41 devices is the
  failure worth engineering against.
- Reconfigure = rediscover and **union** with the stored list, never replace. A
  device that missed one scan is far more likely to be briefly unreachable than
  gone, and dropping it takes its history with it. A second reason to union:
  some protocols cannot distinguish an enrolled device that has not been polled
  yet from an empty slot, so a restart landing during warm-up would otherwise
  delete real entities.
- **Rediscovery cadence follows scan cost.** A sweep of a second or two just
  re-runs on every setup, so adding hardware is a reload and there is no need
  for a reconfigure step at all. A sweep of minutes cannot, and needs an
  explicit reconfigure with a progress step. Union either way.
- Entry title names the *connection*, not a count. Counts go stale; HA already
  shows device and entity counts on the card.

## Tests

Plain `python3 tests/test_x.py`, `assert`-based, a `_main()` that runs every
`test_*` in the module. No pytest, no fixtures, no HA install — CI installs at
most the protocol library.

**Pin against an external standard where one exists** — RFC 6238's TOTP
vectors, a CRC captured from the device — rather than against the
implementation's own output, which only proves it still does what it did.

**Mutation-check the tests that matter.** Copy the repo, break the specific
line the test exists to defend, and confirm the suite fails. A test that passes
against a deliberately broken `_pad` or a dropped `zfill` is decoration. This
has already caught one vacuous assertion written in this family (an `or True`
that made the whole check inert).

**If the logic under test cannot be reached without importing Home Assistant,
that is a layering bug, not a testing problem.** Protocol decoding — firmware
enum tables, "not measured" sentinels, unit scaling — belongs in the HA-free
module with the transport, not in `sensor.py`. Move it. Where something
genuinely must stay in a platform file (a table built from HA enums), inspect
it *as source* with a regex rather than importing it; that still catches a row
whose `translation_key` has no name in `strings.json`.

**Test against real captured device data**, byte for byte, with the capture
noted in a comment. Pin the things that are expensive to get wrong: unit
scaling, the state-class choice, protocol framing, and every failure mode you
actually hit on hardware. When a bug is found on hardware, the fix ships with a
test that reproduces it offline.

Load HA-importing modules in tests via `importlib` under a fake package name so
the package `__init__` (which imports HA) never runs.

**A fake device beats a replayed capture for everything except framing.** Answer
real protocol frames out of an in-memory register/record file and the whole
client becomes testable: discovery, the fallback path when the device refuses a
batched read, retry semantics, one sick device not blacking out the other ten.
A capture pins decode and checksums; a simulator pins *behaviour*. Use both —
the simulator for the logic, one captured frame for the framing truth. The
simulator is what caught the reconnect bug in `references/traps.md`, on the
first run, with no hardware attached.

Keep decision logic out of `config_flow.py`. It imports Home Assistant directly,
so in a no-HA test environment it cannot be loaded at all and a pure helper
stranded in there is untestable by any trick.

**A transport injection seam means the real transport is never exercised.** Every
test that injects a fake skips `connect()`, the URL or port settings it builds,
and the library underneath — so a transport rewrite can go green while being
completely unverified. Serve the same fake device over a real socket in one
test and drive a read, a write and a read-back through it.

## Releasing

- **Bump `version` in `manifest.json` on *any* `strings.json` change.** The
  frontend caches translations keyed by integration version; without a bump the
  edit never reaches the browser and a hard refresh does not help.
- `strings.json` and `translations/en.json` must stay identical — copy, do not
  hand-edit both.
- Commits: short subject, then a body explaining *why* and what was wrong
  before, in prose paragraphs. Trailer:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- Brand assets go in `brand/` with the unmodified original kept alongside and
  an `ATTRIBUTION.md` recording owner, source URL, retrieval date, and exactly
  what was changed. Since HA 2026.3 these serve through the brands proxy, so no
  `home-assistant/brands` submission is needed (checked 2026-08; re-check before
  trusting it on a much older HA). Ship only what can be derived
  honestly: if the vendor publishes no vector there is **no `icon.svg`** —
  tracing one is redrawing their mark rather than using it. Prefer a plain crop
  to a recomposition, and record the crop in numbers (which rows and columns
  went) so the derivation is checkable. Use the model-specific mark when one
  exists; the family logo names the wrong product.
- README: logo top-right, HACS/Validate/License badges, what the hardware is,
  why not the built-in platform, install, setup, entity table, limitations,
  development (standalone tool + tests), licence split between code and brand.

## Dependencies

**Declare only what Home Assistant core does not already ship.** The manifest
docs are explicit, and it is easy to get backwards — an undeclared import looks
like an oversight when it is in fact correct.

```bash
podman exec <ha> grep -inE "^(requests|cryptography|aiohttp|httpx|pyserial)" \
  /usr/src/homeassistant/requirements.txt
```

Anything in that file is pinned by core: declaring it again risks a version
conflict and buys nothing. `requests`, `cryptography`, `aiohttp` and `httpx`
are all in there; `pyserial` is **not**, so a serial integration must declare
it. No core integration declares `requests` or `cryptography` either, though
several import them.

**Use an async HTTP client.** Two quality-scale rules apply, both 🏆 platinum:
`async-dependency` ("there are no exceptions to this rule") and
`inject-websession`, which requires accepting a passed-in session and so means
`aiohttp` or `httpx` specifically. A blocking client behind
`async_add_executor_job` is not *broken* — several core integrations do it —
but it is a context switch per request for I/O asyncio does natively, and it
caps the integration below platinum.

Take the session with `async_get_clientsession(hass)`. The exception is
cookies: a service with a cookie-based login needs its own via
`async_create_clientsession`, or it will scribble on the shared jar.

Keep CPU-bound work (AES, RSA, CRC) synchronous — microseconds of compute, so a
thread hop costs more than it saves. Only I/O belongs in the event loop.

Converting is cheap **if the transport is already one function**: make that one
method async and the callers await it. Keep it as the seam the tests fake and
the suite needs only the `async` keyword.

## HACS readiness

`hassfest` and the HACS action both run in `validate.yml` (with
`ignore: brands`). Beyond that: entity names from `strings.json` and icons from
`icons.json` (both quality-scale rules), at least `en` translations, and a
`homeassistant` minimum in `hacs.json` that actually matches the newest API
used — check `async_update_reload_and_abort`, `AddConfigEntryEntitiesCallback`,
`entry.runtime_data` before claiming an old floor.

**Set the GitHub description and topics before the first push.** The HACS
action validates repository *metadata*, not only the tree, and fails on an
empty description or an empty topic list:

```
X  Validation description failed:  The repository has no description
X  Validation topics       failed:  The repository has no valid topics
```

Nothing in the checkout can fix that, which is why it reads as a code problem
and survives several pushes unexamined — `hassfest` and the tests stay green
throughout. **Read which job failed before reading any diff.**

```bash
gh repo edit <owner>/<repo> --description "Home Assistant integration for X: what, how."
for t in hacs home-assistant home-assistant-integration homeassistant <protocol/domain terms>; do
  gh repo edit <owner>/<repo> --add-topic "$t"
done
gh run rerun <run-id> --failed    # metadata is not in the tree, so no empty commit is needed
```

Description follows the family's form: *Home Assistant integration for X — what
it talks to, how it is reached, and the one thing that makes it worth having.*
Topics are the four standard ones above plus protocol and domain terms. Copy
the shape from `hass-netklima-rtu` or `hass-truma-inetx`; both already pass.

When a shared CI dependency has to move, move it in **all** the hass-* repos in
one pass rather than letting them drift. Open item as of 2026-08:
`actions/checkout@v4` warns that Node 20 is deprecated and is being forced onto
Node 24, still a warning rather than a failure.
