extends Node


func run() -> void:
	var controller_source := FileAccess.get_file_as_string(
		"res://scripts/systems/weekly_planning_controller.gd"
	)
	var closure_policy_source := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_turn_closure_policy.gd"
	)
	var economy_source := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager.gd"
	)
	var economy_wrapper := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager_weekly.gd"
	)
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_closure_presenter.gd"
	)
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	_assert(
		controller_source.contains("func get_summary"), "Debe existir un resumen previo al cierre."
	)
	_assert(
		controller_source.contains("assignments"),
		"El resumen debe incluir asignaciones del personal."
	)
	_assert(
		controller_source.contains("training"), "El resumen debe incluir entrenamiento mensual."
	)
	_assert(
		controller_source.contains("injured"), "El resumen debe incluir gladiadores lesionados."
	)
	_assert(
		controller_source.contains("food_consumption"), "Debe proyectarse el consumo de comida."
	)
	_assert(controller_source.contains("denarii_after"), "Debe proyectarse el saldo de denarios.")
	_assert(
		controller_source.contains("EconomyManager.get_monthly_projection()"),
		"El cierre debe delegar la proyección económica mensual al sistema canónico."
	)
	_assert(
		economy_source.contains("func get_monthly_projection"),
		"Debe existir una proyección económica mensual canónica."
	)
	_assert(
		economy_source.contains("func get_monthly_operating_cost_breakdown"),
		"La proyección mensual debe exponer el desglose de costos del turno."
	)
	_assert(
		economy_source.contains('"sponsor_balance_status": "pending_monthly_design"'),
		"Patrocinadores deben permanecer fuera del balance mensual hasta diseño aprobado."
	)
	_assert(
		economy_source.contains('"loan_balance_status": "pending_monthly_design"'),
		"Préstamos deben permanecer fuera del balance mensual hasta diseño aprobado."
	)
	_assert(
		economy_wrapper.contains("func get_weekly_projection()"),
		"La API semanal debe conservarse sólo como alias de compatibilidad."
	)
	_assert(
		economy_wrapper.contains("return get_monthly_projection()"),
		"El alias semanal no debe tener autoridad económica propia."
	)
	_assert(
		controller_source.contains("GameState.get_month_closure_status()"),
		"El planificador debe consumir la autoridad canónica de cierre mensual."
	)
	_assert(
		closure_policy_source.contains("Hay un evento mensual pendiente"),
		"Un evento mensual sin resolver debe bloquear el cierre."
	)
	_assert(
		closure_policy_source.contains("El encuentro del Gran Torneo de este mes"),
		"Un encuentro GT I pendiente debe bloquear el cierre mensual."
	)
	_assert(
		closure_policy_source.contains('"non_gt_combat_required": false'),
		"Los meses sin GT I no deben inventar un combate obligatorio."
	)
	_assert(
		controller_source.contains('"can_close": bool(closure.get("can_close", false))'),
		"El resumen debe exponer la decisión canónica de cierre."
	)

	_assert(
		presenter_source.contains("MonthlyClosureSummary"),
		"Debe existir un modal de resumen mensual."
	)
	_assert(
		presenter_source.contains("Revisar y cerrar mes"),
		"El botón principal debe indicar la revisión mensual previa."
	)
	_assert(
		presenter_source.contains("RESUMEN ANTES DE CERRAR EL MES"),
		"El modal debe tener un encabezado mensual claro."
	)
	_assert(
		presenter_source.contains("PERSONAL Y ASIGNACIONES"),
		"La interfaz debe mostrar asignaciones."
	)
	_assert(
		presenter_source.contains("ECONOMÍA PROYECTADA"),
		"La interfaz debe mostrar la economía prevista."
	)
	_assert(
		presenter_source.contains("Confirmar cierre de mes"),
		"Debe existir una confirmación mensual explícita."
	)
	_assert(
		presenter_source.contains("confirm_button.disabled"),
		"La confirmación debe bloquearse cuando existan impedimentos."
	)
	_assert(
		presenter_source.contains("GameState.advance_month()"),
		"Solo la confirmación válida debe avanzar el mes."
	)
	_assert(
		presenter_source.contains("pressed.get_connections"),
		"Debe reemplazarse la conexión directa heredada del botón."
	)

	_assert(
		project_source.contains(
			'WeeklyPlanningController="*res://scripts/systems/weekly_planning_controller.gd"'
		),
		"El nombre de autoload legacy debe conservarse para compatibilidad."
	)
	_assert(
		project_source.contains(
			'WeeklyClosurePresenter="*res://scripts/ui/weekly_closure_presenter.gd"'
		),
		"El presentador legacy debe seguir registrado bajo la ruta estable."
	)
	_assert(
		(
			project_source.find("GladiatorTrainingController=")
			< project_source.find("WeeklyPlanningController=")
		),
		"El entrenamiento debe cargar antes del planificador."
	)
	_assert(
		(
			project_source.find("WeeklyPlanningController=")
			< project_source.find("WeeklyClosurePresenter=")
		),
		"El planificador debe cargar antes del modal."
	)

	print("Canonical monthly closure summary contract: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("weekly_closure_summary_test: %s" % message)
		assert(condition, message)
