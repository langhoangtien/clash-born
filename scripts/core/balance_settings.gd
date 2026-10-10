class_name BalanceSettings
extends Resource

@export var hp_per_strength: float = 20.0
@export var hp_regen_per_strength: float = 0.05
@export var armor_per_agility: float = 0.15
@export var magic_armor_per_intelligence: float = 0.15
@export var mana_per_intelligence: float = 12.0
@export var mana_regen_per_intelligence: float = 0.04
@export var primary_damage_enabled: bool = true
@export var primary_damage_coefficient: float = 0.7
@export var armor_coefficient: float = 0.06
## Phase 2 fixed cadence. Configurable attack speed is deferred to Phase 3.
@export var basic_attack_interval_ticks: int = 30
