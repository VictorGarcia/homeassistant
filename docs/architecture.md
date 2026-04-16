# Architecture

## Hardware

| Component | Detail |
|---|---|
| Host | Raspberry Pi 3 Model B, aarch64 |
| OS | Home Assistant OS 17.1 |
| HA Core | 2026.2.3 |
| Supervisor | 2026.04.0 |
| Storage | SD card (`/dev/mmcblk0p8`, 28 GB, ~20% used) |
| Power supply | Monitored via `binary_sensor.rpi_power_status` |
| Zigbee coordinator | Texas Instruments CC2531 USB (legacy; supports Zigbee 3.0 only partially, no coordinator backup support) |

## Location

Barcelona, Spain. `Europe/Madrid` timezone. `EUR` currency. `km`/`°C`/`m/s` unit system. Language set to `en-GB`.

## Network

- LAN: `192.168.0.0/24`
- HA Pi: `192.168.0.52`
- Router/gateway: `192.168.0.1`
- External access: Cloudflared named tunnel → `https://ha.jougarcia.uk`
  - Tunnel routes managed in Cloudflare Zero Trust dashboard (not in add-on config)
  - HA trusts proxy subnet `172.30.33.0/24` (Cloudflared's ingress) per `configuration.yaml`

## Protocol stacks in use

| Protocol | Integration | Devices |
|---|---|---|
| Zigbee (ZHA) | Built-in | 1 coordinator + 4 Aqara/LUMI sensors + 3 IKEA TRADFRI bulbs |
| Tuya local (v3.5) | `xZetsubou/hass-localtuya` (HACS) | 6 EG-BWGU105W001 WiFi bulbs |
| Yeelight | Built-in | 1 Lightstrip |
| Mobile App | Built-in | 1 iPhone 15 Pro |
| MQTT | Mosquitto add-on | *Installed but unused — no MQTT devices* |
| Matter | *Removed 2026-04-16* | Never had paired devices |

## Lighting zone model

The lighting stack uses a three-layer pattern that makes migration and maintenance easy:

```
Adaptive Lighting switch  →  Light group (HA)  →  Individual bulbs
────────────────────────     ───────────────     ──────────────────────────────────
switch.adaptive_lighting_*   light.kitchen_light   light.kitchen_bulb_{2,3,4}_local  (LocalTuya v3.5)
                             light.pasillo         light.pasillo_{1,2}_local         (LocalTuya v3.5)
                             (direct target)       light.office_light_local          (LocalTuya v3.5)
                             light.living_room     light.living_light_{1,2,3}        (IKEA TRADFRI via ZHA)
                                                   └── no AL — wall-switch controlled
```

Why this layering:
- **Adaptive Lighting switches** decide what CT/brightness to apply based on sun position.
- **Light groups** are the stable "zone address" — if individual bulbs are swapped or re-added, AL's target doesn't change.
- **Individual bulbs** do the actual work, over Tuya protocol v3.5 (Kitchen/Pasillo/Office) or Zigbee (Living Room).

Office has no group because it's a single bulb; AL targets `light.office_light_local` directly. Living Room has a group (`light.living_room`) but no Adaptive Lighting because the household uses the physical wall switch to kill power — AL would have nothing to adapt while the bulbs are unavailable, and when the switch is back on the bulbs come up at their firmware defaults (outside our control until further config).

### Why Adaptive Lighting, not manual automations

Previously: three `*_enforce_temperature` automations compensated for Tuya cloud dropouts by forcing CT at `06:00`/`16:00` and on state-change from `unavailable`. They were workarounds for a broken transport.

Now: the transport is local and reliable. Adaptive Lighting replaces all three with smooth circadian curves, manual-override detection, and a 1-second "initial transition" that catches the wall-switch power-restore case.

See [decisions/002-adaptive-lighting.md](decisions/002-adaptive-lighting.md) for the full rationale.

## Wall-switch workflow (critical UX detail)

The household normally controls lights using physical wall switches, which cut power to the bulbs entirely. This pattern has two consequences:

1. When a bulb is turned back on at the wall, it cold-boots to its hardware default (warm, full brightness) before HA can talk to it.
2. Any automation or integration that assumes a bulb is always addressable will have race conditions.

**Mitigation**: Adaptive Lighting's `initial_transition: 1s` ensures the correct CT is applied within one second of a bulb reappearing as `on`. This is the load-bearing configuration choice for this household.

See [decisions/003-wall-switch-pattern.md](decisions/003-wall-switch-pattern.md).

## Areas (6)

| Area | Devices |
|---|---|
| Living Room | 3 IKEA TRADFRI bulbs + Aqara HT sensor |
| Kitchen | 3 Tuya bulbs + Yeelight Lightstrip |
| Bedroom | Aqara HT sensor |
| Outdoor | Aqara HT sensor |
| Lobby | Aqara door/magnet sensor |
| Office | 1 Tuya bulb |

Pasillo (hallway) bulbs live outside any area currently — candidate to assign to Lobby.

## External services

| Service | Purpose | Status |
|---|---|---|
| Cloudflared (add-on) | External HTTPS access via Cloudflare Zero Trust tunnel | Running |
| Tuya IoT Cloud | *One-time per bulb* — fetch local keys during LocalTuya onboarding | Trial renewed 2026-04-16; next renewal ~2026-10-20 |
| Google Translate TTS | Voice output | Default, unused |
| Radio Browser | Audio streams | Default |
| Met.no | Weather forecast | Default |
