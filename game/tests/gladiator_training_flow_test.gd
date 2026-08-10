extends Node


func run() -> void:
	var controller_source := FileAccess.get_file_as_string(
		"res://scripts/systems/gladiator_training_controller.gd"
	)
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/ui/gladiator_training_presenter.gd"
	)
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	_assert(controller_source.contains("const FOCUSES"), "El sistema debe definir focos de entrenamiento.")
	for focus_id in ["balanced", "strength", "agility", "endurance", "technique", "specialization"]:
		_assert(controller_source.contains('"%s"' % focus_id), "Falta el foco %s." % focus_id)
	_assert(controller_source.contains("func set_focus"), "Debe poder elegirse un foco individual.")
	_assert(controller_source.contains("func get_preview"), "Debe existir una previsualización mensual.")
	_assert(controller_source.contains("func process_month"), "Debe existir la entrada mensual explícita.")
	_assert(controller_source.contains("func process_week"), "La API semanal debe quedar como adaptador legacy.")
	_assert(
		not controller_source.contains("GameState.week_advanced.connect"),
		"Entrenamiento no puede conservar scheduler semanal.",
	)
	_assert(
		not controller_source.contains("GameState.month_advanced.connect"),
		"Entrenamiento no puede crear un segundo scheduler mensual.",
	)
	_assert(
		controller_source.contains('"monthly_gain": 0'),
		"La ganancia debe quedar neutral hasta congelar balance mensual.",
	)
	_assert(
		controller_source.contains('"fatigue_gain": 0'),
		"La fatiga de entrenamiento debe quedar neutral hasta congelar balance.",
	)
	_assert(
		controller_source.contains('"injury_risk": 0'),
		"El riesgo de lesión debe quedar neutral hasta congelar balance.",
	)
	_assert(
		controller_source.contains('"balance_ready": false'),
		"La previsualización debe declarar que el balance no está listo.",
	)
	for forbidden in [
		"ATTRIBUTE_THRESHOLD",
		"EstateManager.get_training_multiplier",
		"SpecializationMasteryController.register_training_use",
		"Sobrecarga muscular",
		"_calculate_gain",
		"_injury_risk",
	]:
		_assert(
			not controller_source.contains(forbidden),
			"La regla legacy %s no puede actuar como balance mensual." % forbidden,
		)

	_assert(
		presenter_source.contains("PLAN DE ENTRENAMIENTO MENSUAL"),
		"La ficha debe mostrar planificación mensual.",
	)
	_assert(
		presenter_source.contains("balance mensual pendiente"),
		"La ficha debe explicar que ganancia, fatiga y riesgo siguen pendientes.",
	)
	_assert(
		not presenter_source.to_lower().contains("por semana"),
		"La ficha no debe presentar ganancias semanales activas.",
	)
	_assert(
		presenter_source.contains("GladiatorDossierPresenter.selected_person_id"),
		"La sección debe usar el gladiador abierto en la ficha.",
	)
	_assert(
		not presenter_source.contains('box.name = "Entrenamiento"'),
		"No debe agregarse una sexta pestaña a la ficha.",
	)

	_assert(
		project_source.contains(
			'GladiatorTrainingController="*res://scripts/systems/gladiator_training_controller.gd"'
		),
		"El controlador debe estar registrado como autoload.",
	)
	_assert(
		project_source.contains(
			'GladiatorTrainingPresenter="*res://scripts/ui/gladiator_training_presenter.gd"'
		),
		"El presentador debe estar registrado como autoload.",
	)
	_assert(
		project_source.find("GladiatorTrainingController=")
		< project_source.find("GladiatorTrainingPresenter="),
		"El controlador debe cargarse antes que la interfaz.",
	)

	print("gladiator_training_flow_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("gladiator_training_flow_test: %s" % message)
		assert(condition, message)
