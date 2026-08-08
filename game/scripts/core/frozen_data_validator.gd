extends RefCounted

const DEMO_BUILDING_IDS: Array[String] = [
	"barracks",
	"beast_area",
	"dominus_house",
	"forge",
	"infirmary",
	"mine",
	"training_yard",
]
const REQUIRED_FULL_GAME_BUILDING_IDS: Array[String] = [
	"private_arena",
	"sanctuary",
	"stable",
	"wall_and_gate",
]
const NORMAL_TRAIT_IDS: Array[String] = [
	"beast_hunter",
	"calculating",
	"colossus",
	"disciplined",
	"impulsive",
	"intimidating",
	"lone_fighter",
	"loyal",
	"natural_talent",
	"opportunist",
	"protector",
	"prudent",
	"reckless",
	"showman",
	"tenacious",
	"vigilant",
]
const DEMO_BEAST_IDS: Array[String] = ["bear", "boar", "lion"]
const ABILITY_IDS: Array[String] = [
	"cast_net",
	"dance_of_two_blades",
	"feint",
	"opportunity_strike",
	"precise_strike",
	"relentless_pursuit",
	"shield_charge",
	"throw_sand",
]


func validate_repository(repository) -> Array[String]:
	return validate_snapshot(
		{
			"traits": repository.traits,
			"buildings": repository.buildings,
			"weapons": repository.weapons,
			"abilities": repository.abilities,
			"specializations": repository.specializations,
			"beasts": repository.beasts,
		}
	)


func validate_snapshot(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for collection_name in [
		"traits", "buildings", "weapons", "abilities", "specializations", "beasts"
	]:
		_validate_named_collection(
			str(collection_name), snapshot.get(str(collection_name), []), errors
		)

	_validate_buildings(snapshot.get("buildings", []), errors)
	_validate_traits(snapshot.get("traits", []), errors)
	_validate_beasts(snapshot.get("beasts", []), errors)
	_validate_abilities(snapshot.get("abilities", []), snapshot.get("specializations", []), errors)
	_validate_specializations(
		snapshot.get("specializations", []), snapshot.get("abilities", []), errors
	)
	return errors


func _validate_named_collection(name: String, entries: Variant, errors: Array[String]) -> void:
	if not entries is Array:
		errors.append("%s must be an Array" % name)
		return
	var typed_entries: Array = entries as Array
	if typed_entries.is_empty():
		errors.append("%s must not be empty" % name)
		return
	var ids: Dictionary = {}
	for raw_entry in typed_entries:
		if not raw_entry is Dictionary:
			errors.append("%s contains a non-Dictionary entry" % name)
			continue
		var entry: Dictionary = raw_entry
		var entry_id := str(entry.get("id", ""))
		var entry_name := str(entry.get("name", ""))
		if entry_id.is_empty():
			errors.append("%s contains an entry without id" % name)
			continue
		if entry_name.is_empty():
			errors.append("%s/%s is missing name" % [name, entry_id])
		if ids.has(entry_id):
			errors.append("%s contains duplicate id: %s" % [name, entry_id])
		ids[entry_id] = true


func _validate_buildings(entries: Variant, errors: Array[String]) -> void:
	if not entries is Array:
		return
	var typed_entries: Array = entries as Array
	var by_id := _index_by_id(typed_entries)
	var demo_ids: Array[String] = []
	var legacy_ids: Dictionary = {}
	for raw_entry in typed_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var building_id := str(entry.get("id", ""))
		if bool(entry.get("demo_available", false)):
			demo_ids.append(building_id)
			if int(entry.get("demo_max_level", 0)) != 3:
				errors.append("Demo facility %s must stop at level III" % building_id)
		if int(entry.get("max_level", 0)) < int(entry.get("demo_max_level", 0)):
			errors.append("Building %s has full max below demo max" % building_id)
		for raw_legacy_id in entry.get("legacy_ids", []):
			var legacy_id := str(raw_legacy_id)
			if legacy_id.is_empty():
				continue
			if by_id.has(legacy_id):
				errors.append("Legacy building id collides with canonical id: %s" % legacy_id)
			if legacy_ids.has(legacy_id):
				errors.append("Duplicate legacy building id: %s" % legacy_id)
			legacy_ids[legacy_id] = building_id

	demo_ids.sort()
	if demo_ids != DEMO_BUILDING_IDS:
		errors.append("Demo must expose exactly seven frozen facilities: %s" % [DEMO_BUILDING_IDS])
	for building_id in REQUIRED_FULL_GAME_BUILDING_IDS:
		if not by_id.has(building_id):
			errors.append("Missing required full-game facility: %s" % building_id)
			continue
		var entry: Dictionary = by_id[building_id]
		if bool(entry.get("demo_available", false)):
			errors.append("Full-game facility leaked into demo scope: %s" % building_id)
		if int(entry.get("demo_max_level", 0)) != 0:
			errors.append("Full-game-only facility must have demo_max_level 0: %s" % building_id)


func _validate_traits(entries: Variant, errors: Array[String]) -> void:
	if not entries is Array:
		return
	var typed_entries: Array = entries as Array
	var by_id := _index_by_id(typed_entries)
	var ids := _sorted_ids(typed_entries)
	if ids != NORMAL_TRAIT_IDS:
		errors.append("Frozen normal trait catalog must contain exactly sixteen canonical traits")
	for trait_id in ids:
		var entry: Dictionary = by_id.get(trait_id, {})
		if str(entry.get("category", "")) != "normal":
			errors.append("Trait %s must use category normal" % trait_id)
		for raw_other in entry.get("incompatible_with", []):
			var other_id := str(raw_other)
			if not by_id.has(other_id):
				errors.append(
					"Trait %s references unknown incompatibility: %s" % [trait_id, other_id]
				)
				continue
			var other: Dictionary = by_id[other_id]
			if not other.get("incompatible_with", []).has(trait_id):
				errors.append(
					"Trait incompatibility must be symmetric: %s <-> %s" % [trait_id, other_id]
				)


func _validate_beasts(entries: Variant, errors: Array[String]) -> void:
	if not entries is Array:
		return
	var typed_entries: Array = entries as Array
	var ids := _sorted_ids(typed_entries)
	if ids != DEMO_BEAST_IDS:
		errors.append("Frozen demo beast catalog must contain exactly Jabalí, León and Oso")
	for raw_entry in typed_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var beast_id := str(entry.get("id", ""))
		for forbidden_flag in [
			"can_block",
			"can_parry",
			"has_skills",
			"has_traits",
			"has_specialization",
			"uses_equipment",
			"uses_routines",
			"uses_loyalty",
			"uses_fame",
			"can_train",
		]:
			if bool(entry.get(str(forbidden_flag), false)):
				errors.append("Demo beast %s must keep %s disabled" % [beast_id, forbidden_flag])


func _validate_abilities(
	entries: Variant, specialization_entries: Variant, errors: Array[String]
) -> void:
	if not entries is Array or not specialization_entries is Array:
		return
	var typed_entries: Array = entries as Array
	var typed_specializations: Array = specialization_entries as Array
	var ids := _sorted_ids(typed_entries)
	if ids != ABILITY_IDS:
		errors.append("Frozen ability catalog must contain exactly eight canonical abilities")
	var specialization_ids := _id_set(typed_specializations)
	for raw_entry in typed_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var ability_id := str(entry.get("id", ""))
		if int(entry.get("demo_max_level", 0)) != 2:
			errors.append("Ability %s must stop at rank II in demo" % ability_id)
		if int(entry.get("full_max_level", 0)) != 3:
			errors.append("Ability %s must reserve rank III for full game" % ability_id)
		var levels: Dictionary = entry.get("levels", {})
		for rank in ["1", "2", "3"]:
			if not levels.has(rank):
				errors.append("Ability %s is missing rank %s" % [ability_id, rank])
		var rank_three: Dictionary = levels.get("3", {})
		if not bool(rank_three.get("locked", false)):
			errors.append("Ability %s rank III must remain locked in demo" % ability_id)
		var category := str(entry.get("category", ""))
		if not ["basic", "class"].has(category):
			errors.append("Ability %s has invalid category: %s" % [ability_id, category])
		if category == "class":
			var specialization_id := str(entry.get("specialization", ""))
			if not specialization_ids.has(specialization_id):
				errors.append(
					(
						"Ability %s references unknown specialization: %s"
						% [ability_id, specialization_id]
					)
				)


func _validate_specializations(
	entries: Variant, ability_entries: Variant, errors: Array[String]
) -> void:
	if not entries is Array or not ability_entries is Array:
		return
	var typed_entries: Array = entries as Array
	var typed_abilities: Array = ability_entries as Array
	var ability_ids := _id_set(typed_abilities)
	for raw_entry in typed_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var specialization_id := str(entry.get("id", ""))
		var class_ability := str(entry.get("class_ability", ""))
		if not class_ability.is_empty() and not ability_ids.has(class_ability):
			errors.append(
				(
					"Specialization %s references unknown class ability: %s"
					% [specialization_id, class_ability]
				)
			)


func _index_by_id(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var entry_id := str(entry.get("id", ""))
			if not entry_id.is_empty():
				result[entry_id] = entry
	return result


func _id_set(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry_id in _sorted_ids(entries):
		result[entry_id] = true
	return result


func _sorted_ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry_id := str((raw_entry as Dictionary).get("id", ""))
			if not entry_id.is_empty():
				result.append(entry_id)
	result.sort()
	return result
