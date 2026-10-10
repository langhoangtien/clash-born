class_name UnitStats
extends Resource
## Source data only. Runtime damage never mutates this Resource.

enum PrimaryAttribute { NONE, STRENGTH, AGILITY, INTELLIGENCE }

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
@export var attack_range: float = 700.0
