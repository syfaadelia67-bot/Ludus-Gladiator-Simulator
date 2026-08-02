extends Node

const MAIN_SCENE_NAME := "Main"
const ARENA_RESULT_PATH := "Margin/VBox/Tabs/Arena/Result"

var last_rendered_person_id := ""

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GladiatorRivalryController.rivalry_changed.connect(_on_rivalry_changed)
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene != null and scene.name == MAIN_SCENE_NAME:
            set_process(true)
            return
    set_process(false)

func _process(_delta: float) -> void:
    var dossier = GladiatorDossierPresenter
    if dossier.overlay == null or not dossier.overlay.visible:
        last_rendered_person_id = ""
        return
    var person_id := str(dossier.selected_person_id)
    if person_id.is_empty():
        return
    _ensure_dossier_section(person_id)

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    var opponent_id := str(result.get("enemy_unique_gladiator_id", ""))
    if person_id.is_empty() or opponent_id.is_empty():
        return
    call_deferred("_show_arena_summary", person_id, opponent_id)

func _on_rivalry_changed(person_id: String, _opponent_id: String) -> void:
    if GladiatorDossierPresenter.selected_person_id == person_id:
        last_rendered_person_id = ""

func _show_arena_summary(person_id: String, opponent_id: String) -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    var label := scene.get_node_or_null(ARENA_RESULT_PATH) as Label
    if label == null:
        return
    var rivalry := GladiatorRivalryController.get_rivalry(person_id, opponent_id)
    if rivalry.is_empty():
        return
    var opponent := DataRepository.get_unique_gladiator(opponent_id)
    var opponent_name := str(opponent.get("name", opponent_id))
    label.text += "\nRivalidad con %s: %d-%d · %s (%d%%)" % [
        opponent_name,
        int(rivalry.get("wins", 0)),
        int(rivalry.get("losses", 0)),
        GladiatorRivalryController.get_intensity_label(int(rivalry.get("intensity", 0))),
        int(rivalry.get("intensity", 0))
    ]

func _ensure_dossier_section(person_id: String) -> void:
    var dossier = GladiatorDossierPresenter
    if dossier.tab_container == null:
        return
    var information: Control = null
    for index in range(dossier.tab_container.get_tab_count()):
        var control: Control = dossier.tab_container.get_tab_control(index)
        if control != null and control.name == "Información":
            information = control
            break
    if information == null or information.get_child_count() == 0:
        return
    var box := information.get_child(0) as VBoxContainer
    if box == null:
        return
    var existing := box.get_node_or_null("RivalrySection")
    if existing != null:
        existing.queue_free()
    var section := VBoxContainer.new()
    section.name = "RivalrySection"
    section.add_theme_constant_override("separation", 4)
    box.add_child(section)

    var title := Label.new()
    title.text = "RIVALIDADES"
    title.add_theme_font_size_override("font_size", 18)
    section.add_child(title)

    var rivalries := GladiatorRivalryController.get_rivalries(person_id)
    if rivalries.is_empty():
        var empty := Label.new()
        empty.text = "Todavía no se enfrentó a gladiadores únicos de casas rivales."
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        section.add_child(empty)
        last_rendered_person_id = person_id
        return

    for rivalry in rivalries:
        var opponent_id := str(rivalry.get("opponent_id", ""))
        var opponent := DataRepository.get_unique_gladiator(opponent_id)
        var opponent_name := str(opponent.get("name", opponent_id))
        var house_name := _rival_house_name(str(rivalry.get("rival_id", "")))
        var streak_owner := str(rivalry.get("streak_owner", ""))
        var streak_text := "Sin racha"
        if int(rivalry.get("streak", 0)) > 0:
            streak_text = "%s lleva %d" % ["Tu gladiador" if streak_owner == person_id else opponent_name, int(rivalry.get("streak", 0))]
        var label := Label.new()
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.text = "%s · %s\nMarcador %d-%d · %d enfrentamientos · %s\n%s · Intensidad %d%% · Último cruce: semana %d" % [
            opponent_name,
            house_name,
            int(rivalry.get("wins", 0)),
            int(rivalry.get("losses", 0)),
            int(rivalry.get("encounters", 0)),
            streak_text,
            GladiatorRivalryController.get_intensity_label(int(rivalry.get("intensity", 0))),
            int(rivalry.get("intensity", 0)),
            int(rivalry.get("last_week", 0))
        ]
        section.add_child(label)
    last_rendered_person_id = person_id

func _rival_house_name(rival_id: String) -> String:
    var rival := RivalManager.get_rival(rival_id)
    return str(rival.get("name", "Casa rival"))
