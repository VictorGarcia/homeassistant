# Automation — Living Room wall switch toggles lights

Part of the **smart-switch rollout** (see [ADR-004](../decisions/004-smart-switches.md)). First zone migrated: Living Room.

## What it does

Listens for state changes on `binary_sensor.sonoff_living_opening` (which mirrors the wall switch contact state on the ZBMINI R2/L2's S1 input) and toggles `light.living_room` (the IKEA TRADFRI group) in response.

## Why it works this way

The **ZBMINI** is configured in **detached relay mode** (`switch.sonoff_living_detach_relay = on`):
- The internal relay stays permanently closed (`switch.sonoff_living = on`)
- The IKEA bulbs always receive mains power
- The physical wall switch is electrically **isolated from the relay** — flipping it no longer cuts bulb power
- Instead, each flip changes the ZBMINI's binary_sensor state via Zigbee

HA catches the state change and toggles the bulb group over Zigbee (ZHA). Result:

- **Family UX unchanged**: the wall switches still "turn the lights on and off"
- **Adaptive Lighting works continuously**: bulbs are always powered, no cold-boot race
- **HA-down fallback** exists: turning off `switch.sonoff_living_detach_relay` reverts the ZBMINI to normal coupled mode — wall switches cut power directly, lights work without HA

## Key ZBMINI settings (configured once)

| Entity | Value | Why |
|---|---|---|
| `switch.sonoff_living` | `on` | Relay closed → bulbs have power |
| `switch.sonoff_living_detach_relay` | `on` | Wall switch isolated from relay |
| `select.sonoff_living_external_trigger_mode` | `Edge trigger` | Every state change of the physical switch fires an event |
| `select.sonoff_living_start_up_behaviour` | `On` | On power restore (e.g. breaker), relay defaults to on so bulbs stay lit |

## Wiring pattern used

- Living Room has 2 wall switches (JUNG 506 U) controlling one circuit (2-way).
- ZBMINI-L2 installed in the switch box where the live feed arrives ("Box 1"). No-neutral variant chosen because the flat's electrical install does not carry neutral to switch boxes — neutrals are only spliced in the registry box.
- Cable between the two boxes (2 travelers): one carries the relay's load output to the second box (and on to the bulbs), the other carries the second switch's signal back to the relay's S2 input.
- See [ADR-004 Appendix A](../decisions/004-smart-switches.md#appendix-a--multi-switch-wiring-cookbook) for the generic wiring approach and [front-door-alerts-away.md](front-door-alerts-away.md) for the docs pattern.

## YAML (reference)

Lives in `/config/.storage/` (UI-created). Recovery-safe copy:

```yaml
alias: "Living Room wall switch toggles lights"
description: >
  Wall switch is decoupled from the ZBMINI relay via detach_relay mode.
  Each flip of the wall switch changes binary_sensor.sonoff_living_opening;
  we react by toggling light.living_room. IKEA bulbs stay always-powered so
  Adaptive Lighting / HA retain full control.
mode: single
triggers:
  - trigger: state
    entity_id: binary_sensor.sonoff_living_opening
actions:
  - action: light.toggle
    target:
      entity_id: light.living_room
```

## Testing

End-to-end: flip either wall switch → bulbs toggle on/off. Do it from both switches to verify both paths.

Dry run: toggle `binary_sensor.sonoff_living_opening` state is hard to fake (it's hardware-driven), but you can call `light.toggle` directly to verify the target entity works:

```bash
curl -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id":"light.living_room"}' \
  http://192.168.0.52:8123/api/services/light/toggle
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| One wall switch works, the other doesn't | Wiring issue at the non-working box — tr1/tr2 swapped or loose terminal |
| Neither switch works, but bulbs are lit | Automation disabled, or `detach_relay` accidentally turned off — check entity states |
| Switches work, but lights don't change | IKEA bulbs not reachable via Zigbee (mesh issue, or bulbs are off at the relay — verify `switch.sonoff_living = on`) |
| Lights flicker or behave erratically | No-neutral relay's leakage current is too low for the bulb load; unlikely with 27W of IKEA bulbs but possible if only 1 bulb is installed |

## Future extensions

- **Double-tap = scene** — `select.sonoff_living_external_trigger_mode` could be changed to "Pulse trigger" and ZHA events captured to distinguish single/double presses for scenes like Movie Mode.
- **Long-press = dim** — similar idea with pulse trigger + hold detection.
- **Add to `switch.adaptive_lighting_living_room`** — not created yet because AL doesn't target Living Room (wall-switch workflow used to make it pointless). Now that bulbs are always powered, add an Adaptive Lighting zone for Living Room — see [ADR-002](../decisions/002-adaptive-lighting.md).
