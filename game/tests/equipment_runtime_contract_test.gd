extends Node

const EquipmentDataValidatorScript = preload("res://scripts/core/equipment_data_validator.gd")


func _ready() -> void:
	DataRepository.load_all()
	var validator = EquipmentDataValidatorScript.new()
	var clean_errors: Array[String] = validator.validate_repository(DataRepository)
	assert(clean_errors.is_empty(), "Canonical equipment runtime contract must validate cleanly")

	_assert_invalid_slot_is_rejected(validator)
	_assert_missing_equipment_tag_provider_is_rejected(validator)

	print("Equipment runtime contract: OK")
	get_tree().quit(0)


func _snapshot() -> Dictionary:
	return {
		"weapons": DataRepository.weapons.duplicate(true),
		"abilities": DataRepository.abilities.duplicate(true),
	}


func _assert_invalid_slot_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var equipment := snapshot["weapons"] as Array
	(equipment[0] as Dictionary)["slot"] = "invalid_slot"
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "invalid slot"),
		"Invalid equipment slots must fail the runtime data contract"
	)


func _assert_missing_equipment_tag_provider_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var abilities := snapshot["abilities"] as Array
	var ability := abilities[0] as Dictionary
	ability["required_equipment_tags"] = ["missing_canonical_tag"]
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "no canonical provider"),
		"Ability equipment requirements must resolve to a canonical equipment tag"
	)


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
