# Integrations

State as of 2026-04-16.

## Core / bundled

| Integration | Config entry | Purpose |
|---|---|---|
| `default_config` | YAML | Loads the standard set of integrations |
| `frontend` | YAML | Lovelace UI |
| `http` | YAML | HTTP server + trusted proxy config for Cloudflared |
| `automation` | YAML | Loads `automations.yaml` (currently empty — all automations via `.storage/`) |
| `script` | YAML | Loads `scripts.yaml` |
| `scene` | YAML | Loads `scenes.yaml` |
| `sun` | onboarding | Sun position for Adaptive Lighting |
| `person` | onboarding | Victor |
| `zone` | onboarding | Home zone (radius 100m) |
| `met` | onboarding | Met.no weather forecast |
| `radio_browser` | onboarding | Radio stream directory |
| `shopping_list` | onboarding | Shopping list |
| `google_translate` | onboarding | TTS (unused) |
| `raspberry_pi` | system | RPi-specific helpers |
| `rpi_power` | onboarding | Power-supply health monitor |
| `backup` | system | Backup manager |
| `go2rtc` | system | Camera proxy (no cameras configured) |
| `hassio` | system | Supervisor bridge |

## Device / protocol integrations

| Integration | Source | Config entry title | State | Notes |
|---|---|---|---|---|
| `zha` | Built-in | Texas Instruments CC2531 | Loaded | Coordinator + 7 end-devices |
| `yeelight` | Built-in | Yeelight Stripe `0x8019fb9` | Loaded | Single lightstrip |
| `mobile_app` | Registration | iPhone 15 Pro | Loaded | |
| `mqtt` | User | Mosquitto MQTT Broker | Loaded | **Currently unused** — broker runs, no clients. Candidate for removal if MQTT stays unused long-term. |
| `alexa.smart_home` | YAML (configuration.yaml) | — | Loaded | Voice control via 2× Echo Dots. Self-hosted Smart Home skill backed by an AWS Lambda. Spanish locale, curated entity allowlist. See [runbooks/alexa-setup.md](runbooks/alexa-setup.md) for the full setup, [decisions/](decisions/) for the *why* of self-hosting vs Nabu Casa. |

## LocalTuya stack

| Integration | Source | Version | Purpose |
|---|---|---|---|
| `localtuya` | HACS: `xZetsubou/hass-localtuya` | 2025.11.0 | Local control of Tuya bulbs via protocol v3.5 |

This replaced the `rospogrigio/localtuya` fork on 2026-04-16. Rospogrigio's latest (v5.2.5) only supports protocol up to v3.4 and couldn't connect to these bulbs. See [decisions/001-localtuya-xzetsubou.md](decisions/001-localtuya-xzetsubou.md).

The Tuya IoT Cloud account credentials (`client_id`, `client_secret`, `user_id`) are stored inside the integration's config entry in `.storage/` and are used only during device-onboarding to fetch `local_key` per device. Once devices are added, **no runtime cloud traffic**.

## Adaptive Lighting

| Zone | Config entry | Target lights |
|---|---|---|
| Kitchen | AL entry | `light.kitchen_light` (group of 3) |
| Pasillo | AL entry | `light.pasillo` (group of 2) |
| Office | AL entry | `light.office_light_local` (direct) |

Key settings (identical across zones):

| Option | Value | Why |
|---|---|---|
| `min_color_temp` | 2700K | Matches the EG-BWGU105W001 hardware floor — setting below this creates a clamp-detection feedback loop (see [ADR-002](decisions/002-adaptive-lighting.md) troubleshooting) |
| `max_color_temp` | 5500K | Cool ceiling (midday) |
| `initial_transition` | `1s` | Bulbs boot to hardware default after wall switch — apply correct CT within 1s |
| `transition` | `45s` | Smooth drift during normal operation |
| `send_split_delay` | `128ms` | Paces commands for Tuya firmware that dislikes rapid back-to-back sends |
| `sunrise_offset` | `+30min` | Soften the morning edge |
| `sunset_offset` | `−30min` | Soften the evening edge |
| `take_over_control` | `true` | Back off if user manually adjusts |
| `autoreset_control_seconds` | 900 | Manual-override flags auto-clear after 15 min so AL self-heals from spurious detections (migration races, startup drift, brief glitches) |
| `detect_non_ha_changes` | `true` | Catch changes from Smart Life app or other paths |
| `sleep_color_temp` | 1900K | For bedtime via `switch.adaptive_lighting_sleep_mode_*` |
| `sleep_brightness` | 1% | Same |

### Switches created per zone

For each of Kitchen / Pasillo / Office:

- `switch.adaptive_lighting_<zone>` — master on/off. Flip off to disengage AL for that zone.
- `switch.adaptive_lighting_adapt_color_<zone>` — toggle CT adjustments only.
- `switch.adaptive_lighting_adapt_brightness_<zone>` — toggle brightness adjustments only.
- `switch.adaptive_lighting_sleep_mode_<zone>` — force warm + dim (for scenes).

## HACS

| Repository | Version | Category | Purpose |
|---|---|---|---|
| `xZetsubou/hass-localtuya` | 2025.11.0 | Integration | Tuya local (v3.5 capable) |
| `basnijholt/adaptive-lighting` | 1.30.1 | Integration | Circadian lighting |
| `piitaya/lovelace-mushroom` | 5.1.1 | Plugin (frontend) | Mushroom card pack — used throughout the Home and System dashboards for compact, modern cards (`custom:mushroom-*`) |
| `piitaya/lovelace-mushroom-themes` | 0.0.11 | Theme | Companion theme pack (installed; not currently the active theme) |
| HACS itself | current | — | Integration manager |

## Add-ons

| Add-on | Version | State | Watchdog | Purpose |
|---|---|---|---|---|
| Advanced SSH & Web Terminal | 23.0.2 (23.0.7 available) | Started | ✅ on | Shell access — key auth only, password disabled |
| Cloudflared | 7.0.3 | Started | ? | External HTTPS at `ha.jougarcia.uk` via named-tunnel token |
| Mosquitto MQTT broker | *installed, unused* | Started | ? | MQTT broker — no clients |
| go2rtc | 1.x | Started | — | Camera stream proxy (no cameras) |

## Removed integrations

| Integration | Removed | Reason |
|---|---|---|
| `tuya` (cloud) | 2026-04-16 | Replaced by local control via xZetsubou LocalTuya |
| `matter` | 2026-04-16 | Zero paired devices, no plans to add Matter gear |
| `rospogrigio/localtuya` (HACS) | 2026-04-16 | Replaced by xZetsubou fork for v3.5 support |
