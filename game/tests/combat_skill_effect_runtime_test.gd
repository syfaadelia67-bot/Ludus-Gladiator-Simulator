extends Node

const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")
const CombatSkillEffectResolverScript = preload(
	"res://scripts/combat/combat_skill_effect_resolver.gd"
)

var _policy = CombatPolicyContractScript.new()
var _simulator = CombatSimulatorScript.new()
var _skill_effects = CombatSkillEffectResolverScript.new()
var _observed_skills: Dictionary = {}


func _ready() -> void:
	DataRepository.load_all()
	_policy.set_skill_mechanics(DataRepository.get_skill_mechanics_v1())
	_test_charge()
	_test_closed_guard()
	_test_demolisher()
	_test_feint()
	_test_execution()
	_test_counterattack()
	_test_aid()
	_test_provoke()
	_test_anchor()
	_test_disarm()
	_test_immobilization()
	_test_interception()
	_test_equipment_requirements_fail_closed()
	_test_runtime_contract()
	_assert_all_skills_observed()
	print("Combat V1 rank-1 skill effects runtime: OK")
	get_tree().quit(0)


func _test_charge() -> void:
	var plain := _resolve_1v1(
		_base_state_1v1(),
		{"actor_id": "a", "action_id": "heavy", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	)
	var skilled := _resolve_1v1(
		_base_state_1v1(),
		_skill_intent(_base_state_1v1(), "a", "charge", "b"),
		{"actor_id": "b", "action_id": "block"},
	)
	assert(_damage_by_actor(skilled, "a") == _damage_by_actor(plain, "a") + 2)
	var actor := _fighter(skilled.get("state", {}) as Dictionary, "a")
	assert(is_equal_approx(float(actor.get("stamina", 0.0)), 6.0))
	assert(bool(actor.get("vulnerable", false)))
	_observed_skills["charge"] = true


func _test_closed_guard() -> void:
	var plain := _resolve_1v1(
		_base_state_1v1(),
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	)
	var skilled := _resolve_1v1(
		_base_state_1v1(),
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		_skill_intent(_base_state_1v1(), "b", "closed_guard"),
	)
	assert(_damage_by_actor(skilled, "a") == maxi(0, _damage_by_actor(plain, "a") - 2))
	assert(is_equal_approx(float(_fighter(skilled.state, "b").get("stamina", 0.0)), 9.0))
	_observed_skills["closed_guard"] = true


func _test_demolisher() -> void:
	var state := _base_state_1v1()
	(_fighter_ref(state, "b").get("equipment", {}) as Dictionary)["defense"] = 10
	var result := _resolve_1v1(
		state,
		_skill_intent(state, "a", "demolisher", "b"),
		{"actor_id": "b", "action_id": "block"},
	)
	var attack := _attack_by_actor(result, "a")
	var damage_result := attack.get("damage_result", {}) as Dictionary
	var defender_equipment := damage_result.get("defender_equipment", {}) as Dictionary
	assert(is_equal_approx(float(defender_equipment.get("defense", 0.0)), 8.0))
	_observed_skills["demolisher"] = true


func _test_feint() -> void:
	var result := _resolve_1v1(
		_base_state_1v1(),
		_skill_intent(_base_state_1v1(), "a", "feint", "b"),
		{"actor_id": "b", "action_id": "block"},
	)
	var attack := _attack_by_actor(result, "a")
	assert(bool(attack.get("defense_bypassed_by_skill", false)))
	assert(int(attack.get("damage", 0)) > 0)
	_observed_skills["feint"] = true


func _test_execution() -> void:
	var plain_state := _runtime_state_1v1(100.0, 20.0)
	var skill_state := _runtime_state_1v1(100.0, 20.0)
	var plain := _resolve_1v1(
		plain_state,
		{"actor_id": "a", "action_id": "heavy", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	)
	var skilled := _resolve_1v1(
		skill_state,
		_skill_intent(skill_state, "a", "execution", "b"),
		{"actor_id": "b", "action_id": "block"},
	)
	assert(_damage_by_actor(skilled, "a") == _damage_by_actor(plain, "a") + 4)
	_observed_skills["execution"] = true


func _test_counterattack() -> void:
	var state := _base_state_1v1()
	(_fighter_ref(state, "a").get("stats", {}) as Dictionary)["TEC"] = 6
	(_fighter_ref(state, "b").get("stats", {}) as Dictionary)["TEC"] = 20
	var result := _resolve_1v1(
		state,
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		_skill_intent(state, "b", "counterattack"),
	)
	var counter := _attack_by_action(result, "counterattack")
	assert(not counter.is_empty())
	assert(bool(counter.get("counterattack", false)))
	assert(int(counter.get("damage", 0)) >= 1)
	assert(float(_fighter(result.state, "a").get("current_pv", 0.0)) < 100.0)
	_observed_skills["counterattack"] = true


func _test_aid() -> void:
	var state := _runtime_state_2v2()
	var ally := _fighter_ref(state, "c")
	ally["stamina"] = 4.0
	ally["stamina_capacity"] = 10.0
	ally["vulnerable"] = true
	var result := _resolve(
		state,
		[
			_skill_intent(state, "a", "aid", "c"),
			{"actor_id": "c", "action_id": "block"},
			{"actor_id": "b", "action_id": "block"},
			{"actor_id": "d", "action_id": "block"},
		],
	)
	var resolved_ally := _fighter(result.state, "c")
	assert(is_equal_approx(float(resolved_ally.get("stamina", 0.0)), 6.0))
	assert(not bool(resolved_ally.get("vulnerable", true)))
	_observed_skills["aid"] = true


func _test_provoke() -> void:
	var state := _base_state_2v2()
	var plain := _resolve(
		state,
		[
			{"actor_id": "a", "action_id": "reposition"},
			{"actor_id": "c", "action_id": "block"},
			{"actor_id": "b", "action_id": "light", "target_id": "c"},
			{"actor_id": "d", "action_id": "block"},
		],
	)
	var skilled_state := _base_state_2v2()
	var skilled := _resolve(
		skilled_state,
		[
			_skill_intent(skilled_state, "a", "provoke", "b"),
			{"actor_id": "c", "action_id": "block"},
			{"actor_id": "b", "action_id": "light", "target_id": "c"},
			{"actor_id": "d", "action_id": "block"},
		],
	)
	assert(_damage_by_actor(skilled, "b") == maxi(0, _damage_by_actor(plain, "b") - 2))
	assert(int(_attack_by_actor(skilled, "b").get("provoke_damage_penalty", 0)) == 2)
	_observed_skills["provoke"] = true


func _test_anchor() -> void:
	var plain := _resolve_1v1(
		_base_state_1v1(),
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	)
	var state := _base_state_1v1()
	var skilled := _resolve_1v1(
		state,
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		_skill_intent(state, "b", "anchor"),
	)
	assert(_damage_by_actor(skilled, "a") == maxi(0, _damage_by_actor(plain, "a") - 1))
	_observed_skills["anchor"] = true


func _test_disarm() -> void:
	var state := _base_state_1v1()
	var first := _resolve_1v1(
		state,
		_skill_intent(state, "a", "disarm", "b"),
		{"actor_id": "b", "action_id": "block"},
	)
	assert(_has_status(_fighter(first.state, "b"), "disarm"))
	var second := _resolve_1v1(
		first.state,
		{"actor_id": "a", "action_id": "block"},
		{"actor_id": "b", "action_id": "light", "target_id": "a"},
	)
	var damage_result := _attack_by_actor(second, "b").get("damage_result", {}) as Dictionary
	var attacker_equipment := damage_result.get("attacker_equipment", {}) as Dictionary
	assert(is_equal_approx(float(attacker_equipment.get("power", 0.0)), 8.0))
	assert(not _has_status(_fighter(second.state, "b"), "disarm"))
	_observed_skills["disarm"] = true


func _test_immobilization() -> void:
	var state := _base_state_1v1()
	var first := _resolve_1v1(
		state,
		_skill_intent(state, "a", "immobilization", "b"),
		{"actor_id": "b", "action_id": "block"},
	)
	assert(_has_status(_fighter(first.state, "b"), "immobilization"))
	var second := (
		_simulator
		. resolve_exchange(
			first.state,
			[
				{"actor_id": "a", "action_id": "block"},
				{"actor_id": "b", "action_id": "dodge"},
			],
		)
	)
	assert(second.get("status") == "rejected")
	assert(second.get("reason") == "invalid_intents")
	assert(
		_contains(
			second.get("errors", []) as Array,
			"cannot use dodge while affected by immobilization",
		)
	)
	_observed_skills["immobilization"] = true


func _test_interception() -> void:
	var state := _base_state_2v2()
	var result := _resolve(
		state,
		[
			_skill_intent(state, "a", "interception", "c"),
			{"actor_id": "c", "action_id": "block"},
			{"actor_id": "b", "action_id": "light", "target_id": "c"},
			{"actor_id": "d", "action_id": "block"},
		],
	)
	var enemy_attack := _attack_by_actor(result, "b")
	assert(bool(enemy_attack.get("intercepted", false)))
	assert(enemy_attack.get("original_target_id") == "c")
	assert(enemy_attack.get("target_id") == "a")
	assert(float(_fighter(result.state, "c").get("current_pv", 0.0)) == 100.0)
	assert(float(_fighter(result.state, "a").get("current_pv", 100.0)) < 100.0)
	_observed_skills["interception"] = true


func _test_equipment_requirements_fail_closed() -> void:
	var no_weapon := _base_state_1v1()
	_fighter_ref(no_weapon, "a")["equipment_context"] = {
		"has_weapon": false, "has_shield": false, "tags": []
	}
	var feint := {"actor_id": "a", "skill_id": "feint", "target_id": "b"}
	var feint_errors := _policy.validate_desired_action(no_weapon, feint)
	assert(_contains(feint_errors, "equipment requirement: weapon"))

	var no_shield := _base_state_1v1()
	_fighter_ref(no_shield, "a")["equipment_context"] = {
		"has_weapon": true, "has_shield": false, "tags": ["sword"]
	}
	var anchor := {"actor_id": "a", "skill_id": "anchor"}
	var anchor_errors := _policy.validate_desired_action(no_shield, anchor)
	assert(_contains(anchor_errors, "equipment requirement: shield"))

	var low_stamina := _base_state_1v1()
	_fighter_ref(low_stamina, "a")["stamina"] = 5.0
	var charge_intent := _skill_intent(low_stamina, "a", "charge", "b")
	var rejected := (
		_simulator
		. resolve_exchange(
			low_stamina,
			[charge_intent, {"actor_id": "b", "action_id": "block"}],
		)
	)
	assert(rejected.get("status") == "rejected")
	assert(rejected.get("reason") == "insufficient_stamina")


func _test_runtime_contract() -> void:
	var contract := _skill_effects.get_contract()
	assert(contract.get("status") == "frozen")
	assert(contract.get("authority") == "combat_simulator_subordinate_skill_effects")
	assert(int(contract.get("runtime_rank", 0)) == 1)
	assert(contract.get("higher_rank_runtime_enabled") == false)
	assert(contract.get("equipment_requirements_enforced") == true)
	assert(contract.get("damage_authority") == "combat_simulator")
	assert(contract.get("ko_authority") == "combat_simulator")
	assert(contract.get("winner_authority") == "combat_simulator")


func _assert_all_skills_observed() -> void:
	var expected := [
		"counterattack",
		"charge",
		"closed_guard",
		"demolisher",
		"feint",
		"provoke",
		"execution",
		"aid",
		"anchor",
		"disarm",
		"immobilization",
		"interception",
	]
	for skill_id in expected:
		assert(
			_observed_skills.has(skill_id), "Missing behavior assertion for skill: %s" % skill_id
		)
	assert(_observed_skills.size() == 12)


func _skill_intent(
	state: Dictionary, actor_id: String, skill_id: String, target_id: String = ""
) -> Dictionary:
	var desired := {"actor_id": actor_id, "skill_id": skill_id}
	if not target_id.is_empty():
		desired["target_id"] = target_id
	var errors := _policy.validate_desired_action(state, desired)
	assert(errors.is_empty(), "Skill %s should validate: %s" % [skill_id, errors])
	var translated := _policy.resolve_desired_action(state, desired)
	assert(translated.get("status") == "ready")
	var intent := (translated.get("desired_action", {}) as Dictionary).duplicate(true)
	assert(not (intent.get("skill_activation", {}) as Dictionary).is_empty())
	return intent


func _resolve_1v1(state: Dictionary, first: Dictionary, second: Dictionary) -> Dictionary:
	return _resolve(state, [first, second])


func _resolve(state: Dictionary, intents: Array) -> Dictionary:
	var result := _simulator.resolve_exchange(state, intents)
	assert(
		result.get("status") == "resolved",
		"Exchange should resolve: %s" % [result.get("errors", [])]
	)
	return result


func _base_state_1v1() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_make_fighter("a", "player"),
			_make_fighter("b", "enemy"),
		],
	}


func _base_state_2v2() -> Dictionary:
	return {
		"format": "2v2",
		"fighters":
		[
			_make_fighter("a", "player"),
			_make_fighter("c", "player"),
			_make_fighter("b", "enemy"),
			_make_fighter("d", "enemy"),
		],
	}


func _runtime_state_1v1(a_pv: float, b_pv: float) -> Dictionary:
	var state := _base_state_1v1()
	for raw_fighter in state.fighters:
		var fighter := raw_fighter as Dictionary
		fighter["current_pv"] = a_pv if fighter.id == "a" else b_pv
		fighter["vulnerable"] = false
		fighter["stamina_capacity"] = 10.0
	return state


func _runtime_state_2v2() -> Dictionary:
	var state := _base_state_2v2()
	for raw_fighter in state.fighters:
		var fighter := raw_fighter as Dictionary
		fighter["current_pv"] = 100.0
		fighter["vulnerable"] = false
		fighter["stamina_capacity"] = 10.0
	return state


func _make_fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"entity_type": "gladiator",
		"stats": {"FUE": 20, "AGI": 5, "TEC": 20, "RES": 8, "PV": 100},
		"stamina": 10.0,
		"equipment": {"power": 10, "defense": 4},
		"equipment_context":
		{
			"has_weapon": true,
			"has_shield": true,
			"tags": ["sword", "shield"],
		},
	}


func _fighter(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter
	return {}


func _fighter_ref(state: Dictionary, fighter_id: String) -> Dictionary:
	return _fighter(state, fighter_id)


func _attack_by_actor(result: Dictionary, actor_id: String) -> Dictionary:
	for raw_attack in result.get("attack_results", []) as Array:
		var attack := raw_attack as Dictionary
		if str(attack.get("actor_id", "")) == actor_id:
			return attack
	return {}


func _attack_by_action(result: Dictionary, action_id: String) -> Dictionary:
	for raw_attack in result.get("attack_results", []) as Array:
		var attack := raw_attack as Dictionary
		if str(attack.get("action_id", "")) == action_id:
			return attack
	return {}


func _damage_by_actor(result: Dictionary, actor_id: String) -> int:
	return int(_attack_by_actor(result, actor_id).get("damage", 0))


func _has_status(fighter: Dictionary, status_id: String) -> bool:
	for raw_status in fighter.get("skill_statuses", []) as Array:
		if str((raw_status as Dictionary).get("id", "")) == status_id:
			return true
	return false


func _contains(errors: Array, fragment: String) -> bool:
	for error_message in errors:
		if str(error_message).contains(fragment):
			return true
	return false
