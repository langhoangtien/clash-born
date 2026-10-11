class_name BalanceHub
extends Resource
## Central index for tuning. The referenced Resources remain the runtime source
## of truth, so designers can edit one hub and jump to every balance group.

@export var match_settings: MatchSettings
@export var global_formulas: BalanceSettings
@export var hero_archetypes: Array[UnitStats] = []
@export var abilities: Array[AbilityData] = []
@export var item_resources: Array[EquipmentData] = []

func all_match_items() -> Array[EquipmentData]:
	return MatchItemCatalog.items()

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if match_settings == null: errors.append("Missing MatchSettings")
	if global_formulas == null: errors.append("Missing BalanceSettings")
	if hero_archetypes.is_empty(): errors.append("No hero archetypes")
	if abilities.is_empty(): errors.append("No abilities")
	if item_resources.is_empty(): errors.append("No item resources")
	for item in all_match_items():
		if item == null or not item.is_valid(): errors.append("Invalid match item")
	return errors
