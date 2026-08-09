extends Node

const CombatAccuracyResolverScript = preload("res://scripts/combat/combat_accuracy_resolver.gd")
const CombatDamageResolverScript = preload("res://scripts/combat/combat_damage_resolver.gd")
const CombatDefensiveEffectResolverScript = preload(
	"res://scripts/combat/combat_defensive_effect_resolver.gd"
)


func _ready() -> void:
	var resolver = CombatDefensiveEffectResolverScript.new()
	_assert_contract(resolver)
	_assert_block_uses_res(resolver)
	_assert_parry_uses_tec(resolver)
	_assert_dodge_uses_agi(resolver)
	_assert_reposition_is_non_spatial(resolver)
	_assert_invalid_inputs_fail_closed(resolver)
	print("Combat defensive action effects: OK")
	get_tree().quit(0)


func _assert_contract(resolver) -> void:
	var contract: Dictionary = resolver.get_contract()
	assert(contract.get("status") == "frozen")
	assert(contract.get("deterministic") == true)
	assert(contract.get("rng_allowed") == false)
	assert(contract.get("scope") == "current_exchange")
	assert(contract.get("applies_to_each_incoming_attack") == true)
	assert((contract.get("block") as Dictionary).get("stat") == "RES")
	assert((contract.get("parry") as Dictionary).get("stat") == "TEC")
	assert((contract.get("dodge") as Dictionary).get("stat") == "AGI")
	assert((contract.get("reposition") as Dictionary).get("distance_model_required") == false)


func _assert_block_uses_res(resolver) -> void:
	var attacker := _fighter(10, 10, 10, 10, 12, 0)
	var defender := _fighter(10, 10, 10, 10, 0, 0)
	var base := _base_results(attacker, defender, "heavy")
	var result: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "heavy", "block", base.accuracy, base.damage
	)
	assert(result.get("status") == "resolved")
	assert(result.get("hit") == true)
	assert(result.get("blocked_amount") == 3)
	assert(result.get("damage") == int((base.damage as Dictionary).get("damage")) - 3)


func _assert_parry_uses_tec(resolver) -> void:
	var attacker := _fighter(10, 10, 10, 10, 12, 0)
	var defender := _fighter(10, 10, 10, 10, 0, 0)
	var heavy_base := _base_results(attacker, defender, "heavy")
	var heavy: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "heavy", "parry", heavy_base.accuracy, heavy_base.damage
	)
	assert(heavy.get("parried") == true)
	assert(heavy.get("hit") == false)
	assert(heavy.get("damage") == 0)
	var light_base := _base_results(attacker, defender, "light")
	var light: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "light", "parry", light_base.accuracy, light_base.damage
	)
	assert(light.get("parried") == false)
	assert(light.get("hit") == true)


func _assert_dodge_uses_agi(resolver) -> void:
	var attacker := _fighter(10, 10, 11, 10, 12, 0)
	var defender := _fighter(10, 10, 10, 10, 0, 0)
	var base := _base_results(attacker, defender, "light")
	assert((base.accuracy as Dictionary).get("hit") == true)
	var result: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "light", "dodge", base.accuracy, base.damage
	)
	assert(result.get("effective_evasion_score") == 12.0)
	assert(result.get("dodged") == true)
	assert(result.get("hit") == false)
	assert(result.get("damage") == 0)


func _assert_reposition_is_non_spatial(resolver) -> void:
	var attacker := _fighter(10, 10, 10, 10, 12, 0)
	var defender := _fighter(10, 10, 10, 10, 0, 0)
	defender["vulnerable"] = true
	var heavy_base := _base_results(attacker, defender, "heavy")
	var heavy: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "heavy", "reposition", heavy_base.accuracy, heavy_base.damage
	)
	assert(heavy.get("effective_evasion_score") == 11.0)
	assert(heavy.get("reposition_evaded") == true)
	assert(heavy.get("clear_vulnerable") == true)
	var light_base := _base_results(attacker, defender, "light")
	var light: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "light", "reposition", light_base.accuracy, light_base.damage
	)
	assert(light.get("hit") == true)
	assert(light.get("clear_vulnerable") == true)


func _assert_invalid_inputs_fail_closed(resolver) -> void:
	var attacker := _fighter(10, 10, 10, 10, 0, 0)
	var defender := _fighter(10, 10, 10, 10, 0, 0)
	var base := _base_results(attacker, defender, "light")
	var result: Dictionary = resolver.resolve_against_attack(
		attacker, defender, "light", "light", base.accuracy, base.damage
	)
	assert(result.get("status") == "invalid")


func _base_results(attacker: Dictionary, defender: Dictionary, action_id: String) -> Dictionary:
	var accuracy_resolver = CombatAccuracyResolverScript.new()
	var damage_resolver = CombatDamageResolverScript.new()
	return {
		"accuracy": accuracy_resolver.resolve_hit(attacker, defender, action_id),
		"damage": damage_resolver.resolve_damage(attacker, defender, action_id),
	}


func _fighter(
	fue: float, res: float, tec: float, agi: float, power: float, defense: float
) -> Dictionary:
	return {
		"id": "fighter",
		"team": "team",
		"stats": {"FUE": fue, "AGI": agi, "TEC": tec, "RES": res, "PV": 20},
		"stamina": 10,
		"equipment": {"power": power, "defense": defense},
	}
