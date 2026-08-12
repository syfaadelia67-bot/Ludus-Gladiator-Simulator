extends Node


func run() -> void:
	var economy_source := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager.gd"
	)
	var wrapper_source := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager_weekly.gd"
	)
	var economy_ui := FileAccess.get_file_as_string("res://scripts/ui/economy_panel.gd")

	_assert(
		economy_source.contains("var last_processed_month: int = 0"),
		"La economía debe persistir el último mes procesado."
	)
	_assert(
		economy_source.contains("var last_monthly_report: Dictionary = {}"),
		"La economía debe persistir el último informe mensual."
	)
	_assert(
		economy_source.contains('"last_processed_month": last_processed_month'),
		"El estado exportado debe incluir el último mes procesado."
	)
	_assert(
		economy_source.contains('"last_monthly_report": last_monthly_report.duplicate(true)'),
		"El estado exportado debe incluir el informe mensual."
	)
	_assert(
		economy_source.contains('"legacy_days_remaining"'),
		"Los datos diarios de contratos deben conservarse sólo como compatibilidad legacy."
	)
	_assert(
		economy_source.contains('"legacy_daily_income"'),
		"El ingreso diario legacy debe permanecer marcado como legacy."
	)
	_assert(
		economy_source.contains('"legacy_interest"') and economy_source.contains('"legacy_term"'),
		"Los términos antiguos de préstamos deben quedar explícitamente en cuarentena."
	)
	_assert(
		economy_source.contains('"monthly_balance_status": "pending"'),
		"Contratos y préstamos no deben adquirir balance mensual inventado."
	)
	_assert(
		economy_source.contains('"month": GameState.get_month()'),
		"El libro económico debe registrar el mes canónico."
	)
	_assert(
		economy_source.contains('"day": GameState.day'),
		"El ledger debe conservar el alias day para compatibilidad Save v14."
	)
	_assert(
		wrapper_source.contains('"weekly_scheduler_authority": false'),
		"El wrapper semanal no debe tener autoridad de scheduler."
	)
	_assert(
		wrapper_source.contains('"daily_scheduler_authority": false'),
		"El wrapper diario no debe tener autoridad de scheduler."
	)
	_assert(
		wrapper_source.contains('"sponsor_balance_authority": false'),
		"El wrapper no debe inventar balance de patrocinadores."
	)
	_assert(
		wrapper_source.contains('"loan_balance_authority": false'),
		"El wrapper no debe inventar balance de préstamos."
	)
	_assert(
		economy_ui.contains('contract.get("months_remaining", contract.get("weeks_remaining", 0))'),
		"La UI debe leer primero meses y usar semanas sólo como fallback."
	)
	_assert(
		economy_ui.contains('contract.get("monthly_income", contract.get("weekly_income", 0))'),
		"La UI debe leer primero ingreso mensual."
	)
	_assert(
		economy_ui.contains('entry.get("month", entry.get("week", entry.get("day", 0)))'),
		"La UI del ledger debe leer primero el mes canónico."
	)
	_assert(economy_ui.contains("Mes %d"), "El ledger visible debe mostrar meses.")

	print("monthly_economy_persistence_contract_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("weekly_economy_persistence_contract_test: %s" % message)
		assert(condition, message)
