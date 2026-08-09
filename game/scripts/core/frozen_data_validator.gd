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
const DEMO_BUILDING_CONTRACTS := {
	"barracks": {"name": "Barracones", "starting_level": 1, "base_cost": 220},
	"beast_area": {"name": "Zona de bestias", "starting_level": 0, "base_cost": 360},
	"dominus_house": {"name": "Casa del Dominus", "starting_level": 1, "base_cost": 240},
	"forge": {"name": "Forja", "starting_level": 0, "base_cost": 320},
	"infirmary": {"name": "Enfermería", "starting_level": 0, "base_cost": 280},
	"mine": {"name": "Mina", "starting_level": 0, "base_cost": 0},
	"training_yard": {"name": "Patio de entrenamiento", "starting_level": 1, "base_cost": 260},
}
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
const GENERAL_SKILL_CONTRACTS := {
	"aid": "Auxilio",
	"charge": "Embestida",
	"closed_guard": "Guardia Cerrada",
	"counterattack": "Contraataque",
	"demolisher": "Demoledor",
	"execution": "Ejecución",
	"feint": "Finta",
	"provoke": "Provocación",
}
const SPECIALIZED_SKILL_CONTRACTS := {
	"anchor": "Anclaje",
	"disarm": "Desarme",
	"immobilization": "Inmovilización",
	"interception": "Intercepción",
}
const FAMILIARITY_LEVELS: Array[String] = [
	"Conocida",
	"Aprendida",
	"Practicada",
	"Dominada",
	"Experto",
]
const SKILL_ALLOWED_FIELDS: Array[String] = ["id", "name", "category"]


func validate_repository(repository) -> Array[String]:
	return validate_snapshot(
		{
			"traits": repository.traits,
			"buildings": repository.buildings,
			"weapons": repository.weapons,
			"skills": repository.skills,
			"beasts": repository.beasts,
			"economy_rules": repository.economy_rules,
		}
	)


func validate_snapshot(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for collection_name in [
		"traits",
		"buildings",
		"weapons",
		"skills",
		"beasts",
		"economy_rules",
	]:
		_validate_named_collection(
			str(collection_name), snapshot.get(str(collection_name), []), errors
		)

	_validate_buildings(snapshot.get("buildings", []), errors)
	_validate_traits(snapshot.get("traits", []), errors)
	_validate_beasts(snapshot.get("beasts", []), errors)
	_validate_economy_rules(snapshot.get("economy_rules", []), errors)
	_validate_skills(snapshot.get("skills", []), errors)
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
	var by_id: Dictionary = _index_by_id(typed_entries)
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
	for building_id in DEMO_BUILDING_IDS:
		if not by_id.has(building_id):
			continue
		var entry: Dictionary = by_id[building_id]
		var contract: Dictionary = DEMO_BUILDING_CONTRACTS[building_id]
		for field_name in ["name", "starting_level", "base_cost"]:
			if entry.get(field_name) != contract.get(field_name):
				errors.append("Demo facility %s has non-canonical %s" % [building_id, field_name])
		if int(entry.get("max_level", 0)) != 10:
			errors.append("Demo facility %s must preserve full-game level X" % building_id)
		if building_id == "mine":
			if not bool(entry.get("upgrade_cost_pending", false)):
				errors.append("Mine cost must remain pending until its frozen value is recovered")
		elif bool(entry.get("upgrade_cost_pending", false)):
			errors.append("Only Mine may have a pending demo facility cost")
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
	var by_id: Dictionary = _index_by_id(typed_entries)
	var ids: Array[String] = _sorted_ids(typed_entries)
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
	var ids: Array[String] = _sorted_ids(typed_entries)
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


func _validate_economy_rules(entries: Variant, errors: Array[String]) -> void:
	if not entries is Array:
		return
	var by_id := _index_by_id(entries as Array)
	var starting_resources: Dictionary = by_id.get("demo_starting_resources", {})
	if starting_resources.is_empty():
		errors.append("Missing frozen demo starting resources rule")
		return
	if int(starting_resources.get("denarii", 0)) != 650:
		errors.append("Demo campaign must start with exactly 650 denarii")


func _validate_skills(entries: Variant, errors: Array[String]) -> void:
	if not entries is Array:
		return
	var typed_entries: Array = entries as Array
	var by_id: Dictionary = _index_by_id(typed_entries)
	var expected_ids: Array[String] = []
	for skill_id in GENERAL_SKILL_CONTRACTS.keys():
		expected_ids.append(str(skill_id))
	for skill_id in SPECIALIZED_SKILL_CONTRACTS.keys():
		expected_ids.append(str(skill_id))
	expected_ids.sort()
	if _sorted_ids(typed_entries) != expected_ids:
		errors.append(
			"Frozen combat skill catalog must contain exactly 8 general + 4 specialized skills"
		)
	for skill_id in GENERAL_SKILL_CONTRACTS.keys():
		_validate_skill_entry(
			str(skill_id), str(GENERAL_SKILL_CONTRACTS[skill_id]), "general", by_id, errors
		)
	for skill_id in SPECIALIZED_SKILL_CONTRACTS.keys():
		_validate_skill_entry(
			str(skill_id), str(SPECIALIZED_SKILL_CONTRACTS[skill_id]), "specialized", by_id, errors
		)


func _validate_skill_entry(
	skill_id: String,
	expected_name: String,
	expected_category: String,
	by_id: Dictionary,
	errors: Array[String]
) -> void:
	if not by_id.has(skill_id):
		errors.append("Missing frozen combat skill: %s" % skill_id)
		return
	var entry: Dictionary = by_id[skill_id]
	if str(entry.get("name", "")) != expected_name:
		errors.append("Combat skill %s has non-canonical name" % skill_id)
	if str(entry.get("category", "")) != expected_category:
		errors.append("Combat skill %s has non-canonical category" % skill_id)
	for raw_field in entry.keys():
		var field_name := str(raw_field)
		if not SKILL_ALLOWED_FIELDS.has(field_name):
			errors.append(
				"Combat skill %s contains unfrozen mechanical field: %s" % [skill_id, field_name]
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


func _sorted_ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry_id := str((raw_entry as Dictionary).get("id", ""))
			if not entry_id.is_empty():
				result.append(entry_id)
	result.sort()
	return result
