extends Node


func run() -> void:
	var rival_source := FileAccess.get_file_as_string(
		"res://scripts/systems/rival_manager_weekly.gd"
	)
	var policy_source := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_rival_management_policy.gd"
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
		rival_source.contains("last_processed_month"),
		"El tick rival mensual debe ser idempotente dentro del mismo mes."
	)
	_assert(
		rival_source.contains("DataRepository.get_rival_ludi()"),
		"La identidad rival debe venir de los siete Ludi canónicos."
	)
	_assert(
		rival_source.contains("reconcile_canonical_rivals"),
		"Los Save v14 legacy deben reconciliarse con los Ludi canónicos."
	)
	_assert(
		rival_source.contains('"month": month'), "Las operaciones deben registrar el mes canónico."
	)
	_assert(
		rival_source.contains('"monthly_balance_frozen": true'),
		"Las operaciones deben declarar su balance mensual congelado."
	)
	_assert(
		rival_source.contains('"gt1_mutation_allowed": false'),
		"La gestión rival no puede mutar GT I."
	)
	_assert(
		not rival_source.contains("super.run_operation"),
		"El runtime mensual no debe delegar autoridad a la ejecución legacy."
	)
	_assert(
		not rival_source.contains("super.process_day()"),
		"El cierre mensual no debe ejecutar el scheduler diario legacy."
	)
	_assert(
		not rival_source.contains("TournamentManager"),
		"La gestión rival no debe tocar standings de GT I."
	)
	_assert(
		not rival_source.contains("rival_combat_v1_snapshots"),
		"La gestión rival no debe mutar snapshots Combat V1."
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
		policy_source.contains('const STATUS := "frozen"'),
		"La política rival mensual debe estar congelada."
	)
	_assert(
		policy_source.contains('"canonical_rival_count": 7'),
		"La política debe exigir siete Ludi rivales."
	)
	_assert(
		policy_source.contains('"gladiator_power_is_combat_v1_authority": false'),
		"El índice operativo rival no puede ser autoridad de Combat V1."
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
		"La ruta del manager rival debe permanecer estable por compatibilidad."
	)

	print("monthly_rival_cycle_contract_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("weekly_rival_cycle_contract_test: %s" % message)
		assert(condition, message)
