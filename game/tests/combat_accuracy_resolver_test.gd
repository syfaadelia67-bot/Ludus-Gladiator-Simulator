extends Node

const CombatAccuracyResolverScript = preload("res://scripts/combat/combat_accuracy_resolver.gd")


func _ready() -> void:
	var resolver = CombatAccuracyResolverScript.new()
	_assert_contract(resolver)
	_assert_equal_stats_hit(resolver)
	_assert_light_accuracy_edge(resolver)
	_assert_heavy_requires_full_score(resolver)
	_assert_invalid_inputs_fail_closed(resolver)
	print("Combat D7 accuracy resolver: OK")
	get_tree().quit(0)


func _assert_contract(resolver) -> void:
	var contract: Dictionary = resolver.get_contract()
	assert(contract.get("status") == "frozen")
	assert(contract.get("deterministic") == true)
	assert(contract.get("rng_allowed") == false)
	assert(contract.get("critical_hits_enabled") == false)
	assert(contract.get("attacker_stat") == "TEC")
	assert(contract.get("defender_stat") == "AGI")
	assert(contract.get("action_accuracy_modifiers") == {"light": 1.0, "heavy": 0.0})
	assert(contract.get("hit_rule") == "attack_score_gte_evasion_score")


func _assert_equal_stats_hit(resolver) -> void:
	var light: Dictionary = resolver.resolve_hit(_fighter(10, 10), _fighter(10, 10), "light")
	var heavy: Dictionary = resolver.resolve_hit(_fighter(10, 10), _fighter(10, 10), "heavy")
	assert(light.get("status") == "resolved")
	assert(light.get("hit") == true)
	assert(heavy.get("hit") == true)
	assert(light.get("critical") == false)
	assert(heavy.get("critical") == false)


func _assert_light_accuracy_edge(resolver) -> void:
	var light: Dictionary = resolver.resolve_hit(_fighter(9, 10), _fighter(10, 10), "light")
	assert(light.get("attack_score") == 10.0)
	assert(light.get("evasion_score") == 10.0)
	assert(light.get("hit") == true)


func _assert_heavy_requires_full_score(resolver) -> void:
	var heavy: Dictionary = resolver.resolve_hit(_fighter(9, 10), _fighter(10, 10), "heavy")
	assert(heavy.get("attack_score") == 9.0)
	assert(heavy.get("evasion_score") == 10.0)
	assert(heavy.get("hit") == false)


func _assert_invalid_inputs_fail_closed(resolver) -> void:
	var unsupported: Dictionary = resolver.resolve_hit(_fighter(10, 10), _fighter(10, 10), "block")
	assert(unsupported.get("status") == "invalid")
	var attacker := _fighter(10, 10)
	(attacker.get("stats") as Dictionary)["TEC"] = -1
	var invalid_stat: Dictionary = resolver.resolve_hit(attacker, _fighter(10, 10), "light")
	assert(invalid_stat.get("status") == "invalid")


func _fighter(tec: float, agi: float) -> Dictionary:
	return {
		"id": "fighter",
		"team": "team",
		"stats": {"FUE": 10, "AGI": agi, "TEC": tec, "RES": 10, "PV": 10},
		"stamina": 10,
	}
