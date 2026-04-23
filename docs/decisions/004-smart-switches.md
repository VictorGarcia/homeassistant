# ADR-004 — Smart switch strategy (future rollout)

- **Date**: 2026-04-16 (proposed), Living Room pilot completed 2026-04-22, upgraded to dual-channel 2026-04-23
- **Status**: Phase 1 complete (Living Room + Dining Room share one device); Phases 2–3 pending

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

### Phase 1 — Pilot: Living Room ✅ completed 2026-04-22

What actually happened (differences from original plan noted):

- **Coordinator**: still on CC2531 — upgrade deferred until scaling to Phase 2. One added device doesn't stress the old coordinator.
- **Relay**: **SONOFF ZBMINI-L2** (not Aqara T1 as originally planned). Discovered during wire-tracing that the flat's electrical install doesn't carry neutral to switch boxes — neutrals only spliced in the registry box. No-neutral variant was the pragmatic choice; avoided pulling new wires.
- **Wiring topology**: 2-way (2 wall switches controlling the Living Room circuit). Wired as described in [Appendix A](#appendix-a--multi-switch-wiring-cookbook). The L2's single-circuit 2-input design was a natural fit.
- **Decoupled mode configured** via `switch.sonoff_living_detach_relay`. Relay permanently closed → IKEA bulbs always powered. Wall switches now signal HA via `binary_sensor.sonoff_living_opening`.
- **Automation**: see [docs/automations/living-room-wall-switch-toggle.md](../automations/living-room-wall-switch-toggle.md). Triggered on binary_sensor state change, calls `light.toggle` on `light.living_room`.

Outcome: both wall switches toggle the IKEA TRADFRI group via HA, bulbs stay always-powered, family UX unchanged.

Living Room was the right pilot because:
- Highest pain point today (bulbs were always `unavailable` on the dashboard until this)
- Zigbee bulbs + Zigbee relay share the mesh — validates the mesh under realistic load
- 2-way multi-switch exercised the tricky wiring pattern end-to-end

### Phase 1b — Dual-channel upgrade (2026-04-23)

Extended Phase 1 to also cover the adjacent **Dining Room** dumb bulb sharing the same switch box, by replacing the single-channel ZBMINI-L2 with a dual-channel **SONOFF MINI-ZB2GS**:

- Channel 2 drives the Living Room circuit in decoupled mode (same as before, now via `L2`/`S2` terminals)
- Channel 1 drives the Dining Room circuit in coupled mode (`L1`/`S1`) — dumb bulb, wall-switch-cuts-power is the right behaviour
- Single Zigbee device handles both, one pairing

Key learnings:

- The MINI-ZB2GS requires a neutral wire (unlike the L2). A new blue conductor was pulled from the registry box to the switch box through the existing conduit.
- The MINI-ZB2GS needed **HA Core 2026.4.x** for its ZHA quirk to load. On 2026.2.3 the device paired but exposed only basic entities — `detach_relay` (the whole point) wasn't surfaced as a select. The HA Core upgrade was required; prior to upgrading, direct cluster-attribute writes to the Sonoff manufacturer cluster (`0xFC11`) failed with "unsupported attribute" on all tried IDs.
- The DNS plugin needed explicit upstream servers (`1.1.1.1`, `8.8.8.8`) added via `supervisor/api /dns/options` to make the Core image download reliable — the Pi's only DNS source before that was the router at `192.168.0.1`, which gave intermittent "DNS server returned general failure" errors during the Docker manifest fetch.
- Final configuration (verified working):

  | Entity | Value |
  |---|---|
  | `select.sonoff_salon_comedor_detach_relay` | `CH2 enabled` |
  | `switch.sonoff_salon_comedor_switch_2` | `on` (relay permanently closed → Living Room bulbs always powered) |
  | `select.sonoff_salon_comedor_start_up_behaviour_2` | `On` (channel 2 resilient to power restore) |
  | `select.sonoff_salon_comedor_start_up_behaviour` | `PreviousValue` (channel 1 = Dining Room — restore last state) |
  | `select.sonoff_salon_comedor_external_trigger_mode_2` | `Edge trigger` |

The old ZBMINIR2 (used during the Living Room-only pilot) became redundant and is still paired as of this write; removal pending a restart or UI removal (the ZHA WS remove command changed names between Core versions).

### Migrating ZBMINIR2 → MINI-ZB2GS for channel 2 only

Checklist for future similar migrations (add a dumb-bulb-circuit channel to an existing decoupled smart-bulb install in the same box):

1. Verify HA Core ≥ 2026.4.x (for the MINI-ZB2GS quirk).
2. Add explicit upstream DNS to the Supervisor (`1.1.1.1`, `8.8.8.8`) if not already set — improves image download reliability.
3. Pull a neutral wire from the registry box to the switch box if not present (required for MINI-ZB2GS).
4. Physically install MINI-ZB2GS in place of the ZBMINI-L2:
   - `L In` and `N` from the registry box
   - `L1`/`S1` to the dumb-bulb circuit (Dining Room)
   - `L2`/`S2` to the smart-bulb circuit (Living Room, same topology as ZBMINI-L2's single channel)
5. Pair to ZHA (press and hold button 5-10s).
6. Rename the device and optionally the entities for readability (`Sonoff Salon Comedor` in this flat).
7. Set `detach_relay = "CH2 enabled"`, configure start-up behaviours as above.
8. Update any existing wall-switch automation to point at the channel-2 `binary_sensor.*_opening_2`.
9. Remove the old ZBMINIR2 from ZHA via the UI.

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

---

## Appendix A — Multi-switch wiring cookbook

How the other switches in 2-way (kitchen) and 3-way (pasillo) circuits actually get wired when only one relay is installed.

### The mental model

The relay is the **brain** — it holds the load (the wire going to the bulb). Physical switches become **buttons** whose only job is to tell the relay "someone just pressed me." Every switch needs a signal path back to one of the relay's input terminals (typically labelled `SW`, `SW1`, `SW2`, `L1`, or `L2` depending on model).

```
                    ┌──────────────┐
  [Switch A] ──────▶│              │
                    │   Relay      │────▶ [Bulb(s)]
  [Switch B] ──────▶│   (brain)    │
                    │              │
  [Switch C] ──────▶│              │
                    └──────────────┘
```

The relay is physically installed in **one** of the switch boxes — typically the one closest to the bulb's wiring and with a confirmed neutral wire. The other switches' wires get re-routed (at their own boxes) so they feed signals back to the relay's input terminals.

### The good news: existing traveler wires are reusable

In a traditional 2-way or 3-way switch installation, the switches are already connected to each other by "traveler" wires — 2 or 3 conductors running between boxes *inside the walls*. They exist to pass on/off state between switches. **For smart conversion, those same travelers become the signal path back to the relay** — no new wire needs to be pulled through walls in most cases.

This is why the pasillo 3-way isn't a nightmare: the cable-between-boxes already exists and can be repurposed.

### Scenario 1 — Single switch → single circuit (Living Room, Office)

Trivial. ~15 minutes of DIY per location.

1. Flip breaker. Remove switch plate. Confirm neutral wire (blue, tied off in the box).
2. Install relay inside the box.
3. Wire:
   - Line (brown/black) → relay's `L` input
   - Neutral (blue) → relay's `N` input
   - Load (wire going to the bulb) → relay's `O` output
   - Switch contacts → relay's `SW` input
4. Close up, breaker on, pair to ZHA (or WiFi for Shelly).

### Scenario 2 — Two switches → single circuit (Kitchen)

```
        ┌─── Kitchen ──────────────┐
        │                          │
        │  [Switch 1]══traveler══[Switch 2]
        │      │                   │
        │    [Relay]                     
        │      │                          
        │      └── Load ──▶ bulbs        
        └──────────────────────────┘
```

**Pick the host box**: the one closest to the ceiling wiring (usually the one that currently has the load wire running up to the bulbs). Install the relay there.

Recommended relay: **Shelly Plus 2PM** or **Aqara Dual Relay T1** (2 switch inputs in a single module). Alternative: Shelly Plus 1 + a **Shelly i3** input-only module for the second location.

Wiring changes from the existing 2-way setup:
- **Switch 1** (host box): contact wired to relay's `SW1` input (no longer in the load path)
- **Switch 2** (remote box): rewire so its contact feeds *back through the existing traveler wire* to the relay's `SW2` input
- Relay output goes directly to the bulbs

Both switches now behave identically — a flip of either signals the relay. You don't have to explain anything to family members; the UX looks unchanged.

### Scenario 3 — Three switches → single circuit (Pasillo)

This is the trickiest scenario. Three practical approaches, trade-offs in parentheses.

#### Option A — Convert all three to momentary pushbuttons + one relay ⭐ (cleanest long-term)

Replace all three switches with **momentary pushbuttons** (they spring back after press, like a doorbell button). Wire all three in parallel via the existing traveler wires back to the relay's `SW` input. Each press pulses the input; the relay toggles state.

- Most elegant: every switch is identical, HA sees one input, no "state" on any switch
- Needs existing 3-way wiring understood and re-routed — **recommend hiring an electrician for 1 hour** (~€50–80 in Barcelona)
- Small aesthetic change: pushbuttons look slightly different from rocker switches (though many pushbutton plates match existing Simon/Niessen/Schneider ranges)

#### Option B — Relay + wireless button on the far switch (zero wiring headache)

- Install relay at one switch box (say, the box nearest the Pasillo light junction)
- Rewire the adjacent switch via the existing traveler to the relay's `SW2` input
- **Third switch**: leave existing wiring, disable it by capping one wire inside the box, and stick an **Aqara Mini Switch** (~€15, battery, Zigbee) to the wall next to or over it
- HA automation: Aqara button press → call `switch.toggle` on the relay

Trade-off: you have a battery-powered button on the wall that needs a CR2032 every 1–2 years. But zero cutting into walls.

#### Option C — Two relays linked in HA

- One relay behind each of two of the three switch boxes
- Only one relay is wired as the actual load controller (the other in detached mode)
- HA watches both relays' SW inputs; any input toggles the load relay
- Wasteful (2–3 × €20 relays instead of 1), but no wiring gymnastics between boxes

For the pasillo specifically, **Option A is the right answer when the time comes**. The pasillo is the single piece of this rollout where paying an electrician for one focused hour is the right call.

### Practical advice before starting any of this

1. **Open one multi-switch box first (breaker off) before buying anything.** You'll learn in 5 minutes: number of conductors in the box, whether neutral is present, how the travelers are laid out, how much physical space the relay will have.
2. **Do the Living Room pilot first.** Single switch, single circuit — lets you practice the wiring pattern on the lowest-stakes install.
3. **Then kitchen (2-way) before pasillo (3-way).** Each step teaches you something you'll want to know for the next.
4. **For the pasillo, just budget for the electrician.** €60 once vs. several evenings cursing at wire nuts in a narrow hallway.
5. **Take photos of every existing wiring state before changing anything.** Tag the wires with masking tape and a sharpie.
6. **Pre-test each relay on a workbench** (or the kitchen table) before installing. Wire it to a lamp, pair it to ZHA, toggle it from HA. Confirms it works before you're inside a wall.
