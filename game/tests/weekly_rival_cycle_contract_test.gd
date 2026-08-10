extends Node


func run() -> void:
	var rival_source := FileAccess.get_file_as_string(
		"res://scripts/systems/rival_manager_weekly.gd"
	)
	var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	_assert(
		rival_source.contains("func process_month()"),
		"Rivales debe exponer procesamiento mensual canónico."
	)
	_assert(
		rival_source.contains("monthly_rivalry_processed"),
		"Debe emitir un informe mensual de rivalidad."
	)
	_assert(
		rival_source.contains('"month": month'),
		"Las operaciones bloqueadas deben registrar el mes canónico."
	)
	_assert(
		rival_source.contains('"legacy_balance_quarantined": true'),
		"Las operaciones legacy deben quedar explícitamente en cuarentena."
	)
	_assert(
		rival_source.contains('"gt1_mutation_allowed": false'),
		"La gestión rival no puede mutar GT I."
	)
	_assert(
		not rival_source.contains("super.run_operation"),
		"El runtime mensual no debe ejecutar costes/riesgos legacy."
	)
	_assert(
		not rival_source.contains("super.process_day()"),
		"El cierre mensual no debe ejecutar la represalia diaria legacy."
	)
	_assert(
		(
			rival_source.contains("func process_week()")
			and rival_source.contains("func process_day()")
			and rival_source.count("return process_month()") >= 2
		),
		"Las APIs week/day deben conservarse solo como aliases mensuales."
	)
	_assert(
		game_state_source.contains("RivalManager.process_month()"),
		"GameState debe usar el ciclo rival mensual."
	)
	_assert(
		not game_state_source.contains("RivalManager.process_week()"),
		"GameState no debe usar la API semanal rival."
	)
	_assert(
		not game_state_source.contains("RivalManager.process_day()"),
		"GameState no debe usar la API diaria rival."
	)
	_assert(
		project_source.contains('RivalManager="*res://scripts/systems/rival_manager_weekly.gd"'),
		"La ruta legacy del manager rival debe permanecer estable por compatibilidad."
	)

	print("monthly_rival_cycle_contract_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("weekly_rival_cycle_contract_test: %s" % message)
		assert(condition, message)
