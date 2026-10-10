# Clashborn — Combat Sandbox and Phase 6 Map Foundation

Extend the existing 30 Hz engine, AI, ability resources, equipment aggregation,
status effects and combat events. No rendering code decides hits or movement.

## Distance convention

Units are disks with a configurable `UnitStats.collision_radius` (default 32).
Attack and targeted cast distance is `max(0, center distance - source radius -
target radius)`. Ground/directional cast distance is `max(0, center-to-point
distance - source radius)`. Inclusive boundaries use a 0.000001 tolerance.
Separation and arena bounds use these same per-unit radii.

Selected unit rings mark reach from its collision edge: attack ring is white,
cast ring is blue. A target disk may intersect a ring while its center is outside.
Ability-specific positive cast overrides have additional blue rings.

| Setting | Initial value | Configuration |
| --- | ---: | --- |
| Melee attack range | 150 | UnitStats / Stats tab |
| Ranged attack range | 550 | Ranged Carry and Mage / Stats tab |
| Unit cast range | 700 | UnitStats / Stats tab |
| Projectile speed | 900 units/s | UnitStats or AbilityData |
| Ability effect radius | 250 | AbilityData |
| Projectile lifetime | 30 simulation seconds | BalanceSettings |

`ranged_attacks` selects projectile delivery independently of attack range.
Existing formula-only duel fixtures explicitly retain their former 700 range.

## Range and AI

Final Attack Range = max(0, base + equipment + active ATTACK_RANGE modifiers).
Final Cast Range = max(0, base + equipment + active CAST_RANGE modifiers).
`AbilityData.cast_range = 0` inherits unit cast range; a positive override replaces
only the unit base, retaining equipment and temporary cast bonuses. The three
existing abilities now inherit 700 by default. Range modifiers can be negative.
Status refresh/expiration reuses the existing manager, never edits source stats.
Range Lens grants +100 attack range; Cast Focus grants +150 cast range.

AI approaches the first ready, affordable ability's valid range, otherwise basic
attack range. It stops on reaching that edge distance; range is revalidated at
attack launch, cast start and cast completion. Stun/cast locks are preserved.
There is no range recheck after projectile launch: a homing shot can chase beyond
its original attack/cast range. Lifetime bounds this pursuit.

## Projectile resolution

`CombatProjectile` stores identity, position, destination, speed, lifetime and a
payload. Engine reset clears projectiles and resets IDs. Each existing projectile
advances `speed / 30` per tick after movement. Newly launched shots first move on
the next tick, even at very high speed. Melee resolves instantly through the same
attack resolver used by projectile impacts.

- HOMING updates destination to the living target's center and impacts at its
  collision edge. A stationary shot travels edge-to-edge distance.
- FIXED_POSITION travels to the target's launch position. At arrival the original
  target must still overlap that point; otherwise emit projectile_evaded. No
  retargeting or interception by other units.
- Dead-target policy CANCEL removes the shot on the next tick. CONTINUE_TO_POSITION
  finishes its flight to the last destination and does no damage to dead targets.
- Source death does not cancel a launched shot. Elimination waits for remaining
  shots so a posthumous hit can cause a draw. The global timeout still takes priority.

For a stationary homing target, travel ticks are
`max(1, ceil(edge_distance / speed * 30))`. Fixed-position shots additionally
travel through the target radius to the captured point. Lifetime expiration is
checked before movement and emits projectile_canceled.

Attack offense is snapshotted at launch; current target armor, evasion and status
effects are read at impact. Seeded hit/crit rolls occur at impact, followed by the
existing damage formulas. Attack cooldown is spent at launch even if the shot is
later canceled or evaded. Damage is collected before HP application, retaining
same-tick mutual kills. Metrics count resolved attacks rather than projectile launches.

Events: projectile_launched, projectile_impact, projectile_canceled (each with ID),
projectile_evaded, followed by existing attack/miss/damage/effect events as applicable.
Primitive circles/trails read engine positions. Pause freezes simulation; speed
only changes tick throughput. Renderer delta never enters projectile calculations.

## Ability definitions

- ENEMY: original single-target enemy effect; target is rechecked at cast completion.
- GROUND: captured world point; affect enemy disks intersecting the radius there.
- DIRECTIONAL: captured point defines a finite segment from cast completion origin
  to that point. Affect enemy disks intersecting its capsule (effect_radius is
  half-width). A zero-length segment becomes a disk.

Ground/directional points are captured at cast start. Instant abilities resolve
at completion. Projectile variants travel to the endpoint and resolve the entire
disk/capsule at arrival using current enemy positions. They do not retarget or
apply effects along the flight path before arrival. These are definition modes,
not new heroes. Existing abilities still apply status effects, without adding
ability damage. Friendly and dead units are excluded.

`queue_cast(source_id, ability_index, target_id, point)` accepts next-tick commands
with the same mana/cooldown/range validation as AI. Ground/directional commands
may use an empty target ID. Out-of-range commands are rejected rather than queued
indefinitely; AI movement provides automatic approach. Existing debug queue_effect
continues to intentionally bypass ability costs/range.

## Verification and scope

`tests/test_range_projectiles.gd` covers boundaries/radii, equipment, temporary
modifiers, AI approach/stop, all targeting geometries, projectile timing/damage,
moving/dead targets, source death, lifetime/reset/pause/single-step, armor/crit/miss,
and seeded replay with tick commands at all four simulation speeds. Run all five
existing phase suites as regression checks; `-- --capture` checks real rendering.

Current HP/Mana regeneration, combat formulas and status rules are preserved.
This checkout does not yet contain Phase 4.5 lifesteal/spell vamp/central healing;
the separate attached Phase 4.5 prompt is outside this range/projectile change.
The range/projectile subsystem adds no multiplayer, fog of war or new heroes.

## Phase 6 — MOBA Map Foundation

The user's Phase 6 is **MOBA Map Foundation**, replacing the older master prompt's
Phase 6 Balance Laboratory label. No laboratory, creep/tower combat or later phases
are implemented. `scenes/main.tscn` remains the Combat Sandbox entry point;
its Map Prototype button opens `scenes/map/map_prototype.tscn`, with a return button.

### Data and terrain

`data/maps/moba_foundation.tres` is a MapLayout Resource: 40 × 40 authored cells,
128 units per tile, yielding a 5120 × 5120 world. It stores explicit terrain rows,
symbol definitions (color/walkability), three waypoint arrays, five spawn cells
per team, two base rectangles and twelve empty tower placement markers.
Dimensions/tile size and all authoring data are editable without gameplay code.
Rows must match dimensions; validation reports malformed data.

Blue base is bottom-left, Red base top-right. TOP wraps the top-left corner;
MID crosses diagonally; BOT wraps the bottom-right corner. The river runs from
top-left to bottom-right through the center, separating the team halves.
Jungle passages connect lanes; rock clusters and the outer wall block traversal.
All map visuals are colored cells, rectangles, lines and circles.

Each lane has its own waypoint data. Blue visits it in stored order; Red visits
the same lane in reverse. MapLayout converts cells to world positions. Spawns,
waypoints and markers therefore scale with tile size. This prototype creates two
navigation probes, with existing Physical Tank/Ranged Carry stats and combat-unit
views; there are no new hero definitions or combat participants on the map.

### Navigation and collision

MapNavigation uses Godot's [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html),
configured once per agent radius. Blocked terrain and insufficient center clearance
become solid cells. Diagonals require both adjacent cells to be clear, preventing
corner cutting. Lane traversal concatenates A* legs through every lane waypoint.
Right-click requests a path to the exact world position; blocked/unreachable
destinations are rejected. There is no per-frame path rebuild or dynamic avoidance.

MapUnit is a CharacterBody2D with a circular shape matching UnitRuntimeState's
collision radius. It moves continuously through world-space path points using
the existing runtime movement-speed/can-move methods. Terrain physics rectangles
are generated from the same MapLayout rows (horizontal blocked runs are merged),
plus four exterior boundary walls. Collision prevents crossing obstacles even
under manual WASD control or high velocity. Camera/rendering never changes paths.
The existing CombatAI arena steering and combat formulas are unchanged.

This map uses Godot physics ticks for navigation probes; it does not run a second
CombatEngine, simulate damage, regenerate resources or claim authoritative
multiplayer determinism. Future combat integration should connect map navigation
to the existing engine deliberately; this phase only establishes the map foundation.

### Camera and debug controls

Map camera supports middle-drag/arrow-key pan, wheel zoom (0.15–1.6), selected-unit
follow and viewport-aware clamping. Manual pan disables follow. F toggles follow;
O/Overview fits the map. When a zoomed-out viewport is larger than the map on an
axis, that axis stays centered and background margins remain visible. Fit view
may go below the manual minimum for differently sized maps/windows. Camera state
is independent of combat and probe navigation.

Optional overlays: tile grid, walkable/blocked cells, lane waypoints with both
team order indices, active navigation paths, unit collision circles, base spawn
points and empty tower markers. Only spawn/tower markers are enabled initially.
Controls also select a probe, send it along TOP/MID/BOT, stop, reset and pause movement.

Tests cover layout/routes, both team routes through physical collision, base/jungle
reachability, non-cell-center movement, high-speed wall collision, pause, differing
map sizes, larger agents, camera follow/pan/zoom/clamp, actual desktop input events,
all seven overlays and scene transitions. See `docs/phase6_map.md` for execution
results, modified-file inventory and known limitations.


## Playable local match (subsequent requested extension)

Default entry is now `scenes/match/moba_match.tscn`. The Phase 6 navigation-only
scene and the existing Combat Sandbox remain separate modes. One player controls
Blue with WASD/arrows/on-screen four directions; Red has a simple MID hero bot.
Two melee and one ranged creep per lane/team spawn every 20 simulation seconds.
Twelve authored tower markers become stationary towers; two cores determine victory.
Hero deaths schedule an eight-second respawn, rather than ending the match.

`MatchSettings` and `data/match/default_match.tres` hold prototype stats and timers.
`moba_match.gd` owns waves, target priorities, routes, respawn, input and core victory.
It reuses MapLayout, per-radius cached MapNavigation, MapUnit and CombatUnit.
Each actor/view uses the exact UnitRuntimeState registered in the existing engine.
`CombatEngine.external_control` accepts map-supplied positions/targets and bypasses
arena AI movement/target selection and arena elimination/timeout. Default false
preserves Sandbox behavior. `add_unit` also registers dynamic participants in metrics;
dead creeps leave the live unit list, while historical metrics are retained.

Damage, seeded hit/crit, attack range/cooldown, projectile flight, regen and status
processing remain in the single engine at 30 Hz. The map controller does not
implement alternate damage formulas. Godot CharacterBody2D movement remains on
native physics ticks, then supplies positions for combat ticks. This local map
mode does not promise replay determinism across differing physics schedules;
the pure Sandbox deterministic replay contract remains unchanged. Pause freezes
both native movement and the engine clock/wave/respawn timers.

Target selection uses collision-edge distance and terrain line-of-sight. Creeps
prefer creeps then heroes/buildings; towers/cores prefer creeps then heroes.
The player has separate creep/structure and hero acquisition categories; moving
cancels automatic approach/attack. Clicking an enemy locks that unit. Minimap,
HP, kill score, wave count, floating damage, respawn and victory UI show match state.
Touch direction tracking is independent per finger; desktop keyboard remains
supported. Camera arrow pan is disabled only in this mode so arrows control hero.

The initial playable iteration omitted hero equipment/shop UI and rewards;
those are now implemented in the progression extension below. Hero skills, jungle objectives, dynamic
unit avoidance, structure body blocking, invulnerability progression, team 5v5 or
networking are introduced. Tower aggro does not include hero-on-hero retaliation.
Prototype balance is configurable and not tuned as a finished MOBA.
See `docs/playable_match.md` for controls, changed files and executed verification.


## Hero progression and match shop

HeroGrowth Resources supply three selectable prototype profiles (ranger/tank/mage),
base overrides and numeric UnitStats growth per level. HeroProgression maintains
level, local XP, gold and the existing six-slot EquipmentManager for each hero.
It builds a fresh source at each level, then calls the existing StatCalculator
with equipment. No combat formula or hit/projectile system is duplicated.
Recalculation preserves HP/Mana fractions, death state, position, target, effects
and cooldowns. Level/equipment persist through respawn; new matches reset them.

Nearby living opposing heroes receive XP on creep/hero/tower death, regardless
of last hitter; only a hero landing the final damaging hit receives kill gold.
Income runs once per simulation second; pause stops it. Defaults are starting
1000 gold, 3 gold/second, XP radius 1000, maximum level 15. XP for the next level
is 100 + 50*(level-1); overflow can grant several levels. Death rewards and growth
are configurable Resources. Bots receive XP/income but do not shop yet.

Match shop uses the original 14-item catalog. Buy validates item, funds, unique
item rules and free slot before subtracting gold/equipping; sell refunds floor
of price times 0.5. It is accessible anywhere, including while dead/paused, but
blocked after victory. Opening it stops player movement/attack; combat continues
unless explicitly paused. A hero dropdown starts a fresh match with the chosen
profile. Sandbox equipment selectors retain their separate reference-price behavior.
See `docs/progression_shop.md` for controls, files and executed tests.
