extends Node

const REQUIRED_SYSTEMS := ["barracks", "mercado", "equipamiento", "personal", "forja", "eventos", "campana", "arena"]
const HOSTED_SYSTEMS := ["finca", "barracks", "mercado", "equipamiento", "personal", "forja", "eventos", "campana", "arena"]

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await _wait_frames(8)
    assert(StartScreenController.overlay != null and StartScreenController.overlay.visible, "La pantalla de inicio debe mostrarse al abrir Main.")

    StartScreenController._show_owner_creation()
    await _wait_frames(1)
    assert(StartScreenController.title_selector != null, "La creación de campaña debe ofrecer Dominus o Domina.")
    assert(StartScreenController.origin_selector != null and StartScreenController.origin_selector.item_count > 0, "La creación de campaña debe ofrecer orígenes.")
    StartScreenController.title_selector.select(1)
    StartScreenController.origin_selector.select(0)
    StartScreenController.name_input.text = "Aurelia"
    StartScreenController._start_new_campaign()

    await _wait_frames(8)
    assert(not StartScreenController.overlay.visible, "Una campaña nueva debe cerrar la pantalla de inicio.")
    assert(LudusOwnerManager.get_title_label() == "Domina", "La campaña debe conservar la elección Domina.")
    assert(FincaHubController.get_current_system_id() == "finca", "Una campaña nueva debe entrar automáticamente a Finca.")
    _assert_navigation_state("finca")
    assert(TutorialController.panel != null and TutorialController.panel.visible, "La nueva campaña debe mostrar el tutorial.")

    for system_id in REQUIRED_SYSTEMS:
        assert(FincaHubController.open_system(system_id), "La Finca debe navegar a %s." % system_id)
        await _wait_frames(1)
        assert(FincaHubController.get_current_system_id() == system_id, "La navegación debe abrir %s." % system_id)
        _assert_navigation_state(system_id)
        assert(FincaHubController.show_finca(), "Cada sistema debe permitir regresar al hub de Finca.")
        await _wait_frames(1)
        assert(FincaHubController.get_current_system_id() == "finca", "Regresar desde %s debe restaurar Finca." % system_id)
        _assert_navigation_state("finca")

    var finca_screen := FincaHubController.get_hosted_screen("finca")
    assert(finca_screen != null, "La Finca debe existir como pantalla alojada en ScreenHost.")
    var forge_hotspot := finca_screen.get_node_or_null("Center/WorldPanel/WorldMargin/WorldArea/Hotspot_forge") as Button
    var enter_button := finca_screen.get_node_or_null("Center/BuildingDetailsPanel/Margin/Scroll/Details/Enter") as Button
    assert(forge_hotspot != null, "La Finca debe exponer la Forja como hotspot navegable.")
    assert(enter_button != null, "La Finca debe exponer el acceso contextual del edificio seleccionado.")
    forge_hotspot.pressed.emit()
    await _wait_frames(1)
    enter_button.pressed.emit()
    await _wait_frames(1)
    assert(FincaHubController.get_current_system_id() == "forja", "Entrar a la Forja desde su hotspot debe abrir su sistema.")
    _assert_navigation_state("forja")
    assert(FincaHubController.show_finca(), "El retorno desde una instalación debe volver a Finca.")
    await _wait_frames(1)
    assert(FincaHubController.get_current_system_id() == "finca", "El retorno desde una instalación debe restaurar el hub.")
    _assert_navigation_state("finca")

    var main_scene := get_tree().current_scene
    var close_week := main_scene.get_node_or_null("UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek") as Button
    assert(close_week != null, "El HUD unificado debe exponer el botón Cerrar semana.")
    var starting_week := GameState.get_week()

    close_week.pressed.emit()
    await _wait_frames(2)
    assert(WeeklyClosurePresenter.overlay != null and WeeklyClosurePresenter.overlay.visible, "Cerrar semana debe abrir el resumen previo.")

    var weekly_summary := WeeklyPlanningController.get_summary()
    assert(not bool(weekly_summary.get("event_pending", false)), "Una campaña recién creada no debe bloquear el primer cierre con un evento pendiente.")
    if bool(weekly_summary.get("fight_pending", false)):
        var fighter_id := ""
        for person in RosterManager.get_people():
            if str(person.role) == "gladiator" and person.is_available_for_combat():
                fighter_id = str(person.id)
                break
        assert(not fighter_id.is_empty(), "El cierre semanal obligatorio debe disponer de un gladiador para la Arena.")
        var combat_result := CombatManager.simulate_duel(fighter_id, "balanced")
        assert(not combat_result.is_empty(), "El combate obligatorio debe completarse antes de cerrar la semana.")
        await _wait_frames(2)
        WeeklyClosurePresenter.open_summary()
        await _wait_frames(1)

    weekly_summary = WeeklyPlanningController.get_summary()
    assert(bool(weekly_summary.get("can_close", false)), "El resumen semanal debe quedar habilitado después de resolver sus bloqueos.")
    WeeklyClosurePresenter._confirm()
    await _wait_frames(2)
    assert(GameState.get_week() == starting_week + 1, "Confirmar el cierre debe avanzar exactamente una semana.")

    assert(SaveManager.save_game(), "La campaña debe guardarse antes de volver al menú.")
    MainMenuReturnController._save_and_return()
    await _wait_frames(2)
    assert(StartScreenController.overlay.visible, "Guardar y menú debe restaurar la pantalla de inicio.")
    assert(not StartScreenController.continue_button.disabled, "Una campaña guardada debe habilitar Continuar campaña.")
    StartScreenController._continue_campaign()
    await _wait_frames(8)
    assert(not StartScreenController.overlay.visible, "Continuar campaña debe cerrar la pantalla de inicio.")
    assert(FincaHubController.get_current_system_id() == "finca", "Continuar campaña debe volver a Finca.")
    _assert_navigation_state("finca")

    print("Demo campaign hosted flow integration test: OK")
    get_tree().quit(0)

func _assert_navigation_state(system_id: String) -> void:
    var main_scene := get_tree().current_scene
    assert(main_scene != null and main_scene.name == "Main", "La navegación funcional debe ejecutarse sobre Main.")
    var host := main_scene.get_node_or_null("Margin/VBox/ScreenHost") as Control
    var tabs := main_scene.get_node_or_null("Margin/VBox/Tabs") as TabContainer
    assert(host != null, "Main debe mantener un ScreenHost activo.")
    assert(tabs == null, "Main no debe conservar pestañas heredadas después de la migración.")
    assert(HOSTED_SYSTEMS.has(system_id), "%s debe estar registrado como sistema hospedado." % system_id)

    var active_screen := FincaHubController.get_hosted_screen(system_id)
    assert(active_screen != null, "%s debe estar instanciado dentro de ScreenHost." % system_id)
    assert(active_screen.get_parent() == host, "%s debe permanecer alojado directamente en ScreenHost." % system_id)
    assert(active_screen.visible, "%s debe ser la única pantalla hospedada visible." % system_id)
    assert(active_screen.mouse_filter == Control.MOUSE_FILTER_PASS, "%s debe aceptar interacción." % system_id)
    assert(host.visible and host.mouse_filter == Control.MOUSE_FILTER_PASS, "ScreenHost debe estar activo para %s." % system_id)
    for child in host.get_children():
        if child is Control:
            var hosted_control := child as Control
            assert(hosted_control.visible == (hosted_control == active_screen), "ScreenHost no debe mostrar dos pantallas simultáneamente.")

func _wait_frames(frame_count: int) -> void:
    for _frame in frame_count:
        await get_tree().process_frame
