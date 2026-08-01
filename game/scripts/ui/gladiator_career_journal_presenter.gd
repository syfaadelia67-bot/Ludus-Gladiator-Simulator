extends Node

const JOURNAL_SECTION_NAME := "CareerJournalSection"

var last_person_id := ""
var last_event_count := -1

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    GladiatorCareerJournalController.journal_changed.connect(_on_journal_changed)
    GladiatorInjuryController.injury_state_changed.connect(_on_injury_changed)
    GladiatorInjuryController.scar_added.connect(func(person_id: String, _scar: Dictionary): _on_injury_changed(person_id))
    GladiatorProgressionManager.progression_changed.connect(_refresh_if_open)
    call_deferred("_refresh_if_open")

func _process(_delta: float) -> void:
    var person_id := _get_open_person_id()
    if person_id.is_empty():
        last_person_id = ""
        last_event_count = -1
        return
    var event_count := GladiatorCareerJournalController.get_events(person_id).size()
    if person_id != last_person_id or event_count != last_event_count:
        _render(person_id)

func _on_journal_changed(person_id: String) -> void:
    if person_id == _get_open_person_id():
        call_deferred("_render", person_id)

func _on_injury_changed(person_id: String) -> void:
    if person_id == _get_open_person_id():
        call_deferred("_render", person_id)

func _refresh_if_open() -> void:
    var person_id := _get_open_person_id()
    if not person_id.is_empty():
        call_deferred("_render", person_id)

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
    var previous := box.get_node_or_null(JOURNAL_SECTION_NAME)
    if previous != null:
        previous.queue_free()

    var section := VBoxContainer.new()
    section.name = JOURNAL_SECTION_NAME
    section.add_theme_constant_override("separation", 8)
    box.add_child(section)

    section.add_child(HSeparator.new())
    var title := Label.new()
    title.text = "HISTORIA Y CARRERA"
    title.add_theme_font_size_override("font_size", 20)
    section.add_child(title)

    var background := Label.new()
    background.text = GladiatorCareerJournalController.get_background(person_id)
    background.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    section.add_child(background)

    var summary := GladiatorCareerJournalController.get_summary(person_id)
    var summary_label := Label.new()
    summary_label.text = "Hitos: %d · Combates registrados: %d · Lesiones: %d" % [
        int(summary.get("milestones", 0)),
        int(summary.get("combat_events", 0)),
        int(summary.get("injuries", 0))
    ]
    section.add_child(summary_label)

    _append_medical_section(section, person_id)

    var events: Array = summary.get("events", [])
    if events.is_empty():
        var empty := Label.new()
        empty.text = "Todavía no hay acontecimientos importantes registrados."
        section.add_child(empty)
    else:
        var chronology := RichTextLabel.new()
        chronology.bbcode_enabled = true
        chronology.fit_content = true
        chronology.custom_minimum_size = Vector2(0, 120)
        var lines: Array[String] = []
        for index in range(mini(10, events.size())):
            var entry: Dictionary = events[index]
            lines.append("[b]Semana %d · %s[/b]\n%s" % [
                int(entry.get("week", 1)),
                str(entry.get("title", "Hito de carrera")),
                str(entry.get("description", ""))
            ])
        chronology.text = "\n\n".join(lines)
        section.add_child(chronology)

    last_person_id = person_id
    last_event_count = events.size()

func _append_medical_section(section: VBoxContainer, person_id: String) -> void:
    section.add_child(HSeparator.new())
    var title := Label.new()
    title.text = "ESTADO MÉDICO"
    title.add_theme_font_size_override("font_size", 18)
    section.add_child(title)

    var person = RosterManager.get_person(person_id)
    var active := GladiatorInjuryController.get_active_injury(person_id)
    var scars := GladiatorInjuryController.get_scars(person_id)
    var lines: Array[String] = []
    if person == null:
        lines.append("Sin información médica disponible.")
    elif active.is_empty() or person.injury_days <= 0:
        lines.append("Sin heridas activas · Disponible para combatir: %s" % ("Sí" if person.is_available_for_combat() else "No"))
    else:
        lines.append("Herida activa: %s" % active.get("name", person.injury_name))
        lines.append("Gravedad: %d/3 · Recuperación restante: %d semana(s)" % [int(active.get("severity", person.injury_severity)), person.injury_days])
        lines.append("Disponible para combatir: No")

    if scars.is_empty():
        lines.append("Cicatrices permanentes: ninguna")
    else:
        lines.append("Cicatrices permanentes:")
        for scar in scars:
            lines.append("• %s · Semana %d · %s" % [
                str(scar.get("name", "Cicatriz de combate")).capitalize(),
                int(scar.get("week", 1)),
                _describe_penalty(scar.get("penalty", {}))
            ])

    var medical := Label.new()
    medical.text = "\n".join(lines)
    medical.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    section.add_child(medical)

func _describe_penalty(penalty: Dictionary) -> String:
    if penalty.is_empty():
        return "sin penalización registrada"
    var labels := {"strength":"Fuerza", "agility":"Agilidad", "endurance":"Resistencia", "intelligence":"Inteligencia", "technique":"Técnica", "health":"Vida"}
    var parts: Array[String] = []
    for key in penalty.keys():
        parts.append("%s %+d" % [labels.get(str(key), str(key).capitalize()), int(penalty[key])])
    return ", ".join(parts)
