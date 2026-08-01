extends Node

var selected_person_id := ""
var selector: OptionButton
var status: RichTextLabel

func _ready() -> void:
    GladiatorTrainingController.training_focus_changed.connect(func(person_id: String, _focus_id: String):
        if person_id == selected_person_id:
            call_deferred("_refresh")
    )
    GladiatorTrainingController.training_completed.connect(func(person_id: String, _result: Dictionary):
        if person_id == selected_person_id:
            call_deferred("_refresh")
    )
    RosterManager.roster_changed.connect(func(): call_deferred("_refresh"))
    call_deferred("_attach")

func _attach() -> void:
    for _attempt in range(90):
        await get_tree().process_frame
        var dossier := get_tree().current_scene.get_node_or_null("GladiatorDossier") if get_tree().current_scene != null else null
        if dossier == null:
            continue
        var tabs := dossier.find_child("TabContainer", true, false) as TabContainer
        if tabs == null:
            continue
        if not tabs.tab_changed.is_connected(_on_tab_changed.bind(tabs)):
            tabs.tab_changed.connect(_on_tab_changed.bind(tabs))
        _refresh_from_tabs(tabs)
        return

func _on_tab_changed(_index: int, tabs: TabContainer) -> void:
    _refresh_from_tabs(tabs)

func _refresh_from_tabs(tabs: TabContainer) -> void:
    if not is_instance_valid(tabs):
        return
    var info := tabs.find_child("Información", false, false)
    if info == null:
        return
    var dossier := tabs.get_parent().get_parent().get_parent()
    if dossier == null or not dossier.visible:
        return
    selected_person_id = str(GladiatorDossierPresenter.selected_person_id)
    if selected_person_id.is_empty():
        return
    var box := info.get_child(0) if info.get_child_count() > 0 else null
    if box == null:
        return
    var existing := box.get_node_or_null("IndividualTrainingSection")
    if existing != null:
        existing.queue_free()
    var section := VBoxContainer.new()
    section.name = "IndividualTrainingSection"
    section.add_theme_constant_override("separation", 6)
    box.add_child(section)

    var title := Label.new()
    title.text = "PLAN DE ENTRENAMIENTO SEMANAL"
    title.add_theme_font_size_override("font_size", 18)
    section.add_child(title)

    selector = OptionButton.new()
    for focus_id in GladiatorTrainingController.get_focus_ids():
        var data := GladiatorTrainingController.get_focus_data(focus_id)
        selector.add_item(str(data.get("name", focus_id)))
        selector.set_item_metadata(selector.item_count - 1, focus_id)
        if focus_id == GladiatorTrainingController.get_focus(selected_person_id):
            selector.select(selector.item_count - 1)
    selector.item_selected.connect(_on_focus_selected)
    section.add_child(selector)

    status = RichTextLabel.new()
    status.bbcode_enabled = true
    status.fit_content = true
    section.add_child(status)
    _refresh()

func _on_focus_selected(index: int) -> void:
    if selector == null or index < 0:
        return
    var focus_id := str(selector.get_item_metadata(index))
    if not GladiatorTrainingController.set_focus(selected_person_id, focus_id):
        _refresh()

func _refresh() -> void:
    if selected_person_id.is_empty() or status == null or not is_instance_valid(status):
        return
    var person = RosterManager.get_person(selected_person_id)
    if person == null or person.role != "gladiator":
        return
    var preview := GladiatorTrainingController.get_preview(selected_person_id)
    var focus_data := GladiatorTrainingController.get_focus_data(str(preview.get("focus_id", "balanced")))
    var assignment := "Asignado a Entrenamiento" if bool(preview.get("assigned", false)) else "No está asignado a Entrenamiento"
    var availability := "Disponible" if bool(preview.get("available", false)) else "Bloqueado por lesión"
    var risk := int(preview.get("injury_risk", 0))
    status.text = "[b]%s[/b]\n%s\nEstado: %s · %s\nGanancia estimada: %d puntos por semana\nProgreso acumulado: %d/100\nFatiga semanal estimada: +%d\nRiesgo de lesión por sobreentrenamiento: %d%%" % [
        str(preview.get("focus_name", "Entrenamiento")),
        str(focus_data.get("description", "")),
        assignment,
        availability,
        int(preview.get("weekly_gain", 0)),
        int(preview.get("progress", 0)),
        int(preview.get("fatigue_gain", 0)),
        risk
    ]
