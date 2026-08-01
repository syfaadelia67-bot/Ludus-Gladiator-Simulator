extends Node

const SECTION_NAME := "MedicalCareSection"

var last_person_id := ""
var last_signature := ""
var feedback_text := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    GladiatorMedicalCareController.treatment_purchased.connect(_on_treatment_purchased)
    GladiatorMedicalCareController.treatment_failed.connect(_on_treatment_failed)
    GladiatorMedicalCareController.priority_changed.connect(func(_person_id: String): call_deferred("_refresh_if_open"))
    GladiatorInjuryController.injury_state_changed.connect(func(_person_id: String): call_deferred("_refresh_if_open"))
    EstateManager.estate_changed.connect(func(): call_deferred("_refresh_if_open"))
    GameState.resources_changed.connect(func(): call_deferred("_refresh_if_open"))
    call_deferred("_refresh_if_open")

func _process(_delta: float) -> void:
    var person_id := _get_open_person_id()
    if person_id.is_empty():
        last_person_id = ""
        last_signature = ""
        return
    var signature := _build_signature(person_id)
    if person_id != last_person_id or signature != last_signature:
        _render(person_id)

func _on_treatment_purchased(person_id: String, treatment_id: String, weeks_reduced: int, cost: int) -> void:
    if person_id != _get_open_person_id():
        return
    var treatment := GladiatorMedicalCareController.get_treatment(treatment_id, person_id)
    feedback_text = "%s aplicado: -%d semana(s), costo %d denarios." % [treatment.get("name", treatment_id), weeks_reduced, cost]
    call_deferred("_render", person_id)

func _on_treatment_failed(reason: String) -> void:
    if _get_open_person_id().is_empty():
        return
    feedback_text = reason
    call_deferred("_refresh_if_open")

func _refresh_if_open() -> void:
    var person_id := _get_open_person_id()
    if not person_id.is_empty():
        _render(person_id)

func _get_open_person_id() -> String:
    var dossier := get_node_or_null("/root/GladiatorDossierPresenter")
    if dossier == null:
        return ""
    var person_id := str(dossier.get("selected_person_id"))
    if person_id.is_empty():
        return ""
    var overlay = dossier.get("overlay")
    if overlay == null or not is_instance_valid(overlay) or not overlay.visible:
        return ""
    return person_id

func _render(person_id: String) -> void:
    var dossier := get_node_or_null("/root/GladiatorDossierPresenter")
    if dossier == null:
        return
    var tabs = dossier.get("tab_container") as TabContainer
    if tabs == null:
        return
    var information := tabs.get_node_or_null("Información") as ScrollContainer
    if information == null or information.get_child_count() == 0:
        return
    var box := information.get_child(0) as VBoxContainer
    if box == null:
        return
    var previous := box.get_node_or_null(SECTION_NAME)
    if previous != null:
        previous.free()

    var person = RosterManager.get_person(person_id)
    if person == null:
        return

    var section := VBoxContainer.new()
    section.name = SECTION_NAME
    section.add_theme_constant_override("separation", 8)
    box.add_child(section)
    section.add_child(HSeparator.new())

    var title := Label.new()
    title.text = "ENFERMERÍA Y TRATAMIENTO"
    title.add_theme_font_size_override("font_size", 20)
    section.add_child(title)

    var infirmary_level := EstateManager.get_level("infirmary")
    var status := Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if person.injury_days <= 0:
        status.text = "Enfermería nivel %d · No requiere tratamiento. Las cicatrices permanentes no pueden eliminarse mediante atención común." % infirmary_level
        section.add_child(status)
        _finish_render(person_id)
        return

    status.text = "Enfermería nivel %d · %s · gravedad %d · %d semana(s) restantes." % [
        infirmary_level,
        person.injury_name,
        person.injury_severity,
        person.injury_days
    ]
    section.add_child(status)

    var priority_row := HBoxContainer.new()
    section.add_child(priority_row)
    var priority_label := Label.new()
    priority_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var priority_id := GladiatorMedicalCareController.get_priority_person_id()
    priority_label.text = "Prioridad actual: %s" % (_person_name(priority_id) if not priority_id.is_empty() else "Ninguna")
    priority_row.add_child(priority_label)

    var priority_button := Button.new()
    priority_button.text = "Prioridad asignada" if GladiatorMedicalCareController.is_priority(person_id) else "Asignar prioridad"
    priority_button.disabled = GladiatorMedicalCareController.is_priority(person_id) or CampaignManager.campaign_over
    priority_button.tooltip_text = "La prioridad concede reducción adicional al cerrar la semana. Solo puede existir una prioridad activa."
    priority_button.pressed.connect(_set_priority.bind(person_id))
    priority_row.add_child(priority_button)

    var treatment_header := Label.new()
    treatment_header.text = "Tratamientos disponibles · máximo uno por gladiador y semana"
    section.add_child(treatment_header)

    for treatment_id in GladiatorMedicalCareController.get_treatment_ids():
        var treatment := GladiatorMedicalCareController.get_treatment(treatment_id, person_id)
        var row := HBoxContainer.new()
        section.add_child(row)

        var description := Label.new()
        description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.text = "%s · reduce %d semana(s) · %d denarios\n%s" % [
            treatment.get("name", treatment_id),
            int(treatment.get("weeks", 1)),
            int(treatment.get("cost", 0)),
            treatment.get("description", "")
        ]
        row.add_child(description)

        var button := Button.new()
        button.text = "Aplicar"
        button.disabled = not bool(treatment.get("available", false))
        button.tooltip_text = _treatment_tooltip(person_id, treatment)
        button.pressed.connect(_purchase.bind(person_id, str(treatment_id)))
        row.add_child(button)

    var history := GladiatorMedicalCareController.get_treatment_history(person_id)
    if not history.is_empty():
        var history_label := Label.new()
        history_label.text = "Tratamientos registrados: %d · último en semana %d" % [history.size(), int(history[0].get("week", 1))]
        section.add_child(history_label)

    if not feedback_text.is_empty():
        var feedback := Label.new()
        feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        feedback.text = feedback_text
        section.add_child(feedback)

    _finish_render(person_id)

func _set_priority(person_id: String) -> void:
    feedback_text = "Prioridad médica asignada." if GladiatorMedicalCareController.set_priority(person_id) else feedback_text
    _refresh_if_open()

func _purchase(person_id: String, treatment_id: String) -> void:
    GladiatorMedicalCareController.purchase_treatment(person_id, treatment_id)

func _treatment_tooltip(person_id: String, treatment: Dictionary) -> String:
    if CampaignManager.campaign_over:
        return "La campaña terminó; la ficha está en modo consulta."
    var required_level := int(treatment.get("required_infirmary_level", 1))
    if EstateManager.get_level("infirmary") < required_level:
        return "Requiere Enfermería nivel %d." % required_level
    var record := GladiatorProgressionManager.get_record(person_id)
    if int(record.get("last_medical_treatment_week", 0)) == GameState.get_week():
        return "Ya recibió un tratamiento esta semana."
    if GameState.denarii < int(treatment.get("cost", 0)):
        return "Denarios insuficientes."
    return "Aplicar tratamiento y reducir la recuperación inmediatamente."

func _build_signature(person_id: String) -> String:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return ""
    var record := GladiatorProgressionManager.get_record(person_id)
    return "%d|%d|%d|%d|%s|%d|%d" % [
        person.injury_days,
        person.injury_severity,
        EstateManager.get_level("infirmary"),
        GameState.denarii,
        GladiatorMedicalCareController.get_priority_person_id(),
        int(record.get("last_medical_treatment_week", 0)),
        GladiatorMedicalCareController.get_treatment_history(person_id).size()
    ]

func _person_name(person_id: String) -> String:
    var person = RosterManager.get_person(person_id)
    return person.display_name if person != null else "Ninguna"

func _finish_render(person_id: String) -> void:
    last_person_id = person_id
    last_signature = _build_signature(person_id)
