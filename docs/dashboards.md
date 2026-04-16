# Dashboards

Two dashboards are maintained. Both use HA's `sections` view type (grid-based, responsive) and live in `/config/.storage/` as JSON, with a human-readable YAML source of truth committed under `config/dashboards/`.

| Dashboard | URL path | YAML source | Purpose |
|---|---|---|---|
| Home | `/dashboard-home/home` | [`config/dashboards/home.yaml`](../config/dashboards/home.yaml) | Daily-use view: status, quick actions, per-room lights + climate |
| System | `/dashboard-system/system` | [`config/dashboards/system.yaml`](../config/dashboards/system.yaml) | Low-traffic maintenance view: backups, host health, batteries, updates, firmware |

## Applying changes

Edit the YAML on your Mac, then:

```bash
./scripts/apply-dashboard.sh home        # or: system
```

The script parses the YAML and calls `lovelace/config/save` over WebSocket on the Pi — HA re-renders live, no restart needed. A hard refresh in the browser is only needed the first time after installing a new frontend plugin (e.g., Mushroom).

## Structure of the Home dashboard

Top row uses a **4-column grid**:

- **Status** — `column_span: 1` — chips: weather, person, sun, and conditional alert chips (HA update, low batteries)
- **Quick actions** — `column_span: 2` — four tappable scene macros, 2×2 layout:
  - Good Morning (tap: AL on everywhere; hold: sleep-mode off)
  - Movie Mode (dim all lights to 20%)
  - Bedtime (sleep-mode on for all AL zones)
  - All Off (every light entity off)
- **Forecast** — `column_span: 1` — 5-day daily forecast from Met.no

Below that, per-area sections (each `column_span: 2`): Living Room · Kitchen · Office · Pasillo · Bedroom · Outdoor & Entry. Each area section includes its lights (where applicable), its Adaptive Lighting chip row (where applicable), and compact climate sensor cards with inline mini-graphs.

## Structure of the System dashboard

Four sections, one per concern:

- **Backups** — next scheduled, last successful, manager state
- **Host** — Pi power-supply sensor, iPhone battery + location
- **Sensor batteries** — all Aqara/LUMI battery levels at a glance
- **Updates available** — HA Core, Supervisor, add-ons, HACS integrations
- **Device firmware** — Zigbee bulb/sensor firmware updates (subtitle section)

## Why YAML in the repo if HA stores JSON?

HA's storage format is JSON, per-dashboard, embedded inside `.storage/lovelace.dashboard_<name>`. That file is:

- **not human-readable** — everything on one line if read raw
- **not safely committable** — sits alongside files with raw tokens in the same directory

The apply script is the bridge. Edit YAML (readable, commentable, diffable), apply, commit. The JSON on the Pi stays the actual source of truth for HA itself; the YAML is our editable mirror.

## Dependencies

- [`piitaya/lovelace-mushroom`](https://github.com/piitaya/lovelace-mushroom) v5.1.1 — Mushroom card pack (HACS frontend plugin)
- [`basnijholt/adaptive-lighting`](https://github.com/basnijholt/adaptive-lighting) — provides the `switch.adaptive_lighting_*` entities referenced throughout
