extends Node

const MAIN_SCENE_NAME := "Main"
const FINALE_WEEK := 16
const REQUIRED_WINS := 6

var warning_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    GameState.week_advanced.connect(func(_week: int): call_deferred("_refresh"))
    CampaignManager.campaign_changed.connect(func(): call_deferred("_refresh"))
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_refresh"))
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(120):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        var event_card := scene.find_child("EventPreparation", true, false) as RichTextLabel
        if event_card == null:
            continue
        var arena := event_card.get_parent() as VBoxContainer
        if arena == null:
            continue
        warning_label = arena.get_node_or_null("FinaleWarning") as Label
        if warning_label == null:
            warning_label = Label.new()
            warning_label.name = "FinaleWarning"
            warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            warning_label.custom_minimum_size = Vector2(0, 58)
            arena.add_child(warning_label)
            arena.move_child(warning_label, event_card.get_index() + 1)
        _refresh()
        return
    push_warning("No se pudo montar la advertencia del combate final en Arena.")

func _refresh() -> void:
    if warning_label == null or not is_instance_valid(warning_label):
        return
    var summary: Dictionary = CampaignManager.get_summary()
    var final_resolved := bool(summary.get("final_combat_resolved", false))
    var current_week := GameState.get_week()
    warning_label.visible = current_week == FINALE_WEEK and not final_resolved
    if not warning_label.visible:
        warning_label.text = ""
        return

    var wins := maxi(0, int(summary.get("wins", 0)))
    if wins >= REQUIRED_WINS:
        warning_label.text = "COMBATE FINAL DE LA DEMO — Tenés %d victorias. Este combate decidirá el destino del ludus." % wins
        return
    var missing := REQUIRED_WINS - wins
    warning_label.text = "ADVERTENCIA FINAL — Tenés %d/%d victorias. Faltan %d; al terminar este combate se resolverá la campaña." % [wins, REQUIRED_WINS, missing]
