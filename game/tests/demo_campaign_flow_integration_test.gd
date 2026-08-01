extends Node

const REQUIRED_SYSTEMS := ["personal", "mercado", "forja", "eventos", "campana", "arena"]

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
    assert(TutorialController.panel != null and TutorialController.panel.visible, "La nueva campaña debe mostrar el tutorial.")

    for system_id in REQUIRED_SYSTEMS:
        assert(FincaHubController.open_system(system_id), "La Finca debe navegar a %s." % system_id)
        await _wait_frames(1)
        assert(FincaHubController.get_current_system_id() == system_id, "La navegación debe abrir %s." % system_id)
        assert(FincaReturnNavigationController.return_button != null and FincaReturnNavigationController.return_button.visible, "El botón de volver debe mostrarse fuera de Finca.")

    FincaReturnNavigationController._on_return_pressed()
    await _wait_frames(1)
    assert(FincaHubController.get_current_system_id() == "finca", "Volver a la finca debe restaurar el hub.")

    var main_scene := get_tree().current_scene
    var close_week := main_scene.get_node_or_null("Margin/VBox/TopButtons/AdvanceDay") as Button
    assert(close_week != null, "Main debe exponer el botón Cerrar semana.")
    var starting_week := GameState.get_week()
    close_week.pressed.emit()
    await _wait_frames(2)
    assert(GameState.get_week() == starting_week + 1, "Cerrar semana debe avanzar exactamente una semana.")

    assert(SaveManager.save_game(), "La campaña debe guardarse antes de volver al menú.")
    MainMenuReturnController._save_and_return()
    await _wait_frames(2)
    assert(StartScreenController.overlay.visible, "Guardar y menú debe restaurar la pantalla de inicio.")
    assert(not StartScreenController.continue_button.disabled, "Una campaña guardada debe habilitar Continuar campaña.")
    StartScreenController._continue_campaign()
    await _wait_frames(8)
    assert(not StartScreenController.overlay.visible, "Continuar campaña debe cerrar la pantalla de inicio.")
    assert(FincaHubController.get_current_system_id() == "finca", "Continuar campaña debe volver a Finca.")

    print("Demo campaign flow integration test: OK")
    get_tree().quit(0)

func _wait_frames(frame_count: int) -> void:
    for _frame in frame_count:
        await get_tree().process_frame
