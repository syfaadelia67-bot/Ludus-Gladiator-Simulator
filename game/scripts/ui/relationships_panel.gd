extends Control

@onready var first_select: OptionButton = %FirstSelect
@onready var second_select: OptionButton = %SecondSelect
@onready var summary_label: Label = %SummaryLabel
@onready var values_label: Label = %ValuesLabel
@onready var events_label: RichTextLabel = %EventsLabel
@onready var incident_box: VBoxContainer = %IncidentBox
@onready var incident_title: Label = %IncidentTitle
@onready var incident_description: Label = %IncidentDescription
@onready var incident_choices: VBoxContainer = %IncidentChoices
@onready var status_label: Label = %StatusLabel

var person_ids: Array[String] = []

func _ready() -> void:
    first_select.item_selected.connect(_on_selection_changed)
    second_select.item_selected.connect(_on_selection_changed)
    %TrainTogetherButton.pressed.connect(func(): _run_interaction("train_together"))
    %MediateButton.pressed.connect(func(): _run_interaction("mediate"))
    %EncourageButton.pressed.connect(func(): _run_interaction("encourage_rivalry"))
    RelationshipManager.relationships_changed.connect(_refresh)
    RosterManager.roster_changed.connect(_refresh)
    _refresh()

func _refresh() -> void:
    var previous_a := _selected_id(first_select)
    var previous_b := _selected_id(second_select)
    person_ids.clear()
    first_select.clear()
    second_select.clear()
    for person in RosterManager.get_people():
        person_ids.append(person.id)
        first_select.add_item(person.display_name)
        second_select.add_item(person.display_name)
    _restore_selection(first_select, previous_a, 0)
    _restore_selection(second_select, previous_b, 1 if person_ids.size() > 1 else 0)
    _refresh_relation()
    _refresh_incident()
    _refresh_events()

func _refresh_relation() -> void:
    var a_id := _selected_id(first_select)
    var b_id := _selected_id(second_select)
    if a_id.is_empty() or b_id.is_empty() or a_id == b_id:
        summary_label.text = "Seleccioná dos personas diferentes."
        values_label.text = ""
        return
    var relation := RelationshipManager.get_relationship(a_id, b_id)
    var a = RosterManager.get_person(a_id)
    var b = RosterManager.get_person(b_id)
    summary_label.text = "%s ↔ %s | Estado: %s" % [a.display_name, b.display_name, str(relation.get("state", "neutral")).capitalize()]
    values_label.text = "Afinidad: %d | Respeto: %d | Rivalidad: %d | Celos: %d | Mentoría: %d\nÚltimo cambio: %s" % [
        int(relation.get("affinity", 0)),
        int(relation.get("respect", 0)),
        int(relation.get("rivalry", 0)),
        int(relation.get("jealousy", 0)),
        int(relation.get("mentorship", 0)),
        str(relation.get("last_change", "Sin cambios"))
    ]

func _refresh_incident() -> void:
    for child in incident_choices.get_children():
        child.queue_free()
    var incident := RelationshipManager.get_pending_incident()
    incident_box.visible = not incident.is_empty()
    if incident.is_empty():
        return
    incident_title.text = "%s: %s y %s" % [incident.get("title", "Incidente social"), incident.get("a_name", ""), incident.get("b_name", "")]
    incident_description.text = str(incident.get("description", ""))
    for choice_id in incident.get("choices", []):
        var button := Button.new()
        button.text = RelationshipManager.get_choice_label(str(choice_id))
        button.pressed.connect(_resolve_incident.bind(str(choice_id)))
        incident_choices.add_child(button)

func _refresh_events() -> void:
    var lines: Array[String] = []
    for event in RelationshipManager.recent_events.slice(0, 12):
        lines.append("• %s" % str(event.get("description", "Cambio social")))
    events_label.text = "\n".join(lines) if not lines.is_empty() else "Todavía no hay acontecimientos sociales."

func _run_interaction(interaction: String) -> void:
    var a_id := _selected_id(first_select)
    var b_id := _selected_id(second_select)
    if a_id.is_empty() or b_id.is_empty() or a_id == b_id:
        status_label.text = "Seleccioná dos personas diferentes."
        return
    var result := RelationshipManager.register_interaction(a_id, b_id, interaction)
    status_label.text = str(result.get("description", "No se pudo realizar la interacción."))
    _refresh()

func _resolve_incident(choice_id: String) -> void:
    var result := RelationshipManager.resolve_social_incident(choice_id)
    status_label.text = str(result.get("description", "No se pudo resolver el incidente."))
    _refresh()

func _on_selection_changed(_index: int) -> void:
    _refresh_relation()

func _selected_id(select: OptionButton) -> String:
    var index := select.selected
    return person_ids[index] if index >= 0 and index < person_ids.size() else ""

func _restore_selection(select: OptionButton, person_id: String, fallback: int) -> void:
    var index := person_ids.find(person_id)
    if index < 0:
        index = mini(fallback, maxi(0, person_ids.size() - 1))
    if not person_ids.is_empty():
        select.select(index)
