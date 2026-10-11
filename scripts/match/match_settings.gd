class_name MatchSettings
extends Resource
@export var wave_interval: float = 20.0
@export var show_draft_on_start: bool = true
@export var creeps_per_lane: int = 3
@export var siege_wave_interval: int = 3
@export var maximum_live_creeps: int = 36
@export var respawn_seconds: float = 8.0
@export var respawn_seconds_per_level: float = 2.0
@export var death_gold_per_level: int = 25
@export var aggro_range: float = 750.0
@export var hero_acquisition_range: float = 1400.0
@export var player_target_range: float = 1200.0
@export var player_structure_target_range: float = 1200.0
@export var player_target_leash: float = 1000.0
@export var hero: UnitStats
@export var hero_profiles: Array[HeroGrowth] = []
@export var starting_gold: int = 250
@export var passive_gold_amount: int = 1
@export var passive_gold_interval_seconds: float = 2.0
@export var hero_structure_damage_multiplier: float = 0.5
@export var creep_structure_damage_multiplier: float = 0.65
## Catapults are the lane's intended building breaker.
@export var siege_structure_damage_multiplier: float = 1.25
## Towers use this multiplier only when their target is a siege creep.
@export_range(0.0, 1.0) var tower_damage_to_siege_multiplier: float = 0.55
## Tier stats are applied to each spawned tower runtime. T1 is outer; T4 guards the throne.
@export var tower_t1_hp: float = 3200.0
@export var tower_t2_hp: float = 3500.0
@export var tower_t3_hp: float = 3800.0
@export var tower_t4_hp: float = 4200.0
@export var tower_t1_damage: float = 155.0
@export var tower_t2_damage: float = 195.0
@export var tower_t3_damage: float = 235.0
@export var tower_t4_damage: float = 275.0
@export var maximum_level: int = 20
@export var first_level_xp: int = 100
@export var level_xp_increment: int = 50
@export var xp_radius: float = 1000.0
@export var creep_xp: int = 45
@export var creep_gold: int = 40
@export var ranged_creep_gold: int = 50
@export var siege_xp: int = 90
@export var siege_gold: int = 75
@export var hero_xp: int = 100
@export var hero_xp_per_level: int = 40
@export var hero_gold: int = 250
@export var hero_gold_per_level: int = 16
@export var hero_assist_gold: int = 80
@export var hero_assist_gold_per_level: int = 12
@export var hero_credit_seconds: float = 30.0
@export var tower_xp: int = 150
@export var tower_gold: int = 250
@export var sell_refund: float = 0.5
@export var fountain_radius: float = 250.0
@export var fountain_hp_fraction_per_second: float = 0.20
@export var fountain_mana_fraction_per_second: float = 0.25
## Opponent AI tuning. Tower dive is deliberately disabled by default.
@export var enable_tower_dive: bool = false
@export_range(0.0, 1.0) var bot_retreat_hp_fraction: float = 0.28
@export_range(0.0, 1.0) var bot_recover_hp_fraction: float = 0.72
@export var bot_chase_range: float = 1100.0
## Bot rallies behind its own frontline but will not advance beyond this lane anchor.
@export_range(0.0, 0.5) var bot_frontline_trail_fraction: float = 0.18
@export_range(0.0, 0.5) var bot_tower_anchor_backoff_fraction: float = 0.10
@export var bot_lost_target_ticks: int = 45
@export var bot_decision_ticks: int = 6
@export var bot_tower_safety_margin: float = 90.0
## Lane creep target and return behavior, in world units / simulation ticks.
@export var creep_detection_range: float = 600.0
@export var creep_hero_protection_range: float = 600.0
@export var creep_chase_limit: float = 850.0
@export var creep_lost_target_ticks: int = 24
@export var creep_unreachable_ticks: int = 90
@export var creep_reacquire_ticks: int = 18
@export var creep_target_scan_ticks: int = 6
## Towers acquire hostile creeps before heroes inside these world-unit ranges.
@export var tower_protection_range: float = 700.0
@export var melee_creep: UnitStats
@export var ranged_creep: UnitStats
@export var siege_creep: UnitStats
@export var tower: UnitStats
@export var core: UnitStats

func respawn_duration(level: int) -> float:
	return maxf(0, respawn_seconds) + maxf(0, respawn_seconds_per_level) * maxi(0, level - 1)
