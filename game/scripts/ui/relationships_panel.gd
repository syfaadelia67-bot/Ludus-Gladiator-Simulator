extends Control

@onready var back_button: Button = $Margin/Main/Header/Row/BackToFinca
@onready var interventions_label: Label = $Margin/Main/Header/Row/Interventions
@onready var cohesion_label: Label = $Margin/Main/Overview/Row/Cohesion
@onready var tension_label: Label = $Margin/Main/Overview/Row/Tension
@onready var mentorships_label: Label = $Margin/Main/Overview/Row/Mentorships
@onready var conflicts_label: Label = $Margin/Main/Overview/Row/Conflicts

@onready var incident_panel: PanelContainer = $Margin/Main/IncidentPanel
@onready var incident_title: Label = $Margin/Main/IncidentPanel/Margin/Content/Title
@onready var incident_description: Label = $Margin/Main/IncidentPanel/Margin/Content/Description
@onready var incident_choices: HBoxContainer = $Margin/Main/IncidentPanel/Margin/Content/Choices

@onready var people_list: ItemList = $Margin/Main/Body/PeoplePanel/Margin/Content/PeopleList
@onready var selected_summary: Label = $Margin/Main/Body/PeoplePanel/Margin/Content/SelectedSummary
@onready var bond_cards: VBoxContainer = $Margin/Main/Body/BondsPanel/Margin/Content/Scroll/BondCards

@onready var detail_title: Label = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/DetailTitle
@onready var tone_label: Label = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Tone
@onready var metrics: RichTextLabel = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Metrics
@onready var effect_label: Label = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Effect
@onready var actions: VBoxContainer = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Actions
@onready var status_label: Label = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Status
@onready var recent_events: RichTextLabel = $Margin/Main/Body/DetailPanel/Margin/Scroll/Content/RecentEvents

var person_ids: Array[String] = []
var selected_person_id := ""
var selected_partner_id := ""

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    people_list.item_selected.connect(_on_person_selected)
    visibility_changed.connect(_on_visibility_changed)
    RelationshipManager.relationships_changed.connect(_refresh)
    RelationshipManager.interventions_changed.connect(func(_remaining: int): _refresh_overview())
    RosterManager.roster_changed.connect(_refresh)
    _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
    if is_visible_in_tree():
        _refresh()

func _refresh() -> void:
    if not is_inside_tree():
        return
    _refresh_overview()
    _refresh_people()
    _refresh_bond_cards()
    _refresh_detail()
    _refresh_incident()
    _refresh_events()

func _refresh_overview() -> void:
    var overview := RelationshipManager.get_social_overview()
    cohesion_label.text = "COHESIÓN · %d" % int(overview.get("cohesion", 50))
    tension_label.text = "TENSIÓN · %d" % int(overview.get("tension", 0))
    mentorships_label.text = "MENTORÍAS · %d" % int(overview.get("mentorships", 0))
    conflicts_label.text = "CONFLICTOS · %d" % int(overview.get("conflicts", 0))
    interventions_label.text = "INTERVENCIONES %d/%d" % [
        int(overview.get("interventions_remaining", 0)),
        RelationshipManager.MAX_WEEKLY_INTERVENTIONS
    ]

func _refresh_people() -> void:
    var previous_id := selected_person_id
    person_ids.clear()
    people_list.clear()

    var pending := RelationshipManager.get_pending_incident()
    for person in RosterManager.get_people():
        var person_id := str(person.id)
        person_ids.append(person_id)
        var relations := RelationshipManager.get_person_relationships(person_id)
        var conflict_count := 0
        var strong_count := 0
        for relation_value in relations:
            var relation: Dictionary = relation_value
            if str(relation.get("state", "neutral")) == "enemistad":
                conflict_count += 1
            elif str(relation.get("state", "neutral")) in ["amistad", "mentoría", "rivalidad"]:
                strong_count += 1
        var marker := " · ATENCIÓN" if person_id in [str(pending.get("actor_id", "")), str(pending.get("target_id", ""))] else ""
        people_list.add_item("%s%s\n%d vínculo(s) · %d conflicto(s)" % [
            person.display_name,
            marker,
            strong_count,
            conflict_count
        ])
        people_list.set_item_metadata(people_list.item_count - 1, person_id)

    if person_ids.is_empty():
        selected_person_id = ""
        selected_partner_id = ""
        selected_summary.text = "No hay integrantes en el ludus."
        return

    var selected_index := person_ids.find(previous_id)
    if selected_index < 0:
        selected_index = 0
    selected_person_id = person_ids[selected_index]
    people_list.select(selected_index)
    _refresh_selected_summary()

func _on_person_selected(index: int) -> void:
    if index < 0 or index >= person_ids.size():
        return
    selected_person_id = person_ids[index]
    selected_partner_id = ""
    status_label.text = "Seleccioná uno de sus vínculos para intervenir."
    _refresh_selected_summary()
    _refresh_bond_cards()
    _refresh_detail()

func _refresh_selected_summary() -> void:
    var person = RosterManager.get_person(selected_person_id)
    if person == null:
        selected_summary.text = "Sin integrante seleccionado."
        return
    var relations := RelationshipManager.get_person_relationships(selected_person_id)
    var strongest := "Sin vínculo dominante"
    if not relations.is_empty():
        var first: Dictionary = relations[0]
        strongest = "%s con %s" % [first.get("tone", "Neutral"), first.get("other_name", "otra persona")]
    selected_summary.text = "%s · %s\n%s" % [
        person.display_name,
        "Gladiador" if str(person.role) == "gladiator" else "Personal",
        strongest
    ]

func _refresh_bond_cards() -> void:
    _clear_children(bond_cards)
    if selected_person_id.is_empty():
        _add_empty_card("Seleccioná un integrante.")
        return

    var relations := RelationshipManager.get_person_relationships(selected_person_id)
    if relations.is_empty():
        selected_partner_id = ""
        _add_empty_card("Todavía no existen vínculos con otros integrantes.")
        return

    var selected_exists := false
    for relation_value in relations:
        var relation: Dictionary = relation_value
        var other_id := str(relation.get("other_id", ""))
        if other_id == selected_partner_id:
            selected_exists = true
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 96)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.text = "%s  ·  %s\nAfinidad %d · Respeto %d · Tensión %d\n%s" % [
            relation.get("other_name", "Desconocido"),
            relation.get("tone", "Neutral"),
            int(relation.get("affinity", 0)),
            int(relation.get("respect", 0)),
            int(relation.get("tension", 0)),
            relation.get("effect_summary", "Sin efecto activo")
        ]
        button.tooltip_text = "Abrir ficha del vínculo"
        button.pressed.connect(_select_partner.bind(other_id))
        bond_cards.add_child(button)

    if not selected_exists:
        selected_partner_id = str(relations[0].get("other_id", ""))

func _add_empty_card(text: String) -> void:
    var label := Label.new()
    label.custom_minimum_size = Vector2(0, 110)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.text = text
    bond_cards.add_child(label)

func _select_partner(partner_id: String) -> void:
    selected_partner_id = partner_id
    status_label.text = "Revisá costos y consecuencias antes de intervenir."
    _refresh_detail()

func _refresh_detail() -> void:
    _clear_children(actions)
    if selected_person_id.is_empty() or selected_partner_id.is_empty():
        detail_title.text = "SELECCIONÁ UN VÍNCULO"
        tone_label.text = "Sin estado"
        metrics.text = "Seleccioná una tarjeta del centro."
        effect_label.text = "Sin efecto activo."
        return

    var person = RosterManager.get_person(selected_person_id)
    var partner = RosterManager.get_person(selected_partner_id)
    var relation := RelationshipManager.get_relationship(selected_person_id, selected_partner_id)
    if person == null or partner == null or relation.is_empty():
        detail_title.text = "VÍNCULO NO DISPONIBLE"
        metrics.text = "La pareja seleccionada ya no pertenece al ludus."
        return

    detail_title.text = "%s ↔ %s" % [person.display_name, partner.display_name]
    tone_label.text = str(relation.get("tone", relation.get("state_label", "Neutral"))).to_upper()
    metrics.text = "[b]AFINIDAD[/b] %d\n[b]RESPETO[/b] %d\n[b]RIVALIDAD[/b] %d\n[b]CELOS[/b] %d\n[b]MENTORÍA[/b] %d\n\nÚltimo cambio: %s" % [
        int(relation.get("affinity", 0)),
        int(relation.get("respect", 0)),
        int(relation.get("rivalry", 0)),
        int(relation.get("jealousy", 0)),
        int(relation.get("mentorship", 0)),
        relation.get("last_change", "Sin cambios")
    ]
    effect_label.text = "EFECTO ACTUAL\n%s" % relation.get("effect_summary", "Sin efecto relevante.")

    for action_data in RelationshipManager.get_available_interactions(selected_person_id, selected_partner_id):
        var action: Dictionary = action_data
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 52)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.text = "%s\n%s" % [action.get("label", "INTERVENIR"), action.get("cost", "")]
        button.disabled = not bool(action.get("allowed", false))
        button.tooltip_text = str(action.get("reason", "")) if button.disabled else "Aplicar intervención"
        button.pressed.connect(_run_interaction.bind(str(action.get("id", ""))))
        actions.add_child(button)

func _run_interaction(interaction_id: String) -> void:
    var result := RelationshipManager.register_interaction(selected_person_id, selected_partner_id, interaction_id)
    status_label.text = str(result.get("description", "No se pudo realizar la intervención."))
    _refresh()

func _refresh_incident() -> void:
    _clear_children(incident_choices)
    var incident := RelationshipManager.get_pending_incident()
    incident_panel.visible = not incident.is_empty()
    if incident.is_empty():
        return

    incident_title.text = "%s · %s y %s" % [
        incident.get("title", "Incidente social"),
        incident.get("actor_name", incident.get("a_name", "")),
        incident.get("target_name", incident.get("b_name", ""))
    ]
    incident_description.text = str(incident.get("description", "Una situación requiere atención."))
    for choice_value in incident.get("choices", []):
        var choice_id := str(choice_value)
        var button := Button.new()
        button.custom_minimum_size = Vector2(230, 46)
        button.text = RelationshipManager.get_choice_label(choice_id)
        button.pressed.connect(_resolve_incident.bind(choice_id))
        incident_choices.add_child(button)

func _resolve_incident(choice_id: String) -> void:
    var result := RelationshipManager.resolve_social_incident(choice_id)
    status_label.text = str(result.get("description", "No se pudo resolver el incidente."))
    _refresh()

func _refresh_events() -> void:
    var lines: Array[String] = []
    var count := 0
    for event_value in RelationshipManager.recent_events:
        if not event_value is Dictionary:
            continue
        var event: Dictionary = event_value
        lines.append("• %s" % str(event.get("description", "Cambio social")))
        count += 1
        if count >= 8:
            break
    recent_events.text = "\n".join(lines) if not lines.is_empty() else "Todavía no hay acontecimientos sociales."

func _clear_children(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()

func _return_to_finca() -> void:
    FincaHubController.show_finca()
