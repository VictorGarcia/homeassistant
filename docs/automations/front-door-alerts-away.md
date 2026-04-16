# Automation — Front door alerts (away)

Sends push notifications to the iPhone when the front door changes state **and Victor is not at home**, with an escalation path if the door stays open too long.

## Behavior

| Event | Title | Priority | Notes |
|---|---|---|---|
| Door opened (while away) | 🚪 Front door opened | `time-sensitive` | Bypasses most Focus modes (except Do Not Disturb) |
| Door closed (while away) | 🔒 Front door closed | `active` | Normal priority |
| Door still open after 3 min | ⚠️ Front door still open | `critical` | Plays at volume even under DND / Focus / Silent |

All non-critical notifications share the tag `door-event` — successive banners replace each other on the phone instead of piling up. The critical "held open" alert uses a separate tag `door-event-critical` so it doesn't get overwritten by the next normal event.

## The "not home" condition

The check is `person.victor ≠ home`, not `person.victor = not_home`. The difference:

- `not_home` is a literal HA state — fires only when Victor is outside *any* defined zone.
- `≠ home` fires whenever Victor is outside the "Home" zone, *regardless* of whether he's in a named zone like "Work" or "Gym."

Currently only one zone is defined (`zone.home`, 100m radius around the flat), so the two are equivalent — but the negation form is future-proof: if Victor later adds a "Work" zone, the automation still behaves correctly.

> **Note:** This is HA's geographic-zone concept, *not* iOS Focus Mode. Turning on "Work Focus" on the iPhone doesn't affect this automation — only your GPS position does.

## Critical Alerts on iOS

The "held open" escalation uses iOS Critical Alerts, which bypass Do Not Disturb, Focus, and silent mode, and play at volume 1.0. **These require explicit user approval** — the first time a critical alert is sent, iOS may ask whether to allow them for the HA Companion app. Alternatively:

- iPhone Settings → Notifications → Home Assistant → **Allow Critical Alerts**

If not approved, the notification still arrives but downgrades to normal behavior.

## Entity references

- Trigger: `binary_sensor.door_opening` (Aqara lumi.sensor_magnet in the Lobby)
- Condition: `person.victor` — based on `device_tracker.iphone_15_pro` + `zone.home`
- Action: `notify.mobile_app_iphone_15_pro`
- Tap action: opens the Home dashboard (`/dashboard-home/home`)

## YAML (reference)

This automation lives in `/config/.storage/` (UI-created), not in `automations.yaml`. The YAML below is a reference representation for recovery / recreation.

```yaml
alias: "Front door alerts (away)"
description: >
  Push notification to iPhone when the front door opens or closes while
  Victor is not at home. Escalates to critical if the door stays open for
  3+ minutes. Successive events replace the banner via the 'door-event' tag.
mode: queued
max: 10
triggers:
  - trigger: state
    entity_id: binary_sensor.door_opening
    from: "off"
    to: "on"
    id: opened
  - trigger: state
    entity_id: binary_sensor.door_opening
    from: "on"
    to: "off"
    id: closed
  - trigger: state
    entity_id: binary_sensor.door_opening
    to: "on"
    for: "00:03:00"
    id: held_open
conditions:
  - condition: not
    conditions:
      - condition: state
        entity_id: person.victor
        state: home
actions:
  - choose:
      - conditions: "{{ trigger.id == 'opened' }}"
        sequence:
          - action: notify.mobile_app_iphone_15_pro
            data:
              title: "🚪 Front door opened"
              message: "Door opened at {{ now().strftime('%H:%M') }} while you're away"
              data:
                push:
                  interruption-level: time-sensitive
                  sound: default
                tag: door-event
                url: /dashboard-home/home
      - conditions: "{{ trigger.id == 'closed' }}"
        sequence:
          - action: notify.mobile_app_iphone_15_pro
            data:
              title: "🔒 Front door closed"
              message: "Door closed at {{ now().strftime('%H:%M') }}"
              data:
                push:
                  interruption-level: active
                tag: door-event
                url: /dashboard-home/home
      - conditions: "{{ trigger.id == 'held_open' }}"
        sequence:
          - action: notify.mobile_app_iphone_15_pro
            data:
              title: "⚠️ Front door still open"
              message: "Door has been open for 3 minutes and you're away"
              data:
                push:
                  interruption-level: critical
                  sound:
                    name: default
                    critical: 1
                    volume: 1.0
                tag: door-event-critical
                url: /dashboard-home/home
```

## Testing

**End-to-end:**
1. Walk out with your iPhone (make `person.victor` go `not_home`)
2. Open the door → expect `🚪 Front door opened` banner (time-sensitive)
3. Wait 3 minutes, leaving door open → expect `⚠️ Front door still open` banner at full volume (critical)
4. Close the door → expect `🔒 Front door closed` banner (active)

**Dry run without leaving:**
Temporarily remove the condition in the automation editor, then open/close the door locally.

**One-shot notification test:**
```bash
curl -sS -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","message":"It works","data":{"push":{"interruption-level":"active"}}}' \
  http://192.168.0.52:8123/api/services/notify/mobile_app_iphone_15_pro
```

## Extensions worth considering later

- **Actionable buttons** — add "Dismiss" and "View camera" (if a camera is added later) buttons via the `actions` array on iOS. Requires defining the action IDs in the iOS Companion app first.
- **Presence-based pause** — if a mmWave presence sensor confirms someone is home, skip the alert (handles the "just walked in but GPS hasn't updated yet" case).
- **Context in the message** — "Door opened while you were at Work (2.3 km away)" using the `proximity` integration.
- **Auto-arm after N minutes away** — link this automation to an `input_boolean` that auto-arms when you've been away for >10 minutes, so quick trips don't spam you.
