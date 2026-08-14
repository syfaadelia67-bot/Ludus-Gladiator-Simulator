extends SceneTree

const QuarantineManager = preload("res://scripts/systems/legacy_combat_manager_quarantine.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_project_autoload_uses_quarantine_facade()
	_test_quarantine_contract_blocks_legacy_authority()
	_test_legacy_simulation_fails_closed()
	_finish()


func _test_project_autoload_uses_quarantine_facade() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_assert_true(file != null, "project.godot must be readable")
	if file == null:
		return
	var source := file.get_as_text()
	_assert_true(
		source.contains(
			'CombatManager="*res://scripts/systems/legacy_combat_manager_quarantine.gd"'
		),
		"CombatManager autoload must point to the quarantine facade",
	)
	_assert_true(
		not source.contains('CombatManager="*res://scripts/systems/combat_manager_weekly.gd"'),
		"weekly CombatManager must not remain the active autoload",
	)
	_assert_true(
		not source.contains('CombatManager="*res://scripts/systems/combat_manager_fixed.gd"'),
		"fixed legacy CombatManager must not become the active autoload",
	)


func _test_quarantine_contract_blocks_legacy_authority() -> void:
	var manager := QuarantineManager.new()
	var contract := manager.get_quarantine_contract()
	_assert_eq(
		contract.get("legacy_runtime_authority"), false, "legacy runtime authority must be false"
	)
	_assert_eq(
		contract.get("combat_v1_authority"),
		"CombatSimulator",
		"CombatSimulator must remain authority"
	)
	_assert_eq(
		contract.get("legacy_scheduling_enabled"), false, "legacy scheduling must be disabled"
	)
	_assert_eq(
		contract.get("legacy_ability_mechanics_enabled"), false, "legacy abilities must be disabled"
	)
	_assert_eq(
		contract.get("legacy_beast_combat_enabled"), false, "legacy beast combat must be disabled"
	)
	_assert_eq(contract.get("legacy_rewards_enabled"), false, "legacy rewards must be disabled")
	_assert_eq(contract.get("legacy_injuries_enabled"), false, "legacy injuries must be disabled")
	_assert_eq(
		contract.get("legacy_fatigue_mutation_enabled"),
		false,
		"legacy fatigue mutation must be disabled"
	)
	_assert_eq(
		contract.get("save_v14_compatibility_state_preserved"),
		true,
		"v14 compatibility state must survive"
	)
	manager.free()


func _test_legacy_simulation_fails_closed() -> void:
	var manager := QuarantineManager.new()
	manager.last_result = {"legacy": true}
	manager.last_combat_day = 9
	manager.next_battle_config = {"legacy": true}
	var result := manager.simulate_duel("fighter", "balanced")
	_assert_true(result.is_empty(), "legacy simulate_duel must never produce a playable result")
	_assert_eq(
		manager.last_combat_day, 9, "failed legacy simulation must not mutate combat timestamp"
	)
	_assert_eq(
		manager.last_result,
		{"legacy": true},
		"failed legacy simulation must not mutate persisted result"
	)
	_assert_true(
		manager.get_ability_ids().is_empty(),
		"legacy abilities must not be exposed by active manager"
	)
	_assert_true(
		manager.get_tactic_ids().is_empty(), "legacy tactics must not be exposed by active manager"
	)
	manager.free()


func _finish() -> void:
	if _failures.is_empty():
		print("Legacy CombatManager quarantine: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
