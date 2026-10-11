class_name UnitStats
extends Resource
## Source data only. Runtime damage never mutates this Resource.

enum PrimaryAttribute { NONE, STRENGTH, AGILITY, INTELLIGENCE }

@export var display_name: String = "Unit"
@export_enum("Passive", "Attack nearest", "Attack lowest HP", "Attack highest damage") var ai_mode: int = 1
@export var abilities: Array[AbilityData] = []
@export var abilities_enabled: bool = true

@export var strength: float = 0.0
@export var agility: float = 0.0
@export var intelligence: float = 0.0
@export var primary_attribute: PrimaryAttribute = PrimaryAttribute.NONE
@export var primary_damage_enabled: bool = true
@export var base_hp: float = 1000.0
@export var base_mana: float = 0.0
@export var base_hp_regen: float = 0.0
@export var base_mana_regen: float = 0.0
@export var physical_damage: float = 0.0
@export var magic_damage: float = 0.0
@export var pure_damage: float = 0.0
@export var physical_armor: float = 0.0
@export var magic_armor: float = 0.0
@export var attack_range: float = 150.0
@export var cast_range: float = 700.0
@export var collision_radius: float = 32.0
@export var ranged_attacks: bool = false
@export var projectile_speed: float = 900.0
@export var projectile_hit_behavior: CombatProjectile.HitBehavior = CombatProjectile.HitBehavior.HOMING
@export var projectile_dead_target_behavior: CombatProjectile.DeadTargetBehavior = CombatProjectile.DeadTargetBehavior.CANCEL
## Probabilities/bonuses use fractions: 0.30 means 30 percent.
@export var base_attacks_per_second: float = 1.0
@export var attack_speed_bonus: float = 0.0
@export var movement_speed: float = 300.0
## Hero vision radius in world units. Equipment/effects can be extended later.
@export var vision_range: float = 1200.0
@export var evasion: float = 0.0
@export var evasion_sources: Array[float] = []
@export var accuracy: float = 0.0
@export var critical_chance: float = 0.0
## Zero uses the central balance default.
@export var critical_multiplier: float = 0.0
@export var status_resistance: float = 0.0
@export var armor_reduction: float = 0.0
@export var magic_armor_reduction: float = 0.0
@export var physical_armor_penetration: float = 0.0
@export var attacks_can_miss: bool = true
@export var attacks_can_crit: bool = true
@export var pure_attacks_can_crit: bool = false
