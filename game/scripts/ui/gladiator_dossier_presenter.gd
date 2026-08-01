extends Node

const MAIN_SCENE_NAME := "Main"
const ROSTER_LIST_PATH := "Margin/VBox/Tabs/Personal/Left/RosterList"

var overlay: ColorRect
var tab_container: TabContainer
var title_label: Label
var selected_person_id := ""
var specialization_selector: OptionButton
var specialization_progress: ProgressBar
var specialization_status: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    RosterManager.roster_changed.connect(_refresh_open_dossier)
    EquipmentManager.equipment_changed.connect(func(person_id: String):
        if person_id == selected_person_id:
            _refresh_open_dossier()
    )
    GladiatorProgressionManager.progression_changed.connect(_refresh_open_dossier)
    SpecializationMasteryController.mastery_changed.connect(func(person_id: String, _progress: int):
        if person_id == selected_person_id:
            _refresh_open_dossier()
    )
    TraitManager.traits_changed.connect(func(person_id: String):
        if person_id == selected_person_id:
            _refresh_open_dossier()
    )
    call_deferred("_attach_when_ready")

func _unhandled_key_input(event: InputEvent) -> void:
    if overlay != null and overlay.visible and event.is_action_pressed("ui_cancel"):
        _close()
        get_viewport().set_input_as_handled()

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        var roster_list := scene.get_node_or_null(ROSTER_LIST_PATH) as ItemList
        if roster_list == null:
            continue
        if not roster_list.item_activated.is_connected(_on_roster_activated.bind(roster_list)):
            roster_list.item_activated.connect(_on_roster_activated.bind(roster_list))
        roster_list.tooltip_text = "Seleccioná para ver el resumen. Activá o hacé doble clic para abrir la ficha completa."
        _build_overlay(scene)
        return
    push_error("No se pudo conectar la ficha del gladiador con la lista de Personal.")

func _on_roster_activated(index: int, roster_list: ItemList) -> void:
    if index < 0 or index >= roster_list.item_count:
        return
    var person_id := str(roster_list.get_item_metadata(index))
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return
    open_dossier(person_id)

func open_dossier(person_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return false
    selected_person_id = person_id
    _render(person)
    overlay.visible = true
    return true

func _build_overlay(scene: Node) -> void:
    overlay = ColorRect.new()
    overlay.name = "GladiatorDossier"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.025, 0.022, 0.02, 0.94)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 150
    overlay.visible = false
    scene.add_child(overlay)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 70)
    margin.add_theme_constant_override("margin_top", 44)
    margin.add_theme_constant_override("margin_right", 70)
    margin.add_theme_constant_override("margin_bottom", 44)
    overlay.add_child(margin)

    var panel := PanelContainer.new()
    margin.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    var header := HBoxContainer.new()
    content.add_child(header)

    title_label = Label.new()
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.add_theme_font_size_override("font_size", 28)
    header.add_child(title_label)

    var close_button := Button.new()
    close_button.text = "Cerrar"
    close_button.tooltip_text = "Cerrar ficha del gladiador (Esc)"
    close_button.pressed.connect(_close)
    header.add_child(close_button)

    tab_container = TabContainer.new()
    tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(tab_container)

func _render(person) -> void:
    title_label.text = "%s · Ficha del gladiador" % person.display_name
    for child in tab_container.get_children():
        child.queue_free()
    _build_information_tab(person)
    _build_equipment_tab(person)
    _build_abilities_tab(person)
    _build_traits_tab(person)
    _build_specialization_tab(person)

func _build_information_tab(person) -> void:
    var scroll := ScrollContainer.new()
    scroll.name = "Información"
    tab_container.add_child(scroll)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(box)

    var portrait := ColorRect.new()
    portrait.custom_minimum_size = Vector2(220, 220)
    portrait.color = Color(0.16, 0.14, 0.12, 1.0)
    portrait.tooltip_text = "Espacio reservado para el retrato definitivo del personaje."
    box.add_child(portrait)

    var placeholder := Label.new()
    placeholder.text = "RETRATO PENDIENTE"
    placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait.add_child(placeholder)

    var record := GladiatorProgressionManager.get_record(person.id)
    var info := RichTextLabel.new()
    info.bbcode_enabled = true
    info.fit_content = true
    info.text = "[b]Historia y origen[/b]\n%s nació o fue capturado en %s. Su historia personal todavía no fue documentada en detalle.\n\n[b]Estado[/b]\nNivel %d · %s\nVictorias: %d · Derrotas: %d · Fama: %d\nLealtad: %d · Moral: %d · Fatiga: %d\n\n[b]Atributos[/b]\nFuerza %d · Agilidad %d · Resistencia %d · Inteligencia %d\nAtaque %d · Defensa %d · Vida %d · Energía %d" % [
        person.display_name, person.origin, int(record.get("level", 1)), str(record.get("career_state", "activo")).capitalize(),
        int(record.get("wins", 0)), int(record.get("losses", 0)), int(record.get("fame", 0)),
        person.loyalty, person.morale, person.fatigue,
        person.strength, person.agility, person.endurance, person.intelligence,
        person.get_base_attack(), person.get_base_defense(), person.get_max_health(), person.get_max_energy()
    ]
    box.add_child(info)

func _build_equipment_tab(person) -> void:
    var box := VBoxContainer.new()
    box.name = "Equipamiento"
    tab_container.add_child(box)
    var loadout := EquipmentManager.get_equipped_loadout(person)
    var text := RichTextLabel.new()
    text.bbcode_enabled = true
    text.fit_content = true
    text.text = "[b]Equipo actual[/b]\nArma: %s\nArmadura: %s\nEscudo: %s\n\nEl equipo utilizado en entrenamientos y combates contribuye al dominio de la especialización." % [
        loadout.get("weapon_name", "Ninguno"),
        loadout.get("armor_name", "Ninguna"),
        loadout.get("shield_name", "Ninguno")
    ]
    box.add_child(text)
    var open_equipment := Button.new()
    open_equipment.text = "Gestionar equipamiento"
    open_equipment.pressed.connect(func():
        _close()
        FincaHubController.open_system("equipamiento")
    )
    box.add_child(open_equipment)

func _build_abilities_tab(person) -> void:
    var scroll := ScrollContainer.new()
    scroll.name = "Habilidades"
    tab_container.add_child(scroll)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(box)
    var record := GladiatorProgressionManager.get_record(person.id)
    var learned: Dictionary = record.get("abilities", {})
    var header := Label.new()
    header.text = "Puntos disponibles: %d" % int(record.get("skill_points", 0))
    box.add_child(header)
    for ability_id in GladiatorProgressionManager.get_available_ability_ids(person.id):
        var data: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
        var level := int(learned.get(ability_id, 0))
        var row := HBoxContainer.new()
        box.add_child(row)
        var description := Label.new()
        description.text = "%s · Nivel %d\n%s" % [data.get("name", ability_id), level, data.get("description", "")]
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(description)
        var upgrade := Button.new()
        upgrade.text = "Aprender" if level == 0 else "Mejorar"
        upgrade.disabled = int(record.get("skill_points", 0)) <= 0
        upgrade.pressed.connect(_upgrade_ability.bind(person.id, str(ability_id)))
        row.add_child(upgrade)

func _upgrade_ability(person_id: String, ability_id: String) -> void:
    if GladiatorProgressionManager.upgrade_ability(person_id, ability_id):
        _refresh_open_dossier()

func _build_traits_tab(person) -> void:
    var scroll := ScrollContainer.new()
    scroll.name = "Rasgos"
    tab_container.add_child(scroll)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(box)
    if person.traits.is_empty():
        var empty := Label.new()
        empty.text = "Este gladiador todavía no tiene rasgos registrados."
        box.add_child(empty)
        return
    for trait_id in person.traits:
        var data := TraitManager.get_trait(str(trait_id))
        var label := Label.new()
        label.text = "%s\n%s" % [TraitManager.get_trait_name(str(trait_id)), data.get("description", "Sin descripción.")]
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(label)

func _build_specialization_tab(person) -> void:
    var box := VBoxContainer.new()
    box.name = "Especialización"
    tab_container.add_child(box)
    var record := GladiatorProgressionManager.get_record(person.id)
    var current_id := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))

    var explanation := Label.new()
    explanation.text = "Elegí una especialización al alcanzar nivel 3. El dominio aumenta al ganar combates, combatir con equipo y entrenar con ese equipo."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(explanation)

    specialization_selector = OptionButton.new()
    for specialization_id in GladiatorProgressionManager.get_specialization_ids():
        specialization_selector.add_item(GladiatorProgressionManager.get_specialization_name(specialization_id))
        specialization_selector.set_item_metadata(specialization_selector.item_count - 1, specialization_id)
        if specialization_id == current_id:
            specialization_selector.select(specialization_selector.item_count - 1)
    specialization_selector.disabled = current_id != GladiatorProgressionManager.DEFAULT_SPECIALIZATION or int(record.get("level", 1)) < 3
    box.add_child(specialization_selector)

    var select_button := Button.new()
    select_button.text = "Confirmar especialización"
    select_button.disabled = specialization_selector.disabled
    select_button.pressed.connect(_select_specialization.bind(person.id))
    box.add_child(select_button)

    specialization_progress = ProgressBar.new()
    specialization_progress.max_value = 100
    specialization_progress.value = SpecializationMasteryController.get_progress(person.id)
    specialization_progress.show_percentage = true
    box.add_child(specialization_progress)

    specialization_status = Label.new()
    specialization_status.text = "%s · %d%% de dominio%s" % [
        GladiatorProgressionManager.get_specialization_name(current_id),
        int(specialization_progress.value),
        " · COMPLETADA" if SpecializationMasteryController.is_mastered(person.id) else ""
    ]
    box.add_child(specialization_status)

func _select_specialization(person_id: String) -> void:
    if specialization_selector == null or specialization_selector.selected < 0:
        return
    var specialization_id := str(specialization_selector.get_item_metadata(specialization_selector.selected))
    if SpecializationMasteryController.select_specialization(person_id, specialization_id):
        _refresh_open_dossier()

func _refresh_open_dossier() -> void:
    if selected_person_id.is_empty() or overlay == null or not overlay.visible:
        return
    var person = RosterManager.get_person(selected_person_id)
    if person == null or person.role != "gladiator":
        _close()
        return
    _render(person)

func _close() -> void:
    if overlay != null:
        overlay.visible = false
    selected_person_id = ""
