# Clashborn behavior contract v2

This contract is the implementation baseline for autonomous units. It replaces
implicit cross-type selection with one intent per unit per decision update.
No gameplay behavior is changed by this document alone.

## Decision pipeline

Every unit follows the same pipeline:

1. **Perceive** only legal candidates inside its own vision and local search
   radius. A unit never searches the whole map for a target.
2. **Choose one intent** by the priority table for that unit type. An intent is
   `{ state, target_id, destination, expiry_tick }`.
3. **Commit** until the target dies, leaves that intent's leash, the expiry is
   reached, or a higher-priority event appears.
4. **Drive** movement only from the current intent. No damage event, lane
   follower, or generic target helper may write a second movement order.

The match scene supplies world queries and applies the chosen intent. A unit-type
controller owns all state transitions for that type.

## Player commands

| Command | Rule |
| --- | --- |
| Click enemy | Lock the clicked, visible target. It is kept until invalid, cancelled, or a higher-priority player order replaces it. |
| `J` | Attack the nearest visible hostile creep, including jungle creeps, inside the **local command radius**. Distance wins; lane and jungle creep have equal priority. If no creep is local, attack the next unlocked structure on the nearest lane, also inside the local structure radius. It never searches farther. |
| `K` | Attack the nearest visible hostile hero inside the local hero-command radius. |
| Move command | Cancels attack intent. |

Initial implementation targets: 650 world units for creep/hero command and 700
for structure command. These values must be tuned against the fixed camera
viewport, not the map diagonal.

## Lane creep and catapult

Lane creeps never use neutral camps as targets. They may only leave lane combat
to retaliate against a hero that directly attacked their allied hero.

| Priority | Intent | Condition | Exit |
| --- | --- | --- | --- |
| 1 | `HERO_RETALIATE` | Allied hero was damaged; attacker is within 500-unit aggro leash | 3 seconds, target death, or leash break |
| 2 | `LANE_COMBAT` | Enemy lane creep is visible within 600 | Death, 850-unit chase leash, or target unreachable |
| 3 | `STRUCTURE_SIEGE` | No lane creep is available and the next unlocked lane structure is local | Structure locks/dies or enemy lane creep appears |
| 4 | `LANE_ADVANCE` | No legal combat target | Reaches next authored waypoint or a higher intent appears |

The legal structure order is T1, T2, T3, both T4 guards, then core. A missing
structure registry entry is a configuration error: the creep stops and reports
it; it never falls forward to a deeper tower.

## Jungle camp creep

| Priority | Intent | Condition | Exit |
| --- | --- | --- | --- |
| 1 | `RETALIATE` | A playable-team unit damages a camp member | 10 seconds, target death, or camp leash break |
| 2 | `RETURN_HOME` | Retaliation ended outside home radius | Reaches camp center |
| 3 | `IDLE_HOME` | Otherwise | New direct damage |

Neutral creeps never acquire lane creeps, towers, heroes merely passing nearby,
or any global target. Camp centers must be outside the lane corridor plus a
configured buffer, so a hero attacking a tower does not accidentally include a
camp in a local command search.

## Tower and throne guard

Towers do not move. They retain their current legal target for a short lock
period to avoid target flicker, unless a hero-protection event overrides it.

| Priority | Target | Condition |
| --- | --- | --- |
| 1 | Hero aggressor | That hero directly damaged an allied hero inside the tower protection radius and remains in tower range |
| 2 | Nearest enemy lane creep/catapult | In attack range; neutral camps are excluded |
| 3 | Nearest enemy hero | In attack range |
| 4 | None | No legal target |

T1/T2/T3 can only take damage according to the lane-chain gate. T4 guards are
damageable only after all enemy T3 towers are down; the core is damageable only
after both guards are down. A destroyed structure is removed from collision and
selection immediately.

## Enemy hero bot

The bot only returns to fountain at low health. It does not retreat merely
because a lane wave died or because it is under no target.

| Priority | Intent | Condition | Exit |
| --- | --- | --- |
| 1 | `DEAD` | Not alive | Respawn |
| 2 | `FOUNTAIN_RECOVER` | HP at/below retreat threshold | HP reaches recovery threshold in fountain |
| 3 | `EXIT_TOWER_RANGE` | An enemy tower is actively attacking the bot | Bot exits that tower range plus safety margin |
| 4 | `HERO_RETALIATE` | Enemy hero directly damaged bot; bot is not in unsafe unsupported tower dive | Retaliation leash/time expires, target dies, or a higher priority appears |
| 5 | `DEFEND_BASE` | Enemy lane creep reaches base-defense radius | No base intruder remains |
| 6 | `LANE_FIGHT` | Enemy lane creep is local | Target invalid or higher priority appears |
| 7 | `HERO_FIGHT` | Visible enemy hero is locally safe to engage | Target invalid or higher priority appears |
| 8 | `SIEGE` | Next legal structure is nearby and allied creeps provide tower cover | Cover/structure invalid |
| 9 | `RALLY` | No target | Higher priority appears |

`HERO_RETALIATE` must beat creep farming and siege. A player can therefore not
freely hit a healthy bot while it continues to attack a tower. A bot avoids a
tower dive only when the intended hero target is actually protected by that
enemy tower and no allied lane creep is covering the dive.

## Performance contract

The simulation is deterministic and must remain stable as waves meet.

1. Keep a spatial entity index, updated after movement. Targeting and vision
   query nearby buckets, not every entity.
2. Stagger decisions: lane creeps at 5 Hz, towers at 10 Hz, bot at 5 Hz, and
   event-driven retaliation immediately. Never recompute a bot's full target
   query every simulation tick merely because the player is nearby.
3. Update fog/visibility at 5 Hz and immediately after a relevant movement,
   spawn, death, or brush transition. Use the spatial index for observers.
4. Keep one navigation request per changed destination. Navigation failures use
   a cooldown and are visible in debug state; they do not retry every tick.
5. Enforce a fixed live-wave budget and use a separate, capped jungle budget.
   Profile counts for entities, target queries, vision checks, path requests,
   projectiles, and tick duration in the debug overlay.
6. Only consider object pooling after the profiler shows allocation/freeing is a
   material cost. Correct bounded queries come first.

## Delivery sequence

1. Add intent data, local command radii, and runtime instrumentation without
   changing priorities. **Completed.**
2. Introduce the spatial index and migrate vision/target queries; compare
   deterministic replay results before and after. **Completed.**
3. Implement the priority tables above in the lane, jungle, tower, and bot
   controllers, with one controlled regression scene per table.
4. Re-tune camp placement and all world-unit radii against the fixed viewport.
5. Run a 10-minute soak at maximum creep/camp budget, then play-test targeted
   bot retaliation, lane siege, tower protection, and nearby jungle commands.

