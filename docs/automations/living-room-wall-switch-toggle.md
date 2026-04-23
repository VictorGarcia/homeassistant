# Automation — Living Room wall switch toggles lights

Part of the **smart-switch rollout** (see [ADR-004](../decisions/004-smart-switches.md)). First zone migrated: Living Room.

## What it does

Listens for state changes on `binary_sensor.sonoff_salon_comedor_opening_2` (which mirrors the wall switch contact state on the SONOFF MINI-ZB2GS's S2 input on endpoint 2) and toggles `light.living_room` (the IKEA TRADFRI group) in response.

## Why it works this way

The **SONOFF MINI-ZB2GS** is a **dual-channel Zigbee relay**. It's configured with:

- `select.sonoff_salon_comedor_detach_relay = "CH2 enabled"` — **only channel 2 is decoupled**
- `switch.sonoff_salon_comedor_switch_2 = on` — channel 2 relay is permanently closed
- `select.sonoff_salon_comedor_start_up_behaviour_2 = On` — on power restore, channel 2 defaults to on

This means:

- The IKEA TRADFRI bulbs (wired to channel 2's `L2` output) always receive mains power
- The physical Living Room wall switches (wired to the S2 input via a traveller pair) are electrically **isolated from the relay** — flipping them no longer cuts bulb power
- Each flip changes the MINI-ZB2GS's `binary_sensor.sonoff_salon_comedor_opening_2` state via Zigbee
- HA catches the state change and toggles the bulb group over Zigbee (ZHA)

Channel 1 of the same relay drives the **Dining Room** dumb bulb in **coupled mode** (normal wall-switch-cuts-power behaviour), configured independently — `start_up_behaviour = PreviousValue` so the light restores its last state after a power blip.

Result:

- **Family UX unchanged**: the wall switches still "turn the lights on and off"
- **Adaptive Lighting works continuously**: bulbs are always powered, no cold-boot race
- **HA-down fallback**: set `detach_relay` back to "All channels disabled" to revert channel 2 to normal coupled mode — wall switches cut power directly, lights work without HA

## Key device settings (configured once)

| Entity | Value | Why |
|---|---|---|
| `select.sonoff_salon_comedor_detach_relay` | `CH2 enabled` | Only channel 2 (Living Room) is decoupled; channel 1 (Dining Room) stays coupled |
| `switch.sonoff_salon_comedor_switch_2` | `on` | Channel 2 relay closed → IKEA bulbs have power |
| `select.sonoff_salon_comedor_start_up_behaviour_2` | `On` | On power restore, channel 2 defaults to on so bulbs stay lit |
| `select.sonoff_salon_comedor_external_trigger_mode_2` | `Edge trigger` | Every physical switch flip fires an event |
| `select.sonoff_salon_comedor_start_up_behaviour` | `PreviousValue` | Channel 1 (Dining Room dumb bulb) remembers its last state after a power blip |

## Device model + quirk requirements

- Hardware: **SONOFF MINI-ZB2GS** (Zigbee 3.0, 2-channel, 16A total)
- The MINI-ZB2GS requires a **ZHA quirk** to expose `detach_relay`, `external_trigger_mode`, `start_up_behaviour`, `turbo_mode`, and `network_led`. The quirk is built into HA Core as of **2026.4.x**. Earlier versions (e.g. 2026.2.3) pair the device but only expose basic switch/binary_sensor entities — decoupled mode can't be configured.
- If you ever need to re-pair: upgrade to 2026.4.x first, then join the device, then configure. See [ADR-004](../decisions/004-smart-switches.md#migrating-zbminir2--mini-zb2gs-for-channel-2-only).

## Wiring pattern used

- Living Room has 2 wall switches (JUNG 506 U) controlling one circuit (2-way).
- MINI-ZB2GS installed in the switch box where the live feed arrives ("Box 1"), replacing the earlier pilot's ZBMINI-L2.
- Neutral was pulled from the registry box through the existing conduit (required because the MINI-ZB2GS needs neutral, unlike the L2).
- Cable between the two boxes (2 travelers): one carries channel 2's load output (`L2`) to the second box and on to the bulbs, the other carries the second wall switch's signal back to the `S2` input.
- Channel 1 (`L1`/`S1`) drives the adjacent Dining Room circuit in the same box.
- See [ADR-004 Appendix A](../decisions/004-smart-switches.md#appendix-a--multi-switch-wiring-cookbook) for the generic wiring approach.

## YAML (reference)

The automation lives in `/config/automations.yaml` (API-created, YAML-tracked). Snapshot:

```yaml
alias: "Living Room wall switch toggles lights"
description: >
  Wall switch is decoupled from the ZBMINI relay (channel 2 of the SONOFF
  MINI-ZB2GS, detach_relay = 'CH2 enabled'). Each flip of the wall switch
  changes binary_sensor.sonoff_salon_comedor_opening_2; we react by toggling
  light.living_room. IKEA bulbs stay always-powered so Adaptive Lighting / HA
  retain full control.
mode: single
triggers:
  - trigger: state
    entity_id: binary_sensor.sonoff_salon_comedor_opening_2
actions:
  - action: light.toggle
    target:
      entity_id: light.living_room
```

## Testing

End-to-end: flip either Living Room wall switch → bulbs toggle on/off. Do it from both switches to verify both travel paths.

Dry run: toggle `binary_sensor.sonoff_salon_comedor_opening_2` state is hardware-driven and hard to fake, but you can call `light.toggle` directly to verify the target entity works:

```bash
curl -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id":"light.living_room"}' \
  http://192.168.0.52:8123/api/services/light/toggle
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Wall switch flip → bulbs lose power | `detach_relay` slipped back to "All channels disabled" or "CH1 enabled" — re-set to "CH2 enabled" |
| One wall switch works, the other doesn't | Wiring issue at the non-working box — tr1/tr2 swapped or loose terminal |
| Neither switch works, but bulbs are lit | Automation disabled, or `binary_sensor.sonoff_salon_comedor_opening_2` state isn't updating — check Zigbee mesh health (device `last_seen`) |
| Switches work, but lights don't change | IKEA bulbs not reachable via Zigbee (mesh issue) — check `light.living_light_1/2/3` availability |
| Dining Room light behaves weirdly | That's channel 1 — different wiring/behavior, not affected by the detach setting |

## Future extensions

- **Double-tap = scene** — change `external_trigger_mode_2` to "Pulse trigger" and capture ZHA events to distinguish single/double press for scenes like Movie Mode.
- **Adaptive Lighting zone** — now that bulbs are always powered, add a Living Room AL zone targeting `light.living_room`. See [ADR-002](../decisions/002-adaptive-lighting.md).
- **Dining Room voice control** — the channel 1 relay entity (`switch.sonoff_salon_comedor_switch`) can be exposed to Alexa via the existing Alexa integration — useful for "Alexa, turn off the dining room". See [runbooks/alexa-setup.md](../runbooks/alexa-setup.md).

## History

- **2026-04-22**: Pilot implementation using **SONOFF ZBMINI-L2** (single-channel, no-neutral). Worked cleanly; documented as the first Phase 1 completion of ADR-004.
- **2026-04-23**: Replaced with **SONOFF MINI-ZB2GS** (dual-channel, with neutral pulled) so channel 1 could also control the adjacent Dining Room dumb bulb. Required upgrading HA Core from 2026.2.3 to 2026.4.3 to get the quirk that exposes `detach_relay`.
