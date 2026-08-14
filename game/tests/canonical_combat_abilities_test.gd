extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager = CombatManager
	assert(manager.is_quarantined(), "Active CombatManager must be the legacy quarantine facade")
	assert(
		manager.get_ability_ids().is_empty(),
		"Legacy ability ids must not be exposed as active combat actions"
	)
	assert(
		manager.get_ability("precise_strike", 1).is_empty(),
		"precise_strike must remain legacy-only"
	)
	assert(
		manager.get_ability("throw_sand", 2).is_empty(), "legacy status abilities must fail closed"
	)
	assert(
		manager.get_ability("dance_of_two_blades", 2).is_empty(),
		"legacy class abilities must fail closed"
	)

	var contract: Dictionary = manager.get_quarantine_contract()
	assert(contract.get("legacy_ability_mechanics_enabled") == false)
	assert(contract.get("combat_v1_authority") == "CombatSimulator")

	print("Legacy combat abilities quarantine contract passed")
	get_tree().quit(0)
