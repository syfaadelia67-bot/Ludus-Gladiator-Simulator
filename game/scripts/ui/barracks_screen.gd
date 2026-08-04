extends VBoxContainer

@onready var back_button: Button = $Header/Margin/Row/BackToFinca
@onready var capacity_label: Label = $Header/Margin/Row/Capacity
@onready var personal_button: Button = $PrimaryChoices/PersonalButton
@onready var fighters_button: Button = $PrimaryChoices/FightersButton
@onready var sections: TabContainer = $Sections

@onready var personal_summary: Label = $Sections/Personal/ListPanel/Margin/Content/Summary
@onready var personal_list: ItemList = $Sections/Personal/ListPanel/Margin/Content/PersonalList
@onready var personal_details: RichTextLabel = $Sections/Personal/DetailsPanel/Margin/Content/DetailsScroll/PersonalDetails
@onready var job_selector: OptionButton = $Sections/Personal/DetailsPanel/Margin/Content/JobPanel/Margin/Row/JobSelector
@onready var assign_job_button: Button = $Sections/Personal/DetailsPanel/Margin/Content/JobPanel/Margin/Row/AssignJob
@onready var personal_feedback: Label = $Sections/Personal/DetailsPanel/Margin/Content/Feedback

@onready var fighter_tabs: TabContainer = $Sections/Luchadores/FighterTabs
@onready var gladiator_summary: Label = $Sections/Luchadores/FighterTabs/Gladiadores/ListPanel/Margin/Content/Summary
@onready var gladiator_list: ItemList = $Sections/Luchadores/FighterTabs/Gladiadores/ListPanel/Margin/Content/GladiatorList
@onready var gladiator_details: RichTextLabel = $Sections/Luchadores/FighterTabs/Gladiadores/DetailsPanel/Margin/Content/DetailsScroll/GladiatorDetails
@onready var training_button: Button = $Sections/Luchadores/FighterTabs/Gladiadores/DetailsPanel/Margin/Content/Actions/Training
@onready var equipment_button: Button = $Sections/Luchadores/FighterTabs/Gladiadores/DetailsPanel/Margin/Content/Actions/Equipment
@onready var arena_button: Button = $Sections/Luchadores/FighterTabs/Gladiadores/DetailsPanel/Margin/Content/Actions/Arena
@onready var beast_status: RichTextLabel = $Sections/Luchadores/FighterTabs/Bestias/Content/Status

var personal_ids: Array[String] = []
var gladiator_ids: Array[String] = []
var job_ids: Array[String] = []
var selected_personal_id := ""
var selected_gladiator_id := ""

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    personal_button.pressed.connect(_show_personal)
    fighters_button.pressed.connect(_show_fighters)
    personal_list.item_selected.connect(_on_personal_selected)
    gladiator_list.item_selected.connect(_on_gladiator_selected)
    assign_job_button.pressed.connect(_assign_selected_job)
    training_button.pressed.connect(_open_training)
    equipment_button.pressed.connect(_open_equipment)
    arena_button.pressed.connect(_open_arena)
    visibility_changed.connect(_on_visibility_changed)

    RosterManager.roster_changed.connect(_refresh_all)
    EstateManager.estate_changed.connect(_refresh_all)
    GameState.week_advanced.connect(func(_week: int): _refresh_all())
    EquipmentManager.equipment_changed.connect(func(_person_id: String): _refresh_gladiators())
    GladiatorProgressionManager.progression_changed.connect(_refresh_gladiators)

    _populate_jobs()
    _show_personal()
    _refresh_all()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
    if is_visible_in_tree():
        _refresh_all()

func _populate_jobs() -> void:
    job_selector.clear()
    job_ids = RosterManager.get_job_ids()
    for job_id in job_ids:
        job_selector.add_item(RosterManager.get_job_name(job_id))

func _show_personal() -> void:
    sections.current_tab = 0
    personal_button.disabled = true
    fighters_button.disabled = false

func _show_fighters() -> void:
    sections.current_tab = 1
    personal_button.disabled = false
    fighters_button.disabled = true
    fighter_tabs.current_tab = 0

func _refresh_all() -> void:
    capacity_label.text = "CAPACIDAD %s" % RosterManager.get_capacity_summary()
    _refresh_personal()
    _refresh_gladiators()
    _refresh_beasts()

func _refresh_personal() -> void:
    var previous_id := selected_personal_id
    personal_ids.clear()
    personal_list.clear()

    for person in RosterManager.get_people():
        if str(person.role) == "gladiator":
            continue
        personal_ids.append(str(person.id))
        personal_list.add_item("%s  ·  %s  ·  %s" % [
            person.display_name,
            person.origin,
            _short_job_name(str(person.job))
        ])
        personal_list.set_item_metadata(personal_list.item_count - 1, person.id)

    personal_summary.text = "%d integrante(s) · %d plaza(s) libres" % [
        personal_ids.size(),
        maxi(0, RosterManager.capacity - RosterManager.get_people().size())
    ]

    if personal_ids.is_empty():
        selected_personal_id = ""
        personal_details.text = "[b]SIN PERSONAL DISPONIBLE[/b]\n\nLos esclavos y trabajadores adquiridos aparecerán en esta sección."
        assign_job_button.disabled = true
        personal_feedback.text = ""
        return

    var selected_index := personal_ids.find(previous_id)
    if selected_index < 0:
        selected_index = 0
    selected_personal_id = personal_ids[selected_index]
    personal_list.select(selected_index)
    _refresh_personal_details()

func _on_personal_selected(index: int) -> void:
    if index < 0 or index >= personal_ids.size():
        return
    selected_personal_id = personal_ids[index]
    personal_feedback.text = ""
    _refresh_personal_details()

func _refresh_personal_details() -> void:
    var person = RosterManager.get_person(selected_personal_id)
    if person == null:
        personal_details.text = "Seleccioná un integrante del personal."
        assign_job_button.disabled = true
        return

    assign_job_button.disabled = false
    var traits_text := ", ".join(person.traits) if not person.traits.is_empty() else "Ninguno"
    personal_details.text = "[b]%s[/b]\n%s · %s\n\n[b]ESTADO[/b]\nLealtad %d · Moral %d · Fatiga %d\nSalud %d/%d · Herida: %s\n\n[b]APTITUDES[/b]\nFuerza %d · Agilidad %d · Resistencia %d\nInteligencia %d · Técnica %d\n\n[b]TRABAJO ACTUAL[/b]\n%s\n%s\n\n[b]FORMACIÓN[/b]\nEntrenamiento %d/100\nRasgos: %s" % [
        person.display_name,
        person.origin,
        "Esclavo" if str(person.role) == "slave" else str(person.role).capitalize(),
        int(person.loyalty),
        int(person.morale),
        int(person.fatigue),
        int(person.health),
        int(person.get_max_health()),
        str(person.injury_name) if int(person.injury_days) > 0 else "Ninguna",
        int(person.strength),
        int(person.agility),
        int(person.endurance),
        int(person.intelligence),
        int(person.technique),
        RosterManager.get_job_name(str(person.job)),
        RosterManager.get_job_description(str(person.job)),
        int(person.training),
        traits_text
    ]

    var current_job_index := job_ids.find(str(person.job))
    if current_job_index >= 0:
        job_selector.select(current_job_index)

func _assign_selected_job() -> void:
    if selected_personal_id.is_empty() or job_selector.selected < 0 or job_selector.selected >= job_ids.size():
        personal_feedback.text = "Seleccioná un integrante y un trabajo."
        return
    var job_id := job_ids[job_selector.selected]
    if RosterManager.assign_job(selected_personal_id, job_id):
        var person = RosterManager.get_person(selected_personal_id)
        personal_feedback.text = "%s fue asignado a %s." % [person.display_name, _short_job_name(job_id)]
        _refresh_personal_details()
    else:
        personal_feedback.text = "No fue posible asignar el trabajo."

func _refresh_gladiators() -> void:
    var previous_id := selected_gladiator_id
    gladiator_ids.clear()
    gladiator_list.clear()

    for person in RosterManager.get_people():
        if str(person.role) != "gladiator":
            continue
        gladiator_ids.append(str(person.id))
        var record: Dictionary = GladiatorProgressionManager.get_record(str(person.id))
        var availability := "LISTO" if person.is_available_for_combat() else _fighter_state_text(person)
        gladiator_list.add_item("%s  ·  Nv.%d  ·  %s" % [
            person.display_name,
            int(record.get("level", 1)),
            availability
        ])
        gladiator_list.set_item_metadata(gladiator_list.item_count - 1, person.id)

    gladiator_summary.text = "%d gladiador(es)" % gladiator_ids.size()

    if gladiator_ids.is_empty():
        selected_gladiator_id = ""
        gladiator_details.text = "[b]SIN GLADIADORES[/b]\n\nLos esclavos que completen su formación y los luchadores comprados aparecerán aquí."
        training_button.disabled = true
        equipment_button.disabled = true
        arena_button.disabled = true
        return

    var selected_index := gladiator_ids.find(previous_id)
    if selected_index < 0:
        selected_index = 0
    selected_gladiator_id = gladiator_ids[selected_index]
    gladiator_list.select(selected_index)
    _refresh_gladiator_details()

func _on_gladiator_selected(index: int) -> void:
    if index < 0 or index >= gladiator_ids.size():
        return
    selected_gladiator_id = gladiator_ids[index]
    _refresh_gladiator_details()

func _refresh_gladiator_details() -> void:
    var fighter = RosterManager.get_person(selected_gladiator_id)
    if fighter == null:
        gladiator_details.text = "Seleccioná un gladiador."
        training_button.disabled = true
        equipment_button.disabled = true
        arena_button.disabled = true
        return

    var record: Dictionary = GladiatorProgressionManager.get_record(str(fighter.id))
    var specialization_id := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))
    var specialization := GladiatorProgressionManager.get_specialization_name(specialization_id)
    var loadout: Dictionary = EquipmentManager.get_equipped_loadout(fighter)
    var traits_text := ", ".join(fighter.traits) if not fighter.traits.is_empty() else "Ninguno"

    gladiator_details.text = "[b]%s[/b]\n%s · Nivel %d\n%s\n\n[b]ESTADO DE COMBATE[/b]\nSalud %d/%d · Energía %d\nMoral %d · Fatiga %d\nEstado: %s\n\n[b]ATRIBUTOS[/b]\nAtaque %d · Defensa %d\nFuerza %d · Agilidad %d · Resistencia %d · Técnica %d\n\n[b]EQUIPAMIENTO[/b]\nArma: %s\nArmadura: %s\nEscudo: %s\n\n[b]CARRERA[/b]\nExperiencia %d · Victorias %d · Derrotas %d\nRasgos: %s" % [
        fighter.display_name,
        fighter.origin,
        int(record.get("level", 1)),
        specialization,
        int(fighter.health),
        int(fighter.get_max_health()),
        int(fighter.get_max_energy()),
        int(fighter.morale),
        int(fighter.fatigue),
        "Listo" if fighter.is_available_for_combat() else _fighter_state_text(fighter).capitalize(),
        int(fighter.get_base_attack()),
        int(fighter.get_base_defense()),
        int(fighter.strength),
        int(fighter.agility),
        int(fighter.endurance),
        int(fighter.technique),
        loadout.get("weapon_name", "Sin arma"),
        loadout.get("armor_name", "Sin armadura"),
        loadout.get("shield_name", "Sin escudo"),
        int(record.get("experience", 0)),
        int(record.get("wins", 0)),
        int(record.get("losses", 0)),
        traits_text
    ]
    training_button.disabled = false
    equipment_button.disabled = false
    arena_button.disabled = false

func _fighter_state_text(person) -> String:
    if int(person.injury_days) > 0:
        return "HERIDO"
    if int(person.fatigue) >= 85:
        return "AGOTADO"
    return "NO DISPONIBLE"

func _refresh_beasts() -> void:
    var beast_area: Dictionary = EstateManager.get_building_data("beast_area")
    var locked := beast_area.is_empty() or bool(beast_area.get("locked", true))
    if locked:
        beast_status.text = "[center][b]CORRALES EN CONSTRUCCIÓN[/b]\n\nLas bestias estarán separadas de los gladiadores y del personal. Cuando se habilite el área de bestias, esta pestaña mostrará sus fichas, estado, alimentación y disponibilidad para la Arena.[/center]"
    else:
        beast_status.text = "[center][b]NO HAY BESTIAS REGISTRADAS[/b]\n\nLas bestias adquiridas o capturadas aparecerán aquí con su estado y preparación.[/center]"

func _short_job_name(job_id: String) -> String:
    var full_name := RosterManager.get_job_name(job_id)
    var separator := full_name.find(" — ")
    return full_name.substr(0, separator) if separator >= 0 else full_name

func _open_training() -> void:
    FincaHubController.open_system("progresion")

func _open_equipment() -> void:
    FincaHubController.open_system("equipamiento")

func _open_arena() -> void:
    FincaHubController.open_system("arena")

func _return_to_finca() -> void:
    FincaHubController.show_finca()
