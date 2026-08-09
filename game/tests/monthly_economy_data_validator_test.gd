extends Node

const MonthlyEconomyDataValidatorScript = preload(
	"res://scripts/core/monthly_economy_data_validator.gd"
)


func _ready() -> void:
	var validator = MonthlyEconomyDataValidatorScript.new()
	var errors: Array[String] = validator.validate_repository(DataRepository)
	assert(errors.is_empty(), "Frozen monthly economy data must validate cleanly: %s" % [errors])

	var monthly := DataRepository.get_economy_rule("monthly_operating_costs")
	assert(int(monthly.get("fixed_expense", -1)) == 88)
	assert(int(monthly.get("slave_maintenance", -1)) == 5)
	assert(int(monthly.get("gladiator_maintenance", -1)) == 20)
	assert(int(monthly.get("beast_maintenance", -1)) == 10)

	var changed_rules := DataRepository.economy_rules.duplicate(true)
	for raw_entry in changed_rules:
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == "monthly_operating_costs":
			entry["fixed_expense"] = 89
			break
	var changed_errors: Array[String] = validator.validate_rules(changed_rules)
	assert(
		_contains_error(changed_errors, "exactly 88 denarii"),
		"Changing the frozen monthly fixed expense must fail the contract"
	)

	print("Frozen monthly economy data validator: OK")
	get_tree().quit(0)


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
