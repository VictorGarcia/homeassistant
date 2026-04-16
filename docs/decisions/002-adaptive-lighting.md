# ADR-002 — Adaptive Lighting replaces enforce-temperature automations

- **Date**: 2026-04-16
- **Status**: Accepted

## Context

Three custom HA automations existed to force bulbs to a specific color temperature:

- `kitchen_lights_enforce_temperature` (disabled; superseded duplicate)
- `kitchen_lights_enforce_temperature_better`
- `office_light_enforce_temperature`

Each triggered on:

1. A bulb transitioning *from* `unavailable` (indicating it just reconnected).
2. A state change from `off` → `on`.
3. Fixed times (`06:00` and `16:00`).

Each then applied a fixed CT value: `5000K` during the day (06:00–16:00), `2700K` at night. The Kitchen version had a convergence loop that re-asserted CT until verified within 50K of target.

## Problems with this approach

- **Symptom, not cause**. These existed because the Tuya cloud integration was unreliable — bulbs would go `unavailable` frequently. Fixing the transport (see [ADR-001](001-localtuya-xzetsubou.md)) removes most of the need for enforcement.
- **Per-zone duplication**. Each zone needed its own automation with its own entity list. Adding a new bulb or a new zone meant copying and adapting boilerplate.
- **Hard step function at 06:00 / 16:00**. Real daylight doesn't change instantaneously; the hard switchpoints created visible jumps.
- **No brightness adaptation**. Only Office had brightness enforcement, and only at a binary 100% / 50%.
- **No manual-override detection**. Touching a bulb manually would be immediately overridden on the next trigger, making the bulbs feel "fighting you."

## Decision

Install the **`basnijholt/adaptive-lighting`** HACS integration. Create one Adaptive Lighting instance per zone (Kitchen, Pasillo, Office), each targeting the stable "zone address" (either a `light.<zone>` group entity, or the single bulb entity in Office's case).

Delete all three enforce-temperature automations. The state the automations were enforcing is now handled by Adaptive Lighting continuously and smoothly.

## Settings chosen and why

| Setting | Value | Rationale |
|---|---|---|
| `min_color_temp` | 2200K | Warmer than the old `2700K` — more cozy at evening |
| `max_color_temp` | 5500K | Cooler than the old `5000K` — more alert at midday |
| `initial_transition` | 1s | **Load-bearing for the wall-switch pattern** (see [ADR-003](003-wall-switch-pattern.md)). A bulb coming back from power-off snaps to the correct CT within 1s. |
| `transition` | 45s | Smooth continuous drift; no visible jumps |
| `sunrise_offset` / `sunset_offset` | ±30 min | Pushes the curve extremes further from the horizon; less harsh edges |
| `send_split_delay` | 128ms | Empirical: Tuya firmware doesn't like back-to-back commands to the same bulb |
| `take_over_control` | `true` | If the user manually sets CT/brightness, AL backs off until the bulb is cycled |
| `detect_non_ha_changes` | `true` | Catches changes made via the Smart Life app or physical remotes |
| `sleep_color_temp` / `sleep_brightness` | 1900K / 1% | For night scenes via `switch.adaptive_lighting_sleep_mode_<zone>` |

## Alternatives considered

### A. Keep the enforce-temp automations, just fix Tuya

- **Pros**: fewer moving parts.
- **Cons**: still have hard step functions, no per-zone smoothness, no manual-override detection, have to hand-write the same automation for every new zone.

### B. Write a single generic Blueprint

- **Pros**: one definition, many instances.
- **Cons**: would still need to solve all the hard problems AL solves out of the box (sun curve math, override detection, interpolation). Reinventing a solved problem.

### C. Just leave bulbs on their hardware defaults

- **Pros**: zero automation complexity.
- **Cons**: no circadian lighting, wasting the capability of CT bulbs entirely.

## Consequences

### Positive

- **One system of record** for lighting behavior across all zones.
- **Smooth, continuous curves** rather than hard step functions.
- **Manual override respect** — adjusting a bulb manually works as expected until cycled.
- **New zones are one config entry** instead of a new automation with custom triggers.
- **Codified in UI**, easy to tweak any setting without YAML editing.

### Negative / ongoing

- **HACS dependency** — `basnijholt/adaptive-lighting` is a custom component (though in the default HACS index and heavily used).
- **Brightness adaptation is now always on** — could feel odd if you're used to lights never dimming themselves during the day. Disable with `switch.adaptive_lighting_adapt_brightness_<zone>` per zone if desired.

## References

- https://github.com/basnijholt/adaptive-lighting
- [ADR-001](001-localtuya-xzetsubou.md) — LocalTuya migration (prerequisite for this decision to be useful)
- [ADR-003](003-wall-switch-pattern.md) — wall-switch workflow (defines `initial_transition`)
