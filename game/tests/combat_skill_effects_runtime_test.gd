extends SceneTree

const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")
const CombatSkillRuntimeResolverScript = preload(
	"res://scripts/combat/combat_skill_runtime_resolver.gd"
)
const DataRepositoryScript = preload("res://scripts/core/data_repository.gd")

var _simulator = CombatSimulatorScript.new()
var _skill_resolver = CombatSkillRuntimeResolverScript.new()
var _mechanics: Dictionary = {}


func _initialize() -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	_mechanics = _index(repository.get_skill_mechanics_v1())
	_test_charge_uses_skill_cost_and_effect()
	_test_counterattack_requires_successful_parry()
	_test_equipment_requirements_fail_closed()
	_test_disarm_and_immobilization_persist_to_next_exchange()
	repository.free()
	print("Combat V1 real skill effects runtime: OK")
	quit(0)


func _test_charge_uses_skill_cost_and_effect() -> void:
	var state := _state_1v1(_fighter("p", "player"), _fighter("e", "enemy"))
	var charge := _skill_intent(state, "p", "charge", "e")
	var result := _simulator.resolve_exchange(
		state,
		[
			charge,
			{"actor_id": "e", "action_id": "block", "target_id": ""},
		]
	)
	assert(result.get("status") == "resolved")
	var player := _fighter_from(result.get("state", {}) as Dictionary, "p")
	# 10 - 6 skill cost + 2 end-exchange recovery.
	assert(is_equal_approx(float(player.get("stamina", 0.0)), 6.0))
	assert(player.get("vulnerable") == true)
	var attacks := result.get("attack_results", []) as Array
	assert(attacks.size() == 1)
	assert(str((attacks[0] as Dictionary).get("skill_id", "")) == "charge")


func _test_counterattack_requires_successful_parry() -> void:
	var defender := _fighter("p", "player", 20, 5, 10, true, false)
	var attacker := _fighter("e", "enemy", 1, 5, 10, true, false)
	var state := _state_1v1(defender, attacker)
	var counter := _skill_intent(state, "p", "counterattack", "")
	var result := _simulator.resolve_exchange(
		state,
		[
			counter,
			{"actor_id": "e", "action_id": "light", "target_id": "p"},
		]
	)
	assert(result.get("status") == "resolved")
	var found_counter := false
	for raw_attack in result.get("attack_results", []) as Array:
		var attack := raw_attack as Dictionary
		if str(attack.get("skill_id", "")) == "counterattack":
			found_counter = true
			assert(attack.get("counterattack") == true)
			assert(int(attack.get("damage", 0)) >= 1)
	assert(found_counter)


func _test_equipment_requirements_fail_closed() -> void:
	var no_shield := _fighter("p", "player", 10, 5, 10, true, false)
	var state := _state_1v1(no_shield, _fighter("e", "enemy"))
	var translated := _skill_resolver.resolve_desired_action(
		no_shield,
		{"actor_id": "p", "skill_id": "closed_guard", "target_id": ""},
		_mechanics,
	)
	assert(translated.get("status") == "rejected")
	assert(str(translated.get("reason", "")) == "equipment_requirement_missing")


func _test_disarm_and_immobilization_persist_to_next_exchange() -> void:
	var target := _fighter("e", "enemy", 5, 5, 10, true, false)
	target["equipment"] = {"power": 10, "defense": 0}
	var state := _state_1v1(_fighter("p", "player", 20, 5, 10, true, false), target)
	var disarm := _skill_intent(state, "p", "disarm", "e")
	var first := _simulator.resolve_exchange(
		state,
		[
			disarm,
			{"actor_id": "e", "action_id": "block", "target_id": ""},
		]
	)
	assert(first.get("status") == "resolved")
	var disarmed := _fighter_from(first.get("state", {}) as Dictionary, "e")
	assert(_has_status(disarmed, "disarm"))

	var second_state := first.get("state", {}) as Dictionary
	var second := _simulator.resolve_exchange(
		second_state,
		[
			{"actor_id": "p", "action_id": "block", "target_id": ""},
			{"actor_id": "e", "action_id": "light", "target_id": "p"},
		]
	)
	assert(second.get("status") == "resolved")
	assert(not _has_status(_fighter_from(second.get("state", {}) as Dictionary, "e"), "disarm"))

	var immobilize_state := _state_1v1(
		_fighter("p", "player", 20, 5, 10, true, false), _fighter("e", "enemy")
	)
	var immobilize := _skill_intent(immobilize_state, "p", "immobilization", "e")
	var imm_first := _simulator.resolve_exchange(
		immobilize_state,
		[
			immobilize,
			{"actor_id": "e", "action_id": "block", "target_id": ""},
		]
	)
	assert(imm_first.get("status") == "resolved")
	var immobilized := _fighter_from(imm_first.get("state", {}) as Dictionary, "e")
	assert(_has_status(immobilized, "immobilization"))
	var imm_second := _simulator.resolve_exchange(
		imm_first.get("state", {}) as Dictionary,
		[
			{"actor_id": "p", "action_id": "block", "target_id": ""},
			{"actor_id": "e", "action_id": "dodge", "target_id": ""},
		]
	)
	assert(imm_second.get("status") == "rejected")
	assert(str(imm_second.get("reason", "")) == "invalid_skill_activation")


func _skill_intent(state: Dictionary, actor_id: String, skill_id: String, target_id: String) -> Dictionary:
	var fighter := _fighter_from(state, actor_id)
	var result := _skill_resolver.resolve_desired_action(
		fighter,
		{"actor_id": actor_id, "skill_id": skill_id, "target_id": target_id},
		_mechanics,
	)
	assert(result.get("status") == "ready")
	return (result.get("desired_action", {}) as Dictionary).duplicate(true)


func _state_1v1(player: Dictionary, enemy: Dictionary) -> Dictionary:
	return {"format": "1v1", "fighters": [player, enemy]}


func _fighter(
	fighter_id: String,
	team: String,
	tec: int = 10,
	agi: int = 5,
	stamina: int = 10,
	has_weapon: bool = true,
	has_shield: bool = true
) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team,
		"stats": {"FUE": 10, "AGI": agi, "TEC": tec, "RES": 5, "PV": 50},
		"stamina": float(stamina),
		"equipment": {"power": 4, "defense": 4},
		"equipment_context": {
			"has_weapon": has_weapon,
			"has_shield": has_shield,
			"tags": [],
		},
	}


func _fighter_from(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter
	return {}


func _has_status(fighter: Dictionary, status_id: String) -> bool:
	for raw_status in fighter.get("skill_statuses", []) as Array:
		if str((raw_status as Dictionary).get("id", "")) == status_id:
			return true
	return false


func _index(entries: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		indexed[str(entry.get("id", ""))] = entry.duplicate(true)
	return indexed
