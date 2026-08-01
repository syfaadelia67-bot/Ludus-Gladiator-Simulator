extends Node

signal planning_changed

func _ready() -> void:
    GameState.resources_changed.connect(_emit_changed)
    RosterManager.roster_changed.connect(_emit_changed)
    EventManager.events_changed.connect(_emit_changed)
    EconomyManager.economy_changed.connect(_emit_changed)
    CombatManager.combat_finished.connect(func(_result: Dictionary): _emit_changed())
    GladiatorTrainingController.training_focus_changed.connect(func(_person_id: String, _focus_id: String): _emit_changed())

func _emit_changed() -> void:
    planning_changed.emit()

func get_summary() -> Dictionary:
    var assignments: Array[Dictionary] = []
    var training: Array[Dictionary] = []
    var injured: Array[Dictionary] = []
    var available_gladiators := 0
    var retired_staff := 0

    for person in RosterManager.get_people():
        assignments.append({
            "id": person.id,
            "name": person.display_name,
            "role": person.role,
            "job": person.job,
            "job_name": RosterManager.get_job_name(person.job),
            "fatigue": person.fatigue
        })
        if person.role == "gladiator":
            if person.is_available_for_combat():
                available_gladiators += 1
            if person.job == "training":
                training.append(GladiatorTrainingController.get_preview(person.id))
                training[training.size() - 1]["id"] = person.id
                training[training.size() - 1]["name"] = person.display_name
            if person.injury_days > 0:
                injured.append({
                    "id": person.id,
                    "name": person.display_name,
                    "injury": person.injury_name,
                    "severity": person.injury_severity,
                    "weeks": person.injury_days
                })
        elif person.role == "retired":
            retired_staff += 1

    var economy := EconomyManager.get_weekly_projection()
    var food_consumption := maxi(1, int(ceil(float(RosterManager.get_people().size() * GameState.DAYS_PER_WEEK) * EventManager.get_food_consumption_multiplier())))
    var event_pending := not EventManager.get_pending_event().is_empty()
    var fight_pending := UniqueGladiatorManager.first_purchase_completed and RosterManager.has_gladiator() and CombatManager.last_combat_day != GameState.day
    var blockers: Array[String] = []
    var warnings: Array[String] = []

    if event_pending:
        blockers.append("Hay un evento semanal pendiente de resolución.")
    if fight_pending:
        blockers.append("El combate obligatorio de esta semana todavía no fue disputado.")
    if GameState.food < food_consumption:
        warnings.append("La comida no alcanza para cubrir el consumo previsto.")
    if GameState.denarii + int(economy.get("income", 0)) < int(economy.get("expenses", 0)):
        warnings.append("La tesorería proyectada no alcanza para todos los pagos.")
    if available_gladiators == 0 and RosterManager.has_gladiator():
        warnings.append("No hay gladiadores disponibles para combatir.")
    for item in training:
        if int(item.get("injury_risk", 0)) >= 20:
            warnings.append("%s tiene %d%% de riesgo de lesión por entrenamiento." % [item.get("name", "Gladiador"), int(item.get("injury_risk", 0))])

    return {
        "week": GameState.get_week(),
        "next_week": GameState.get_week() + 1,
        "assignments": assignments,
        "training": training,
        "injured": injured,
        "retired_staff": retired_staff,
        "available_gladiators": available_gladiators,
        "food_consumption": food_consumption,
        "food_after": maxi(0, GameState.food - food_consumption),
        "economy": economy,
        "denarii_after": GameState.denarii + int(economy.get("net", 0)),
        "fight": CombatManager.get_current_event_details(),
        "fight_pending": fight_pending,
        "event_pending": event_pending,
        "blockers": blockers,
        "warnings": warnings,
        "can_close": blockers.is_empty() and not CampaignManager.campaign_over
    }
