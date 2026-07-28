extends VBoxContainer

@onready var person_selector: OptionButton = $PersonSelector
@onready var details: RichTextLabel = $MainSplit/Left/Details
@onready var incident: RichTextLabel = $MainSplit/Right/Incident
@onready var choices: VBoxContainer = $MainSplit/Right/Choices
@onready var history: RichTextLabel = $MainSplit/Right/History
@onready var reward_button: Button = $MainSplit/Left/Actions/Reward
@onready var leniency_button: Button = $MainSplit/Left/Actions/Leniency
@onready var punishment_button: Button = $MainSplit/Left/Actions/Punishment

var person_ids: Array[String] = []

func _ready() -> void:
    person_selector.item_selected.connect(_on_person_selected)
    reward_button.pressed.connect(func(): _apply_action("reward"))
    leniency_button.pressed.connect(func(): _apply_action("leniency"))
    punishment_button.pressed.connect(func(): _apply_action("punishment"))
    PersonalityManager.personality_changed.connect(func(_id): _refresh())
    PersonalityManager.incident_changed.connect(_refresh)
    RosterManager.roster_changed.connect(_rebuild_people)
    _rebuild_people()

func _rebuild_people() -> void:
    var previous: String = ""
    if person_selector.selected >= 0 and person_selector.selected < person_ids.size():
        previous = person_ids[person_selector.selected]
    person_selector.clear()
    person_ids.clear()
    for person in RosterManager.get_people():
        person_ids.append(person.id)
        person_selector.add_item(person.display_name)
    if not previous.is_empty() and person_ids.has(previous):
        person_selector.select(person_ids.find(previous))
    elif not person_ids.is_empty():
        person_selector.select(0)
    _refresh()

func _on_person_selected(_index: int) -> void:
    _refresh()

func _selected_person_id() -> String:
    if person_selector.selected < 0 or person_selector.selected >= person_ids.size():
        return ""
    return person_ids[person_selector.selected]

func _refresh() -> void:
    _refresh_person()
    _refresh_incident()
    _refresh_history()

func _refresh_person() -> void:
    var person_id: String = _selected_person_id()
    var person = RosterManager.get_person(person_id)
    if person == null:
        details.text = "Seleccioná un miembro del ludus."
        return
    var record: Dictionary = PersonalityManager.get_record(person_id)
    var trait_lines: Array[String] = []
    for trait_id in person.traits:
        trait_lines.append("• [b]%s[/b]: %s" % [PersonalityManager.get_trait_name(trait_id), PersonalityManager.get_trait_description(trait_id)])
    if trait_lines.is_empty():
        trait_lines.append("• Sin rasgos destacados")
    details.text = "[b]%s[/b] — %s\nMoral: %d | Lealtad: %d | Fatiga: %d\n\n[b]Estado interno[/b]\nDeseo de libertad: %d/100\nResentimiento: %d/100\nAmbición: %d/100\nDisciplina: %d/100\nConfianza: %d/100\nÚltima reacción: %s\n\n[b]Rasgos[/b]\n%s" % [
        person.display_name,
        person.role,
        person.morale,
        person.loyalty,
        person.fatigue,
        int(record.get("freedom_desire", 0)),
        int(record.get("resentment", 0)),
        int(record.get("ambition", 0)),
        int(record.get("discipline", 50)),
        int(record.get("confidence", 50)),
        str(record.get("last_reaction", "Sin reacción reciente")),
        "\n".join(trait_lines)
    ]

func _refresh_incident() -> void:
    for child in choices.get_children():
        child.queue_free()
    var current: Dictionary = PersonalityManager.pending_incident
    if current.is_empty():
        incident.text = "[b]Situación interna[/b]\nNo hay conflictos pendientes."
        return
    incident.text = "[b]Situación interna pendiente[/b]\n%s" % PersonalityManager._incident_description(current)
    match str(current.get("type", "")):
        "escape_attempt":
            _add_choice("Negociar mejores condiciones (35 denarios)", "negotiate")
            _add_choice("Enviar a los guardias", "guards")
            _add_choice("Conceder la libertad", "release")
        "internal_fight":
            _add_choice("Mediar entre ambos", "mediate")
            _add_choice("Castigar a ambos", "punish_both")
        "personal_sabotage":
            _add_choice("Investigar (8 inteligencia)", "investigate")
            _add_choice("Compensar el agravio (40 denarios)", "compensate")
            _add_choice("Aplicar un castigo", "punish")

func _add_choice(label: String, choice_id: String) -> void:
    var button: Button = Button.new()
    button.text = label
    button.pressed.connect(func():
        PersonalityManager.resolve_pending_incident(choice_id)
        _refresh()
    )
    choices.add_child(button)

func _apply_action(action: String) -> void:
    var person_id: String = _selected_person_id()
    if person_id.is_empty():
        return
    PersonalityManager.apply_discipline(person_id, action)
    _refresh()

func _refresh_history() -> void:
    var lines: Array[String] = ["[b]Historial reciente[/b]"]
    for event in PersonalityManager.recent_events.slice(0, 10):
        lines.append("• %s" % str(event.get("description", "Evento interno")))
    if lines.size() == 1:
        lines.append("Sin acontecimientos registrados.")
    history.text = "\n".join(lines)
