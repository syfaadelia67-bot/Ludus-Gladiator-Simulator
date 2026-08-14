extends RefCounted

const STARTING_DENARII := 650
const FIXED_EXPENSE := 88
const SLAVE_MAINTENANCE := 5
const GLADIATOR_MAINTENANCE := 20
const BEAST_MAINTENANCE := 10


func validate_repository(repository) -> Array[String]:
	return validate_rules(repository.economy_rules)


func validate_rules(entries: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not entries is Array:
		errors.append("Economy rules must be an Array")
		return errors
	var by_id: Dictionary = {}
	for raw_entry in entries as Array:
		if raw_entry is Dictionary:
			var entry := raw_entry as Dictionary
			var rule_id := str(entry.get("id", ""))
			if not rule_id.is_empty():
				by_id[rule_id] = entry

	var starting: Dictionary = by_id.get("demo_starting_resources", {})
	if int(starting.get("denarii", -1)) != STARTING_DENARII:
		errors.append("Demo campaign must start with exactly 650 denarii")

	var monthly: Dictionary = by_id.get("monthly_operating_costs", {})
	if monthly.is_empty():
		errors.append("Missing frozen monthly operating cost rule")
		return errors
	if int(monthly.get("fixed_expense", -1)) != FIXED_EXPENSE:
		errors.append("Monthly fixed expense must be exactly 88 denarii")
	if int(monthly.get("slave_maintenance", -1)) != SLAVE_MAINTENANCE:
		errors.append("Monthly slave maintenance must be exactly 5 denarii")
	if int(monthly.get("gladiator_maintenance", -1)) != GLADIATOR_MAINTENANCE:
		errors.append("Monthly gladiator maintenance must be exactly 20 denarii")
	if int(monthly.get("beast_maintenance", -1)) != BEAST_MAINTENANCE:
		errors.append("Monthly beast maintenance must be exactly 10 denarii")
	return errors
