# Automation — Front door alerts (away)

Sends a push notification to the iPhone when the front door opens or closes **and Victor is not at home**.

## Behavior

| Event | Title | Priority | Notes |
|---|---|---|---|
| Door opened (while away) | 🚪 Front door opened | `time-sensitive` | Bypasses most Focus modes (except Do Not Disturb) |
| Door closed (while away) | 🔒 Front door closed | `active` | Normal priority |

All notifications use the tag `door-event` — successive events replace each other on the phone instead of piling up, so you see the *latest* door state rather than a spammy thread.

The condition is `person.victor` ≠ `home` (not literally `not_home`) so it also fires correctly when you're in another zone (e.g. "Work"), not just "away but unplaced."

Mode is `queued, max: 10` — bursts of door activity (someone holding it open) get processed sequentially, not dropped, and won't overlap.

## Entity references

- Trigger: `binary_sensor.door_opening` (Aqara lumi.sensor_magnet in the Lobby)
- Condition: `person.victor`
- Action: `notify.mobile_app_iphone_15_pro`
- Tap action: opens the Home dashboard (`/dashboard-home/home`)

## YAML (reference)

This automation lives in `/config/.storage/` (UI-created), not in `automations.yaml`. The YAML below is a reference representation for recovery / recreation.

```yaml
alias: "Front door alerts (away)"
description: >
  Push notification to iPhone when the front door opens or closes while
  Victor is not at home. Successive events replace the banner via the
  'door-event' tag.
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
```

## Testing

Quick end-to-end: walk out (make `person.victor` go `not_home`), open the door, close it. Expect two banners that replace each other in the Notification Centre.

Dry run without leaving: disable the condition temporarily (Settings → Automations → Front door alerts (away) → Edit → remove condition → save), then open/close the door.

Send a one-shot test notification:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","message":"It works","data":{"push":{"interruption-level":"active"}}}' \
  http://192.168.0.52:8123/api/services/notify/mobile_app_iphone_15_pro
```

## Extensions worth considering later

- **"Door held open" alert** — if the door stays open >3 min while away, escalate to `critical` priority (bypasses even DND and plays a sound at volume).
- **Actionable buttons** — add "View dashboard" and "Dismiss" buttons via the `actions` array on iOS. Requires defining the action IDs in the iOS Companion app first.
- **Presence-based pause** — if the mmWave presence sensor confirms someone is home but `device_tracker.iphone_15_pro` hasn't yet updated, skip the alert (handles the "just walked in but geofence hasn't caught up" case).
- **Context in the message** — "Door opened while you were at Work (2.3 km away)" using `proximity` integration.
