extends Node

func run() -> void:
    var economy_source := FileAccess.get_file_as_string("res://scripts/systems/economy_manager_weekly.gd")
    var economy_ui := FileAccess.get_file_as_string("res://scripts/ui/economy_panel.gd")

    _assert(economy_source.contains("weeks_remaining"), "Contratos y préstamos deben exponer semanas restantes.")
    _assert(economy_source.contains("weekly_income"), "Los patrocinadores deben exponer ingreso semanal.")
    _assert(economy_source.contains("entry[\"week\"]"), "El libro económico debe migrar movimientos a semanas.")
    _assert(economy_source.contains("entry[\"day\"]"), "Debe conservarse el alias day para guardados v14.")
    _assert(economy_source.contains("insolvency_weeks"), "La insolvencia debe exponer su unidad semanal canónica.")
    _assert(economy_source.contains("Ingreso semanal de"), "Los motivos del libro no deben seguir mostrando ingresos diarios.")
    _assert(economy_ui.contains("contract.get(\"weeks_remaining\""), "La UI debe leer primero semanas restantes.")
    _assert(economy_ui.contains("contract.get(\"weekly_income\""), "La UI debe leer primero ingreso semanal.")
    _assert(economy_ui.contains("entry.get(\"week\""), "La UI del libro debe leer primero la semana.")

    print("weekly_economy_persistence_contract_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("weekly_economy_persistence_contract_test: %s" % message)
        assert(condition, message)
