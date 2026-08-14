extends Node

const RivalLudiDataValidatorScript = preload("res://scripts/core/rival_ludi_data_validator.gd")


func _ready() -> void:
	var validator = RivalLudiDataValidatorScript.new()
	DataRepository.load_all()

	var errors: Array[String] = validator.validate_entries(DataRepository.rival_ludi)
	assert(
		errors.is_empty(), "Canonical rival Ludus identities must validate cleanly: %s" % [errors]
	)
	assert(
		(
			validator.get_canonical_ids()
			== ["aurelius", "cassianus", "drusus", "flavianus", "marcellus", "severus", "varro"]
		)
	)

	var with_runtime_stats := DataRepository.rival_ludi.duplicate(true)
	(with_runtime_stats[0] as Dictionary)["gladiator_power"] = 99
	errors = validator.validate_entries(with_runtime_stats)
	assert(_contains_error(errors, "must not define runtime field gladiator_power"))

	var missing_one := DataRepository.rival_ludi.duplicate(true)
	missing_one.pop_back()
	errors = validator.validate_entries(missing_one)
	assert(_contains_error(errors, "exactly seven entries"))
	assert(_contains_error(errors, "Missing canonical rival Ludus id"))

	print("Canonical rival Ludus identity-only data contract: OK")
	get_tree().quit(0)


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
