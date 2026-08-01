extends Node

func run() -> void:
    var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
    var weekly_ui_source := FileAccess.get_file_as_string("res://scripts/ui/weekly_cycle_presentation.gd")

    _assert(game_state_source.contains("\"period\":\"week\""), "El reporte debe identificarse como semanal.")
    _assert(game_state_source.contains("\"internal_work_ticks\":DAYS_PER_WEEK"), "Debe documentarse la cantidad de ciclos internos sin confundirla con el calendario visible.")
    _assert(game_state_source.contains("\"work_results\":work_results"), "Los resultados de trabajo deben tener una clave semanal canónica.")
    _assert(game_state_source.contains("\"daily_results\":work_results"), "El alias daily_results debe conservarse para compatibilidad v14.")
    _assert(game_state_source.contains("weekly_report.emit(report)"), "El reporte debe emitirse mediante la señal semanal.")
    _assert(game_state_source.contains("daily_report.emit(report)"), "La señal diaria heredada debe conservarse temporalmente.")
    _assert(game_state_source.contains("RivalManager.process_week()"), "Rivales deben procesarse semanalmente.")
    _assert(game_state_source.contains("EconomyManager.process_week()"), "Economía debe procesarse semanalmente.")
    _assert(game_state_source.contains("TournamentManager.process_week()"), "Torneos deben procesarse semanalmente.")

    _assert(weekly_ui_source.contains("Procesa trabajos, economía, recuperación y consecuencias"), "El tooltip debe explicar el cierre semanal en términos jugables.")
    _assert(not weekly_ui_source.contains("Procesa siete días internos"), "La interfaz no debe exponer el detalle técnico diario.")
    _assert(weekly_ui_source.contains("Compatibility cleanup"), "La normalización de logs antiguos debe permanecer explícita.")

    print("weekly_report_contract_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("weekly_report_contract_test: %s" % message)
        assert(condition, message)
