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

func _init(id: String, team: int, spawn: Vector2, source: UnitStats, balance: BalanceSettings, equipment: Array[EquipmentData] = []) -> void:
	unit_id = id
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
