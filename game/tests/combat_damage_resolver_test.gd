extends Node

const CombatDamageResolverScript = preload("res://scripts/combat/combat_damage_resolver.gd")


func _ready() -> void:
	var resolver = CombatDamageResolverScript.new()
	_assert_contract(resolver)
	_assert_light_and_heavy(resolver)
	_assert_equipment_contribution(resolver)
	_assert_minimum_damage(resolver)
	_assert_invalid_inputs_fail_closed(resolver)
	print("Combat D4 damage resolver: OK")
	get_tree().quit(0)


func _assert_contract(resolver) -> void:
	var contract := resolver.get_contract()
	assert(contract.get("status") == "frozen")
	assert(contract.get("deterministic") == true)
	assert(contract.get("minimum_damage") == 1)
	assert(contract.get("armor_penetration_enabled") == false)
	assert(contract.get("equipment_missing_means_zero") == true)


func _assert_light_and_heavy(resolver) -> void:
	var attacker := _fighter(10, 10, 12, 0)
	var defender := _fighter(10, 10, 0, 10)
	var light := resolver.resolve_damage(attacker, defender, "light")
	var heavy := resolver.resolve_damage(attacker, defender, "heavy")
	assert(light.get("status") == "resolved")
	assert(light.get("damage") == 6)
	assert(heavy.get("damage") == 10)
	assert(float(heavy.get("raw_damage")) > float(light.get("raw_damage")))


func _assert_equipment_contribution(resolver) -> void:
	var defender := _fighter(10, 10, 0, 0)
	var unarmed := resolver.resolve_damage(_fighter(10, 10, 0, 0), defender, "light")
	var armed := resolver.resolve_damage(_fighter(10, 10, 12, 0), defender, "light")
	assert(int(armed.get("damage")) > int(unarmed.get("damage")))
	var armored := resolver.resolve_damage(
		_fighter(10, 10, 12, 0), _fighter(10, 10, 0, 10), "light"
	)
	assert(int(armored.get("damage")) < int(armed.get("damage")))


func _assert_minimum_damage(resolver) -> void:
	var result := resolver.resolve_damage(_fighter(1, 1, 0, 0), _fighter(1, 50, 0, 50), "light")
	assert(result.get("damage") == 1)


func _assert_invalid_inputs_fail_closed(resolver) -> void:
	var invalid_action := resolver.resolve_damage(
		_fighter(10, 10, 0, 0), _fighter(10, 10, 0, 0), "block"
	)
	assert(invalid_action.get("status") == "invalid")
	var attacker := _fighter(10, 10, 0, 0)
	(attacker["stats"] as Dictionary)["FUE"] = -1
	var invalid_stat := resolver.resolve_damage(attacker, _fighter(10, 10, 0, 0), "light")
	assert(invalid_stat.get("status") == "invalid")


func _fighter(fue: float, res: float, power: float, defense: float) -> Dictionary:
	return {
		"id": "fighter",
		"team": "team",
		"stats": {"FUE": fue, "AGI": 10, "TEC": 10, "RES": res, "PV": 10},
		"stamina": 10,
		"equipment": {"power": power, "defense": defense},
	}
