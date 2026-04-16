# ADR-004 — Smart switch strategy (future rollout)

- **Date**: 2026-04-16
- **Status**: Proposed (not yet implemented)

## Context

The household uses physical wall switches that **cut power** to the bulbs. This works, but creates two classes of problems:

1. **Smart bulbs cold-boot to firmware defaults** on every power cycle, so Adaptive Lighting has to re-apply state within seconds (works, but fragile).
2. **Rooms without smart bulbs** (bedroom, bathrooms, etc.) can't be automated at all — HA has no power to turn them off when unoccupied, no way to include them in "All off," no presence-driven behavior.

The long-term desire: replace the power-cutting UX with **decoupled** switches that send events to HA instead of breaking the circuit, so:

- Smart bulbs stay powered → AL works continuously, no cold-boot race
- Wall switches become programmable (toggle / scene / dim on tap / double-tap / hold)
- Dumb-bulb rooms become addressable by automations

## Switch inventory

| Zone | Physical switches | Lighting circuits | Bulb type |
|---|---|---|---|
| Living Room | 1 | 1 | Smart (IKEA TRADFRI ×3, Zigbee) |
| Kitchen | 2 (two-way) | 1 | Smart (Tuya ×3 + Yeelight) |
| Pasillo | 3 (three-way) | 1 | Smart (Tuya ×2) |
| Office | 1 | 1 | Smart (Tuya ×1) |
| **Other rooms (future)** | ~5 | ~5 | Dumb bulbs |
| **Total** | ~12 | ~9 |

## Key insight: one relay per *circuit*, not per *switch*

The kitchen's 2 switches and pasillo's 3 switches each control **one** lighting circuit (classic two-way / three-way wiring). Smart relays like Shelly Plus 1 and Aqara T1 have a `SW1`/`SW2` input pair — you wire one relay at the load, and the other physical switches become *inputs* to that same relay.

So the relay count isn't 12 — it's ~9, one per circuit. This cuts hardware cost by ~30%.

## Decision

**Pattern B — in-wall relays, decoupled mode** (see the shopping-advice conversation for the three patterns). Installed inside existing wall boxes so:

- **Existing switch plates stay in place** (home is 5 years old, plates are still nice — no aesthetic motivation to change)
- Dumb wall switches become input signals to the relay
- For smart-bulb rooms: relay is in **detached/decoupled mode** — output always on, switch events trigger HA automations
- For dumb-bulb rooms: relay is in **normal mode** — output toggles, switch also toggles locally (HA-down fallback)

Hardware candidate: **Aqara Wireless Relay T1** (Zigbee, ~€20) as the default. Falls back to **Shelly Plus 1** (WiFi, ~€18) for any location with poor Zigbee mesh signal or unusual wiring requirements.

## Alternatives considered

### A. Pattern A — battery button stuck next to the dumb switch
- **Pros**: cheapest (~€10–15/location, no wiring)
- **Cons**: two visible controls per wall; battery replacement every 1–2 years; dumb switch has to be left permanently ON with a piece of tape to stop family members flipping it

### C. Pattern C — replace the entire switch plate
- **Pros**: cleanest aesthetic, integrated wall-mounted scene buttons
- **Cons**: €40–60+ per location (€240–500+ total); the flat's existing plates are nice; would force replacement of adjacent *non-smart* switches on the same wall for consistency

### D. Scene panel at each wall (Legrand, multi-button Aqara H2)
- **Pros**: 2–4 dedicated scene buttons per location (e.g., "work mode", "movie mode", "off")
- **Cons**: €70–90+ per location; higher cognitive load — users have to remember button meanings; most scenes are better triggered by context (time, presence) than buttons anyway

### E. Continue with pure Adaptive Lighting, don't touch switches
- **Pros**: zero cost, nothing to break
- **Cons**: the wall-switch-cuts-power UX is the root cause of the cold-boot race, "unavailable" dashboard states, and inability to automate dumb-bulb rooms. Doesn't address the problem.

## Rollout plan

Phased, not big-bang. Pilot → validate → scale.

### Phase 0 — Prerequisites (before buying anything)

1. **Upgrade Zigbee coordinator to SONOFF ZBDongle-E (~€25).** The CC2531 can't handle additional Zigbee devices reliably. ZHA has a built-in migration flow; existing devices don't need re-pairing. Document as ADR-005 when it happens.
2. **Confirm neutral wire in switch boxes.** Flip the breaker, open one plate, look for a blue wire tied off in the box (not connected to the switch). Spanish flats built in the last ~30 years almost always have neutral. If the flat doesn't, use the **Aqara T1-N** or **Sonoff ZBMINI-L2** variants which tolerate no-neutral, ~€5–10 more per unit.
3. **Review HA-down fallback strategy.** Decide per-room: should a switch still work when HA is offline? Default: yes, via the relay's built-in local toggle mode. Some relays can also be configured to fall back automatically after N minutes of HA unreachability.

### Phase 1 — Pilot: Living Room (€45–55)

- 1× Zigbee coordinator upgrade (Phase 0)
- 1× Aqara T1 relay installed behind the existing living-room switch
- Configure in **decoupled mode** — relay's load output is permanently on, IKEA bulbs stay always-powered
- Wire the existing dumb switch to SW1 as an input (single tap = toggle group, long press = scene)
- Validate for 2–4 weeks: family acceptance, no weird edge cases, fallback tested by intentionally killing HA

Living Room is the right pilot because:
- Highest pain point today (bulbs always `unavailable` on the dashboard)
- Single-circuit, single-switch — simplest possible install
- Zigbee bulbs + Zigbee relay share the mesh — validates the new coordinator under realistic load

### Phase 2 — Smart zones (€80–100)

Once Phase 1 is rock-solid, scale to Kitchen, Pasillo, Office. One relay per circuit:

- Kitchen: 1 relay, wire the 2 switches as SW1+SW2 inputs
- Pasillo: 1 relay, wire the 3 switches — one as SW1 input, two others as 3-wire traveler pairs, or convert them to momentary pushbuttons (cleaner long-term). May require some wiring work.
- Office: 1 relay, single switch

### Phase 3 — Dumb-bulb rooms (€80–100)

Bedroom, bathrooms, dining, etc. — install relays in **normal mode** (not decoupled). Relay output drives the dumb bulb; switch toggles the relay locally and signals HA. Enables:

- "All off" actually turns off dumb-bulb rooms too
- Presence-driven auto-off (leave the bathroom → light off after 2 min)
- Occupancy-aware bedtime routine
- Vacation simulation includes these rooms

## Budget summary

| Phase | What | Hardware cost | Labor |
|---|---|---|---|
| 0 | Zigbee coordinator (SONOFF ZBDongle-E) | €25 | 0 (USB swap) |
| 1 | Living Room pilot (1 relay) | €20 | ~30 min DIY |
| 2 | Kitchen + Pasillo + Office (3 relays) | €60 | ~2 hrs DIY; pasillo three-way may want an electrician (~€40–60) |
| 3 | 5 dumb-bulb rooms (5 relays) | €100 | ~3 hrs DIY |
| | **Grand total** | **€205** | **~5–6 hrs DIY + optional electrician** |

Realistic end-state for the whole flat: **~€200–260 hardware**, which is well under the "€500+ nightmare" the household might have feared. The multi-way insight is the key saver (9 circuits ≠ 12 relays).

## Consequences

### Positive

- **Wall-switch UX preserved exactly** — family still uses the same physical switches, same plates, same muscle memory. Zero learning curve.
- **Smart bulbs stay always-powered** — Adaptive Lighting works continuously instead of racing against cold-boot.
- **Dumb-bulb rooms become addressable** — unlocks scene-based automation across the whole flat (All Off, presence-driven, vacation simulation, bedtime routine).
- **Scene events from switches** — every switch becomes a programmable input (single tap / double tap / long press) via HA automation. Potential future use: `double-tap living room switch` = trigger "Movie Mode" scene.
- **Local fallback** — Shelly/Aqara relays have built-in local-control mode, so if HA is offline for any reason, wall switches still toggle the lights directly.

### Negative / ongoing

- **One-time wiring work**. Low risk for single-circuit rooms; three-way pasillo may need an electrician or careful study.
- **Relay count grows with the flat's lighting complexity**. Each future dumb-bulb room adds ~€20 + an installation.
- **HA becomes more load-bearing**. A larger share of the lighting UX flows through HA — need to ensure HA uptime, backup strategy, and HA-down fallback actually works (re-test Phase 1 after every major HA update).
- **Firmware updates on relays** are a recurring chore (Shelly is particularly chatty with updates). Put them in the System dashboard's update list.

## References

- Shelly Plus 1 Mini — https://www.shelly.com/products/shelly-plus-1-mini
- Aqara Wireless Relay T1 — https://www.aqara.com/en/product/T1-relay
- Sonoff ZBMINI-L2 (no-neutral variant) — https://sonoff.tech/product/diy-smart-switches/zbmini-l2/
- SONOFF ZBDongle-E — https://sonoff.tech/product/gateway-and-sensors/sonoff-zbdongle-e/
- [ADR-003](003-wall-switch-pattern.md) — the wall-switch-kills-power pattern this decision aims to supersede
- [ADR-002](002-adaptive-lighting.md) — AL becomes *simpler* once bulbs are always-powered (initial_transition becomes less load-bearing)
