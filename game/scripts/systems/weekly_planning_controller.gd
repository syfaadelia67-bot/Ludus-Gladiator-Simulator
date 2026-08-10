extends Node

signal planning_changed


func _ready() -> void:
	GameState.resources_changed.connect(_emit_changed)
	RosterManager.roster_changed.connect(_emit_changed)
	EventManager.events_changed.connect(_emit_changed)
	EconomyManager.economy_changed.connect(_emit_changed)
	TournamentManager.grand_tournament_changed.connect(func(_summary: Dictionary): _emit_changed())
	GladiatorTrainingController.training_focus_changed.connect(
		func(_person_id: String, _focus_id: String): _emit_changed()
	)


func _emit_changed() -> void:
	planning_changed.emit()


func get_summary() -> Dictionary:
	var assignments: Array[Dictionary] = []
	var training: Array[Dictionary] = []
	var injured: Array[Dictionary] = []
	var available_gladiators := 0
	var retired_staff := 0
	var roster_policy := RosterManager.get_monthly_work_policy()

	for person in RosterManager.get_people():
		(
			assignments
			. append(
				{
					"id": person.id,
					"name": person.display_name,
					"role": person.role,
					"job": person.job,
					"job_name": RosterManager.get_job_name(person.job),
					"fatigue": person.fatigue,
				}
			)
		)
		if person.role == "gladiator":
			if person.is_available_for_combat():
				available_gladiators += 1
			if person.job == "training":
				var preview: Dictionary = GladiatorTrainingController.get_preview(person.id)
				preview["id"] = person.id
				preview["name"] = person.display_name
				training.append(preview)
			if person.injury_days > 0:
				(
					injured
					. append(
						{
							"id": person.id,
							"name": person.display_name,
							"injury": person.injury_name,
							"severity": person.injury_severity,
							"months": person.get_injury_recovery_months(),
						}
					)
				)
		elif person.role == "retired":
			retired_staff += 1

	var economy := EconomyManager.get_monthly_projection()
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
	var closure := GameState.get_month_closure_status()
	var fight: Dictionary = closure.get("fight", {})
	var fight_pending := bool(closure.get("fight_pending", false))
	var event_pending := bool(closure.get("event_pending", false))
	var blockers: Array = closure.get("blockers", [])
	var warnings: Array[String] = []

	if GameState.food < food_consumption:
		warnings.append("La comida no alcanza para cubrir el consumo previsto.")
	if GameState.denarii + int(economy.get("income", 0)) < int(economy.get("expenses", 0)):
		warnings.append("La tesorería proyectada no alcanza para todos los pagos.")
	if available_gladiators == 0 and RosterManager.has_gladiator():
		warnings.append("No hay gladiadores disponibles para combatir.")
	if not bool(roster_policy.get("work_outputs_enabled", false)):
		warnings.append("Trabajo, entrenamiento, fatiga y recuperación: balance mensual pendiente.")

	return {
		"period": "month",
		"month": GameState.get_month(),
		"next_month": GameState.get_month() + 1,
		"assignments": assignments,
		"training": training,
		"injured": injured,
		"retired_staff": retired_staff,
		"available_gladiators": available_gladiators,
		"roster_policy": roster_policy,
		"food_consumption": food_consumption,
		"food_after": maxi(0, GameState.food - food_consumption),
		"economy": economy,
		"denarii_after": GameState.denarii + int(economy.get("net", 0)),
		"fight": fight,
		"fight_pending": fight_pending,
		"event_pending": event_pending,
		"blockers": blockers.duplicate(),
		"warnings": warnings,
		"can_close": bool(closure.get("can_close", false)),
		"closure": closure.duplicate(true),
	}
