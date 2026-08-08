extends SceneTree

const V1_AUTHORITY_FILES: Array[String] = [
	"res://scripts/combat/combat_contract.gd",
	"res://scripts/combat/combat_policy_contract.gd",
	"res://scripts/combat/combat_policy_context_builder.gd",
	"res://scripts/combat/combat_simulator.gd",
	"res://scripts/combat/combat_resolution_readiness.gd",
	"res://scripts/combat/limboai_policy_adapter.gd",
	"res://scripts/combat/limboai_policy_tree_factory.gd",
	"res://scripts/combat/limboai_policy_runner.gd",
	"res://scripts/combat/combat_decision_gateway.gd",
	"res://ai/tasks/combat/publish_desired_action.gd",
]

const FORBIDDEN_AUTHORITY_FRAGMENTS: Array[String] = [
	"combat_manager_fixed.gd",
	"CombatManager",
	"GameState.day",
	"BASIC_ATTACK",
	"energy_cost",
	"max_energy",
	"attacker.energy",
]

var _failures: Array[String] = []


func _initialize() -> void:
	for path in V1_AUTHORITY_FILES:
		_assert_legacy_authority_absent(path)

	if _failures.is_empty():
		print("Combat V1 legacy quarantine contract: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_legacy_authority_absent(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Combat V1 authority file could not be opened: %s" % path)
		return
	var source := file.get_as_text()
	for fragment in FORBIDDEN_AUTHORITY_FRAGMENTS:
		if source.contains(fragment):
			_failures.append(
				"Combat V1 authority must not depend on legacy fragment '%s': %s" % [fragment, path]
			)
