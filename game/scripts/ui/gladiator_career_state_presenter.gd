extends Node

var selected_person_id := ""
var section: VBoxContainer

func _ready() -> void:
    GladiatorCareerStateController.career_state_changed.connect(func(person_id: String, _state: String):
        if person_id == selected_person_id:
            call_deferred("_refresh")
    )
    GladiatorCareerStateController.gladiator_joined_staff.connect(func(person_id: String, _role: String):
        if person_id == selected_person_id:
            GladiatorDossierPresenter._close()
    )
    GladiatorProgressionManager.progression_changed.connect(func(): call_deferred("_refresh"))
    GladiatorInjuryController.injury_state_changed.connect(func(person_id: String):
        if person_id == selected_person_id:
            call_deferred("_refresh")
    )
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
    var existing := box.get_node_or_null("CareerStateSection")
    if existing != null:
        existing.queue_free()
    section = VBoxContainer.new()
    section.name = "CareerStateSection"
    section.add_theme_constant_override("separation", 6)
    box.add_child(section)
    _build_section()

func _build_section() -> void:
    if section == null or not is_instance_valid(section):
        return
    var person = RosterManager.get_person(selected_person_id)
    if person == null or person.role != "gladiator":
        return
    var record := GladiatorProgressionManager.get_record(selected_person_id)
    var state := GladiatorCareerStateController.get_state(selected_person_id)
    var fights := int(record.get("wins", 0)) + int(record.get("losses", 0))
    var level := int(record.get("level", 1))
    var scars := GladiatorInjuryController.get_scars(selected_person_id).size()

    var title := Label.new()
    title.text = "ESTADO DE CARRERA"
    title.add_theme_font_size_override("font_size", 18)
    section.add_child(title)

    var details := RichTextLabel.new()
    details.bbcode_enabled = true
    details.fit_content = true
    details.text = "[b]%s[/b]\n%s\nSemanas en el ludus: %d · Combates: %d · Nivel: %d · Cicatrices: %d\n\nVeterano: nivel 6 o 8 combates.\nDeclive: 14 combates y al menos 2 cicatrices o nivel 9." % [
        GladiatorCareerStateController.get_state_name(state),
        GladiatorCareerStateController.get_state_description(selected_person_id),
        int(record.get("career_weeks", 0)), fights, level, scars
    ]
    section.add_child(details)

    var retirement := GladiatorCareerStateController.get_retirement_preview(selected_person_id)
    var warning := Label.new()
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.text = "El retiro es permanente. El gladiador deja de combatir, pero conserva su historia y permanece en el ludus."
    section.add_child(warning)

    var actions := HBoxContainer.new()
    section.add_child(actions)

    var trainer := Button.new()
    trainer.text = "Retirar como entrenador"
    trainer.tooltip_text = str(retirement.get("trainer_bonus", ""))
    trainer.disabled = not bool(retirement.get("eligible", false))
    trainer.pressed.connect(_retire.bind("trainer"))
    actions.add_child(trainer)

    var mentor := Button.new()
    mentor.text = "Retirar como mentor"
    mentor.tooltip_text = str(retirement.get("mentor_bonus", ""))
    mentor.disabled = not bool(retirement.get("eligible", false))
    mentor.pressed.connect(_retire.bind("mentor"))
    actions.add_child(mentor)

    if not bool(retirement.get("eligible", false)):
        var reason := Label.new()
        reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        reason.text = "El retiro se habilita al alcanzar Veteranía y requiere no tener una lesión activa."
        section.add_child(reason)

func _retire(staff_role: String) -> void:
    if GladiatorCareerStateController.retire_to_staff(selected_person_id, staff_role):
        selected_person_id = ""

func _refresh() -> void:
    if selected_person_id.is_empty():
        return
    var dossier := get_tree().current_scene.get_node_or_null("GladiatorDossier") if get_tree().current_scene != null else null
    if dossier == null or not dossier.visible:
        return
    var tabs := dossier.find_child("TabContainer", true, false) as TabContainer
    if tabs != null:
        _refresh_from_tabs(tabs)
