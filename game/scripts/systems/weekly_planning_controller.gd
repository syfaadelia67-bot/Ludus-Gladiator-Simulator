extends Node

signal planning_changed


func _ready() -> void:
	GameState.resources_changed.connect(_emit_changed)
	RosterManager.roster_changed.connect(_emit_changed)
	EventManager.events_changed.connect(_emit_changed)
	EconomyManager.economy_changed.connect(_emit_changed)
	CombatManager.combat_finished.connect(func(_result: Dictionary): _emit_changed())
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
	var event_pending := not EventManager.get_pending_event().is_empty()
	var fight := TournamentManager.get_gt1_encounter(GameState.get_month())
	var fight_pending := false
	if not fight.is_empty():
		var gt1_summary := TournamentManager.get_gt1_summary()
		var progress: Dictionary = gt1_summary.get("encounter_progress", {})
		fight_pending = int(progress.get(str(GameState.get_month()), 0)) < 3
		fight["required"] = true
	else:
		fight = {
			"month": GameState.get_month(),
			"required": false,
			"name": "Gestión del ludus",
		}
	var blockers: Array[String] = []
	var warnings: Array[String] = []

	if event_pending:
		blockers.append("Hay un evento mensual pendiente de resolución.")
	if fight_pending:
		blockers.append("El encuentro del Gran Torneo de este mes todavía no fue completado.")
	if GameState.food < food_consumption:
		warnings.append("La comida no alcanza para cubrir el consumo previsto.")
	if GameState.denarii + int(economy.get("income", 0)) < int(economy.get("expenses", 0)):
		warnings.append("La tesorería proyectada no alcanza para todos los pagos.")
	if available_gladiators == 0 and RosterManager.has_gladiator():
		warnings.append("No hay gladiadores disponibles para combatir.")
	if not bool(roster_policy.get("work_outputs_enabled", false)):
		(
			warnings
			. append(
				"Trabajo, entrenamiento, fatiga y recuperación no aplicarán cambios numéricos hasta congelar su balance mensual."
			)
		)

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
		"blockers": blockers,
		"warnings": warnings,
		"can_close": blockers.is_empty() and not CampaignManager.campaign_over,
	}
