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
var last_processed_month: int = 0
var _monthly_policy = MonthlyEventRuntimePolicyScript.new()


func process_month() -> Dictionary:
	var month := GameState.get_month()
	if month == last_processed_month:
		return _normalize_event_month(pending_event) if not pending_event.is_empty() else {}
	last_processed_month = month

	_process_monthly_active_effects()
	_tick_monthly_cooldowns()
	if not pending_event.is_empty():
		pending_event = _normalize_event_month(pending_event)
		return pending_event.duplicate(true)
	if not queued_chain_event.is_empty() and month >= queued_chain_month:
		pending_event = _build_chain_event(queued_chain_event)
		queued_chain_event = ""
		queued_chain_month = 0
		months_without_event = 0
		weeks_without_event = 0
		event_started.emit(pending_event.duplicate(true))
		events_changed.emit()
		return pending_event.duplicate(true)

	months_without_event += 1
	weeks_without_event = months_without_event
	var event_id := _pick_monthly_event()
	if event_id.is_empty():
		return {}
	pending_event = _build_monthly_event(event_id)
	months_without_event = 0
	weeks_without_event = 0
	event_started.emit(pending_event.duplicate(true))
	events_changed.emit()
	return pending_event.duplicate(true)


func process_week() -> Dictionary:
	return process_month()


func process_day() -> Dictionary:
	return process_month()


func resolve_choice(choice_id: String) -> Dictionary:
	if pending_event.is_empty():
		return {"success": false, "reason": "No hay un evento pendiente."}
	pending_event = _normalize_event_month(pending_event)
	var selected := _find_choice(pending_event, choice_id)
	if selected.is_empty():
		return {"success": false, "reason": "La decisión seleccionada no existe."}
	var unmet := get_unmet_requirements(selected)
	if not unmet.is_empty():
		return {"success": false, "reason": unmet}
	var current_id := str(pending_event.get("id", ""))
	var result := super.resolve_choice(choice_id)
	if bool(result.get("success", false)):
		var cooldown_months := _monthly_policy.get_event_cooldown_months(current_id)
		if cooldown_months > 0:
			cooldowns[current_id] = cooldown_months
		else:
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
	data["last_processed_month"] = last_processed_month
	# Save-v14 compatibility aliases. Their values mirror canonical months only.
	data["queued_chain_week"] = queued_chain_month
	data["weeks_without_event"] = months_without_event
	data["last_processed_week"] = last_processed_month
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
	last_processed_month = maxi(
		0,
		int(
			data.get("last_processed_month", data.get("last_processed_week", GameState.get_month()))
		),
	)
	weeks_without_event = months_without_event
	if not queued_chain_event.is_empty() and not CHAIN_EVENTS.has(queued_chain_event):
		queued_chain_event = ""
		queued_chain_month = 0
	if not pending_event.is_empty():
		pending_event = _normalize_event_month(pending_event)
	_normalize_active_effects()


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
	return _normalize_event_month(data)


func _build_monthly_event(event_id: String) -> Dictionary:
	if not EVENTS.has(event_id):
		return {}
	var data: Dictionary = EVENTS[event_id].duplicate(true)
	var month := GameState.get_month()
	data["id"] = event_id
	data["month"] = month
	data["week"] = month
	data["chapter"] = str(CampaignManager.get_chapter_for_month(month).get("id", "ruins"))
	return _normalize_event_month(data)


func _pick_monthly_event() -> String:
	var chapter_id := str(
		CampaignManager.get_chapter_for_month(GameState.get_month()).get("id", "ruins")
	)
	var candidates: Array[String] = []
	for raw_event_id in MonthlyEventRuntimePolicyScript.EVENT_RULES.keys():
		var event_id := str(raw_event_id)
		if not EVENTS.has(event_id):
			continue
		if int(cooldowns.get(event_id, 0)) > 0:
			continue
		var event_data := EVENTS[event_id] as Dictionary
		if not event_data.get("chapters", []).has(chapter_id):
			continue
		var weight := _monthly_policy.get_event_weight(event_id)
		for _index in range(weight):
			candidates.append(event_id)
	return "" if candidates.is_empty() else candidates.pick_random()


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
		var effects_value: Variant = choice.get("effects", {})
		if not effects_value is Dictionary:
			continue
		var effects := effects_value as Dictionary
		var timed_value: Variant = effects.get("timed", {})
		if timed_value is Dictionary and not (timed_value as Dictionary).is_empty():
			effects["timed"] = _monthly_policy.normalize_authored_timed_effect(
				timed_value as Dictionary
			)
			choice["effects"] = effects
	return normalized


func _normalize_active_effects() -> void:
	for index in range(active_effects.size()):
		active_effects[index] = _monthly_policy.normalize_authored_timed_effect(
			active_effects[index]
		)


func _tick_monthly_cooldowns() -> void:
	for raw_event_id in cooldowns.keys():
		var event_id := str(raw_event_id)
		var remaining := int(cooldowns.get(event_id, 0)) - 1
		if remaining <= 0:
			cooldowns.erase(event_id)
		else:
			cooldowns[event_id] = remaining


func _process_monthly_active_effects() -> void:
	var expired: Array[Dictionary] = []
	var resources_changed := false
	for effect in active_effects:
		if not _monthly_policy.is_canonical_monthly_effect(effect):
			continue
		var monthly_denarii := int(effect.get("monthly_denarii", 0))
		if monthly_denarii != 0:
			GameState.denarii = maxi(0, GameState.denarii + monthly_denarii)
			resources_changed = true
		effect["months"] = int(effect.get("months", 1)) - 1
		if int(effect.get("months", 0)) <= 0:
			GameState.reputation = maxi(
				0, GameState.reputation + int(effect.get("reputation_on_expire", 0))
			)
			expired.append(effect)
	for effect in expired:
		active_effects.erase(effect)
		effect_expired.emit(effect.duplicate(true))
	if resources_changed:
		GameState.resources_changed.emit()
	if resources_changed or not expired.is_empty():
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
