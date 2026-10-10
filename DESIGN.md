# Clashborn — Range & Projectile System

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
No multiplayer, fog of war, pathfinding, new heroes, MOBA map or Phase 6 features.
