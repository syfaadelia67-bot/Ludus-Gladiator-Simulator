extends Node

func run() -> void:
    var event_source := FileAccess.get_file_as_string("res://scripts/systems/event_manager_demo.gd")
    var chapter_source := FileAccess.get_file_as_string("res://scripts/systems/chapter_objective_controller.gd")
    var chapter_ui := FileAccess.get_file_as_string("res://scripts/ui/chapter_objective_presenter.gd")
    var rival_source := FileAccess.get_file_as_string("res://scripts/systems/rival_gladiator_action_controller.gd")
    var rival_ui := FileAccess.get_file_as_string("res://scripts/ui/rival_gladiator_action_presenter.gd")
    var economy_source := FileAccess.get_file_as_string("res://scripts/systems/demo_economy_balance_controller.gd")
    var economy_ui := FileAccess.get_file_as_string("res://scripts/ui/demo_economy_balance_presenter.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(event_source.contains("CHAIN_EVENTS"), "Los eventos deben incluir cadenas narrativas.")
    _assert(event_source.contains("rival_challenge_aftermath"), "Debe existir la continuación del desafío rival.")
    _assert(event_source.contains("veteran_trial"), "Debe existir la continuación del veterano.")
    for requirement in ["healthy_gladiator", "specialized_gladiator", "building_level", "trait", "rivalry_intensity"]:
        _assert(event_source.contains(requirement), "Falta el requisito contextual %s." % requirement)
    _assert(event_source.contains("queued_chain_event"), "La cadena debe persistir entre semanas y guardados.")
    _assert(project_source.contains("EventManager=\"*res://scripts/systems/event_manager_demo.gd\""), "El EventManager extendido debe estar activo.")

    _assert(chapter_source.contains("PRIMARY_BY_CHAPTER"), "Cada capítulo debe tener objetivo principal.")
    _assert(chapter_source.contains("deadline_week"), "Los objetivos deben exponer fecha límite.")
    _assert(chapter_source.contains("failed"), "Los objetivos deben distinguir fracaso.")
    _assert(chapter_source.contains("get_calendar_milestones"), "Los capítulos deben generar hitos de calendario.")
    _assert(chapter_ui.contains("OBJETIVO PRINCIPAL"), "Campaña debe identificar el objetivo principal.")
    _assert(chapter_ui.contains("HITOS DEL CALENDARIO"), "Campaña debe mostrar los hitos futuros.")

    _assert(rival_source.contains("get_rival_gladiators"), "Debe poder inspeccionarse a los gladiadores rivales.")
    _assert(rival_source.contains("undermine_loyalty"), "Debe poder reducirse su lealtad.")
    _assert(rival_source.contains("sabotage_training"), "Debe poder sabotearse su entrenamiento.")
    _assert(rival_source.contains("contract_gladiator"), "Debe poder comprarse un contrato rival bajo condiciones.")
    _assert(rival_source.contains("loyalty") and rival_source.contains("intelligence_points"), "Las operaciones deben depender de lealtad e inteligencia.")
    _assert(rival_ui.contains("GLADIADORES ÚNICOS DE CASAS RIVALES"), "Rivales debe mostrar la nueva sección operativa.")

    _assert(economy_source.contains("SAFE_RUNWAY_WEEKS"), "La auditoría debe medir autonomía económica.")
    _assert(economy_source.contains("weekly_fixed_cost"), "Debe mostrar costos semanales.")
    _assert(economy_source.contains("food_consumption"), "Debe proyectar comida.")
    _assert(economy_source.contains("key_prices"), "Debe comparar precios clave.")
    _assert(economy_source.contains("BLOQUEO ECONÓMICO"), "Debe detectar situaciones de bloqueo.")
    _assert(economy_ui.contains("BALANCE ECONÓMICO DE LA DEMO"), "Economía debe mostrar el panel de balance.")

    for autoload in ["ChapterObjectiveController", "RivalGladiatorActionController", "DemoEconomyBalanceController", "ChapterObjectivePresenter", "RivalGladiatorActionPresenter", "DemoEconomyBalancePresenter"]:
        _assert(project_source.contains("%s=" % autoload), "Falta registrar %s." % autoload)

    print("demo_management_depth_flow_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("demo_management_depth_flow_test: %s" % message)
        assert(condition, message)
