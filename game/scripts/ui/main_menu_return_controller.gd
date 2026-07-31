extends Node

const MAIN_SCENE_NAME := "Main"
const MAX_ATTACH_ATTEMPTS := 60

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(MAX_ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME or not scene.is_inside_tree():
            continue
        var top_buttons := scene.find_child("TopButtons", true, false) as Container
        if top_buttons != null:
            _attach_button(top_buttons)
            return
    push_warning("No se encontró TopButtons para añadir el acceso al menú principal.")

func _attach_button(container: Container) -> void:
    if container.get_node_or_null("ReturnToMainMenu") != null:
        return
    var button := Button.new()
    button.name = "ReturnToMainMenu"
    button.text = "Guardar y menú"
    button.tooltip_text = "Guarda la campaña actual y regresa a la pantalla principal."
    button.pressed.connect(_save_and_return)
    container.add_child(button)

func _save_and_return() -> void:
    if not SaveManager.save_game():
        push_warning("No se pudo guardar antes de regresar al menú principal.")
        return
    StartScreenController.show_main_menu()
