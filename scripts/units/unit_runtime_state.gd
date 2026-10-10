class_name UnitRuntimeState
extends RefCounted

var unit_id: String
var team_id: int
var position: Vector2
var stats: Dictionary
var current_hp: float
var current_mana: float
var alive: bool = true
var next_attack_tick: int = 1

func _init(id: String, team: int, spawn: Vector2, source: UnitStats, balance: BalanceSettings) -> void:
	unit_id = id
	team_id = team
	position = spawn
	stats = StatCalculator.calculate(source, balance)
	current_hp = stats.max_hp
	current_mana = stats.max_mana
