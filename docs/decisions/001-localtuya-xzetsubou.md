# ADR-001 — LocalTuya via xZetsubou fork

- **Date**: 2026-04-16
- **Status**: Accepted
- **Supersedes**: Previous use of Tuya Cloud integration and `rospogrigio/localtuya`

## Context

The six Tuya WiFi bulbs (EG-BWGU105W001) were originally controlled via the **official Tuya cloud integration**. This setup had chronic problems:

1. **Frequent `unavailable` states** — cloud connection would drop, requiring HA to re-authenticate, and bulbs would temporarily lose their color temperature after reconnect.
2. **Recurring trial expiry** — the underlying Tuya IoT Cloud subscription is a 6-month free trial; when it lapsed, the entire cloud integration broke (`setup_error`) and we lost all Tuya control until renewal.
3. **Latency** — every command round-trips through Tuya's servers, ~300-500ms end-to-end.
4. **Workaround sprawl** — three custom "enforce temperature" automations were written to re-apply color temperature after bulb dropouts. These were treating symptoms, not the cause.

An earlier attempt to migrate to `rospogrigio/localtuya` (the longest-established LocalTuya fork) failed: the fork only supports Tuya protocol up to v3.4, but these bulbs speak **v3.5**. No local connection could be established regardless of correct local keys.

## Decision

Switch to the **`xZetsubou/hass-localtuya`** fork (installed as a HACS custom repository; not in the default HACS index) as the Tuya transport layer. Remove the official Tuya cloud integration entirely.

## Alternatives considered

### A. Stay on Tuya Cloud

- **Pros**: zero migration work; official integration, stable codebase.
- **Cons**: all four problems from Context remain. In particular, the trial expiry is a forever-recurring annoyance.

### B. `rospogrigio/localtuya`

- **Pros**: most-starred fork, familiar name, in HACS default index.
- **Cons**: no v3.5 support. Would require downgrading bulb firmware or replacing hardware.

### C. `ClusterM/localtuya_rc`

- **Pros**: another fork, claims newer protocol support.
- **Cons**: low stars, unclear maintenance, smaller community — riskier.

### D. Flash bulbs to OpenBeken / Tasmota / ESPHome

- **Pros**: permanent elimination of Tuya dependency; no cloud, no trial, no key rotation ever.
- **Cons**: ~5-10% brick risk per bulb; requires identifying chipset (BK7231 vs ESP variants); Cloudcutter success rates vary by firmware version; destructive and non-reversible. Good long-term direction if Tuya ever removes the free trial entirely; not worth it now.

## Consequences

### Positive

- **Local control, no runtime cloud dependency.** Cloud is only needed once per device, to fetch the `local_key` during onboarding.
- **Sub-100ms response time**, vs ~300-500ms cloud.
- **Trial lapses don't break anything operational.** Existing bulbs keep working even if the IoT Cloud API is down.
- **v3.5 protocol handled natively**, with auto-configuration of DPS mappings (no manual DPS editing required).
- **Three custom automations retired** (kitchen enforce-temp ×2, office enforce-temp ×1) — the symptoms they addressed are gone.

### Negative / ongoing

- **Off-index HACS dependency**. xZetsubou isn't in the default HACS repo list; adding it requires the "Add custom repository" step. Documented in [runbooks/add-tuya-device.md](../runbooks/add-tuya-device.md).
- **Cloud API still needed for onboarding new devices.** If Tuya removes the trial tier entirely, fallback is `@tuyapi/cli wizard`.
- **Maintainer risk**. xZetsubou is active as of late 2025 but smaller team than the legacy fork. Worth watching the repo.

## References

- xZetsubou/hass-localtuya: https://github.com/xZetsubou/hass-localtuya
- Tuya protocol v3.5 spec (community notes): tinytuya project
