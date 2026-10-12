# Clashborn AI state machine

This document is the runtime contract for autonomous match entities. It replaces
ad-hoc target changes. Each actor has exactly one state owner. A decision selects
the state and its target; only that state's driver may issue movement or write the
combat target. The combat engine remains responsible only for resolving legal
attacks against the target it receives.

## Common rules

1. A target is an entity ID, never a movement order. A movement order is derived
   from the current state once per decision update.
2. An actor keeps a valid combat target until the state-specific invalidation rule
   occurs. Another generic lane-follow or rally system may not clear it.
3. Every acquisition is deterministic: priority, shortest edge distance, then ID.
4. Only terrain blocks line of sight. Units do not block target acquisition.
5. Dead, allied, hidden, locked, unreachable, and out-of-leash candidates are
   removed before a state is chosen.

## Lane creep and siege catapult

| State | Entry condition | Target priority | Exit condition | Movement |
| --- | --- | --- | --- | --- |
| `LANE_ADVANCE` | Spawned or combat target lost | None | Enemy lane creep in detection radius; next legal structure in detection radius | Next forward waypoint on its own lane |
| `LANE_COMBAT` | Visible enemy lane creep in 600 range | Enemy lane creep, nearest first | Target dead, leaves 850 leash, or cannot be reached | Stop in attack range; otherwise approach target |
| `HERO_RETALIATE` | Nearby allied hero was directly damaged | The attacking hero only | 3 seconds elapse, hero/creep leaves 500 aggro leash, or target dies | Stop in attack range; otherwise approach attacker |
| `STRUCTURE_SIEGE` | No eligible enemy lane creep and next unlocked structure is in detection radius | T1 -> T2 -> T3 -> one unlocked T4 -> core | Structure dies/locks or an enemy lane creep is detected | Stop in attack range; otherwise approach only that next structure |
| `RETURN_TO_LANE` | Hero leash, path, or target validity failed | None | Reaches a forward lane waypoint | Navigate to nearest forward waypoint |

Lane creeps never acquire a hero merely because it is nearby. Catapults have the
same state machine; their only difference is attack profile and building multiplier.
They do not pursue a hero through a tower, beyond the leash, into another lane, or
to a fountain.

## Neutral camp creep

| State | Entry | Exit | Movement |
| --- | --- | --- | --- |
| `IDLE_HOME` | Spawned or returned home | Damaged by a playable-team unit | Hold camp center |
| `RETALIATE` | Damaged by a hero | Target dies, 10 seconds expire, or target leaves 420 camp leash | Approach/attack aggressor |
| `RETURN_HOME` | Retaliation ends or leash breaks | Within 35 units of camp center | Navigate to camp center |

Neutral units never join lane combat and are not auto-selected by lane creep or bot
AI. A full camp respawns only after every member of that camp is dead.

## Tower and core

| State | Priority |
| --- | --- |
| `DEFEND` | Visible enemy lane creep/catapult in attack range, nearest first; then visible hero in range |
| `PROTECT_HERO` | A hero that directly attacked an allied hero inside protection range, provided it remains in tower range |
| `IDLE` | No legal target |

Towers never move. Locked structures may defend but cannot receive damage. The
structure chain is T1 -> T2 -> T3 on each lane, then both T4 guards after all T3s,
then the core.

## Enemy hero bot

The bot has a strict priority state machine; a lower state may not interrupt a
higher one.

| Priority | State | Entry | Exit | Action |
| --- | --- | --- | --- | --- |
| 1 | `DEAD` | Not alive | Respawn | No action |
| 2 | `FOUNTAIN_RECOVER` | HP <= retreat threshold | HP >= recovery threshold while in fountain | Move to fountain; hold there |
| 3 | `EXIT_TOWER_RANGE` | An enemy tower is actively targeting the bot | Bot is outside that tower's range plus safety margin | Move only to the nearest valid point outside that tower's range |
| 4 | `DEFEND_BASE` | Hostile lane creep is within base-defense radius | No such creep remains | Fight that creep; do not rally forward |
| 5 | `LANE_FIGHT` | Visible lane creep is within engagement radius | No lane creep target remains | Fight the nearest eligible creep |
| 6 | `HERO_FIGHT` | Visible enemy hero is in range and the bot is not diving unsupported | Hero invalid/leaves range | Fight hero |
| 7 | `SIEGE` | Next structure is legal and allied creeps cover it | Cover/structure invalid | Attack structure |
| 8 | `RALLY` | No higher-priority condition | Higher-priority condition appears | Follow friendly frontline at fixed trail distance; with no frontline, wait just outside next enemy tower |

The bot does **not** return to its own T2/T3 just because a wave dies. A tower hit
causes only `EXIT_TOWER_RANGE`; it does not become a fountain retreat unless HP is
below the retreat threshold.

## Implementation boundaries

- `scripts/match/lane_creep_ai.gd` exclusively decides and drives lane creeps and catapults.
- `scripts/match/enemy_bot_ai.gd` exclusively decides and drives enemy hero bots.
- `moba_match.gd` is the world adapter: it dispatches by entity kind, supplies world queries, and applies the one resulting movement command.
- `decide_*` functions may choose a state and target, but cannot move an actor.
- `drive_*` functions may issue movement and set `runtime.target_id` only for the
  state decision they receive.
- Damage events may create bounded retaliation facts; they cannot directly issue
  arbitrary movement orders.
- The match tick reads one decision result and applies it once. It does not reread
  and overwrite state using a stale entity dictionary.

## Required regression scenarios

1. Two opposing lane waves that enter 600 range select one another and exchange
   actual combat damage before either advances.
2. When the local enemy wave is dead, allied creeps select the next unlocked tower
   and never a deeper structure.
3. Hero retaliation expires at time/leash and the wave resumes its own lane.
4. A bot hit by a tower exits only the tower radius, then immediately resumes
   `LANE_FIGHT` if an eligible creep remains nearby.
5. A low-health bot recovers at fountain, clears a hostile creep that reached base,
   then returns to its lane.
6. A cleared neutral camp returns as three units on its configured respawn timer.
