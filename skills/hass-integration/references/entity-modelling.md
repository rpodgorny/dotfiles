# Entity modelling

## There is no "meter" domain, and there is no domain for most things

Home Assistant has ~45 entity platforms. `climate` exists because a thermostat
has *behaviour* — modes, setpoints, commands. A meter has one number that only
goes up, so `sensor` + `device_class` + `state_class` **is** the model. Check
the real list before assuming a domain exists:

```bash
podman exec <ha> python -c "from homeassistant.const import Platform; print(sorted(p.value for p in Platform))"
```

The meter-shaped *UI* is the Energy dashboard, not an entity type. Design for
it: get the device class and state class right and the sensors become eligible
automatically.

## Device class is a claim about meaning, not about units

The same unit means different things on different hardware, and the device
class is what decides where HA files it. Getting this wrong is silent and
corrupts a dashboard rather than throwing.

| Case | Right | Why |
|---|---|---|
| Water a household consumed | `water` | Eligible for the Energy dashboard's Water section |
| Water circulating a heating loop | `volume` | It comes back. As `water` it inflates household usage by the whole circulation |
| Thermal energy (kWh) | `energy` | No thermal category exists; core's `landisgyr_heat_meter` does the same |
| Electrical energy (kWh) | `energy` | Same class as thermal — only naming and icon separate them |

Ask what the number *means* before picking. When a vendor's own label is
ambiguous ("heat water meter" for a drinking-water meter), ask the user — this
is domain knowledge, not a code decision.

## State class

- `total_increasing` for meters — monotonic, resets handled automatically.
  This is what the sensor developer docs name for gas/electricity/water meters.
  (Core's `landisgyr_heat_meter` uses `TOTAL`; the docs are the better guide.)
- **Frozen billing snapshots get no state class at all.** A value the meter
  froze at period end steps *backwards* when the period rolls over. As
  `total_increasing` that reports an enormous phantom delta to the Energy
  dashboard. Ship them disabled by default too.
- `measurement` for instantaneous values.

## Names and icons come from translations

Both are integration quality-scale rules and prerequisites for HACS.

- `_attr_translation_key` on the entity; the name lives in
  `strings.json` → `entity.<platform>.<key>.name`.
- Numbers in names ride as `_attr_translation_placeholders`, so
  `"Energy tariff {tariff}"` stays translatable.
- Icons live in `icons.json` → `entity.<platform>.<key>.default`.

**Icon translations are static per translation key.** An icon that depends on
runtime context (thermal vs electrical energy) cannot be expressed unless that
context gets its own translation key. That is usually an improvement anyway —
"Heat energy" reads better than a second entity called "Energy".

**Keep `translation_key` separate from the key used in `unique_id`.** Changing
presentation must never move the unique_id, or every entity is orphaned and
loses its history. Converting an existing integration is therefore safe *if*
`translation_key` simply reuses the unique_id suffix already in use and the
English strings move across verbatim — nothing visible changes and no history
is lost. Do it that way; save any renaming for a separate, deliberate commit.

Class-attribute platforms use `_attr_translation_key = "..."` in place of
`_attr_name`; description-table platforms swap `name=` for
`translation_key=`. `strings.json` is keyed per platform:
`entity.binary_sensor.<key>.name`, `entity.select.<key>.name`, and so on.

**Three cases need no translation key at all**, and adding one would be wrong:

- **A device's primary feature** — `_attr_name = None` makes the entity inherit
  the device name, which is the intended HA pattern. A lone `climate` entity on
  a thermostat has no name of its own to translate.
- **Entities named by a device class** — `ButtonDeviceClass.RESTART` supplies
  both name and icon; `SensorDeviceClass.BATTERY` supplies the name. Overriding
  those makes the integration inconsistent with every other one.
- **Entities built from runtime device metadata.** Where names come from the
  hardware's own captions (`_attr_name = descriptor["name"]`, as in
  `hass-climatix-ic`), there is no fixed key set to translate against, and no
  amount of effort makes one. Leave it, and say why in a comment.

Only set an icon where it says something the device class does not. Overriding
an icon that already matches the device class just makes the integration look
different from every other one.

**Write a test that walks every row through every variant** and asserts each
resulting translation key exists with placeholders matching what the entity
supplies. A missing key produces an unnamed entity and a log error; a
placeholder mismatch fails when HA formats it. Neither appears until that exact
hardware is on someone's bus.

## Devices

- One HA device per physical device, `via_device` pointing at a hub device
  registered in `__init__.py`.
- `DeviceInfo(identifiers=...)` from hardware identity. `serial_number` is a
  good home for the full address — visible on the device page and matching what
  every other tool for that protocol prints.
- Name devices from what the protocol knows (`Water 00142809`). Users rename;
  do not invent a mapping you cannot verify.
- `entity_category=DIAGNOSTIC` for housekeeping counters. Disabled by default
  for raw vendor bit fields.

## Presentation is not the integration's job past this point

Forty devices is a wall no integration-side polish fixes. Point users at the
Energy dashboard, the `utility_meter` helper for cycles and tariffs, and areas.
Do not reimplement any of those.
