extends Node


func run() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var weekly_ui_source := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_cycle_presentation.gd"
	)

	_assert(
		game_state_source.contains("\"period\": \"month\""),
		"El reporte canónico debe identificarse como mensual."
	)
	_assert(
		game_state_source.contains("\"internal_work_ticks\": 1"),
		"Un cierre mensual debe resolver exactamente un tick interno."
	)
	_assert(
		game_state_source.contains("\"work_results\": work_results"),
		"Los resultados de trabajo deben tener una clave mensual canónica."
	)
	_assert(
		game_state_source.contains("\"daily_results\": work_results"),
		"El alias daily_results debe conservarse para compatibilidad v14."
	)
	_assert(
		game_state_source.contains("monthly_report.emit(report)"),
		"El reporte debe emitirse mediante la señal mensual canónica."
	)
	_assert(
		game_state_source.contains("weekly_report.emit(report)"),
		"La señal semanal heredada debe conservarse temporalmente como alias."
	)
	_assert(
		game_state_source.contains("daily_report.emit(report)"),
		"La señal diaria heredada debe conservarse temporalmente."
	)
	_assert(
		game_state_source.contains("RivalManager.process_week()"),
		"Rivales deben resolver una vez por mes aunque el método legado conserve su nombre."
	)
	_assert(
		game_state_source.contains("EconomyManager.process_week()"),
		"Economía debe resolver una vez por mes aunque el método legado conserve su nombre."
	)
	_assert(
		game_state_source.contains("TournamentManager.process_week()"),
		"Torneos deben resolver una vez por mes aunque el método legado conserve su nombre."
	)

	# Presentation is migrated in a later UI slice. It may still carry weekly
	# labels, but it must not expose a seven-day internal simulation anymore.
	_assert(
		not weekly_ui_source.contains("Procesa siete días internos"),
		"La interfaz no debe exponer una simulación diaria que ya no existe."
	)
	_assert(
		weekly_ui_source.contains("Compatibility cleanup"),
		"La normalización de logs antiguos debe permanecer explícita."
	)

	print("monthly_report_contract_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("monthly_report_contract_test: %s" % message)
		assert(condition, message)
