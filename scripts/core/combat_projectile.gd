class_name CombatProjectile
extends RefCounted
## Simulation-only projectile. Rendering reads position, never advances it.
enum HitBehavior { HOMING, FIXED_POSITION }
enum DeadTargetBehavior { CANCEL, CONTINUE_TO_POSITION }

var id: int
var source_id: String
var target_id: String
var position: Vector2
var destination: Vector2
var speed: float = 900.0
var hit_behavior: HitBehavior = HitBehavior.HOMING
var dead_target_behavior: DeadTargetBehavior = DeadTargetBehavior.CANCEL
var launch_tick: int
var expires_tick: int
var payload: Dictionary

func advance(target: UnitRuntimeState) -> bool:
	if hit_behavior == HitBehavior.HOMING and target != null and target.alive:
		destination = target.position
	var delta := destination - position
	var contact_radius: float = target.stats.collision_radius if target != null and target.alive and hit_behavior == HitBehavior.HOMING else 0.0
	var travel := speed * SimulationClock.TICK_SECONDS
	if delta.length() <= travel + contact_radius + 0.000001:
		position = destination if delta.length() <= contact_radius else position + delta.normalized() * maxf(0, delta.length() - contact_radius)
		return true
	position += delta.normalized() * travel
	return false
