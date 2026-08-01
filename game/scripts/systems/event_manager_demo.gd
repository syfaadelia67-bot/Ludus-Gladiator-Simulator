extends "res://scripts/systems/event_manager.gd"

const CHAIN_EVENTS := {
    "rival_challenge_aftermath": {
        "title":"La respuesta de la casa rival",
        "text":"El desafío público dejó heridas en el orgullo de ambos ludus. El rival exige una respuesta definitiva.",
        "choices":[
            {"id":"public_duel","label":"Aceptar un duelo público","context_requirements":{"gladiators":1,"healthy_gladiator":true},"effects":{"reputation":3,"morale_all":2},"result":"La ciudad espera el próximo cruce entre ambas casas."},
            {"id":"buy_peace","label":"Pagar una compensación","requirements":{"denarii":110},"effects":{"denarii":-110,"reputation":-1},"result":"La tensión baja, aunque la casa parece débil."},
            {"id":"counter_rumor","label":"Responder con rumores","context_requirements":{"intelligence":10},"effects":{"intelligence":-10,"reputation":2},"result":"La opinión pública se divide y la rivalidad continúa."}
        ]
    },
    "veteran_trial": {
        "title":"La prueba del veterano",
        "text":"El veterano refugiado exige comprobar que el ludus merece sus enseñanzas.",
        "choices":[
            {"id":"train_specialist","label":"Presentar un gladiador especializado","context_requirements":{"specialized_gladiator":true},"effects":{"training_all":10,"morale_all":3},"result":"El veterano reconoce disciplina y comparte técnicas avanzadas."},
            {"id":"improve_yard","label":"Mostrar el patio de entrenamiento","context_requirements":{"building_id":"training_yard","building_level":2},"effects":{"reputation":2,"training_all":6},"result":"Las instalaciones convencen al veterano de permanecer una semana más."},
            {"id":"dismiss","label":"Dar por terminado el acuerdo","effects":{"morale_all":-1},"result":"El veterano abandona la finca sin revelar sus mejores métodos."}
        ]
    }
}

var queued_chain_event: String = ""
var queued_chain_week: int = 0

func process_week() -> Dictionary:
    if not pending_event.is_empty():
        return pending_event.duplicate(true)
    if not queued_chain_event.is_empty() and GameState.get_week() >= queued_chain_week:
        pending_event = _build_chain_event(queued_chain_event)
        queued_chain_event = ""
        queued_chain_week = 0
        event_started.emit(pending_event.duplicate(true))
        events_changed.emit()
        return pending_event.duplicate(true)
    return super.process_week()

func resolve_choice(choice_id: String) -> Dictionary:
    if pending_event.is_empty():
        return {"success":false,"reason":"No hay un evento pendiente."}
    var selected := _find_choice(pending_event, choice_id)
    if selected.is_empty():
        return {"success":false,"reason":"La decisión seleccionada no existe."}
    var unmet := get_unmet_requirements(selected)
    if not unmet.is_empty():
        return {"success":false,"reason":unmet}
    var current_id := str(pending_event.get("id", ""))
    var result := super.resolve_choice(choice_id)
    if bool(result.get("success", false)):
        _queue_followup(current_id, choice_id)
    return result

func get_unmet_requirements(choice: Dictionary) -> String:
    var base_reason := super.get_unmet_requirements(choice)
    if not base_reason.is_empty():
        return base_reason
    var requirements: Dictionary = choice.get("context_requirements", {})
    if int(requirements.get("intelligence", 0)) > RosterManager.intelligence_points:
        return "No hay suficiente inteligencia acumulada."
    if int(requirements.get("gladiators", 0)) > _count_gladiators():
        return "No hay suficientes gladiadores disponibles."
    if bool(requirements.get("healthy_gladiator", false)) and not _has_healthy_gladiator():
        return "No hay un gladiador sano disponible."
    if bool(requirements.get("specialized_gladiator", false)) and not _has_specialized_gladiator():
        return "Ningún gladiador eligió todavía una especialización."
    var building_id := str(requirements.get("building_id", ""))
    if not building_id.is_empty() and EstateManager.get_level(building_id) < int(requirements.get("building_level", 1)):
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
    data["queued_chain_week"] = queued_chain_week
    return data

func import_state(data: Dictionary) -> void:
    super.import_state(data)
    queued_chain_event = str(data.get("queued_chain_event", ""))
    queued_chain_week = maxi(0, int(data.get("queued_chain_week", 0)))
    if not queued_chain_event.is_empty() and not CHAIN_EVENTS.has(queued_chain_event):
        queued_chain_event = ""
        queued_chain_week = 0

func _queue_followup(event_id: String, choice_id: String) -> void:
    if event_id == "rival_challenge" and choice_id in ["accept", "counter_offer"]:
        queued_chain_event = "rival_challenge_aftermath"
    elif event_id == "wounded_veteran" and choice_id == "welcome":
        queued_chain_event = "veteran_trial"
    else:
        return
    queued_chain_week = GameState.get_week() + 1
    events_changed.emit()

func _build_chain_event(event_id: String) -> Dictionary:
    var data: Dictionary = CHAIN_EVENTS[event_id].duplicate(true)
    data["id"] = event_id
    data["week"] = GameState.get_week()
    data["chapter"] = str(CampaignManager.get_chapter_for_week(GameState.get_week()).get("id", "ruins"))
    data["chain_event"] = true
    return data

func _has_healthy_gladiator() -> bool:
    for person in RosterManager.get_people():
        if person.role == "gladiator" and person.is_available_for_combat():
            return true
    return false

func _has_specialized_gladiator() -> bool:
    for person in RosterManager.get_people():
        if person.role == "gladiator" and SpecializationMasteryController.has_selected_specialization(person.id):
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
