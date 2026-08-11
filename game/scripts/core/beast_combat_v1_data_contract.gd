extends RefCounted

const REQUIRED_BEAST_IDS: Array[String] = ["bear", "boar", "lion"]
const REQUIRED_STAT_IDS: Array[String] = ["FUE", "AGI", "TEC", "RES", "PV"]
const REQUIRED_PROFILES := {
	"boar": {
		"FUE": 7,
		"AGI": 5,
		"TEC": 6,
		"RES": 6,
		"PV": 56,
		"stamina": 10,
	},
	"lion": {
		"FUE": 8,
		"AGI": 9,
		"TEC": 8,
		"RES": 5,
		"PV": 55,
		"stamina": 10,
	},
	"bear": {
		"FUE": 10,
		"AGI": 4,
		"TEC": 5,
		"RES": 8,
		"PV": 68,
		"stamina": 10,
	},
}
const ALLOWED_FIELDS: Array[String] = [
	"id",
	"name",
	"technique_label",
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
	"FUE",
	"AGI",
	"TEC",
	"RES",
	"PV",
	"stamina",
]


func validate_entries(entries: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not entries is Array:
		return ["beasts must be an Array"]

	var by_id: Dictionary = {}
	for raw_entry in entries as Array:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var beast_id := str(entry.get("id", ""))
		if not REQUIRED_BEAST_IDS.has(beast_id):
			continue
		if by_id.has(beast_id):
			errors.append("Duplicate canonical Combat V1 beast id: %s" % beast_id)
			continue
		by_id[beast_id] = entry

	for beast_id in REQUIRED_BEAST_IDS:
		if not by_id.has(beast_id):
			errors.append("Missing canonical Combat V1 beast profile: %s" % beast_id)
			continue
		var beast := by_id[beast_id] as Dictionary
		var expected := REQUIRED_PROFILES[beast_id] as Dictionary
		for field_name in beast.keys():
			if str(field_name) not in ALLOWED_FIELDS:
				errors.append(
					"Demo beast %s contains unfrozen Combat V1 field: %s" % [beast_id, field_name]
				)
		for stat_id in REQUIRED_STAT_IDS:
			_validate_numeric_value(beast_id, stat_id, beast, expected, errors)
		_validate_numeric_value(beast_id, "stamina", beast, expected, errors)
	return errors


func get_profile(beast_id: String) -> Dictionary:
	if not REQUIRED_PROFILES.has(beast_id):
		return {}
	return (REQUIRED_PROFILES[beast_id] as Dictionary).duplicate(true)


func get_profiles() -> Dictionary:
	return REQUIRED_PROFILES.duplicate(true)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"required_beast_ids": REQUIRED_BEAST_IDS.duplicate(),
		"required_stat_ids": REQUIRED_STAT_IDS.duplicate(),
		"requires_stamina": true,
		"profiles": REQUIRED_PROFILES.duplicate(true),
		"source": "explicit_canonical_beast_data",
		"generated_stats_allowed": false,
		"legacy_beast_stats_allowed": false,
		"save_version_change_required": false,
	}


func _validate_numeric_value(
	beast_id: String,
	value_id: String,
	beast: Dictionary,
	expected: Dictionary,
	errors: Array[String]
) -> void:
	if not beast.has(value_id):
		errors.append("Demo beast %s is missing canonical %s" % [beast_id, value_id])
		return
	var value: Variant = beast[value_id]
	if not _is_numeric(value):
		errors.append("Demo beast %s canonical %s must be numeric" % [beast_id, value_id])
		return
	if float(value) != float(expected[value_id]):
		errors.append("Demo beast %s has non-canonical %s" % [beast_id, value_id])


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float
