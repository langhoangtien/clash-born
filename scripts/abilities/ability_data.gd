class_name AbilityData
extends Resource

enum TargetType { ENEMY, DIRECTIONAL, GROUND }
@export var id: String = ""
@export var display_name: String = ""
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
## Zero inherits the unit's Cast Range; positive values override its base.
@export var cast_range: float = 0.0
@export var effect_radius: float = 250.0
@export var uses_projectile: bool = false
@export var projectile_speed: float = 900.0
@export var projectile_hit_behavior: CombatProjectile.HitBehavior = CombatProjectile.HitBehavior.HOMING
@export var projectile_dead_target_behavior: CombatProjectile.DeadTargetBehavior = CombatProjectile.DeadTargetBehavior.CANCEL
@export var cast_time: float = 0.0
@export var target_type: TargetType = TargetType.ENEMY
@export var effects: Array[AbilityEffectData] = []
