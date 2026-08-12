extends Node


func run() -> void:
	var economy_source := FileAccess.get_file_as_string("res://scripts/systems/economy_manager.gd")
	var wrapper_source := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager_weekly.gd"
	)
	var economy_ui := FileAccess.get_file_as_string("res://scripts/ui/economy_panel.gd")

	_assert(
		economy_source.contains("var last_processed_month: int = 0"),
		"Debe persistirse el último mes procesado."
	)
	_assert(
		economy_source.contains("var last_monthly_report: Dictionary = {}"),
		"Debe persistirse el informe mensual."
	)
	_assert(
		economy_source.contains('"last_processed_month": last_processed_month'),
		"El export debe incluir el mes procesado."
	)
	_assert(
		economy_source.contains('"last_monthly_report": last_monthly_report.duplicate(true)'),
		"El export debe incluir el informe mensual."
	)
	_assert(
		economy_source.contains("PENDING_SPONSOR_REASON"),
		"Sponsors deben quedar explícitamente fuera de demo."
	)
	_assert(
		economy_source.contains("PENDING_LOAN_REASON"),
		"Préstamos deben quedar explícitamente fuera de demo."
	)
	_assert(
		(
			economy_source.contains("func sign_contract(sponsor_id: String) -> bool:")
			and economy_source.contains("contract_failed.emit(")
		),
		"Firmar sponsors debe fallar cerrado y emitir el motivo."
	)
	_assert(
		(
			economy_source.contains("func take_loan(loan_id: String) -> bool:")
			and economy_source.contains("loan_failed.emit(")
		),
		"Tomar préstamos debe fallar cerrado y emitir el motivo."
	)
	_assert(
		economy_source.contains('contract["unfrozen_actions_fail_closed"] = true'),
		"El contrato mensual debe declarar fail-closed."
	)
	_assert(
		economy_source.contains('"month": GameState.get_month()'),
		"El ledger debe registrar el mes canónico."
	)
	_assert(
		economy_source.contains('"day": GameState.day'),
		"El ledger debe conservar day por Save v14."
	)
	_assert(
		wrapper_source.contains('"weekly_scheduler_authority": false'),
		"El wrapper semanal no debe tener autoridad."
	)
	_assert(
		wrapper_source.contains('"daily_scheduler_authority": false'),
		"El wrapper diario no debe tener autoridad."
	)
	_assert(
		wrapper_source.contains('"sponsor_balance_authority": false'),
		"El wrapper no debe inventar sponsors."
	)
	_assert(
		wrapper_source.contains('"loan_balance_authority": false'),
		"El wrapper no debe inventar préstamos."
	)
	_assert(
		economy_ui.contains("fuera de demo"),
		"La UI debe explicar que sponsors y préstamos están fuera de demo."
	)
	_assert(
		economy_ui.contains("sponsor_selector.disabled = true"),
		"El selector de sponsors debe estar deshabilitado."
	)
	_assert(
		economy_ui.contains("loan_selector.disabled = true"),
		"El selector de préstamos debe estar deshabilitado."
	)
	_assert(
		economy_ui.contains('entry.get("month", entry.get("week", entry.get("day", 0)))'),
		"El ledger debe leer primero mes."
	)
	_assert(economy_ui.contains("Mes %d"), "El ledger visible debe mostrar meses.")

	print("monthly_economy_persistence_contract_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("weekly_economy_persistence_contract_test: %s" % message)
		assert(condition, message)
