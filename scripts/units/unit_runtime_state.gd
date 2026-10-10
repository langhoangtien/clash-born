class_name UnitRuntimeState
extends RefCounted

var unit_id: String
var team_id: int
var position: Vector2
var stats: Dictionary
var current_hp: float
var current_mana: float
var alive: bool = true
var next_attack_tick: float = 1.0
var effects := StatusEffectManager.new()
var current_tick: int = 0
var display_name: String
var ai_enabled: bool = false
var ai_mode: int = 1
var target_id: String = ""
var abilities: Array[AbilityData] = []
var ability_ready_ticks: Dictionary = {}
var casting: Dictionary = {}
## Map-only siege rules; defaults leave sandbox damage unchanged.
var is_structure: bool = false
var structure_damage_multiplier: float = 1.0
var passive_id: String = ""
var passive_level: int = 0
var permanent_damage_bonus: float = 0.0
var fury_stacks: int = 0
var fury_expires_tick: int = 0

func _init(id: String, team: int, spawn: Vector2, source: UnitStats, balance: BalanceSettings, equipment: Array[EquipmentData] = []) -> void:
	unit_id = id
	display_name = source.display_name
	ai_mode = source.ai_mode
	abilities.assign(source.abilities)
	if not source.abilities_enabled: abilities.clear()
	team_id = team
	position = spawn
	stats = StatCalculator.calculate(source, balance, equipment)
	current_hp = stats.max_hp
	current_mana = stats.max_mana

func can_act() -> bool:
	return alive and not effects.is_stunned()

func can_move() -> bool:
	return can_act()

func can_cast() -> bool:
	return can_act()

func movement_speed(balance: BalanceSettings) -> float:
	if not can_move():
		return 0.0
	return maxf(balance.minimum_movement_speed, stats.movement_speed * (1 - effects.strongest_slow()))

func physical_armor() -> float:
	return stats.physical_armor - effects.armor_reduction()

func attack_speed() -> float:
	var fury_bonus := fury_stacks * 0.10 * passive_level if passive_id == "fury" and current_tick < fury_expires_tick else 0.0
	var result: float = stats.attack_speed * (1.0 + fury_bonus) * (1.0 - effects.strongest_attack_slow())
	return clampf(result, 0.1, stats.get("attack_speed_cap", 999.0))

func attack_range() -> float:
	return maxf(0, stats.attack_range + effects.range_bonus(StatusEffect.Kind.ATTACK_RANGE))

func cast_range(ability: AbilityData = null) -> float:
	var base: float = stats.cast_range
	if ability != null and ability.cast_range > 0:
		base = ability.cast_range + stats.cast_range_bonus
	return maxf(0, base + effects.range_bonus(StatusEffect.Kind.CAST_RANGE))

## Edge-to-edge distance. Ground points have radius zero.
func distance_to_unit(target: UnitRuntimeState) -> float:
	return maxf(0, position.distance_to(target.position) - stats.collision_radius - target.stats.collision_radius)

func distance_to_point(point: Vector2) -> float:
	return maxf(0, position.distance_to(point) - stats.collision_radius)
