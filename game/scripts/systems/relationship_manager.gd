extends Node

signal relationships_changed
signal relationship_event(event: Dictionary)
signal social_incident_available(incident: Dictionary)
signal social_incident_resolved(result: Dictionary)
signal interventions_changed(remaining: int)

const MAX_WEEKLY_INTERVENTIONS := 2
const PAIR_INTERACTION_COOLDOWN_WEEKS := 2
const INCIDENT_COOLDOWN_WEEKS := 2

var relationships: Dictionary = {}
var recent_events: Array[Dictionary] = []
var pending_incident: Dictionary = {}
var incident_cooldown: int = 0
var day_serial: int = 0
var incident_serial: int = 0
var interventions_week: int = 1
var interventions_used: int = 0
var last_processed_week: int = 0

func _ready() -> void:
    RosterManager.roster_changed.connect(_ensure_all_pairs)
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.week_advanced.connect(_on_week_advanced)
    call_deferred("_ensure_all_pairs")

func _on_week_advanced(week: int) -> void:
    _reset_interventions_for_week(week)
    relationships_changed.emit()

func _pair_key(a_id: String, b_id: String) -> String:
    if a_id < b_id:
        return "%s|%s" % [a_id, b_id]
    return "%s|%s" % [b_id, a_id]

func _ensure_all_pairs() -> void:
    var people: Array = RosterManager.get_people()
    for i: int in range(people.size()):
        for j: int in range(i + 1, people.size()):
            ensure_relationship(str(people[i].id), str(people[j].id))

func ensure_relationship(a_id: String, b_id: String) -> Dictionary:
    if a_id == b_id:
        return {}
    var key := _pair_key(a_id, b_id)
    if not relationships.has(key):
        relationships[key] = {
            "a_id": a_id,
            "b_id": b_id,
            "affinity": 0,
            "respect": 0,
            "rivalry": 0,
            "jealousy": 0,
            "mentorship": 0,
            "state": "neutral",
            "tone": "",
            "last_change": "Sin cambios",
            "last_interaction_week": -999
        }
    var relation: Dictionary = relationships[key]
    relation["last_interaction_week"] = int(relation.get("last_interaction_week", -999))
    relation["state"] = _derive_state(relation)
    relation["tone"] = _derive_tone(relation)
    return relation

# Compatibility entry point. RosterManager invokes this during each internal
# work tick, but social simulation is intentionally processed only once per
# visible campaign week.
func process_day(totals: Dictionary) -> Array:
    var week := GameState.get_week()
    _reset_interventions_for_week(week)
    if last_processed_week == week:
        return []

    last_processed_week = week
    day_serial += 1
    incident_cooldown = maxi(0, incident_cooldown - 1)
    _ensure_all_pairs()

    var events: Array = []
    _process_shared_activities(totals, events)
    _process_fame_tension(events)
    _apply_weekly_social_effects()
    _refresh_all_states(events)
    _try_generate_social_incident()

    relationships_changed.emit()
    return events

func _process_shared_activities(totals: Dictionary, events: Array) -> void:
    var groups: Dictionary = {}
    for person in RosterManager.get_people():
        var job_id := str(person.job)
        if job_id == "idle":
            continue
        if not groups.has(job_id):
            groups[job_id] = []
        groups[job_id].append(person)

    for job_id in groups.keys():
        var workers: Array = groups[job_id]
        # Pair sequentially: each person creates at most one automatic social
        # interaction per week, avoiding quadratic gains with large rosters.
        var cursor := 0
        while cursor + 1 < workers.size():
            var a = workers[cursor]
            var b = workers[cursor + 1]
            cursor += 2
            var relation := ensure_relationship(str(a.id), str(b.id))
            var previous_state := str(relation.get("state", "neutral"))
            relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 1, -100, 100)
            relation["respect"] = clampi(int(relation.get("respect", 0)) + 1, -100, 100)
            if str(job_id) == "training":
                var mentoring_gain := 2 if a.traits.has("mentor") or b.traits.has("mentor") else 1
                relation["mentorship"] = clampi(int(relation.get("mentorship", 0)) + mentoring_gain, 0, 100)
                totals["training"] = int(totals.get("training", 0)) + 1
            _stamp_relation(relation)
            _append_state_event_if_changed(a, b, relation, previous_state, events)

func _process_fame_tension(events: Array) -> void:
    for relation_value in relationships.values():
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        var a = RosterManager.get_person(str(relation.get("a_id", "")))
        var b = RosterManager.get_person(str(relation.get("b_id", "")))
        if a == null or b == null or str(a.role) != "gladiator" or str(b.role) != "gladiator":
            continue
        var a_progress := GladiatorProgressionManager.get_record(str(a.id))
        var b_progress := GladiatorProgressionManager.get_record(str(b.id))
        var fame_gap := absi(int(a_progress.get("fame", 0)) - int(b_progress.get("fame", 0)))
        if fame_gap < 20:
            continue
        if not (a.traits.has("popular") or b.traits.has("popular") or a.traits.has("vengeful") or b.traits.has("vengeful")):
            continue
        var previous_state := str(relation.get("state", "neutral"))
        relation["jealousy"] = clampi(int(relation.get("jealousy", 0)) + 2, 0, 100)
        if a.traits.has("vengeful") or b.traits.has("vengeful"):
            relation["rivalry"] = clampi(int(relation.get("rivalry", 0)) + 1, 0, 100)
        _stamp_relation(relation)
        _append_state_event_if_changed(a, b, relation, previous_state, events)

func _apply_weekly_social_effects() -> void:
    var morale_delta: Dictionary = {}
    var fatigue_delta: Dictionary = {}
    for relation_value in relationships.values():
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        var a_id := str(relation.get("a_id", ""))
        var b_id := str(relation.get("b_id", ""))
        if RosterManager.get_person(a_id) == null or RosterManager.get_person(b_id) == null:
            continue
        match str(relation.get("state", "neutral")):
            "amistad":
                morale_delta[a_id] = int(morale_delta.get(a_id, 0)) + 1
                morale_delta[b_id] = int(morale_delta.get(b_id, 0)) + 1
            "mentoría":
                morale_delta[a_id] = int(morale_delta.get(a_id, 0)) + 1
                morale_delta[b_id] = int(morale_delta.get(b_id, 0)) + 1
            "rivalidad":
                fatigue_delta[a_id] = int(fatigue_delta.get(a_id, 0)) + 1
                fatigue_delta[b_id] = int(fatigue_delta.get(b_id, 0)) + 1
            "enemistad":
                morale_delta[a_id] = int(morale_delta.get(a_id, 0)) - 2
                morale_delta[b_id] = int(morale_delta.get(b_id, 0)) - 2

    for person in RosterManager.get_people():
        var person_id := str(person.id)
        var morale_change := clampi(int(morale_delta.get(person_id, 0)), -3, 3)
        var fatigue_change := clampi(int(fatigue_delta.get(person_id, 0)), 0, 2)
        person.morale = clampi(int(person.morale) + morale_change, 0, 100)
        person.fatigue = clampi(int(person.fatigue) + fatigue_change, 0, 100)

func _refresh_all_states(events: Array) -> void:
    for relation_value in relationships.values():
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        var a = RosterManager.get_person(str(relation.get("a_id", "")))
        var b = RosterManager.get_person(str(relation.get("b_id", "")))
        if a == null or b == null:
            continue
        var previous_state := str(relation.get("state", "neutral"))
        relation["state"] = _derive_state(relation)
        relation["tone"] = _derive_tone(relation)
        _append_state_event_if_changed(a, b, relation, previous_state, events)

func register_interaction(a_id: String, b_id: String, interaction: String) -> Dictionary:
    _reset_interventions_for_week(GameState.get_week())
    var relation := ensure_relationship(a_id, b_id)
    var a = RosterManager.get_person(a_id)
    var b = RosterManager.get_person(b_id)
    if relation.is_empty() or a == null or b == null:
        return _interaction_failure("La pareja seleccionada ya no está disponible.")
    if interventions_used >= MAX_WEEKLY_INTERVENTIONS:
        return _interaction_failure("Ya utilizaste las dos intervenciones sociales de esta semana.")

    var last_week := int(relation.get("last_interaction_week", -999))
    if GameState.get_week() - last_week < PAIR_INTERACTION_COOLDOWN_WEEKS:
        return _interaction_failure("Esta pareja necesita tiempo antes de otra intervención.")

    var canonical_interaction := "foster_competition" if interaction == "encourage_rivalry" else interaction
    var validation := can_register_interaction(a_id, b_id, canonical_interaction)
    if not bool(validation.get("allowed", false)):
        return _interaction_failure(str(validation.get("reason", "La intervención no está disponible.")))

    var previous_state := str(relation.get("state", "neutral"))
    var description := ""
    match canonical_interaction:
        "train_together":
            relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 3, -100, 100)
            relation["respect"] = clampi(int(relation.get("respect", 0)) + 4, -100, 100)
            a.fatigue = mini(100, int(a.fatigue) + 6)
            b.fatigue = mini(100, int(b.fatigue) + 6)
            description = "%s y %s completaron una sesión conjunta." % [a.display_name, b.display_name]
        "mediate":
            if not GameState.spend_denarii(15):
                return _interaction_failure("No hay suficientes denarios para mediar.")
            relation["rivalry"] = maxi(0, int(relation.get("rivalry", 0)) - 12)
            relation["jealousy"] = maxi(0, int(relation.get("jealousy", 0)) - 8)
            description = "La mediación redujo la tensión entre %s y %s." % [a.display_name, b.display_name]
        "foster_competition":
            relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 10)
            relation["respect"] = mini(100, int(relation.get("respect", 0)) + 5)
            a.fatigue = mini(100, int(a.fatigue) + 6)
            b.fatigue = mini(100, int(b.fatigue) + 6)
            description = "%s y %s iniciaron una competencia controlada." % [a.display_name, b.display_name]
        "support_bond":
            if int(relation.get("mentorship", 0)) >= 30:
                relation["mentorship"] = mini(100, int(relation.get("mentorship", 0)) + 4)
            else:
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 4, -100, 100)
            a.morale = mini(100, int(a.morale) + 2)
            b.morale = mini(100, int(b.morale) + 2)
            description = "El ludus respaldó el vínculo entre %s y %s." % [a.display_name, b.display_name]
        _:
            return _interaction_failure("La intervención seleccionada no existe.")

    interventions_used += 1
    relation["last_interaction_week"] = GameState.get_week()
    _stamp_relation(relation)
    var event := {
        "type": "relationship_interaction",
        "a_id": a_id,
        "b_id": b_id,
        "interaction": canonical_interaction,
        "description": description,
        "week": GameState.get_week()
    }
    _push_event(event)
    if previous_state != str(relation.get("state", "neutral")):
        _push_event(_build_state_event(a, b, relation))
    RosterManager.roster_changed.emit()
    relationships_changed.emit()
    interventions_changed.emit(get_interventions_remaining())
    return {
        "success": true,
        "description": description,
        "interventions_remaining": get_interventions_remaining()
    }

func can_register_interaction(a_id: String, b_id: String, interaction: String) -> Dictionary:
    var relation := ensure_relationship(a_id, b_id)
    var a = RosterManager.get_person(a_id)
    var b = RosterManager.get_person(b_id)
    if relation.is_empty() or a == null or b == null:
        return {"allowed": false, "reason": "Pareja no disponible."}
    if interventions_used >= MAX_WEEKLY_INTERVENTIONS:
        return {"allowed": false, "reason": "Sin intervenciones semanales."}
    if GameState.get_week() - int(relation.get("last_interaction_week", -999)) < PAIR_INTERACTION_COOLDOWN_WEEKS:
        return {"allowed": false, "reason": "Pareja en descanso social."}

    match interaction:
        "train_together":
            if int(a.injury_days) > 0 or int(b.injury_days) > 0:
                return {"allowed": false, "reason": "No pueden entrenar mientras haya lesiones."}
            if int(a.fatigue) >= 85 or int(b.fatigue) >= 85:
                return {"allowed": false, "reason": "Uno de los dos está agotado."}
        "mediate":
            if get_tension(relation) < 25:
                return {"allowed": false, "reason": "No existe un conflicto que justifique mediación."}
            if GameState.denarii < 15:
                return {"allowed": false, "reason": "Requiere 15 denarios."}
        "foster_competition":
            if str(a.role) != "gladiator" or str(b.role) != "gladiator":
                return {"allowed": false, "reason": "Solo puede organizarse entre gladiadores."}
        "support_bond":
            if int(relation.get("affinity", 0)) < 25 and int(relation.get("mentorship", 0)) < 25 and int(relation.get("respect", 0)) < 30:
                return {"allowed": false, "reason": "Todavía no existe un vínculo que respaldar."}
        _:
            return {"allowed": false, "reason": "Intervención desconocida."}
    return {"allowed": true, "reason": ""}

func get_available_interactions(a_id: String, b_id: String) -> Array[Dictionary]:
    var definitions: Array[Dictionary] = [
        {"id":"train_together", "label":"ENTRENAR JUNTOS", "cost":"1 intervención · +6 fatiga"},
        {"id":"mediate", "label":"MEDIAR", "cost":"1 intervención · 15 denarios"},
        {"id":"foster_competition", "label":"FOMENTAR COMPETENCIA", "cost":"1 intervención · riesgo de tensión"},
        {"id":"support_bond", "label":"APOYAR VÍNCULO", "cost":"1 intervención"}
    ]
    for definition in definitions:
        var validation := can_register_interaction(a_id, b_id, str(definition.get("id", "")))
        definition["allowed"] = bool(validation.get("allowed", false))
        definition["reason"] = str(validation.get("reason", ""))
    return definitions

func resolve_social_incident(choice_id: String) -> Dictionary:
    if pending_incident.is_empty():
        return {}
    var relation := ensure_relationship(str(pending_incident.get("a_id", "")), str(pending_incident.get("b_id", "")))
    var actor = RosterManager.get_person(str(pending_incident.get("actor_id", pending_incident.get("a_id", ""))))
    var target = RosterManager.get_person(str(pending_incident.get("target_id", pending_incident.get("b_id", ""))))
    if relation.is_empty() or actor == null or target == null:
        pending_incident.clear()
        relationships_changed.emit()
        return {}

    var description := ""
    match str(pending_incident.get("type", "")):
        "jealousy":
            if choice_id == "recognize_both":
                if not GameState.spend_denarii(30): return {}
                relation["jealousy"] = maxi(0, int(relation.get("jealousy", 0)) - 18)
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 6, -100, 100)
                actor.morale = mini(100, int(actor.morale) + 5)
                target.morale = mini(100, int(target.morale) + 5)
                description = "El reconocimiento compartido redujo los celos."
            elif choice_id == "favor_actor":
                _apply_favorite_choice(actor, target, relation)
                description = "%s fue favorecido y la tensión aumentó." % actor.display_name
            elif choice_id == "favor_target" or choice_id == "choose_favorite":
                _apply_favorite_choice(target, actor, relation)
                description = "%s fue favorecido y la tensión aumentó." % target.display_name
            elif choice_id == "ignore":
                relation["jealousy"] = mini(100, int(relation.get("jealousy", 0)) + 8)
                description = "La tensión continuó creciendo sin intervención."
            else: return {}
        "mentorship":
            if choice_id == "formalize":
                relation["mentorship"] = mini(100, int(relation.get("mentorship", 0)) + 20)
                relation["respect"] = mini(100, int(relation.get("respect", 0)) + 10)
                actor.training += 4
                target.training += 8
                description = "La mentoría fue formalizada y el aprendiz progresó."
            elif choice_id == "separate":
                relation["mentorship"] = maxi(0, int(relation.get("mentorship", 0)) - 15)
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) - 5, -100, 100)
                description = "La separación debilitó el vínculo de aprendizaje."
            else: return {}
        "friendship":
            if choice_id == "celebrate":
                if not GameState.spend_denarii(20): return {}
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 10, -100, 100)
                actor.morale = mini(100, int(actor.morale) + 7)
                target.morale = mini(100, int(target.morale) + 7)
                description = "La celebración fortaleció la amistad."
            elif choice_id == "exploit":
                relation["respect"] = maxi(-100, int(relation.get("respect", 0)) - 8)
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) - 6, -100, 100)
                GameState.add_denarii(25)
                description = "El ludus obtuvo ingresos, pero perdió respeto."
            else: return {}
        "protection":
            if choice_id == "honor_protector":
                relation["respect"] = mini(100, int(relation.get("respect", 0)) + 15)
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 8, -100, 100)
                actor.loyalty = mini(100, int(actor.loyalty) + 4)
                target.loyalty = mini(100, int(target.loyalty) + 4)
                GameState.reputation += 2
                description = "%s fue honrado por proteger a %s." % [actor.display_name, target.display_name]
            elif choice_id == "punish_interference":
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) - 12, -100, 100)
                relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 8)
                actor.morale = maxi(0, int(actor.morale) - 5)
                description = "Castigar la intervención dañó profundamente el vínculo."
            else: return {}
        "betrayal":
            if choice_id == "reconcile":
                if not GameState.spend_denarii(35): return {}
                relation["rivalry"] = maxi(0, int(relation.get("rivalry", 0)) - 20)
                relation["jealousy"] = maxi(0, int(relation.get("jealousy", 0)) - 15)
                relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 8, -100, 100)
                description = "La reconciliación evitó una ruptura definitiva."
            elif choice_id == "sanction_actor" or choice_id == "sanction":
                relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 10)
                relation["respect"] = maxi(-100, int(relation.get("respect", 0)) - 12)
                actor.loyalty = maxi(0, int(actor.loyalty) - 6)
                description = "%s fue sancionado; el orden volvió, pero la enemistad creció." % actor.display_name
            else: return {}
        _:
            return {}

    _stamp_relation(relation)
    var result := pending_incident.duplicate(true)
    result["choice_id"] = choice_id
    result["description"] = description
    result["resolved_week"] = GameState.get_week()
    pending_incident.clear()
    incident_cooldown = INCIDENT_COOLDOWN_WEEKS
    _push_event(result)
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    relationships_changed.emit()
    social_incident_resolved.emit(result)
    return result

func _apply_favorite_choice(favored, other, relation: Dictionary) -> void:
    relation["jealousy"] = mini(100, int(relation.get("jealousy", 0)) + 15)
    relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 10)
    favored.morale = mini(100, int(favored.morale) + 6)
    other.morale = maxi(0, int(other.morale) - 8)

func get_relationship(a_id: String, b_id: String) -> Dictionary:
    return _enrich_relation(ensure_relationship(a_id, b_id), a_id)

func get_person_relationships(person_id: String) -> Array:
    var result: Array = []
    for relation_value in relationships.values():
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        if str(relation.get("a_id", "")) == person_id or str(relation.get("b_id", "")) == person_id:
            var enriched := _enrich_relation(relation, person_id)
            if not enriched.is_empty():
                result.append(enriched)
    result.sort_custom(_sort_by_importance)
    return result

func get_priority_relationships(limit: int = 8) -> Array:
    var result: Array = []
    for relation_value in relationships.values():
        if relation_value is Dictionary:
            var enriched := _enrich_relation(relation_value, "")
            if not enriched.is_empty():
                result.append(enriched)
    result.sort_custom(_sort_by_importance)
    if result.size() > limit:
        result.resize(limit)
    return result

func _sort_by_importance(left: Dictionary, right: Dictionary) -> bool:
    return int(left.get("importance", 0)) > int(right.get("importance", 0))

func _enrich_relation(source: Dictionary, perspective_id: String) -> Dictionary:
    if source.is_empty():
        return {}
    var result := source.duplicate(true)
    var a = RosterManager.get_person(str(source.get("a_id", "")))
    var b = RosterManager.get_person(str(source.get("b_id", "")))
    if a == null or b == null:
        return {}
    var other = b if perspective_id == str(a.id) else a
    result["a_name"] = a.display_name
    result["b_name"] = b.display_name
    result["other_id"] = str(other.id)
    result["other_name"] = other.display_name
    result["tension"] = get_tension(source)
    result["state"] = _derive_state(source)
    result["state_label"] = get_state_label(str(result["state"]))
    result["tone"] = _derive_tone(source)
    result["effect_summary"] = get_effect_summary(source)
    result["importance"] = _relationship_importance(source)
    return result

func get_social_overview() -> Dictionary:
    var valid_count := 0
    var total_affinity := 0
    var total_respect := 0
    var total_tension := 0
    var mentorships := 0
    var conflicts := 0
    var friendships := 0
    for relation_value in relationships.values():
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        if RosterManager.get_person(str(relation.get("a_id", ""))) == null or RosterManager.get_person(str(relation.get("b_id", ""))) == null:
            continue
        valid_count += 1
        total_affinity += int(relation.get("affinity", 0))
        total_respect += int(relation.get("respect", 0))
        total_tension += get_tension(relation)
        match _derive_state(relation):
            "mentoría": mentorships += 1
            "enemistad": conflicts += 1
            "amistad": friendships += 1

    var divisor := maxi(1, valid_count)
    var average_affinity := int(round(float(total_affinity) / float(divisor)))
    var average_respect := int(round(float(total_respect) / float(divisor)))
    var average_tension := int(round(float(total_tension) / float(divisor)))
    var cohesion := clampi(50 + int(round(float(average_affinity + average_respect - average_tension) / 3.0)), 0, 100)
    return {
        "cohesion": cohesion,
        "tension": clampi(average_tension, 0, 100),
        "mentorships": mentorships,
        "conflicts": conflicts,
        "friendships": friendships,
        "relationships": valid_count,
        "interventions_remaining": get_interventions_remaining(),
        "pending_incident": not pending_incident.is_empty()
    }

func get_pending_incident() -> Dictionary:
    return pending_incident.duplicate(true)

func get_interventions_remaining() -> int:
    _reset_interventions_for_week(GameState.get_week())
    return maxi(0, MAX_WEEKLY_INTERVENTIONS - interventions_used)

func get_tension(relation: Dictionary) -> int:
    return clampi(maxi(int(relation.get("rivalry", 0)), int(relation.get("jealousy", 0))), 0, 100)

func get_state_label(state: String) -> String:
    var labels := {
        "neutral":"Neutral",
        "respeto":"Respeto",
        "amistad":"Amistad",
        "rivalidad":"Rivalidad",
        "mentoría":"Mentoría",
        "enemistad":"Enemistad"
    }
    return str(labels.get(state, state.capitalize()))

func get_effect_summary(relation: Dictionary) -> String:
    match _derive_state(relation):
        "amistad": return "+Moral semanal, reacción emocional ante heridas."
        "mentoría": return "+Moral y progreso cuando entrenan juntos."
        "rivalidad": return "+Competencia, pero aumenta la fatiga y el riesgo social."
        "enemistad": return "Pérdida semanal de moral y riesgo de traición."
        "respeto": return "Vínculo estable sin bonificación activa."
        _: return "Sin efecto relevante todavía."

func get_combat_morale_bonus(person_id: String) -> int:
    var bonus := 0
    for relation_value in get_person_relationships(person_id):
        var relation: Dictionary = relation_value
        match str(relation.get("state", "neutral")):
            "amistad": bonus += 2
            "mentoría": bonus += 1
            "rivalidad":
                if int(relation.get("respect", 0)) >= 30:
                    bonus += 1
            "enemistad": bonus -= 2
    return clampi(bonus, -4, 4)

func export_state() -> Dictionary:
    return {
        "relationships": relationships.duplicate(true),
        "recent_events": recent_events.duplicate(true),
        "pending_incident": pending_incident.duplicate(true),
        "incident_cooldown": incident_cooldown,
        "day_serial": day_serial,
        "incident_serial": incident_serial,
        "interventions_week": interventions_week,
        "interventions_used": interventions_used,
        "last_processed_week": last_processed_week
    }

func import_state(data: Dictionary) -> void:
    relationships = data.get("relationships", {}).duplicate(true)
    recent_events.assign(data.get("recent_events", []))
    pending_incident = data.get("pending_incident", {}).duplicate(true)
    incident_cooldown = maxi(0, int(data.get("incident_cooldown", 0)))
    day_serial = maxi(0, int(data.get("day_serial", 0)))
    incident_serial = maxi(0, int(data.get("incident_serial", 0)))
    interventions_week = maxi(1, int(data.get("interventions_week", GameState.get_week())))
    interventions_used = clampi(int(data.get("interventions_used", 0)), 0, MAX_WEEKLY_INTERVENTIONS)
    last_processed_week = maxi(0, int(data.get("last_processed_week", 0)))
    _reset_interventions_for_week(GameState.get_week())
    _ensure_all_pairs()
    relationships_changed.emit()

func _on_combat_finished(result: Dictionary) -> void:
    var fighter_id := str(result.get("fighter_id", ""))
    if fighter_id.is_empty():
        return
    var fighter = RosterManager.get_person(fighter_id)
    for relation_value in get_person_relationships(fighter_id):
        var relation: Dictionary = relation_value
        var other_id := str(relation.get("other_id", ""))
        var stored := ensure_relationship(fighter_id, other_id)
        if bool(result.get("victory", false)):
            stored["respect"] = mini(100, int(stored.get("respect", 0)) + 3)
            var other = RosterManager.get_person(other_id)
            if other != null and fighter != null and (other.traits.has("popular") or fighter.traits.has("popular")):
                stored["jealousy"] = mini(100, int(stored.get("jealousy", 0)) + 2)
        else:
            if int(stored.get("affinity", 0)) > 20:
                stored["affinity"] = clampi(int(stored.get("affinity", 0)) + 2, -100, 100)
            if fighter != null and fighter.traits.has("vengeful"):
                stored["rivalry"] = mini(100, int(stored.get("rivalry", 0)) + 3)
        _stamp_relation(stored)
    relationships_changed.emit()

func _try_generate_social_incident() -> void:
    if not pending_incident.is_empty() or incident_cooldown > 0:
        return
    var candidates: Array[Dictionary] = []
    for relation_value in relationships.values():
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        var state := _derive_state(relation)
        if int(relation.get("jealousy", 0)) >= 55:
            candidates.append(_make_incident("jealousy", relation, "Los celos amenazan con dividir el ludus.", ["recognize_both", "favor_actor", "favor_target", "ignore"]))
        elif state == "mentoría" and int(relation.get("mentorship", 0)) >= 55:
            candidates.append(_make_incident("mentorship", relation, "Una mentoría reclama reconocimiento formal.", ["formalize", "separate"]))
        elif state == "amistad" and int(relation.get("affinity", 0)) >= 60:
            candidates.append(_make_incident("friendship", relation, "Una amistad se ha vuelto visible para toda la casa.", ["celebrate", "exploit"]))
        elif state == "enemistad":
            candidates.append(_make_incident("betrayal", relation, "Una enemistad amenaza con convertirse en traición.", ["reconcile", "sanction_actor"]))
        elif int(relation.get("respect", 0)) >= 60 and int(relation.get("affinity", 0)) >= 25 and _pair_has_trait(relation, "protector"):
            candidates.append(_make_incident("protection", relation, "Uno de ellos protegió al otro durante una crisis.", ["honor_protector", "punish_interference"]))
    if candidates.is_empty() or randf() > 0.35:
        return
    pending_incident = candidates[randi_range(0, candidates.size() - 1)]
    social_incident_available.emit(pending_incident.duplicate(true))
    relationships_changed.emit()

func _make_incident(type_id: String, relation: Dictionary, text: String, choices: Array) -> Dictionary:
    incident_serial += 1
    var a = RosterManager.get_person(str(relation.get("a_id", "")))
    var b = RosterManager.get_person(str(relation.get("b_id", "")))
    var actor = a
    var target = b
    if a != null and b != null:
        match type_id:
            "jealousy":
                var a_fame := int(GladiatorProgressionManager.get_record(str(a.id)).get("fame", 0)) if str(a.role) == "gladiator" else 0
                var b_fame := int(GladiatorProgressionManager.get_record(str(b.id)).get("fame", 0)) if str(b.role) == "gladiator" else 0
                actor = a if a_fame <= b_fame else b
                target = b if actor == a else a
            "mentorship":
                actor = a if a.traits.has("mentor") else (b if b.traits.has("mentor") else a)
                target = b if actor == a else a
            "protection":
                actor = a if a.traits.has("protector") else (b if b.traits.has("protector") else a)
                target = b if actor == a else a
            "betrayal":
                actor = a if int(a.loyalty) <= int(b.loyalty) else b
                target = b if actor == a else a
    return {
        "id": "social_%d" % incident_serial,
        "type": type_id,
        "a_id": relation.get("a_id", ""),
        "b_id": relation.get("b_id", ""),
        "a_name": a.display_name if a != null else "Desconocido",
        "b_name": b.display_name if b != null else "Desconocido",
        "actor_id": actor.id if actor != null else relation.get("a_id", ""),
        "target_id": target.id if target != null else relation.get("b_id", ""),
        "actor_name": actor.display_name if actor != null else "Desconocido",
        "target_name": target.display_name if target != null else "Desconocido",
        "title": _incident_title(type_id),
        "description": text,
        "choices": choices,
        "created_week": GameState.get_week()
    }

func get_choice_label(choice_id: String) -> String:
    if pending_incident.get("type", "") == "jealousy":
        if choice_id == "favor_actor":
            return "Favorecer a %s" % pending_incident.get("actor_name", "uno")
        if choice_id == "favor_target":
            return "Favorecer a %s" % pending_incident.get("target_name", "otro")
    var labels := {
        "recognize_both":"Reconocer a ambos (30 denarios)",
        "ignore":"Ignorar la tensión",
        "formalize":"Formalizar mentoría",
        "separate":"Separarlos",
        "celebrate":"Celebrar el vínculo (20 denarios)",
        "exploit":"Explotar su popularidad",
        "honor_protector":"Honrar al protector",
        "punish_interference":"Castigar la intervención",
        "reconcile":"Financiar reconciliación (35 denarios)",
        "sanction_actor":"Sancionar al responsable"
    }
    return str(labels.get(choice_id, choice_id.capitalize()))

func _incident_title(type_id: String) -> String:
    var titles := {
        "jealousy":"Celos en el ludus",
        "mentorship":"Mentoría emergente",
        "friendship":"Amistad visible",
        "protection":"Acto de protección",
        "betrayal":"Riesgo de traición"
    }
    return str(titles.get(type_id, "Incidente social"))

func _derive_state(relation: Dictionary) -> String:
    var affinity := int(relation.get("affinity", 0))
    var respect := int(relation.get("respect", 0))
    var rivalry := int(relation.get("rivalry", 0))
    var mentorship := int(relation.get("mentorship", 0))
    var tension := get_tension(relation)
    if tension >= 70 and (affinity <= 10 or respect <= 0):
        return "enemistad"
    if mentorship >= 45 and respect >= 25 and tension < 65:
        return "mentoría"
    if rivalry >= 45 and (respect >= 20 or affinity > -20):
        return "rivalidad"
    if tension >= 50:
        return "rivalidad"
    if affinity >= 45 and tension < 45:
        return "amistad"
    if respect >= 35:
        return "respeto"
    return "neutral"

func _derive_tone(relation: Dictionary) -> String:
    var state := _derive_state(relation)
    var tension := get_tension(relation)
    if state == "rivalidad" and int(relation.get("respect", 0)) >= 35:
        return "Rivalidad respetuosa"
    if state == "amistad" and int(relation.get("jealousy", 0)) >= 25:
        return "Amistad con celos"
    if state == "mentoría" and int(relation.get("affinity", 0)) >= 40:
        return "Mentoría cercana"
    if state == "enemistad" and tension >= 85:
        return "Enemistad abierta"
    return get_state_label(state)

func _relationship_importance(relation: Dictionary) -> int:
    var score := get_tension(relation)
    score += absi(int(relation.get("affinity", 0))) / 2
    score += int(relation.get("mentorship", 0)) / 2
    if _derive_state(relation) == "enemistad":
        score += 80
    elif _derive_state(relation) in ["amistad", "mentoría", "rivalidad"]:
        score += 35
    return score

func _build_state_event(a, b, relation: Dictionary) -> Dictionary:
    var state := str(relation.get("state", "neutral"))
    return {
        "type": "relationship_state",
        "a_id": a.id,
        "b_id": b.id,
        "state": state,
        "description": "%s y %s desarrollaron un vínculo de %s." % [a.display_name, b.display_name, get_state_label(state).to_lower()],
        "week": GameState.get_week()
    }

func _append_state_event_if_changed(a, b, relation: Dictionary, previous_state: String, events: Array) -> void:
    relation["state"] = _derive_state(relation)
    relation["tone"] = _derive_tone(relation)
    if previous_state == str(relation.get("state", "neutral")):
        return
    var event := _build_state_event(a, b, relation)
    events.append(event)
    _push_event(event)

func _stamp_relation(relation: Dictionary) -> void:
    relation["state"] = _derive_state(relation)
    relation["tone"] = _derive_tone(relation)
    relation["last_change"] = "Semana %d" % GameState.get_week()

func _pair_has_trait(relation: Dictionary, trait_id: String) -> bool:
    var a = RosterManager.get_person(str(relation.get("a_id", "")))
    var b = RosterManager.get_person(str(relation.get("b_id", "")))
    return (a != null and a.traits.has(trait_id)) or (b != null and b.traits.has(trait_id))

func _reset_interventions_for_week(week: int) -> void:
    if interventions_week == week:
        return
    interventions_week = week
    interventions_used = 0
    interventions_changed.emit(get_interventions_remaining())

func _interaction_failure(reason: String) -> Dictionary:
    return {"success": false, "description": reason, "reason": reason, "interventions_remaining": get_interventions_remaining()}

func _push_event(event: Dictionary) -> void:
    recent_events.push_front(event.duplicate(true))
    if recent_events.size() > 50:
        recent_events.resize(50)
    relationship_event.emit(event)
