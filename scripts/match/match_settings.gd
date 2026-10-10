class_name MatchSettings
extends Resource
@export var wave_interval: float = 20.0
@export var show_draft_on_start: bool = true
@export var creeps_per_lane: int = 3
@export var siege_wave_interval: int = 3
@export var maximum_live_creeps: int = 108
@export var respawn_seconds: float = 8.0
@export var respawn_seconds_per_level: float = 2.0
@export var death_gold_per_level: int = 25
@export var aggro_range: float = 750.0
@export var hero_acquisition_range: float = 1400.0
@export var hero: UnitStats
@export var hero_profiles: Array[HeroGrowth] = []
@export var starting_gold: int = 250
@export var passive_gold_amount: int = 1
@export var passive_gold_interval_seconds: float = 2.0
@export var hero_structure_damage_multiplier: float = 0.5
@export var creep_structure_damage_multiplier: float = 0.65
@export var siege_structure_damage_multiplier: float = 1.0
@export var maximum_level: int = 15
@export var first_level_xp: int = 100
@export var level_xp_increment: int = 50
@export var xp_radius: float = 1000.0
@export var creep_xp: int = 45
@export var creep_gold: int = 20
@export var siege_xp: int = 90
@export var siege_gold: int = 45
@export var hero_xp: int = 100
@export var hero_xp_per_level: int = 40
@export var hero_gold: int = 125
@export var hero_gold_per_level: int = 8
@export var hero_assist_gold: int = 40
@export var hero_assist_gold_per_level: int = 6
@export var hero_credit_seconds: float = 30.0
@export var tower_xp: int = 150
@export var tower_gold: int = 250
@export var sell_refund: float = 0.5
@export var fountain_radius: float = 300.0
@export var fountain_hp_fraction_per_second: float = 0.20
@export var fountain_mana_fraction_per_second: float = 0.25
@export var melee_creep: UnitStats
@export var ranged_creep: UnitStats
@export var siege_creep: UnitStats
@export var tower: UnitStats
@export var core: UnitStats

func respawn_duration(level: int) -> float:
	return maxf(0, respawn_seconds) + maxf(0, respawn_seconds_per_level) * maxi(0, level - 1)
