extends "res://scripts/systems/event_manager.gd"

const MonthlyEventRuntimePolicyScript = preload(
	"res://scripts/systems/monthly_event_runtime_policy.gd"
)

const CHAIN_EVENTS := {
	"rival_challenge_aftermath":
	{
		"title": "La respuesta de la casa rival",
		"text":
		(
			"El desafío público dejó heridas en el orgullo de ambos ludus. "
			+ "El rival exige una respuesta definitiva."
		),
		"choices":
		[
			{
				"id": "public_duel",
				"label": "Aceptar un duelo público",
				"context_requirements": {"gladiators": 1, "healthy_gladiator": true},
				"effects": {"reputation": 3, "morale_all": 2},
				"result": "La ciudad espera el próximo cruce entre ambas casas."
			},
			{
				"id": "buy_peace",
				"label": "Pagar una compensación",
				"requirements": {"denarii": 110},
				"effects": {"denarii": -110, "reputation": -1},
				"result": "La tensión baja, aunque la casa parece débil."
			},
			{
				"id": "counter_rumor",
				"label": "Responder con rumores",
				"context_requirements": {"intelligence": 10},
				"effects": {"intelligence": -10, "reputation": 2},
				"result": "La opinión pública se divide y la rivalidad continúa."
			}
		]
	},
	"veteran_trial":
	{
		"title": "La prueba del veterano",
		"text": "El veterano refugiado exige comprobar que el ludus merece sus enseñanzas.",
		"choices":
		[
			{
				"id": "train_specialist",
				"label": "Presentar un gladiador especializado",
				"context_requirements": {"specialized_gladiator": true},
				"effects": {"training_all": 10, "morale_all": 3},
				"result": "El veterano reconoce disciplina y comparte técnicas avanzadas."
			},
			{
				"id": "improve_yard",
				"label": "Mostrar el patio de entrenamiento",
				"context_requirements": {"building_id": "training_yard", "building_level": 2},
				"effects": {"reputation": 2, "training_all": 6},
				"result": "Las instalaciones convencen al veterano de permanecer un mes más."
			},
			{
				"id": "dismiss",
				"label": "Dar por terminado el acuerdo",
				"effects": {"morale_all": -1},
				"result": "El veterano abandona la finca sin revelar sus mejores métodos."
			}
		]
	},
}

var queued_chain_event: String = ""
var queued_chain_month: int = 0
var months_without_event: int = 0
var _monthly_policy = MonthlyEventRuntimePolicyScript.new()


func process_month() -> Dictionary:
	_process_monthly_active_effects()
	if not pending_event.is_empty():
		return _normalize_event_month(pending_event)
	if not queued_chain_event.is_empty() and GameState.get_month() >= queued_chain_month:
		pending_event = _build_chain_event(queued_chain_event)
		queued_chain_event = ""
		queued_chain_month = 0
		months_without_event = 0
		weeks_without_event = 0
		event_started.emit(pending_event.duplicate(true))
		events_changed.emit()
		return pending_event.duplicate(true)

	# Random event cadence, weekly cooldown values and weekly timed-effect values
	# are legacy balance. They stay fail-closed until monthly numbers are frozen.
	months_without_event += 1
	weeks_without_event = months_without_event
	return {}


func process_week() -> Dictionary:
	return process_month()


func process_day() -> Dictionary:
	return process_month()


func resolve_choice(choice_id: String) -> Dictionary:
	if pending_event.is_empty():
		return {"success": false, "reason": "No hay un evento pendiente."}
	var selected := _find_choice(pending_event, choice_id)
	if selected.is_empty():
		return {"success": false, "reason": "La decisión seleccionada no existe."}
	var unmet := get_unmet_requirements(selected)
	if not unmet.is_empty():
		return {"success": false, "reason": unmet}
	var current_id := str(pending_event.get("id", ""))
	var result := super.resolve_choice(choice_id)
	if bool(result.get("success", false)):
		# The base Save-v14 kernel writes a legacy cooldown value. Canonical monthly
		# scheduling does not consume it, so remove it rather than reinterpret it.
		cooldowns.erase(current_id)
		result["month"] = GameState.get_month()
		result["week"] = GameState.get_month()
		_queue_followup(current_id, choice_id)
	return result


func get_unmet_requirements(choice: Dictionary) -> String:
	var timing_reason := _monthly_policy.get_choice_timing_block_reason(choice)
	if not timing_reason.is_empty():
		return timing_reason
	var base_reason := super.get_unmet_requirements(choice)
	if not base_reason.is_empty():
		return base_reason
	var requirements: Dictionary = choice.get("context_requirements", {})
	var roster_reason := _get_roster_requirement_error(requirements)
	if not roster_reason.is_empty():
		return roster_reason
	return _get_world_requirement_error(requirements)


func get_food_consumption_multiplier() -> float:
	return _multiply_monthly_effect("food_consumption_multiplier")


func get_training_multiplier() -> float:
	return _multiply_monthly_effect("training_multiplier")


func get_market_discount() -> float:
	var discount := 0.0
	for effect in active_effects:
		if not _monthly_policy.is_canonical_monthly_effect(effect):
			continue
		discount = maxf(discount, float(effect.get("market_discount", 0.0)))
	return clampf(discount, 0.0, 0.50)


func get_monthly_runtime_contract() -> Dictionary:
	return _monthly_policy.get_contract()


func _get_roster_requirement_error(requirements: Dictionary) -> String:
	if int(requirements.get("intelligence", 0)) > RosterManager.intelligence_points:
		return "No hay suficiente inteligencia acumulada."
	if int(requirements.get("gladiators", 0)) > _count_gladiators():
		return "No hay suficientes gladiadores disponibles."
	if bool(requirements.get("healthy_gladiator", false)) and not _has_healthy_gladiator():
		return "No hay un gladiador sano disponible."
	if bool(requirements.get("specialized_gladiator", false)) and not _has_specialized_gladiator():
		return "Ningún gladiador eligió todavía una especialización."
	return ""


func _get_world_requirement_error(requirements: Dictionary) -> String:
	var building_id := str(requirements.get("building_id", ""))
	if (
		not building_id.is_empty()
		and EstateManager.get_level(building_id) < int(requirements.get("building_level", 1))
	):
		return "La instalación requerida no tiene nivel suficiente."
	var trait_id := str(requirements.get("trait", ""))
	if not trait_id.is_empty() and not _has_trait(trait_id):
		return "Ningún miembro de la casa posee el rasgo requerido."
	var rivalry_intensity := int(requirements.get("rivalry_intensity", 0))
	if rivalry_intensity > 0 and not _has_rivalry_intensity(rivalry_intensity):
		return "No existe una rivalidad con la intensidad requerida."
	return ""


func export_state() -> Dictionary:
	var data := super.export_state()
	data["queued_chain_event"] = queued_chain_event
	data["queued_chain_month"] = queued_chain_month
	data["months_without_event"] = months_without_event
	# Save-v14 compatibility aliases. Their values mirror canonical months only.
	data["queued_chain_week"] = queued_chain_month
	data["weeks_without_event"] = months_without_event
	return data


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	queued_chain_event = str(data.get("queued_chain_event", ""))
	queued_chain_month = maxi(
		0, int(data.get("queued_chain_month", data.get("queued_chain_week", 0)))
	)
	months_without_event = maxi(
		0, int(data.get("months_without_event", data.get("weeks_without_event", 0)))
	)
	weeks_without_event = months_without_event
	# Legacy cooldown values are retained by old saves but are not canonical
	# monthly timing and therefore cannot affect event selection.
	cooldowns.clear()
	if not queued_chain_event.is_empty() and not CHAIN_EVENTS.has(queued_chain_event):
		queued_chain_event = ""
		queued_chain_month = 0
	if not pending_event.is_empty():
		pending_event = _normalize_event_month(pending_event)


func _queue_followup(event_id: String, choice_id: String) -> void:
	if event_id == "rival_challenge" and choice_id in ["accept", "counter_offer"]:
		queued_chain_event = "rival_challenge_aftermath"
	elif event_id == "wounded_veteran" and choice_id == "welcome":
		queued_chain_event = "veteran_trial"
	else:
		return
	queued_chain_month = (
		GameState.get_month() + MonthlyEventRuntimePolicyScript.CHAIN_FOLLOWUP_DELAY_MONTHS
	)
	events_changed.emit()


func _build_chain_event(event_id: String) -> Dictionary:
	var data: Dictionary = CHAIN_EVENTS[event_id].duplicate(true)
	var month := GameState.get_month()
	data["id"] = event_id
	data["month"] = month
	data["week"] = month
	data["chapter"] = str(CampaignManager.get_chapter_for_month(month).get("id", "ruins"))
	data["chain_event"] = true
	return data


func _normalize_event_month(event: Dictionary) -> Dictionary:
	var normalized := event.duplicate(true)
	var month := int(normalized.get("month", normalized.get("week", GameState.get_month())))
	normalized["month"] = month
	normalized["week"] = month
	for raw_choice in normalized.get("choices", []) as Array:
		if not raw_choice is Dictionary:
			continue
		var choice := raw_choice as Dictionary
		if str(choice.get("label", "")) == "Racionar durante una semana":
			choice["label"] = "Racionar temporalmente"
	return normalized


func _process_monthly_active_effects() -> void:
	var expired: Array[Dictionary] = []
	for effect in active_effects:
		if not _monthly_policy.is_canonical_monthly_effect(effect):
			continue
		GameState.denarii = maxi(0, GameState.denarii + int(effect.get("monthly_denarii", 0)))
		effect["months"] = int(effect.get("months", 1)) - 1
		if int(effect.get("months", 0)) <= 0:
			GameState.reputation = maxi(
				0, GameState.reputation + int(effect.get("reputation_on_expire", 0))
			)
			expired.append(effect)
	for effect in expired:
		active_effects.erase(effect)
		effect_expired.emit(effect.duplicate(true))
	if not expired.is_empty():
		events_changed.emit()


func _multiply_monthly_effect(key: String) -> float:
	var value := 1.0
	for effect in active_effects:
		if not _monthly_policy.is_canonical_monthly_effect(effect):
			continue
		value *= float(effect.get(key, 1.0))
	return value


func _has_healthy_gladiator() -> bool:
	for person in RosterManager.get_people():
		if person.role == "gladiator" and person.is_available_for_combat():
			return true
	return false


func _has_specialized_gladiator() -> bool:
	for person in RosterManager.get_people():
		if (
			person.role == "gladiator"
			and SpecializationMasteryController.has_selected_specialization(person.id)
		):
			return true
	return false


func _has_trait(trait_id: String) -> bool:
	for person in RosterManager.get_people():
		if person.traits.has(trait_id):
			return true
	return false


func _has_rivalry_intensity(required: int) -> bool:
	for person in RosterManager.get_people():
		if person.role != "gladiator":
			continue
		for rivalry in GladiatorRivalryController.get_rivalries(person.id):
			if int(rivalry.get("intensity", 0)) >= required:
				return true
	return false
