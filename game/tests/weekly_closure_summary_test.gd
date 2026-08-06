extends Node

func run() -> void:
    var controller_source := FileAccess.get_file_as_string("res://scripts/systems/weekly_planning_controller.gd")
    var economy_source := FileAccess.get_file_as_string("res://scripts/systems/economy_manager_weekly.gd")
    var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/weekly_closure_presenter.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(controller_source.contains("func get_summary"), "Debe existir un resumen previo al cierre.")
    _assert(controller_source.contains("assignments"), "El resumen debe incluir asignaciones del personal.")
    _assert(controller_source.contains("training"), "El resumen debe incluir entrenamiento semanal.")
    _assert(controller_source.contains("injured"), "El resumen debe incluir gladiadores lesionados.")
    _assert(controller_source.contains("food_consumption"), "Debe proyectarse el consumo de comida.")
    _assert(controller_source.contains("denarii_after"), "Debe proyectarse el saldo de denarios.")
    _assert(controller_source.contains("EconomyManager.get_weekly_projection()"), "El cierre debe delegar la proyección económica al sistema canónico.")
    _assert(economy_source.contains("func get_weekly_projection"), "Debe existir una proyección económica semanal canónica.")
    _assert(economy_source.contains("get_weekly_fixed_costs()"), "La proyección debe usar los costos económicos reales.")
    _assert(economy_source.contains("active_loans"), "La proyección debe considerar préstamos.")
    _assert(economy_source.contains("active_contracts"), "La proyección debe considerar patrocinadores.")
    _assert(controller_source.contains("Hay un evento semanal pendiente"), "Un evento sin resolver debe bloquear el cierre.")
    _assert(controller_source.contains("combate obligatorio"), "El combate semanal pendiente debe bloquear el cierre.")
    _assert(controller_source.contains("can_close"), "El resumen debe exponer si la semana puede cerrarse.")

    _assert(presenter_source.contains("WeeklyClosureSummary"), "Debe existir un modal de resumen semanal.")
    _assert(presenter_source.contains("Revisar y cerrar semana"), "El botón principal debe indicar la revisión previa.")
    _assert(presenter_source.contains("RESUMEN ANTES DE CERRAR LA SEMANA"), "El modal debe tener un encabezado claro.")
    _assert(presenter_source.contains("PERSONAL Y ASIGNACIONES"), "La interfaz debe mostrar asignaciones.")
    _assert(presenter_source.contains("ECONOMÍA PROYECTADA"), "La interfaz debe mostrar la economía prevista.")
    _assert(presenter_source.contains("Confirmar cierre de semana"), "Debe existir una confirmación explícita.")
    _assert(presenter_source.contains("confirm_button.disabled"), "La confirmación debe bloquearse cuando existan impedimentos.")
    _assert(presenter_source.contains("GameState.advance_week()"), "Solo la confirmación válida debe avanzar la semana.")
    _assert(presenter_source.contains("pressed.get_connections"), "Debe reemplazarse la conexión directa heredada del botón.")

    _assert(project_source.contains("WeeklyPlanningController=\"*res://scripts/systems/weekly_planning_controller.gd\""), "El planificador debe estar registrado.")
    _assert(project_source.contains("WeeklyClosurePresenter=\"*res://scripts/ui/weekly_closure_presenter.gd\""), "El presentador debe estar registrado.")
    _assert(project_source.find("GladiatorTrainingController=") < project_source.find("WeeklyPlanningController="), "El entrenamiento debe cargar antes del planificador.")
    _assert(project_source.find("WeeklyPlanningController=") < project_source.find("WeeklyClosurePresenter="), "El planificador debe cargar antes del modal.")

    print("Canonical weekly closure summary contract: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("weekly_closure_summary_test: %s" % message)
        assert(condition, message)
