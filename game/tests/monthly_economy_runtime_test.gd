extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")


func run() -> void:
	DataRepository.load_all()
	var previous_people: Array = RosterManager.people.duplicate()
	var previous_owned_beasts := OwnedBeastRegistry.export_state()
	var previous_day := GameState.day
	var previous_denarii := GameState.denarii
	var previous_reputation := GameState.reputation
	var previous_economy := EconomyManager.export_state()

	RosterManager.people = [
		PERSON_SCRIPT.new({"id": "economy_slave_1", "name": "Esclavo I", "role": "slave"}),
		PERSON_SCRIPT.new({"id": "economy_slave_2", "name": "Esclavo II", "role": "slave"}),
		PERSON_SCRIPT.new(
			{"id": "economy_gladiator_1", "name": "Gladiador I", "role": "gladiator"}
		),
	]
	OwnedBeastRegistry.reset_state()
	_reset_economy_runtime()
	GameState.day = 5
	GameState.denarii = 1000

	_test_frozen_population_cost()
	_test_owned_beast_cost_and_persistence()
	_test_exactly_once_per_month()
	_test_processed_month_persists()
	_test_insufficient_funds_uses_monthly_cost()

	EconomyManager.import_state(previous_economy)
	OwnedBeastRegistry.import_state(previous_owned_beasts)
	RosterManager.people = previous_people
	GameState.day = previous_day
	GameState.denarii = previous_denarii
	GameState.reputation = previous_reputation
	print("monthly_economy_runtime_test: OK")


func _test_frozen_population_cost() -> void:
	var population := EconomyManager.get_monthly_population_snapshot()
	_assert(int(population.get("slave_count", -1)) == 2, "Debe contar esclavos del roster vivo.")
	_assert(
		int(population.get("gladiator_count", -1)) == 1, "Debe contar gladiadores del roster vivo."
	)
	_assert(int(population.get("beast_count", -1)) == 0, "Una campaña nueva no posee bestias.")
	_assert(
		population.get("beast_count_source_ready") == true,
		"La propiedad de bestias debe tener una fuente canónica explícita."
	)
	var breakdown := EconomyManager.get_monthly_operating_cost_breakdown()
	_assert(breakdown.get("status") == "ready", "La fórmula congelada debe estar disponible.")
	_assert(int(breakdown.get("fixed_expense", 0)) == 88, "El costo fijo mensual debe ser 88.")
	_assert(int(breakdown.get("slave_cost", 0)) == 10, "Dos esclavos deben costar 10.")
	_assert(int(breakdown.get("gladiator_cost", 0)) == 20, "Un gladiador debe costar 20.")
	_assert(int(breakdown.get("beast_cost", -1)) == 0, "Sin bestias poseídas el costo debe ser 0.")
	_assert(int(breakdown.get("total", 0)) == 118, "El costo mensual total debe ser 118.")
	_assert(
		breakdown.get("legacy_daily_formula_used") == false,
		"La fórmula diaria heredada no puede participar."
	)


func _test_owned_beast_cost_and_persistence() -> void:
	_assert(
		not OwnedBeastRegistry.register_owned_beast("unknown_1", "unknown"),
		"No debe registrar una especie inventada."
	)
	_assert(
		OwnedBeastRegistry.register_owned_beast("boar_1", "boar"),
		"Debe aceptar una instancia de bestia canónica."
	)
	_assert(
		OwnedBeastRegistry.register_owned_beast("boar_2", "boar"),
		"No debe inventar un límite de una bestia por especie."
	)
	_assert(OwnedBeastRegistry.get_owned_count() == 2, "Debe contar ambas instancias poseídas.")
	var breakdown := EconomyManager.get_monthly_operating_cost_breakdown()
	_assert(int(breakdown.get("beast_cost", 0)) == 20, "Dos bestias poseídas deben costar 20/mes.")
	_assert(int(breakdown.get("total", 0)) == 138, "Las bestias deben elevar el costo total a 138.")

	var exported := OwnedBeastRegistry.export_state()
	OwnedBeastRegistry.reset_state()
	OwnedBeastRegistry.import_state(exported)
	_assert(OwnedBeastRegistry.owns_instance("boar_1"), "La primera instancia debe persistir.")
	_assert(OwnedBeastRegistry.owns_instance("boar_2"), "La segunda instancia debe persistir.")
	_assert(OwnedBeastRegistry.release_owned_beast("boar_1"), "Debe poder liberar una instancia.")
	_assert(
		OwnedBeastRegistry.release_owned_beast("boar_2"), "Debe poder liberar la otra instancia."
	)
	_assert(OwnedBeastRegistry.get_owned_count() == 0, "El registro debe volver a quedar vacío.")


func _test_exactly_once_per_month() -> void:
	var first := EconomyManager.process_month()
	_assert(int(first.get("operating_costs", 0)) == 118, "Debe liquidar 118 una vez.")
	_assert(GameState.denarii == 882, "La primera liquidación debe descontar exactamente 118.")
	_assert(EconomyManager.last_processed_month == 5, "Debe registrar el mes liquidado.")
	_assert(
		(
			EconomyManager.ledger.size() > 0
			and str(EconomyManager.ledger[0].get("reason", "")).contains(
				"Costos operativos mensuales"
			)
		),
		"El ledger debe registrar el costo mensual canónico."
	)
	var ledger_size := EconomyManager.ledger.size()
	var weekly_alias := EconomyManager.process_week()
	var daily_alias := EconomyManager.process_day()
	_assert(GameState.denarii == 882, "Los aliases legacy no pueden volver a cobrar el mes.")
	_assert(
		(
			weekly_alias.get("duplicate_call_ignored") == true
			and daily_alias.get("duplicate_call_ignored") == true
		),
		"Los aliases repetidos deben devolver el reporte cacheado."
	)
	_assert(
		EconomyManager.ledger.size() == ledger_size, "Un alias repetido no debe duplicar ledger."
	)


func _test_processed_month_persists() -> void:
	var exported := EconomyManager.export_state()
	EconomyManager.last_processed_month = 0
	EconomyManager.last_monthly_report.clear()
	EconomyManager.import_state(exported)
	var before := GameState.denarii
	var duplicate := EconomyManager.process_month()
	_assert(
		duplicate.get("duplicate_call_ignored") == true, "Save v14 debe recordar el mes liquidado."
	)
	_assert(
		GameState.denarii == before, "Recargar no puede habilitar un segundo cobro del mismo mes."
	)

	GameState.day = 6
	var next_month := EconomyManager.process_month()
	_assert(
		next_month.get("duplicate_call_ignored") == false, "El mes siguiente sí debe liquidarse."
	)
	_assert(GameState.denarii == before - 118, "Cada nuevo mes debe cobrar una sola vez.")


func _test_insufficient_funds_uses_monthly_cost() -> void:
	GameState.day = 7
	GameState.denarii = 50
	EconomyManager.missed_payments = 0
	var report := EconomyManager.process_month()
	_assert(int(report.get("operating_costs", 0)) == 118, "La obligación mensual sigue siendo 118.")
	_assert(GameState.denarii == 0, "Fondos insuficientes deben agotar el saldo disponible.")
	_assert(
		int(report.get("missed_payments", 0)) == 1,
		"El costo operativo impago debe registrar un incumplimiento."
	)
	_assert(
		(
			not str(report.get("sponsor_balance_status", "")).is_empty()
			and not str(report.get("loan_balance_status", "")).is_empty()
		),
		"Sponsors y préstamos deben permanecer marcados como compatibilidad pendiente."
	)


func _reset_economy_runtime() -> void:
	EconomyManager.active_contracts.clear()
	EconomyManager.active_loans.clear()
	EconomyManager.ledger.clear()
	EconomyManager.missed_payments = 0
	EconomyManager.insolvency_days = 0
	EconomyManager.total_income = 0
	EconomyManager.total_expenses = 0
	EconomyManager.serial = 0
	EconomyManager.last_processed_month = 0
	EconomyManager.last_monthly_report.clear()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("monthly_economy_runtime_test: %s" % message)
		assert(condition, message)
