extends Node

signal economy_balance_changed

# Transitional thresholds preserve the previous turn counts until Part 2
# freezes economy balance. They are no longer weekly scheduler constants.
const LEGACY_SAFE_RUNWAY_TURNS := 3
const LEGACY_CRITICAL_RUNWAY_TURNS := 1


func _ready() -> void:
	GameState.resources_changed.connect(func(): economy_balance_changed.emit())
	EconomyManager.economy_changed.connect(func(): economy_balance_changed.emit())
	RosterManager.roster_changed.connect(func(): economy_balance_changed.emit())
	EstateManager.estate_changed.connect(func(): economy_balance_changed.emit())
	MarketManager.market_changed.connect(func(): economy_balance_changed.emit())


func get_audit() -> Dictionary:
	var projection := EconomyManager.get_monthly_projection()
	var fixed_cost := int(projection.get("fixed_costs", 0))
	var sponsor_income := int(projection.get("sponsor_income", 0))
	var loan_payments := int(projection.get("loan_payments", 0))
	var food_consumption := maxi(
		1,
		int(
			ceil(
				(
					float(RosterManager.get_people().size())
					* EventManager.get_food_consumption_multiplier()
				)
			)
		),
	)
	var monthly_net := int(projection.get("net", 0))
	var runway_months := (
		99
		if monthly_net >= 0
		else int(floor(float(GameState.denarii) / float(maxi(1, abs(monthly_net)))))
	)
	var warnings: Array[String] = []
	var blockers: Array[String] = []
	if GameState.food < food_consumption:
		warnings.append("La comida actual no cubre el próximo consumo mensual.")
	if runway_months <= LEGACY_CRITICAL_RUNWAY_TURNS:
		warnings.append("La tesorería tiene una autonomía crítica de %d mes(es)." % runway_months)
	elif runway_months < LEGACY_SAFE_RUNWAY_TURNS:
		warnings.append(
			"La autonomía económica es inferior a %d meses." % LEGACY_SAFE_RUNWAY_TURNS
		)
	if EconomyManager.get_bankruptcy_level() >= 2:
		warnings.append(EconomyManager.get_bankruptcy_message())
	if not UniqueGladiatorManager.first_purchase_completed:
		var cheapest := _cheapest_initial_price()
		if GameState.denarii < cheapest:
			blockers.append(
				"No hay fondos para contratar al gladiador inicial más económico (%d)." % cheapest
			)
	var treatment_floor := _cheapest_treatment_cost()
	if GameState.denarii < treatment_floor and _has_injured_gladiator():
		warnings.append("No hay fondos para el tratamiento médico más económico.")
	return {
		"period": "month",
		"denarii": GameState.denarii,
		"food": GameState.food,
		"monthly_fixed_cost": fixed_cost,
		"sponsor_income": sponsor_income,
		"loan_payments": loan_payments,
		"monthly_net": monthly_net,
		"food_consumption": food_consumption,
		"runway_months": runway_months,
		"debt": EconomyManager.get_total_debt(),
		"bankruptcy_level": EconomyManager.get_bankruptcy_level(),
		"warnings": warnings,
		"blockers": blockers,
		"key_prices": get_key_prices(),
		# Compatibility aliases for existing save/UI consumers.
		"weekly_fixed_cost": fixed_cost,
		"weekly_net": monthly_net,
		"runway_weeks": runway_months,
	}


func get_key_prices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in DataRepository.unique_gladiators:
		if entry is Dictionary and str(entry.get("release_stage", "")) == "demo":
			result.append(
				{
					"category": "Gladiador",
					"name": str(entry.get("name", "Gladiador")),
					"price": int(entry.get("price", 0))
				}
			)
	for building_id in EstateManager.get_building_ids():
		var data := EstateManager.get_building_data(building_id)
		var level := EstateManager.get_level(building_id)
		var costs: Array = data.get("upgrade_costs", [])
		if level < costs.size():
			var cost: Dictionary = costs[level]
			result.append(
				{
					"category": "Mejora",
					"name": str(data.get("name", building_id)),
					"price": int(cost.get("denarii", 0))
				}
			)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary): return int(a.get("price", 0)) < int(b.get("price", 0))
	)
	return result


func get_balance_label() -> String:
	var audit := get_audit()
	if not audit.get("blockers", []).is_empty() or int(audit.get("bankruptcy_level", 0)) >= 3:
		return "BLOQUEO ECONÓMICO"
	if (
		int(audit.get("runway_months", 99)) <= LEGACY_CRITICAL_RUNWAY_TURNS
		or int(audit.get("bankruptcy_level", 0)) >= 2
	):
		return "RIESGO CRÍTICO"
	if not audit.get("warnings", []).is_empty():
		return "ECONOMÍA FRÁGIL"
	return "ECONOMÍA ESTABLE"


func _cheapest_initial_price() -> int:
	var price := 999999
	for offer in UniqueGladiatorManager.get_initial_candidate_offers():
		price = mini(price, int(offer.get("price", price)))
	return 0 if price == 999999 else price


func _cheapest_treatment_cost() -> int:
	var cheapest := 999999
	for treatment_id in GladiatorMedicalCareController.get_treatment_ids():
		var treatment := GladiatorMedicalCareController.get_treatment(treatment_id)
		cheapest = mini(cheapest, int(treatment.get("cost", treatment.get("base_cost", 999999))))
	return 0 if cheapest == 999999 else cheapest


func _has_injured_gladiator() -> bool:
	for person in RosterManager.get_people():
		if person.role == "gladiator" and person.injury_days > 0:
			return true
	return false
