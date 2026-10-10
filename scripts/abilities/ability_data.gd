class_name AbilityData
extends Resource

enum TargetType { ENEMY }
@export var id: String = ""
@export var display_name: String = ""
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
@export var cast_range: float = 300.0
@export var cast_time: float = 0.0
@export var target_type: TargetType = TargetType.ENEMY
@export var effects: Array[AbilityEffectData] = []
