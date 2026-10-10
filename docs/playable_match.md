# Playable local MOBA match

Open `project.godot` and press F5. Default scene:
`scenes/match/moba_match.tscn`. The player is Blue; one Red hero bot follows MID.
Combat Sandbox and the navigation-only Map Prototype remain accessible from the
top-left buttons, and both have a button returning to this match.

## Controls and match rules

| Control | Action |
| --- | --- |
| WASD / arrows / bottom-left four buttons | Move continuously with terrain collision |
| J / bottom-right creep button | Acquire enemy creep, then tower/core if no creep is nearby |
| K / hero button | Acquire enemy hero only |
| Click enemy | Lock that specific target |
| Space / move | Cancel automatic attack/approach |
| Right click ground / Ra MID | Navigate to point / allied MID approach |
| Tab / Trang bị hai đội | Inspect live enemy/player equipment icons and stats |
| B / Shop–Hero | Buy/craft/sell items, inspect full stats, upgrade passive |
| P | Pause/resume movement, combat and timers |
| F | Follow player camera |
| Middle drag / wheel / click minimap | Pan / zoom / inspect map location |
| Chơi lại | Restart with fresh units, timers and score |

Attack commands approach the target if necessary, stop within collision-edge
attack range, and repeat basic attacks until cancelled. A move command cancels
auto attack; mobile-style touch movement uses independent finger tracking.
Native touchscreen input is covered by synthetic events; an actual mobile build
has not been exported or tested.

Creeps spawn immediately, then every 20 simulation seconds: two melee and one
ranged unit for each of TOP/MID/BOT, for both teams. Waves 1/4/7/... also add
one siege catapult to every team/lane. At most 108 live creeps can
exist; a wave is skipped if the full wave would exceed the cap. Twelve towers and
two cores attack within range/terrain line-of-sight, preferring creeps over heroes.
Hero death awards the opposing team a kill; heroes respawn at their bases after
8 + 2 × (level − 1) seconds, losing up to 25 × level unspent gold. Dead creeps are removed from the live scene and combat list.
Destroy the opposing core to win. The result freezes combat/movement and offers
restart. Hero deaths and creep losses alone do not end the match.

## Configuration and integration

`data/match/default_match.tres` uses the small `MatchSettings` Resource for wave
size/interval/cap, respawn delay, acquisition distances and six UnitStats profiles.
`data/maps/moba_foundation.tres` still supplies terrain, lanes, spawns and tower
markers. Core positions and tower team assignment currently follow the default
40x40 map's authored orientation; a different map should update those placements
in `moba_match.gd` too.

One existing CombatEngine handles HP, regen, attack cooldown, seeded hit/crit,
mitigation, effects and projectile impact. Dynamic units register with the same
metrics. External control accepts positions/targets from the map instead of using
arena steering or arena victory rules. All scene actors and views share the same
UnitRuntimeState. Native Godot physics performs continuous map movement; a 30 Hz
clock advances combat and match timers. Full map replay across different physics
schedules is not promised; the Sandbox replay contract remains unchanged.

## Modified files

New files:

- `scripts/match/match_settings.gd`
- `scripts/match/moba_match.gd`
- `scripts/match/battle_controls.gd`
- `scripts/match/match_minimap.gd`
- `data/match/default_match.tres`
- `scenes/match/moba_match.tscn`
- `tests/test_playable_match.gd`
- `docs/playable_match.md`
- Godot-generated `.gd.uid` companions for the new scripts/tests.

Existing files updated:

- `project.godot`: default scene is the playable match.
- `scripts/core/combat_engine.gd`: external control and dynamic registration.
- `scripts/simulation/combat_metrics.gd`: register units after initial setup.
- `scripts/map/map_unit.gd`: accept shared navigation/runtime.
- `scripts/map/map_camera.gd`: optional arrow-key pan, disabled in match.
- `scripts/map/map_prototype.gd`: enter match button.
- `scripts/ui/sandbox_controller.gd`: enter match button.
- `scripts/units/combat_unit.gd`: rectangular buildings/compact creep visuals.
- `README.md`, `DESIGN.md`, `docs/combat_formulas.md`: current behavior and controls.

## Executed verification

Godot 4.7.2 stable, Windows, Compatibility renderer, NVIDIA RTX 3060:

- `test_playable_match.gd`: 66 checks headless, 67 with real renderer/capture,
  zero failures. Includes dynamic units, all six team/lane creep groups,
  continuous native movement and actual keyboard polling/release, four-direction controls, independent touch fingers,
  separate attack categories, actual projectile damage, tower creep priority,
  wave timing/cap, pause, lethal hero damage/respawn, input, core victory and a
  live autonomous physics run with terrain-clearance checks.
- Regression headless suites Phase 1/2/3/4/5/6:
  23 / 112 / 170 / 645 / 170 / 690 checks, zero failures.
- Range/projectile regression: 93 checks, zero failures.
- `.local/playable-match.png` captured through the actual renderer and inspected.
- Editor import and the default match scene executed successfully; the scene ran
  180 frames with the real renderer, exit code 0 and no runtime/leak errors.

## Remaining limitations

This is a local 1v1 prototype with basic geometry. It has no 5v5 roster,
multiplayer, skill buttons or jungle objectives. Hero selection, progression and
shop economy are now available; see `progression_shop.md`.
Units do not avoid/block each other; buildings do not physically obstruct units.
Tower priority has no special retaliation rule for attacking an allied hero.
There is no tower-before-core invulnerability rule. Historical per-creep metrics
are retained for the session, so very long matches still accumulate metric entries.
Balance is experimental. The next useful step is hero skill controls and a simple
cooldown UI, followed by tuning tower/creep aggro and damage.

Latest balance/navigation/icon changes: `match_balance.md`.

Siege tuning, shared XP and level-scaled kill/assist/team gold: `docs/siege_rewards.md`.

Player auto-attack can approach reachable targets around terrain; see `docs/death_lane_attacks.md`.

A fresh match first pauses at hero/passive selection. Match heroes use BAT 2.0,
320 opening move speed and a 500% AS cap; tower range is 600. Item recipes and
passive ranks are documented in `docs/late_game_items_passives.md`.
