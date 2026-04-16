# ADR-003 — Design for the wall-switch workflow

- **Date**: 2026-04-16
- **Status**: Accepted

## Context

The household normally controls lights using **physical wall switches**, not automations or HA dashboards. Wall switches cut power to the bulbs entirely. This is an important deviation from the common smart-home assumption that bulbs are always powered and addressable.

## Implications

When a bulb is turned back on at the wall:

1. It cold-boots with its **firmware default state** (typically warm white, full brightness).
2. It connects to WiFi, takes 2–5 seconds to join and become addressable.
3. HA sees it transition from `unavailable` → `on`.
4. Only after that can HA apply any desired state.

If no automation/system watches for the transition, the bulb simply stays at its hardware default — not great if it's, say, 9 AM and the default is warm white.

## Decision

Design every lighting automation to **react to the state transition `unavailable → on`** (or, equivalently, to a bulb first appearing on the LAN). Apply the correct target state (CT, brightness, scene) within ~1 second of the transition.

For Adaptive Lighting, this translates to the setting:

```
initial_transition: 1  # seconds
```

For any custom automations (should we add them later), the template pattern is:

```yaml
triggers:
  - trigger: state
    entity_id: light.something
    from: unavailable
    to: on
actions:
  - delay: "00:00:01"  # give the bulb time to stabilize
  - action: light.turn_on
    target: { entity_id: light.something }
    data: { color_temp_kelvin: "{{ ... }}", brightness: "{{ ... }}" }
```

## Alternatives considered

### A. Configure the bulbs' hardware default to the "common case"

Tuya bulbs allow setting a power-on default via the Smart Life app (the `select.*_start_up_behaviour` entities on Zigbee devices expose similar). Could set defaults to "last state" or a "6500K at 100%."

- **Pros**: no HA involvement needed for the baseline case.
- **Cons**: defaults are static — doesn't handle circadian at all. Also, Tuya's "last state" is persisted across power cycles only when the cloud is reachable, which we no longer rely on.

### B. Ask the household to control via HA dashboard or voice instead of wall switches

- **Pros**: avoids the problem entirely — bulbs stay powered and addressable.
- **Cons**: changing user behavior is much harder than writing correct software. Wall switches are the right UX for most members of the household.

### C. Install smart switches that don't cut power (e.g., scene controllers)

- **Pros**: bulbs stay always-on; switches send events, not cut power.
- **Cons**: significant cost (~€40–70 per switch × multiple switches); requires replacing existing switches and re-wiring. Over-engineered for the current scale.

## Consequences

### Positive

- **Works with how the house already behaves.** No behavioral change required.
- **Self-correcting**. Any bulb that comes online for any reason gets the correct state applied.
- **Single pattern.** Same rule works for wall-switch power cycles, power outages, bulb firmware restarts, and router reboots.

### Negative / ongoing

- **Brief flash of incorrect state**. There's a sub-second window where the bulb shows its hardware default before AL catches up. In practice, this is hard to notice — `initial_transition: 1` starts the correction immediately.
- **Depends on bulbs being reachable on WiFi quickly.** If a bulb takes >10 seconds to connect, it'll linger at default longer. Not observed with the current 6 EG-BWGU105W001s.

## How to verify this works

Turn any Tuya wall switch off, wait 5 seconds, turn it on. The bulb(s) should come on at their hardware warm default, then visibly shift to the current sun-position CT within a second or two. If they stay warm, check:

- `switch.adaptive_lighting_<zone>` is `on`
- Bulb entity is reachable (not stuck at `unavailable`)
- `initial_transition` is still set to 1 in the AL options

## References

- [ADR-002](002-adaptive-lighting.md) — Adaptive Lighting settings
- Adaptive Lighting docs on `initial_transition`: https://github.com/basnijholt/adaptive-lighting#configuration
