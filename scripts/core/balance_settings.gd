class_name BalanceSettings
extends Resource

@export var hp_per_strength: float = 20.0
@export var hp_regen_per_strength: float = 0.05
@export var armor_per_agility: float = 0.15
@export var magic_armor_per_intelligence: float = 0.15
@export var mana_per_intelligence: float = 12.0
@export var mana_regen_per_intelligence: float = 0.04
@export var primary_damage_enabled: bool = true
@export var primary_damage_coefficient: float = 1.0
@export var armor_coefficient: float = 0.06
@export var attack_speed_per_agility: float = 0.005
@export var minimum_attack_speed: float = 0.3
@export var maximum_attack_speed: float = 4.2
@export var maximum_attack_speed_multiplier: float = 7.0
@export var minimum_attack_interval: float = 0.1
@export var evasion_cap: float = 0.75
@export var multiplicative_evasion: bool = true
@export var default_critical_multiplier: float = 2.0
@export var status_resistance_cap: float = 0.6
@export var minimum_movement_speed: float = 100.0
@export var unit_radius: float = 32.0
@export var projectile_lifetime_seconds: float = 30.0
## Experimental timeout for passive/stalemate scenarios; returns a draw.
@export var battle_time_limit_seconds: float = 180.0
