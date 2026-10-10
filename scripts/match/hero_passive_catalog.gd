class_name HeroPassiveCatalog
extends RefCounted
## Fixed hero-skill definitions. Every named hero owns one skill with five ranks.

const DEFINITIONS: Array[Dictionary] = [
	{"id": "base_power", "name": "Sức Mạnh Căn Bản", "description": "+15/20/25/30/35% base damage"},
	{"id": "soul_hunter", "name": "Săn Linh Hồn", "description": "kill creep +1–3, hero +5–13 damage; giới hạn tăng theo cấp"},
	{"id": "long_shot", "name": "Tầm Bắn", "description": "+80/120/160/200/240 Attack Range"},
	{"id": "pure_throw", "name": "Phi Tiêu Pure", "description": "mỗi đòn thêm 20/25/30/35/40% base damage pure"},
	{"id": "fury", "name": "Cuồng Tốc", "description": "đánh trúng +10/12.5/15/17.5/20% AS trong 6 giây, tối đa 10 stack"},
	{"id": "bat_mastery", "name": "Nhịp Chiến", "description": "giảm BAT còn 1.9/1.8/1.7/1.6/1.5 giây"},
	{"id": "melee_bash", "name": "Bash Cận Chiến", "description": "20% choáng 1.5 giây, bonus 30/40/50/60/70"},
	{"id": "iron_skin", "name": "Da Sắt", "description": "+6/8/10/12/14 giáp"},
	{"id": "giant_strength", "name": "Cường Lực", "description": "+20/30/40/50/60 STR"},
	{"id": "wind_agility", "name": "Nhanh Nhẹn", "description": "+20/30/40/50/60 AGI"},
	{"id": "assassin", "name": "Sát Thủ", "description": "15–35% crit, hệ số 2.0–3.0"},
	{"id": "feast", "name": "Xé Thịt", "description": "đòn đánh thêm 1.5–3.5% max HP mục tiêu thành pure damage"},
]

static func definition(id: String) -> Dictionary:
	for entry in DEFINITIONS:
		if entry.id == id: return entry
	return DEFINITIONS[0]

static func id_at(index: int) -> String:
	return DEFINITIONS[clampi(index, 0, DEFINITIONS.size() - 1)].id

static func apply(stats: Dictionary, source: UnitStats, id: String, level: int, permanent_damage: float) -> void:
	if level <= 0:
		stats.physical_damage += permanent_damage
		return
	var rank := clampi(level, 1, 5)
	stats.physical_damage += permanent_damage
	stats.passive_pure_fraction = 0.0
	stats.passive_max_hp_fraction = 0.0
	stats.passive_bash_chance = 0.0
	stats.passive_bash_duration = 0.0
	stats.passive_bash_damage = 0.0
	stats.passive_fury_per_stack = 0.0
	match id:
		"base_power": stats.physical_damage += source.physical_damage * [0.15, 0.20, 0.25, 0.30, 0.35][rank - 1]
		"long_shot": stats.attack_range += [80.0, 120.0, 160.0, 200.0, 240.0][rank - 1]
		"pure_throw": stats.passive_pure_fraction = [0.20, 0.25, 0.30, 0.35, 0.40][rank - 1]
		"fury": stats.passive_fury_per_stack = [0.10, 0.125, 0.15, 0.175, 0.20][rank - 1]
		"bat_mastery":
			var new_bat: float = [1.9, 1.8, 1.7, 1.6, 1.5][rank - 1]
			var old_base: float = maxf(stats.base_attacks_per_second, 0.001)
			var speed_multiplier: float = stats.attack_speed / old_base
			var new_base := 1.0 / new_bat
			stats.base_attack_time = new_bat
			stats.base_attacks_per_second = new_base
			stats.attack_speed_cap = new_base * 5.0
			stats.attack_speed = minf(stats.attack_speed_cap, new_base * speed_multiplier)
		"melee_bash":
			stats.passive_bash_chance = 0.20
			stats.passive_bash_duration = 1.5
			stats.passive_bash_damage = 20.0 + 10.0 * rank
		"iron_skin": stats.physical_armor += 4.0 + 2.0 * rank
		"giant_strength":
			var amount := 10.0 + 10.0 * rank
			stats.strength += amount
			stats.max_hp += amount * 20.0
			stats.hp_regen += amount * 0.05
		"wind_agility":
			var amount := 10.0 + 10.0 * rank
			stats.agility += amount
			stats.physical_armor += amount * 0.15
			stats.attack_speed = minf(stats.attack_speed_cap, stats.attack_speed * (1.0 + amount * 0.005))
		"assassin":
			stats.critical_chance = clampf(stats.critical_chance + 0.10 + 0.05 * rank, 0, 1)
			stats.critical_multiplier = maxf(stats.critical_multiplier, 1.8 + 0.2 * rank)
		"feast": stats.passive_max_hp_fraction = 0.01 + 0.005 * rank
