# Device Inventory

Snapshot date: 2026-04-24. Update after any physical change.

## Tuya WiFi bulbs (LocalTuya, protocol v3.5)

All six bulbs are model **EG-BWGU105W001** (GU10 WiFi RGBCCT). MAC OUI `d8:c8:0c` (Shenzhen Aodisen Technology).

| Zone | HA Entity | IP | Device ID | MAC |
|---|---|---|---|---|
| Kitchen | `light.kitchen_bulb_2_local` | `192.168.0.205` | `bfbb534528fcd7b2a68drc` | `d8:c8:0c:59:3a:cc` |
| Kitchen | `light.kitchen_bulb_3_local` | `192.168.0.98` | `bf6794d81d57ba8af0a7pe` | `d8:c8:0c:59:3c:bf` |
| Kitchen | `light.kitchen_bulb_4_local` | `192.168.0.110` | `bf0224b24fc131197bj3pd` | `d8:c8:0c:59:46:a9` |
| Pasillo | `light.pasillo_1_local` | `192.168.0.239` | `bfd628ab786598c849k0vs` | `d8:c8:0c:59:3b:9f` |
| Pasillo | `light.pasillo_2_local` | `192.168.0.179` | `bf70ca8d25548a7795ef8e` | `d8:c8:0c:59:3b:63` |
| Office | `light.office_light_local` | `192.168.0.232` | `bf27533d481c4f1362m2gk` | `d8:c8:0c:59:3d:f6` |

**Local keys are stored in HA's `.storage/core.config_entries` and never in this repo.** To fetch them if needed, use the Tuya IoT Cloud API (see [runbooks/add-tuya-device.md](runbooks/add-tuya-device.md)).

### DPS (data-point) mapping for EG-BWGU105W001

Auto-detected by xZetsubou's `auto_configure_device`. Provided here for reference if ever configuring manually:

| DPS | Purpose | Range / Values |
|---|---|---|
| 20 | Power on/off | `true` / `false` |
| 21 | Work mode | `"white"` or `"colour"` |
| 22 | Brightness (white mode) | `1`–`1000` |
| 23 | Color temperature | `0`–`1000` (0=warm, 1000=cool) |
| 24 | Color (HSV hex) | `"HHHHSSVVVV"` format |
| 25 | Scene/effect | hex-encoded scene data |
| 26 | Countdown | seconds (0 = off) |
| 34 | Music mode | boolean |
| 41 | (reserved) | boolean |

## Zigbee devices (ZHA)

### Coordinator

| Entity | Device | Notes |
|---|---|---|
| `light.zigbee_hub_living_room_light` | Texas Instruments CC2531 | USB coordinator. Old hardware — limited device count, no Zigbee 3.0 fully, no backup/restore of coordinator state. Replacement recommended long-term (SONOFF ZBDongle-E or HA SkyConnect/Connect ZBT-1) but not urgent — no new Zigbee devices planned. |

### Sensors (Aqara / LUMI)

| Entity prefix | Area | Model | Battery % |
|---|---|---|---|
| `sensor.living_room_*` | Living Room | `lumi.sens` (temp + humidity) | 59% |
| `sensor.master_bedroom_*` | Bedroom | `lumi.sensor_ht` | 55% |
| `sensor.outdoor_*` | Outdoor | `lumi.sens` (temp + humidity) | 48% — replace soon |
| `binary_sensor.door_opening` | Lobby | `lumi.sensor_magnet` | 69.5% |

### Bulbs (IKEA TRADFRI)

| Entity | Device | Wall switch | Notes |
|---|---|---|---|
| `light.living_light_1` | IKEA TRADFRI bulb E27 WW 806lm | Yes | Normally `unavailable` — not a fault, the wall switch cuts power |
| `light.living_light_2` | IKEA TRADFRI bulb E27 WW 806lm | Yes | Same |
| `light.living_light_3` | IKEA TRADFRI bulb E27 WW 806lm | Yes | Same |

## Yeelight

| Entity | Device | Area |
|---|---|---|
| `light.lightstrip` | Yeelight Stripe | Kitchen |

## Mobile

| Entity prefix | Device | Notes |
|---|---|---|
| `device_tracker.iphone_15_pro` | iPhone 15 Pro | Primary presence tracker |
| `sensor.iphone_15_pro_*` | Same | Most companion-app sensors disabled in iOS app settings — enable in *HA Companion → Settings → Sensors* if needed |

## HA Pi system sensors

| Entity | Purpose |
|---|---|
| `binary_sensor.rpi_power_status` | Power-supply health (detects undervoltage) |
| `sensor.backup_*` | Backup state + next/last scheduled run |
| `update.home_assistant_core_update` | Core update availability |
| `update.home_assistant_supervisor_update` | Supervisor update |
| `update.*_firmware` | Zigbee bulb/sensor firmware |

## SONOFF ZBMINIR2 (Zigbee relay, single-channel, Eric's Bedroom)

Originally piloted on the Living Room circuit on 2026-04-22, repurposed on 2026-04-23 as follows:

- **Location**: Eric's Bedroom switch box
- **Mode**: **Coupled** (`switch.sonoff_eric_bedroom_detach_relay = off`) — wall switch physically toggles the relay → dumb bulb. Normal behaviour, no automation needed at the HA level.
- **Start-up behaviour**: `PreviousValue` — on power return, the bulb restores its last state (better than defaulting to always-on for a bedroom).
- Entity prefix: `sonoff_eric_bedroom_*`
- IEEE: `94:b2:16:ff:fe:8c:35:fe`

When device was re-installed after removal from the ZHA registry, it auto-rejoined with the same IEEE thanks to ZHA being in `permit_join` mode at power-up. No fresh pairing needed.

## SONOFF MINI-ZB2GS (Zigbee relay, dual-channel)

Controls two independent circuits in the Salón/Comedor switch box:

| Channel | Circuit | Mode | Notes |
|---|---|---|---|
| CH1 (`L1`/`S1`) | Dining Room (Comedor) dumb bulb | Coupled (normal) | Wall switch physically toggles the bulb; HA can also control via `switch.sonoff_salon_comedor_switch` |
| CH2 (`L2`/`S2`) | Living Room (Salón) IKEA TRADFRI group | **Decoupled** (`detach_relay = "CH2 enabled"`) | Relay permanently closed; wall switches signal HA via `binary_sensor.sonoff_salon_comedor_opening_2`; see [automations/living-room-wall-switch-toggle.md](automations/living-room-wall-switch-toggle.md) |

Neutral is present at the switch box (pulled from the registry box through existing conduit during the MINI-ZB2GS install — the earlier ZBMINI-L2 pilot didn't need it).

## SONOFF MINI-ZBRBS (Zigbee roller-shutter controller, Claudia's Bedroom)

Installed 2026-04-24 behind the JUNG Auf/Zu pushbutton in Claudia's Bedroom to motorise the existing roller blind.

- **Entity**: `cover.persiana_claudia` (+ `sensor.*_calibrated`, `switch.*_inverted`, `select.*_external_trigger_mode`, `button.*_configure_cover_limits`)
- **Area**: Claudia's Bedroom
- **IEEE**: `04:e3:e5:ff:fe:a2:f6:88`
- **Quirk**: `zigpy.quirks.v2.CustomDeviceV2` (auto-applied on pairing; no eWeLink app required)
- **External trigger mode**: `edge trigger` — correct for JUNG momentary pushbuttons
- **Inverted**: `off` — Open moves the blind up
- **Calibration**: done via `button.persiana_claudia_configure_cover_limits`; persists on-device through reboots. Sensor `sensor.persiana_claudia_calibrated` reports status (`calibrated` / `not_calibrated`).
- **Wiring**: L → live from lighting circuit, N → neutral pulled from registry box, Lout1/Lout2 → motor up/down, S1/S2 → JUNG Auf/Zu outputs

## Light groups

| Group entity | Members | Why the group exists |
|---|---|---|
| `light.kitchen_light` | `light.kitchen_bulb_2_local`, `light.kitchen_bulb_3_local`, `light.kitchen_bulb_4_local` | Stable zone address for Adaptive Lighting and dashboards — survives bulb swaps |
| `light.pasillo` | `light.pasillo_1_local`, `light.pasillo_2_local` | Same rationale |
| `light.living_room` | `light.living_light_1`, `light.living_light_2`, `light.living_light_3` | The three IKEA bulbs share a wall switch so are always synchronised; one entity matches the physical reality |

All three groups are regular HA light groups (config entries with `domain: group`, subtype `light`). Dashboards and automations should target these groups rather than individual bulbs.
