extends RefCounted

const VALID_SLOTS: Array[String] = [
	"right_hand",
	"left_hand",
	"torso",
	"head",
	"lower_body",
	"accessory",
]


func validate_repository(repository) -> Array[String]:
	return validate_snapshot(
		{
			"weapons": repository.weapons,
			"abilities": repository.abilities,
		}
	)


func validate_snapshot(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var equipment_entries: Variant = snapshot.get("weapons", [])
	var ability_entries: Variant = snapshot.get("abilities", [])
	if not equipment_entries is Array:
		errors.append("Equipment catalog must be an Array")
		return errors
	if not ability_entries is Array:
		errors.append("Ability catalog must be an Array")
		return errors

	var available_tags: Dictionary = {}
	for raw_entry in equipment_entries as Array:
		if not raw_entry is Dictionary:
			errors.append("Equipment catalog contains a non-Dictionary entry")
			continue
		var entry := raw_entry as Dictionary
		var equipment_id := str(entry.get("id", ""))
		if equipment_id.is_empty():
			errors.append("Equipment entry is missing id")
			continue
		if str(entry.get("name", "")).is_empty():
			errors.append("Equipment %s is missing name" % equipment_id)
		if str(entry.get("type", "")).is_empty():
			errors.append("Equipment %s is missing type" % equipment_id)
		var slot := str(entry.get("slot", ""))
		if not VALID_SLOTS.has(slot):
			errors.append("Equipment %s has invalid slot: %s" % [equipment_id, slot])
		if int(entry.get("forge_level", 0)) < 1:
			errors.append("Equipment %s must require forge level I or higher" % equipment_id)
		for numeric_field in ["ore", "denarii", "power", "defense"]:
			if int(entry.get(str(numeric_field), -1)) < 0:
				errors.append(
				"Equipment %s has invalid %s" % [equipment_id, str(numeric_field)]
			)
		var tags: Variant = entry.get("tags", null)
		if not tags is Array:
			errors.append("Equipment %s must define tags as an Array" % equipment_id)
			continue
		for raw_tag in tags as Array:
			var tag := str(raw_tag)
			if not tag.is_empty():
				available_tags[tag] = true

	for raw_ability in ability_entries as Array:
		if not raw_ability is Dictionary:
			continue
		var ability := raw_ability as Dictionary
		var ability_id := str(ability.get("id", ""))
		for raw_required_tag in ability.get("required_equipment_tags", []):
			var required_tag := str(raw_required_tag)
			if not available_tags.has(required_tag):
				errors.append(
				(
					"Ability %s requires equipment tag with no canonical provider: %s"
					% [ability_id, required_tag]
				)
			)
	return errors
