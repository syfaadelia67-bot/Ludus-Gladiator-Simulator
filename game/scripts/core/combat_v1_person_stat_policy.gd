extends RefCounted

const LEGACY_RESISTANCE_BASELINE := 5


func validate_new_person_data(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("resistance"):
		errors.append("New Combat V1 people require explicit resistance")
	elif int(data.get("resistance", 0)) < 1:
		errors.append("New Combat V1 people require resistance >= 1")
	return errors


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"canonical_stat": "resistance",
		"new_people_require_explicit_resistance": true,
		"legacy_missing_resistance_baseline": LEGACY_RESISTANCE_BASELINE,
		"derive_from_endurance": false,
		"derive_from_intelligence": false,
		"random_generation_range_frozen": false,
		"save_version_change_required": false,
	}
