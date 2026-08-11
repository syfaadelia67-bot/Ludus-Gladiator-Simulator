extends "res://scripts/systems/rival_manager.gd"

signal monthly_rivalry_processed(month: int, events: Array)
# Compatibility signal only. It mirrors the same monthly result.
signal weekly_rivalry_processed(week: int, events: Array)

const MonthlyRivalManagementPolicyScript = preload(
	"res://scripts/systems/monthly_rival_management_policy.gd"
)

var last_processed_month: int = 0
var _monthly_policy = MonthlyRivalManagementPolicyScript.new()


func _seed_rivals() -> void:
	rivals.clear()
	for raw_identity in DataRepository.get_rival_ludi():
		if raw_identity is Dictionary:
			rivals.append(_monthly_policy.build_management_profile(raw_identity))
	last_processed_month = 0
	rivals_changed.emit()


func reconcile_canonical_rivals() -> void:
	var aliases := MonthlyRivalManagementPolicyScript.LEGACY_RIVAL_ID_ALIASES
	var existing_by_id: Dictionary = {}
	for raw_rival in rivals:
		if not raw_rival is Dictionary:
			continue
		var rival := raw_rival as Dictionary
		var raw_id := str(rival.get("id", ""))
		var canonical_id := str(aliases.get(raw_id, raw_id))
		if DataRepository.get_rival_ludus(canonical_id).is_empty():
			continue
		if not existing_by_id.has(canonical_id):
			existing_by_id[canonical_id] = rival.duplicate(true)

	var fallback_last_month := maxi(0, GameState.get_month() - 1)
	var rebuilt: Array[Dictionary] = []
	var restored_last_month := 0
	for raw_identity in DataRepository.get_rival_ludi():
		if not raw_identity is Dictionary:
			continue
		var identity := raw_identity as Dictionary
		var rival_id := str(identity.get("id", ""))
		var profile := _monthly_policy.build_management_profile(identity)
		var existing := existing_by_id.get(rival_id, {}) as Dictionary
		if existing.is_empty():
			profile["last_management_month"] = fallback_last_month
		else:
			_copy_management_state(existing, profile, fallback_last_month)
		profile["id"] = rival_id
		profile["name"] = str(identity.get("name", rival_id))
		profile["combat_v1_authority"] = false
		restored_last_month = maxi(
			restored_last_month, int(profile.get("last_management_month", fallback_last_month))
		)
		rebuilt.append(profile)
	rivals.assign(rebuilt)
	last_processed_month = restored_last_month
	rivals_changed.emit()


func get_rivals() -> Array:
	_ensure_canonical_rivals()
	return rivals.duplicate(true)


func get_rival(rival_id: String) -> Dictionary:
	_ensure_canonical_rivals()
	for rival in rivals:
		if str(rival.get("id", "")) == rival_id:
			return rival
	return {}


func get_operation_ids() -> Array[String]:
	return _monthly_policy.get_operation_ids()


func get_operation(operation_id: String) -> Dictionary:
	var data := _monthly_policy.get_operation(operation_id)
	if data.is_empty():
		return data
	data["id"] = operation_id
	data["available"] = true
	data["period"] = "month"
	data["balance_source"] = "legacy_authored_values_one_turn_equals_one_month"
	data["gt1_mutation_allowed"] = false
	return data


func run_operation(rival_id: String, operation_id: String, agent_id: String = "") -> Dictionary:
	_ensure_canonical_rivals()
	var month := GameState.get_month()
	var rival := get_rival(rival_id)
	if rival.is_empty():
		return _reject_operation("El rival seleccionado no existe.")
	var operation := _monthly_policy.get_operation(operation_id)
	if operation.is_empty():
		return _reject_operation("La operación seleccionada no existe.")
	var agent = _resolve_agent(agent_id)
	if agent == null:
		return _reject_operation("No hay un agente disponible para la operación.")
	if agent.injury_days > 0:
		return _reject_operation("El agente está herido y no puede operar.")

	var intel_cost := int(operation.get("intel_cost", 0))
	var denarii_cost := int(operation.get("denarii_cost", 0))
	if RosterManager.intelligence_points < intel_cost:
		return _reject_operation("No hay suficientes puntos de inteligencia.")
	if not GameState.spend_denarii(denarii_cost):
		return _reject_operation("No hay suficientes denarios para financiar la operación.")
	RosterManager.intelligence_points -= intel_cost

	var formula: Dictionary = MonthlyRivalManagementPolicyScript.OPERATION_FORMULA
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var skill: int = (
		int(agent.intelligence) * int(formula.get("intelligence_weight", 6))
		+ int(agent.agility) * int(formula.get("agility_weight", 3))
		+ floori(float(agent.loyalty) / float(formula.get("loyalty_divisor", 5)))
	)
	if agent.traits.has("mentor"):
		skill += int(formula.get("mentor_bonus", 6))
	if agent.traits.has("freedom_seeker"):
		skill -= int(formula.get("freedom_seeker_penalty", 5))
	var defense: int = (
		int(rival.get("security", 50))
		+ floori(
			float(int(rival.get("suspicion", 0)))
			/ float(formula.get("defense_suspicion_divisor", 2))
		)
	)
	var success_chance: int = clampi(
		int(formula.get("success_base", 45))
		+ floori(float(skill) / float(formula.get("skill_divisor", 3)))
		- floori(float(defense) / float(formula.get("defense_divisor", 2))),
		int(formula.get("success_min", 12)),
		int(formula.get("success_max", 92))
	)
	var detection_chance: int = clampi(
		int(operation.get("risk", 20))
		+ floori(float(defense) / float(formula.get("detection_defense_divisor", 4)))
		- int(agent.agility) * int(formula.get("detection_agility_weight", 2)),
		int(formula.get("detection_min", 5)),
		int(formula.get("detection_max", 85))
	)
	var success: bool = rng.randi_range(1, 100) <= success_chance
	var detected: bool = rng.randi_range(1, 100) <= detection_chance
	var effect_text := ""

	if success:
		effect_text = _apply_monthly_success(rival, operation_id, rng)
		operations_completed += 1
		agent.loyalty = mini(
			100, agent.loyalty + int(formula.get("success_loyalty_gain", 2))
		)
	else:
		effect_text = "La operación fracasó sin producir beneficios."
		agent.fatigue = mini(
			100, agent.fatigue + int(formula.get("failure_fatigue_gain", 8))
		)

	if detected:
		operations_detected += 1
		hostility_heat += int(formula.get("detected_heat_gain", 12))
		rival["relation"] = maxi(
			-100,
			int(rival.get("relation", 0)) - int(formula.get("detected_relation_loss", 18))
		)
		rival["suspicion"] = mini(
			100,
			int(rival.get("suspicion", 0))
			+ int(formula.get("detected_suspicion_gain", 22))
		)
		GameState.reputation = maxi(
			0, GameState.reputation - int(formula.get("detected_reputation_loss", 2))
		)
		agent.morale = maxi(
			0, agent.morale - int(formula.get("detected_agent_morale_loss", 5))
		)
	else:
		rival["suspicion"] = maxi(
			0,
			int(rival.get("suspicion", 0))
			- int(formula.get("undetected_suspicion_decay", 3))
		)

	var result := {
		"status": "resolved",
		"rival_id": rival_id,
		"rival_name": rival.get("name", rival_id),
		"operation_id": operation_id,
		"operation_name": operation.get("name", operation_id),
		"agent_id": agent.id,
		"agent_name": agent.display_name,
		"success": success,
		"detected": detected,
		"success_chance": success_chance,
		"detection_chance": detection_chance,
		"effect": effect_text,
		"month": month,
		"week": month,
		"day": month,
		"monthly_balance_frozen": true,
		"gt1_mutation_allowed": false,
	}
	GameState.resources_changed.emit()
	RosterManager.roster_changed.emit()
	rivals_changed.emit()
	operation_completed.emit(result.duplicate(true))
	return result


func process_month() -> Array:
	_ensure_canonical_rivals()
	var month := GameState.get_month()
	if month == last_processed_month:
		return []
	last_processed_month = month
	var rules: Dictionary = MonthlyRivalManagementPolicyScript.RETALIATION_RULES
	var events: Array = []
	hostility_heat = maxi(
		0, hostility_heat - int(rules.get("hostility_heat_decay", 1))
	)
	for rival in rivals:
		rival["suspicion"] = maxi(
			0, int(rival.get("suspicion", 0)) - int(rules.get("suspicion_decay", 1))
		)
		rival["last_management_month"] = month
		if int(rival.get("relation", 0)) > int(rules.get("relation_threshold", -45)):
			continue
		var retaliation_chance: float = (
			float(rules.get("base_chance", 0.10))
			+ float(hostility_heat) / float(rules.get("heat_divisor", 300.0))
		)
		if randf() >= retaliation_chance:
			continue
		var event := _resolve_monthly_retaliation(rival)
		event["month"] = month
		event["week"] = month
		event["day"] = month
		event["gt1_mutation_allowed"] = false
		events.append(event)
		rival_event.emit(event.duplicate(true))
	if not events.is_empty():
		GameState.resources_changed.emit()
	rivals_changed.emit()
	monthly_rivalry_processed.emit(month, events.duplicate(true))
	weekly_rivalry_processed.emit(month, events.duplicate(true))
	return events


func process_week() -> Array:
	return process_month()


func process_day() -> Array:
	return process_month()


func get_monthly_management_contract() -> Dictionary:
	return _monthly_policy.get_contract()


func _apply_monthly_success(
	rival: Dictionary, operation_id: String, rng: RandomNumberGenerator
) -> String:
	var effects: Dictionary = MonthlyRivalManagementPolicyScript.OPERATION_EFFECTS
	var rule := effects.get(operation_id, {}) as Dictionary
	match operation_id:
		"scout":
			var gained := rng.randi_range(
				int(rule.get("intel_gain_min", 8)), int(rule.get("intel_gain_max", 16))
			)
			rival["intel"] = mini(100, int(rival.get("intel", 0)) + gained)
			RosterManager.intelligence_points += int(rule.get("player_intel_gain", 3))
			return "Se obtuvieron datos sobre seguridad, riqueza y gladiadores del rival."
		"steal_plans":
			var plans_power_loss := rng.randi_range(
				int(rule.get("management_power_loss_min", 4)),
				int(rule.get("management_power_loss_max", 9))
			)
			rival["gladiator_power"] = maxi(
				10, int(rival.get("gladiator_power", 50)) - plans_power_loss
			)
			RosterManager.intelligence_points += int(rule.get("player_intel_gain", 8))
			return (
				"Los planes robados redujeron el índice operativo del rival; "
				+ "no alteran Combat V1 ni GT I."
			)
		"poison_supplies":
			var poison_power_loss := rng.randi_range(
				int(rule.get("management_power_loss_min", 8)),
				int(rule.get("management_power_loss_max", 15))
			)
			rival["gladiator_power"] = maxi(
				10, int(rival.get("gladiator_power", 50)) - poison_power_loss
			)
			rival["prestige"] = maxi(
				0, int(rival.get("prestige", 50)) - int(rule.get("prestige_loss", 3))
			)
			return (
				"Los suministros contaminados dañaron la preparación operativa y el prestigio "
				+ "del rival sin alterar Combat V1."
			)
		"bribe_guard":
			var security_loss := rng.randi_range(
				int(rule.get("security_loss_min", 7)), int(rule.get("security_loss_max", 13))
			)
			rival["security"] = maxi(10, int(rival.get("security", 50)) - security_loss)
			rival["intel"] = mini(
				100, int(rival.get("intel", 0)) + int(rule.get("rival_intel_gain", 12))
			)
			return "Un guardia reveló rutas de acceso y turnos de seguridad."
		"spread_rumors":
			var prestige_loss := rng.randi_range(
				int(rule.get("prestige_loss_min", 6)), int(rule.get("prestige_loss_max", 12))
			)
			rival["prestige"] = maxi(0, int(rival.get("prestige", 50)) - prestige_loss)
			GameState.reputation += int(rule.get("player_reputation_gain", 1))
			return "Los rumores dañaron el prestigio del rival entre patrocinadores y ciudadanos."
		_:
			return "La operación fue exitosa."


func _resolve_monthly_retaliation(rival: Dictionary) -> Dictionary:
	var rules: Dictionary = MonthlyRivalManagementPolicyScript.RETALIATION_RULES
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var security: int = int(RosterManager.security_score) + int(EstateManager.get_security_bonus())
	var attack_strength: int = (
		floori(float(int(rival.get("wealth", 50))) / 3.0)
		+ floori(float(int(rival.get("suspicion", 0))) / 2.0)
	)
	var blocked: bool = (
		security
		+ rng.randi_range(
			int(rules.get("security_roll_min", 1)), int(rules.get("security_roll_max", 30))
		)
		>= attack_strength
	)
	var description := ""
	var loss := 0
	if blocked:
		description = (
			"Los guardias frustraron una represalia enviada por %s."
			% rival.get("name", "un rival")
		)
		rival["relation"] = maxi(
			-100,
			int(rival.get("relation", 0)) - int(rules.get("blocked_relation_loss", 2))
		)
	else:
		loss = mini(
			GameState.denarii,
			rng.randi_range(
				int(rules.get("denarii_loss_min", 35)), int(rules.get("denarii_loss_max", 110))
			)
		)
		GameState.denarii -= loss
		GameState.food = maxi(
			0,
			GameState.food
			- rng.randi_range(
				int(rules.get("food_loss_min", 4)), int(rules.get("food_loss_max", 12))
			)
		)
		description = (
			"%s saboteó la finca: se perdieron %d denarios y suministros."
			% [rival.get("name", "Un rival"), loss]
		)
	return {
		"type": "retaliation",
		"rival_id": rival.get("id", ""),
		"rival_name": rival.get("name", "Rival"),
		"blocked": blocked,
		"loss": loss,
		"description": description,
	}


func _reject_operation(reason: String) -> Dictionary:
	operation_failed.emit(reason)
	return {
		"status": "rejected",
		"success": false,
		"reason": reason,
		"month": GameState.get_month(),
		"week": GameState.get_month(),
		"day": GameState.get_month(),
		"gt1_mutation_allowed": false,
	}


func _ensure_canonical_rivals() -> void:
	var canonical_ids: Array[String] = []
	for raw_identity in DataRepository.get_rival_ludi():
		if raw_identity is Dictionary:
			canonical_ids.append(str((raw_identity as Dictionary).get("id", "")))
	var current_ids: Array[String] = []
	for rival in rivals:
		current_ids.append(str(rival.get("id", "")))
	canonical_ids.sort()
	current_ids.sort()
	if canonical_ids != current_ids:
		reconcile_canonical_rivals()
		return
	var restored_last_month := 0
	var fallback_last_month := maxi(0, GameState.get_month() - 1)
	for rival in rivals:
		var rival_last_month := int(rival.get("last_management_month", fallback_last_month))
		rival["last_management_month"] = rival_last_month
		restored_last_month = maxi(restored_last_month, rival_last_month)
	last_processed_month = restored_last_month


func _copy_management_state(
	existing: Dictionary, profile: Dictionary, fallback_last_month: int
) -> void:
	for key in [
		"wealth",
		"security",
		"prestige",
		"relation",
		"intel",
		"suspicion",
		"gladiator_power",
		"status",
		"owner",
	]:
		if existing.has(key):
			profile[key] = existing[key]
	profile["wealth"] = maxi(0, int(profile.get("wealth", 50)))
	profile["security"] = clampi(int(profile.get("security", 50)), 0, 100)
	profile["prestige"] = maxi(0, int(profile.get("prestige", 50)))
	profile["relation"] = clampi(int(profile.get("relation", 0)), -100, 100)
	profile["intel"] = clampi(int(profile.get("intel", 0)), 0, 100)
	profile["suspicion"] = clampi(int(profile.get("suspicion", 0)), 0, 100)
	profile["gladiator_power"] = maxi(10, int(profile.get("gladiator_power", 50)))
	profile["last_management_month"] = maxi(
		0, int(existing.get("last_management_month", fallback_last_month))
	)
	profile["management_baseline_source"] = "legacy_explicit_fallbacks"
	profile["combat_v1_authority"] = false
