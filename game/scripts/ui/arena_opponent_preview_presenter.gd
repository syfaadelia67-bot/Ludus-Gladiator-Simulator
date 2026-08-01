extends Node

const MAIN_SCENE_NAME := "Main"
const ARENA_PATH := "Margin/VBox/Tabs/Arena"
const SELECTOR_PATH := "Margin/VBox/Tabs/Arena/Setup/GladiatorSelector"

var preview: RichTextLabel
var selector: OptionButton

func _ready() -> void:
    GameState.week_advanced.connect(func(_week: int): call_deferred("_refresh"))
    RivalManager.rivals_changed.connect(func(): call_deferred("_refresh"))
    RosterManager.roster_changed.connect(func(): call_deferred("_refresh"))
    GladiatorRivalryController.rivalry_changed.connect(func(_person_id: String, _opponent_id: String): call_deferred("_refresh"))
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        var arena := scene.get_node_or_null(ARENA_PATH) as VBoxContainer
        selector = scene.get_node_or_null(SELECTOR_PATH) as OptionButton
        if arena == null or selector == null:
            continue
        preview = RichTextLabel.new()
        preview.name = "OpponentPreview"
        preview.bbcode_enabled = true
        preview.fit_content = true
        preview.custom_minimum_size = Vector2(0, 118)
        preview.tooltip_text = "Información conocida sobre el oponente programado para esta semana."
        arena.add_child(preview)
        arena.move_child(preview, 1)
        selector.item_selected.connect(func(_index: int): _refresh())
        _refresh()
        return
    push_error("No se pudo montar la previsualización del rival semanal en Arena.")

func _refresh() -> void:
    if preview == null:
        return
    var fighter_id := _selected_fighter_id()
    var event := CombatManager.get_current_event_details()
    var opponent := CombatManager.get_current_opponent_preview(fighter_id)
    var header := "[b]PRÓXIMO COMBATE · Semana %d[/b]\n%s\n" % [GameState.get_week(), event.get("name", "Arena")]
    if not bool(opponent.get("known", false)):
        preview.text = header + "[b]%s[/b]\n%s\nRiesgo: %s · Recompensa: %s" % [opponent.get("title", "Oponente por confirmar"), opponent.get("description", ""), event.get("risk", "—"), event.get("reward", "—")]
        return
    var rivalry: Dictionary = opponent.get("rivalry", {})
    var rivalry_line := "Sin enfrentamientos previos."
    if not rivalry.is_empty():
        rivalry_line = "Marcador personal: %d-%d · %s (%d%%)" % [int(rivalry.get("wins", 0)), int(rivalry.get("losses", 0)), GladiatorRivalryController.get_intensity_label(int(rivalry.get("intensity", 0))), int(rivalry.get("intensity", 0))]
    preview.text = header + "[b]%s[/b] · %s · Nivel %d\nCasa: %s · Récord rival: %d-%d\nFUE %d · AGI %d · RES %d · TEC %d · Vida estimada %d\n%s" % [
        opponent.get("name", "Rival"), opponent.get("origin", "Desconocido"), int(opponent.get("level", 1)),
        opponent.get("rival_name", "Casa rival"), int(opponent.get("wins", 0)), int(opponent.get("losses", 0)),
        int(opponent.get("strength", 0)), int(opponent.get("agility", 0)), int(opponent.get("endurance", 0)), int(opponent.get("technique", 0)), int(opponent.get("health", 0)), rivalry_line
    ]

func _selected_fighter_id() -> String:
    if selector == null or selector.selected < 0:
        return ""
    var gladiators: Array = []
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            gladiators.append(person)
    if selector.selected >= gladiators.size():
        return ""
    return str(gladiators[selector.selected].id)
