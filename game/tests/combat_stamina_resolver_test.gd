extends Node

const CombatStaminaResolverScript = preload("res://scripts/combat/combat_stamina_resolver.gd")


func _ready() -> void:
	var resolver = CombatStaminaResolverScript.new()
	_assert_contract(resolver)
	_assert_spend(resolver)
	_assert_insufficient_stamina(resolver)
	_assert_recovery(resolver)
	_assert_recovery_action_breaks_low_stamina_lock(resolver)
	_assert_inputs_are_isolated(resolver)
	print("Combat D6 stamina resolver: OK")
	get_tree().quit(0)


func _assert_contract(resolver) -> void:
	var contract: Dictionary = resolver.get_contract()
	assert(contract.get("status") == "frozen")
	assert(
		(
			contract.get("action_costs")
			== {
				"light": 3,
				"heavy": 5,
				"block": 2,
				"parry": 3,
				"dodge": 4,
				"reposition": 2,
				"recover": 0,
			}
		)
	)
	assert(contract.get("recovery_amount") == 2)
	assert(contract.get("recovery_timing") == "end_exchange")
	assert(contract.get("recovery_cap_field") == "stamina_capacity")


func _assert_spend(resolver) -> void:
	var fighter := _fighter(10, 10)
	var result: Dictionary = resolver.spend(fighter, "heavy")
	assert(result.get("status") == "resolved")
	assert(result.get("cost") == 5)
	assert((result.get("fighter", {}) as Dictionary).get("stamina") == 5.0)
	assert(resolver.can_pay(fighter, "heavy"))


func _assert_insufficient_stamina(resolver) -> void:
	var fighter := _fighter(4, 10)
	assert(not resolver.can_pay(fighter, "heavy"))
	var result: Dictionary = resolver.spend(fighter, "heavy")
	assert(result.get("status") == "invalid")
	assert((result.get("errors", []) as Array).has("insufficient_stamina"))
	assert((result.get("fighter", {}) as Dictionary).get("stamina") == 4)


func _assert_recovery(resolver) -> void:
	var recovered: Dictionary = resolver.recover(_fighter(4, 10))
	assert(recovered.get("status") == "resolved")
	assert((recovered.get("fighter", {}) as Dictionary).get("stamina") == 6.0)
	var capped: Dictionary = resolver.recover(_fighter(9, 10))
	assert((capped.get("fighter", {}) as Dictionary).get("stamina") == 10.0)


func _assert_recovery_action_breaks_low_stamina_lock(resolver) -> void:
	var fighter := _fighter(2, 10)
	var spent: Dictionary = resolver.spend(fighter, "recover")
	assert(spent.get("status") == "resolved")
	assert(spent.get("cost") == 0)
	assert((spent.get("fighter", {}) as Dictionary).get("stamina") == 2.0)
	var recovered: Dictionary = resolver.recover(spent.get("fighter", {}) as Dictionary)
	var next_fighter := recovered.get("fighter", {}) as Dictionary
	assert(next_fighter.get("stamina") == 4.0)
	assert(resolver.can_pay(next_fighter, "light"))


func _assert_inputs_are_isolated(resolver) -> void:
	var fighter := _fighter(10, 10)
	var before := fighter.duplicate(true)
	resolver.spend(fighter, "light")
	resolver.recover(fighter)
	assert(fighter == before)


func _fighter(stamina: float, capacity: float) -> Dictionary:
	return {"id": "fighter", "stamina": stamina, "stamina_capacity": capacity}
