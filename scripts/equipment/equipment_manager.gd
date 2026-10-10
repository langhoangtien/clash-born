class_name EquipmentManager
extends RefCounted
## Loadout source only. Stats are always recalculated from items, never patched.

const SLOT_COUNT: int = 6
var _slots: Array[EquipmentData] = []

func _init() -> void:
	_slots.resize(SLOT_COUNT)

func get_item(slot: int) -> EquipmentData:
	return _slots[slot] if slot >= 0 and slot < SLOT_COUNT else null

func equip(slot: int, item: EquipmentData) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or item == null or not item.is_valid():
		return false
	for index in range(SLOT_COUNT):
		var existing := _slots[index]
		if index != slot and existing != null and existing.id == item.id and (not item.allow_multiple or not existing.allow_multiple):
			return false
	_slots[slot] = item
	return true

func remove(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or _slots[slot] == null:
		return false
	_slots[slot] = null
	return true

func clear() -> void:
	_slots.fill(null)

func items() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for item in _slots:
		if item != null:
			result.append(item)
	return result

func count_id(id: String) -> int:
	var count := 0
	for item in _slots:
		if item != null and item.id == id: count += 1
	return count

func consume_ids(ids: PackedStringArray) -> bool:
	var needed: Dictionary = {}
	for id in ids: needed[id] = needed.get(id, 0) + 1
	for id in needed:
		if count_id(id) < needed[id]: return false
	for id in ids:
		for slot in range(SLOT_COUNT):
			if _slots[slot] != null and _slots[slot].id == id:
				_slots[slot] = null
				break
	return true

static func aggregate(items_to_combine: Array[EquipmentData]) -> Dictionary:
	var bonuses: Dictionary = {}
	var evasion_sources: Array[float] = []
	for item in items_to_combine:
		if item == null or not item.is_valid():
			continue
		for key in item.modifiers:
			if key == "evasion":
				evasion_sources.append(item.modifiers[key])
			elif key == "critical_multiplier_override":
				bonuses[key] = maxf(bonuses.get(key, 0.0), item.modifiers[key])
			else:
				bonuses[key] = bonuses.get(key, 0.0) + item.modifiers[key]
	return {"bonuses": bonuses, "evasion_sources": evasion_sources}
