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
	_assert_thirteenth_skill_is_rejected(validator)
	_assert_unfrozen_skill_mechanics_are_rejected(validator)
	_assert_duplicate_ids_are_rejected(validator)

	print("Frozen Part 3 data validator contract: OK")
	get_tree().quit(0)


func _snapshot() -> Dictionary:
	return {
		"traits": DataRepository.traits.duplicate(true),
		"buildings": DataRepository.buildings.duplicate(true),
		"weapons": DataRepository.weapons.duplicate(true),
		"skills": DataRepository.skills.duplicate(true),
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
		if str(entry.get("id", "")) == "mine":
			entry["base_cost"] = 301
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "non-canonical base_cost"),
		"Changing the frozen Mine cost must fail the contract"
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


func _assert_thirteenth_skill_is_rejected(validator) -> void:
	var snapshot := _snapshot()
	var skills := snapshot["skills"] as Array
	skills.append({"id": "invalid_skill_13", "name": "Invalid Skill", "category": "general"})
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "exactly 8 general + 4 specialized skills"),
		"A thirteenth combat skill must fail the frozen contract"
	)


func _assert_unfrozen_skill_mechanics_are_rejected(validator) -> void:
	var snapshot := _snapshot()
	var skills := snapshot["skills"] as Array
	for raw_entry in skills:
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == "counterattack":
			entry["damage_multiplier"] = 1.25
			break
	var errors: Array[String] = validator.validate_snapshot(snapshot)
	assert(
		_contains_error(errors, "unfrozen mechanical field"),
		"Part 3 must reject invented skill mechanics"
	)


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
