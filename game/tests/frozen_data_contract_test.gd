extends Node

const FrozenDataValidatorScript = preload("res://scripts/core/frozen_data_validator.gd")


func _ready() -> void:
	var validator = FrozenDataValidatorScript.new()
	DataRepository.load_all()

	var errors: Array[String] = validator.validate_repository(DataRepository)
	assert(errors.is_empty(), "Frozen Part 3 data contract must validate cleanly: %s" % [errors])

	_assert_eighth_demo_building_is_rejected(validator)
	_assert_changed_demo_facility_contract_is_rejected(validator)
	_assert_changed_starting_denarii_is_rejected(validator)
	_assert_seventeenth_trait_is_rejected(validator)
	_assert_duplicate_ids_are_rejected(validator)
	_assert_broken_references_are_rejected(validator)

	print("Frozen Part 3 data validator contract: OK")
	get_tree().quit(0)


func _snapshot() -> Dictionary:
	return {
		"traits": DataRepository.traits.duplicate(true),
		"buildings": DataRepository.buildings.duplicate(true),
		"weapons": DataRepository.weapons.duplicate(true),
		"abilities": DataRepository.abilities.duplicate(true),
		"specializations": DataRepository.specializations.duplicate(true),
		"beasts": DataRepository.beasts.duplicate(true),
		"economy_rules": DataRepository.economy_rules.duplicate(true),
	}


func _assert_eighth_demo_building_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var buildings := snapshot["buildings"] as Array
	(
		buildings
		. append(
			{
				"id": "invalid_demo_facility",
				"name": "Invalid Demo Facility",
				"legacy_ids": [],
				"starting_level": 0,
				"max_level": 10,
				"demo_available": true,
				"demo_max_level": 3,
			}
		)
	)
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "exactly seven frozen facilities"),
		"An eighth demo facility must fail the frozen contract"
	)


func _assert_seventeenth_trait_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var traits := snapshot["traits"] as Array
	(
		traits
		. append(
			{
				"id": "invalid_trait_17",
				"name": "Invalid Trait 17",
				"category": "normal",
				"incompatible_with": [],
			}
		)
	)
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "exactly sixteen canonical traits"),
		"A seventeenth normal trait must fail the frozen contract"
	)


func _assert_changed_demo_facility_contract_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var buildings := snapshot["buildings"] as Array
	for entry_value in buildings:
		var entry := entry_value as Dictionary
		if str(entry.get("id", "")) == "forge":
			entry["base_cost"] = 321
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "non-canonical base_cost"),
		"Changing a frozen demo facility cost must fail the contract"
	)


func _assert_duplicate_ids_are_rejected(validator) -> void:
	var snapshot := _snapshot()
	var beasts := snapshot["beasts"] as Array
	var duplicate_beast: Dictionary = (beasts[0] as Dictionary).duplicate(true)
	beasts.append(duplicate_beast)
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "duplicate id"), "Duplicate data ids must fail the frozen contract"
	)


func _assert_changed_starting_denarii_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var rules := snapshot["economy_rules"] as Array
	(rules[0] as Dictionary)["denarii"] = 500
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "exactly 650 denarii"),
		"Changing the frozen demo starting balance must fail the contract"
	)


func _assert_broken_references_are_rejected(validator) -> void:
	var snapshot := _snapshot()
	var specializations := snapshot["specializations"] as Array
	var broken_specialization := specializations[1] as Dictionary
	broken_specialization["class_ability"] = "missing_ability"
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "unknown class ability"),
		"Broken cross-catalog references must fail the frozen contract"
	)


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
