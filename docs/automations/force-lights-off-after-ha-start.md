# Automation — Force lights off after HA start (away)

Safety net for the "power outage while away" scenario. When HA boots (which happens naturally after a power restore), if you're not at home, turns off every light and both coupled-mode switches, and pings your iPhone.

## Why it exists

Different devices behave differently on power restore:

| Device family | Configurable in HA? | Default on restore |
|---|---|---|
| IKEA TRADFRI (Zigbee) | Yes — `select.living_light_*_start_up_behaviour` | Set to **Off** |
| SONOFF relay channels | Yes — `select.sonoff_*_start_up_behaviour*` | Comedor + Eric = `PreviousValue`; Salón CH2 relay = `On` (to keep bulbs powered for Adaptive Lighting) |
| Tuya WiFi bulbs (LocalTuya) | Not via LocalTuya | Firmware default — usually **On** (bad) |
| Yeelight lightstrip | Via Yeelight app only | Firmware default |

The Tuya and Yeelight gaps mean that *even with every HA-configurable setting correct*, the firmware of those bulbs will still wake them up "on" after a power restore. This automation catches them with a brute-force `turn_off` call.

## Behavior

1. **Trigger**: `homeassistant.start` event — fires whenever HA Core boots (power restore, or manual restart).
2. **Wait step**: `wait_template` that holds until `person.victor` has a resolved state (not `unknown` / `unavailable`). Timeout 5 min, continues either way.
3. **Condition**: person is NOT at `home` (matches `not_home`, `Work`, or any other non-home state).
4. **Delay**: 30 s grace period for integrations (ZHA, LocalTuya, Yeelight) to reconnect to devices.
5. **Action**: `homeassistant.turn_off` targeting every light + both coupled-mode switches.
6. **Notification**: `active`-priority push to the iPhone so user knows it happened.

## Entity references

- Trigger: `homeassistant.start` event
- Condition: `person.victor`
- Actions:
  - `light.kitchen_light`, `light.pasillo`, `light.office_light_local`, `light.lightstrip`, `light.living_room`
  - `switch.sonoff_salon_comedor_switch` (Comedor, CH1 coupled)
  - `switch.sonoff_eric_bedroom` (coupled)
- Notify: `notify.mobile_app_iphone_15_pro`

## YAML (reference)

Lives in `/config/automations.yaml` (API-created, YAML-tracked).

```yaml
alias: "Force lights off after HA start (away)"
description: >
  When HA boots (power restore, manual restart), wait for device_tracker
  to resolve, and if person.victor isn't at home, turn off every light +
  both coupled-mode switches. Covers Tuya / Yeelight whose firmware wakes
  'on' after power loss. Notifies the iPhone.
mode: single
triggers:
  - trigger: homeassistant
    event: start
actions:
  - wait_template: "{{ states('person.victor') not in ['unknown', 'unavailable'] }}"
    timeout: "00:05:00"
    continue_on_timeout: true
  - condition: not
    conditions:
      - condition: state
        entity_id: person.victor
        state: home
  - delay: "00:00:30"
  - action: homeassistant.turn_off
    target:
      entity_id:
        - light.kitchen_light
        - light.pasillo
        - light.office_light_local
        - light.lightstrip
        - light.living_room
        - switch.sonoff_salon_comedor_switch
        - switch.sonoff_eric_bedroom
  - action: notify.mobile_app_iphone_15_pro
    data:
      title: "💡 Power restored — lights off"
      message: "HA rebooted at {{ now().strftime('%H:%M') }} while you were away. All lights turned off as a precaution."
      data:
        push:
          interruption-level: active
        tag: power-restore
        url: /dashboard-home/home
```

## Testing

End-to-end test (invasive — requires you to leave):
1. Leave the flat (`person.victor` → not_home)
2. Turn on several lights
3. Flip the main breaker (or just `ha core restart` via SSH)
4. Wait 5 min
5. All lights should be off; iPhone should have a banner

Dry run (while at home — skips the condition):
1. Temporarily change `condition: not → condition: state entity_id: person.victor state: home` (so it fires when home)
2. `ha core restart`
3. Observe: banner + lights off

Remember to restore the condition after testing.

## Edge cases handled

- **Brief power flicker while at home**: HA reboots (if it was affected — often a Pi survives momentary dips), person is `home`, automation doesn't fire, lights come back as firmware dictates (generally on, which matches being at home).
- **Power flicker while away, HA reboots**: automation fires after a 30-second grace delay, all lights off.
- **Extended outage while away**: same — HA eventually comes back up, automation fires.
- **User restarts HA manually while away**: also fires (which is desirable — catches the lights coming up in whatever state after restart).
- **`person.victor` stuck in `unknown` for >5 min after boot**: `continue_on_timeout: true` means the automation proceeds anyway. Then the not-home condition still gates: if state never resolves from `unknown`, the condition `not state home` is true → fires. This is a safe failure mode (prefer off over on when uncertain).

## Extensions

- **Notification with list of what was turned off** — could iterate actual light states at trigger time and report only the ones that were on. Marginal utility.
- **Don't kill lights that were expected to be on** — if you have a "vacation mode" with scheduled lights, exclude those from the `turn_off` list. Future work if that automation gets added.
- **Include the MINI-ZB2GS CH2 relay** — currently excluded because that relay should stay on (so IKEA bulbs stay powered for AL). If you decide you want total darkness during outages, add `switch.sonoff_salon_comedor_switch_2` to the entity list and remove the "channel 2 start-up = On" device config.
