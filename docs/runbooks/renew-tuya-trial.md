# Runbook — Renew the Tuya IoT Cloud trial

## What this unblocks

Renewing keeps the Tuya Cloud API available for **onboarding new devices** (LocalTuya fetches each new device's `local_key` from the cloud once, during add-device). Control of already-onboarded devices is local and does not depend on the cloud — if the trial lapses, existing bulbs keep working; only *new* additions break.

## Cadence

The free trial runs ~6 months. Tuya sends a warning email a few weeks before expiry. The trial was last renewed **2026-04-16**; next expected lapse is around **2026-10-20**.

## Steps

1. Log in to [iot.tuya.com](https://iot.tuya.com). Account: `Victor@victorgarcia.org`.
2. **Cloud → Development → (your project) → IoT Core** tab.
3. Look for an **Extend** or **Renew** button next to IoT Core. Click it, accept terms. Extensions are now manually reviewed by Tuya (takes hours to 2 days).
4. Scroll to **Cloud Develop Base Resource Trial** on the same page. If it shows *Suspended*, click **"Subscribe to Resource Pack"** and re-subscribe to the free tier. This is a separate action from the IoT Core extension — both need to be active for API calls to work.
5. Wait for approval email from Tuya.
6. Once approved, reload the LocalTuya integration in HA to pick up working credentials:

```bash
# From this Mac
curl -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.0.52:8123/api/config/config_entries/entry/<LOCALTUYA_ENTRY_ID>/reload
```

Or in the UI: Settings → Devices & Services → LocalTuya → ⋮ → Reload.

## Verification

After renewal, confirm the cloud API works by opening **Settings → Devices & Services → LocalTuya → Configure → Add device**. If devices appear in the dropdown with IPs, cloud API is healthy.

## If Tuya stops offering free trial extensions

Two fallbacks:

1. **`@tuyapi/cli` wizard** — extracts `local_key` via the consumer Smart Life API (no IoT Cloud subscription required):
   ```bash
   npm install -g @tuyapi/cli
   tuya-cli wizard
   ```
   Then add new devices in LocalTuya using **"Add Device Manually"** with the extracted keys.
2. **Flash devices to open firmware** (OpenBeken / Tasmota / ESPHome via cloudcutter) — permanently removes the Tuya dependency. Larger project; see [decisions/001-localtuya-xzetsubou.md](../decisions/001-localtuya-xzetsubou.md) for trade-offs.

## Existing cloud credentials (reference)

The credentials are stored in `.storage/core.config_entries` on the Pi. They are **not** in this repo. If you need to re-enter them (e.g., after a fresh install):

- Log into iot.tuya.com
- Open the project → **Authorization Key** shows the `Access ID/Client ID` and `Access Secret/Client Secret`
- `User ID` is on the **Link Tuya App Account** tab
- Region: `eu` (Central Europe Data Center)
