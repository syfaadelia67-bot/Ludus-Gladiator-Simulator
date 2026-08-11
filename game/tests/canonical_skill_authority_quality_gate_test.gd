extends SceneTree

const CANONICAL_COMBAT_FILES: Array[String] = [
	"res://scripts/combat/combat_simulator.gd",
	"res://scripts/combat/combat_exchange_coordinator.gd",
	"res://scripts/combat/combat_policy_contract.gd",
	"res://scripts/combat/combat_1v1_loop.gd",
	"res://scripts/combat/combat_1v2_loop.gd",
	"res://scripts/combat/combat_2v2_loop.gd",
	"res://scripts/combat/gt1_combat_runtime.gd",
	"res://scripts/combat/gt1_championship_tiebreak_runtime.gd",
	"res://scripts/combat/gt1_combat_intent_bridge.gd",
	"res://scripts/combat/gt1_month_13_host.gd",
	"res://scripts/combat/gt1_month_16_host.gd",
	"res://scripts/combat/gt1_month_20_host.gd",
	"res://scripts/ui/combat_v1_arena_runtime.gd",
]
const FORBIDDEN_LEGACY_SKILL_AUTHORITY: Array[String] = [
	"DataRepository.abilities",
	"GladiatorProgressionManager",
	"abilities.json",
]


func _initialize() -> void:
	for path in CANONICAL_COMBAT_FILES:
		var source := _source(path)
		for forbidden in FORBIDDEN_LEGACY_SKILL_AUTHORITY:
			assert(
				not source.contains(forbidden),
				"Combat V1 must not reference legacy skill authority '%s': %s" % [forbidden, path],
			)
	var policy := _source("res://scripts/combat/combat_policy_contract.gd")
	assert(policy.contains('desired_action.get("skill_id", "")'))
	assert(policy.contains("skill activation is unavailable"))
	print("Canonical skill authority quality gate: OK")
	quit(0)


func _source(path: String) -> String:
	assert(FileAccess.file_exists(path), "Canonical skill authority source missing: %s" % path)
	return FileAccess.get_file_as_string(path)
