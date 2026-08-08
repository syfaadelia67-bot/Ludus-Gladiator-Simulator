extends Node


func run() -> void:
	var manager_source := FileAccess.get_file_as_string(
		"res://scripts/systems/campaign_manager_demo.gd"
	)
	var controller_source := FileAccess.get_file_as_string(
		"res://scripts/systems/chapter_objective_controller.gd"
	)
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	_assert(
		manager_source.contains("var failed_objectives"),
		"Los objetivos fallidos deben persistir en el estado de campaña."
	)
	_assert(
		manager_source.contains("GameState.get_month() > _deadline_for_objective"),
		"La recompensa debe bloquearse después del plazo mensual."
	)
	_assert(
		manager_source.contains(
			"completed_objectives.has(objective_id) or failed_objectives.has(objective_id)"
		),
		"Un objetivo resuelto no debe evaluarse otra vez."
	)
	_assert(
		manager_source.contains("data[\"failed_objectives\"]"),
		"El guardado debe exportar objetivos fallidos."
	)
	_assert(
		manager_source.contains("data.get(\"failed_objectives\", [])"),
		"Partidas antiguas sin el campo deben seguir cargando."
	)
	_assert(
		manager_source.contains("data[\"deadline_month\"]"),
		"El contrato canónico del plazo debe expresarse en meses."
	)
	_assert(
		manager_source.contains("data[\"deadline_week\"]"),
		"El alias semanal debe conservarse temporalmente para compatibilidad."
	)
	_assert(
		manager_source.contains("objective_failed.emit"),
		"El vencimiento debe emitir una señal visible."
	)
	_assert(
		controller_source.contains("bool(objective.get(\"failed\", false))"),
		"La interfaz debe usar el estado oficial del manager."
	)
	_assert(
		project_source.contains(
			"CampaignManager=\"*res://scripts/systems/campaign_manager_demo.gd\""
		),
		"La extensión de campaña debe estar activa."
	)

	print("chapter_objective_deadline_persistence_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("chapter_objective_deadline_persistence_test: %s" % message)
		assert(condition, message)
