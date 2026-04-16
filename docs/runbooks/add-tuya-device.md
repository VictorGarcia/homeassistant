# Runbook — Add a new Tuya device

Scope: adding a new Tuya WiFi device (bulb, plug, etc.) to Home Assistant and bringing it under LocalTuya control with no runtime cloud dependency.

## Prerequisites

- Tuya IoT Cloud trial must be **active** (see [renew-tuya-trial.md](renew-tuya-trial.md)).
- Device must be on the same LAN subnet as the Pi (`192.168.0.0/24`).
- `xZetsubou/hass-localtuya` must be installed (it already is — see [integrations.md](../integrations.md)).

## Steps

### 1. Pair the device using the Smart Life app (phone)

Use the official app, not HA. Select the device type, put the device in pairing mode (usually power-cycle 3–5× until it flashes), connect the app to it, and assign it to a room.

Once the app shows the device online, it also exists in the Tuya IoT Cloud against your account — this is how we'll fetch its `local_key`.

### 2. Confirm the device is visible to the LocalTuya integration

In HA: **Settings → Devices & Services → LocalTuya → Configure → Add device**.

The dropdown should auto-populate with the new device, including its LAN IP. If it doesn't appear within 30 seconds:

- Check the device is powered on and on WiFi (try the Smart Life app).
- In the LocalTuya Configure menu, pick **"Reconfigure Cloud API account"** and re-submit the same credentials to force a cache refresh.
- If still missing: see Troubleshooting below.

### 3. Configure the device

When you select the device from the dropdown, the form auto-fills:

- `friendly_name` — suggested from Smart Life, edit to HA naming convention
- `host` — LAN IP
- `device_id` — Tuya-assigned, leave as-is
- `local_key` — fetched from cloud, leave as-is
- `protocol_version` — **leave as `auto` or set to `3.5`**
- `scan_interval` — `30` seconds is fine

Submit. On the next screen pick **`auto_configure_device`**. The integration probes the device's DPS and creates the appropriate entities (light, switch, etc.) without manual mapping.

### 4. Add the entity to groups / Adaptive Lighting (if applicable)

If it's a new bulb in an existing zone:

- **Kitchen or Pasillo**: add to the corresponding light group at *Settings → Devices & Services → Helpers → (group)*.
- **Office or a new zone**: reconfigure the Adaptive Lighting entry to target the new entity, or create a new AL zone.

## Troubleshooting

### Device doesn't appear in the LocalTuya dropdown

Most common cause: cloud API credentials are stale or the IoT trial has lapsed. Verify by going to [iot.tuya.com](https://iot.tuya.com) → Cloud → Development → your project → **IoT Core** — the status should be "In service" (not "Trial Edition expired").

### Device appears but `auto_configure_device` fails

Protocol version mismatch. The form lists `auto`, `3.1`–`3.5`. Set explicitly to `3.5` for any recent Tuya hardware.

### Entity is created but shows `unavailable`

Verify the bulb is physically on and reachable:

```bash
# From a machine on the LAN
python3 -c "
import tinytuya
d = tinytuya.OutletDevice('DEVICE_ID','IP','LOCAL_KEY', version=3.5)
d.set_socketTimeout(3)
print(d.status())
"
```

If tinytuya gets a response, LocalTuya should too — reload the integration.

If tinytuya also times out: device isn't on the LAN or firmware version is newer than v3.5 — check for a `hass-localtuya` update.

### Can I get local keys without the Tuya IoT Cloud?

Yes, fallback path: `npm install -g @tuyapi/cli && tuya-cli wizard`. This extracts keys from the consumer Smart Life API (no IoT Cloud subscription needed). Last-resort option if Tuya removes the free trial tier entirely.
