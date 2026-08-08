extends Node

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")


func _ready() -> void:
	var contract = CombatContractScript.new()
	_assert_action_catalog(contract)
	_assert_supported_formats(contract)
	_assert_unresolved_stats_are_rejected(contract)
	_assert_three_vs_three_is_rejected(contract)
	print("Combat Simulator V1 foundation contract: OK")
	get_tree().quit(0)


func _assert_action_catalog(contract) -> void:
	assert(
		contract.ACTION_IDS == ["light", "heavy", "block", "parry", "dodge", "reposition"],
		"Combat V1 must expose exactly the six frozen actions"
	)
	for action_id in contract.ACTION_IDS:
		assert(contract.is_action_id_valid(action_id))
	assert(
		not contract.is_action_id_valid("special"), "Unknown actions must not become authoritative"
	)


func _assert_supported_formats(contract) -> void:
	for format_id in ["1v1", "2v2", "1v2"]:
		var state := _state_for_format(format_id)
		var errors: Array[String] = contract.validate_state(state)
		assert(errors.is_empty(), "Frozen combat format %s must validate: %s" % [format_id, errors])


func _assert_unresolved_stats_are_rejected(contract) -> void:
	var state := _state_for_format("1v1")
	var first_fighter := (state["fighters"] as Array)[0] as Dictionary
	(first_fighter["stats"] as Dictionary)["RES"] = null
	var errors: Array[String] = contract.validate_state(state)
	assert(
		_contains_error(errors, "unresolved stat RES"),
		"Combat authority must refuse unresolved RES instead of inventing a legacy mapping"
	)


func _assert_three_vs_three_is_rejected(contract) -> void:
	var state := {
		"format": "3v3",
		"fighters":
		[
			_fighter("a1", "a"),
			_fighter("a2", "a"),
			_fighter("a3", "a"),
			_fighter("b1", "b"),
			_fighter("b2", "b"),
			_fighter("b3", "b"),
		],
	}
	var errors: Array[String] = contract.validate_state(state)
	assert(
		_contains_error(errors, "Unsupported combat format: 3v3"),
		"3v3 must not enter the frozen competitive combat contract"
	)


func _state_for_format(format_id: String) -> Dictionary:
	match format_id:
		"1v1":
			return {"format": format_id, "fighters": [_fighter("a1", "a"), _fighter("b1", "b")]}
		"2v2":
			return {
				"format": format_id,
				"fighters":
				[
					_fighter("a1", "a"),
					_fighter("a2", "a"),
					_fighter("b1", "b"),
					_fighter("b2", "b"),
				],
			}
		"1v2":
			return {
				"format": format_id,
				"fighters":
				[
					_fighter("a1", "a"),
					_fighter("b1", "b"),
					_fighter("b2", "b"),
				],
			}
	return {}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 10},
		"stamina": 10,
	}


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
