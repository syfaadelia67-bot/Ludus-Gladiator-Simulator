extends Control

const TAB_ORDER: Array[String] = [
    "information",
    "statistics",
    "equipment",
    "skills",
    "specialization",
    "traits",
    "bonds"
]
const TAB_TITLES := {
    "information": "INFORMACIÓN",
    "statistics": "ESTADÍSTICAS",
    "equipment": "EQUIPAMIENTO",
    "skills": "HABILIDADES",
    "specialization": "ESPECIALIZACIÓN",
    "traits": "RASGOS",
    "bonds": "VÍNCULOS"
}

@onready var back_button: Button = $Margin/Main/Header/Margin/Row/Back
@onready var header_portrait: TextureRect = $Margin/Main/Header/Margin/Row/Portrait
@onready var header_name: Label = $Margin/Main/Header/Margin/Row/Identity/Name
@onready var header_subtitle: Label = $Margin/Main/Header/Margin/Row/Identity/Subtitle
@onready var quick_health: Label = $Margin/Main/Header/Margin/Row/QuickStatus/Health
@onready var quick_fatigue: Label = $Margin/Main/Header/Margin/Row/QuickStatus/Fatigue
@onready var quick_morale: Label = $Margin/Main/Header/Margin/Row/QuickStatus/Morale
@onready var quick_loyalty: Label = $Margin/Main/Header/Margin/Row/QuickStatus/Loyalty

@onready var summary_portrait: TextureRect = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Portrait
@onready var summary_name: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Name
@onready var summary_role: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Role
@onready var experience_label: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/ExperienceLabel
@onready var experience_bar: ProgressBar = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Experience
@onready var health_label: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/HealthLabel
@onready var health_bar: ProgressBar = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Health
@onready var fatigue_label: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/FatigueLabel
@onready var fatigue_bar: ProgressBar = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Fatigue
@onready var morale_label: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/MoraleLabel
@onready var morale_bar: ProgressBar = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Morale
@onready var loyalty_label: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/LoyaltyLabel
@onready var loyalty_bar: ProgressBar = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/Loyalty
@onready var summary_state: Label = $Margin/Main/Body/SummaryPanel/Margin/Scroll/Content/State

@onready var section_title: Label = $Margin/Main/Body/ContentPanel/Margin/Layout/SectionTitle
@onready var feedback: Label = $Margin/Main/Body/ContentPanel/Margin/Layout/Feedback
@onready var content: VBoxContainer = $Margin/Main/Body/ContentPanel/Margin/Layout/Scroll/Content

var tab_buttons: Dictionary = {}
var gladiator_id := ""
var return_context: Dictionary = {}
var active_tab := "information"
var selected_equipment_slot := "right_hand"
var equipment_candidate_ids: Array[String] = []
var equipment_candidate_list: ItemList
var equipment_feedback := ""

func _ready() -> void:
    tab_buttons = {
        "information": $Margin/Main/Tabs/Margin/Row/Information,
        "statistics": $Margin/Main/Tabs/Margin/Row/Statistics,
        "equipment": $Margin/Main/Tabs/Margin/Row/Equipment,
        "skills": $Margin/Main/Tabs/Margin/Row/Skills,
        "specialization": $Margin/Main/Tabs/Margin/Row/Specialization,
        "traits": $Margin/Main/Tabs/Margin/Row/Traits,
        "bonds": $Margin/Main/Tabs/Margin/Row/Bonds
    }
    back_button.pressed.connect(_return_to_context)
    for tab_id in TAB_ORDER:
        var button := tab_buttons.get(tab_id) as Button
        if button != null:
            button.pressed.connect(_select_tab.bind(tab_id))

    RosterManager.roster_changed.connect(_refresh_if_open)
    GladiatorProgressionManager.progression_changed.connect(_refresh_if_open)
    EquipmentManager.inventory_changed.connect(_refresh_if_equipment)
    EquipmentManager.equipment_changed.connect(_on_equipment_changed)
    EquipmentManager.equipment_failed.connect(_on_equipment_failed)
    RelationshipManager.relationships_changed.connect(_refresh_if_bonds)
    TraitManager.traits_changed.connect(_on_traits_changed)
    visibility_changed.connect(_on_visibility_changed)

    _bind_portraits()
    _refresh_empty_state()

func open_gladiator(person_id: String, context: Dictionary = {}, initial_tab: String = "information") -> void:
    gladiator_id = person_id
    return_context = context.duplicate(true)
    active_tab = initial_tab if TAB_ORDER.has(initial_tab) else "information"
    selected_equipment_slot = "right_hand"
    equipment_feedback = ""
    _refresh_all()

func get_gladiator_id() -> String:
    return gladiator_id

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_context()
        get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
    if is_visible_in_tree() and not gladiator_id.is_empty():
        _refresh_all()

func _bind_portraits() -> void:
    var texture := Pack000Assets.get_texture("ui/arena_combat/combat_attack")
    header_portrait.texture = texture
    summary_portrait.texture = texture

func _fighter():
    if gladiator_id.is_empty():
        return null
    var person = RosterManager.get_person(gladiator_id)
    if person == null or str(person.role) != "gladiator":
        return null
    return person

func _refresh_empty_state() -> void:
    header_name.text = "FICHA DEL GLADIADOR"
    header_subtitle.text = "No hay un gladiador seleccionado"
    quick_health.text = "SALUD —"
    quick_fatigue.text = "FATIGA —"
    quick_morale.text = "MORAL —"
    quick_loyalty.text = "LEALTAD —"
    summary_name.text = "GLADIADOR"
    summary_role.text = "Sin selección"
    experience_bar.value = 0
    health_bar.value = 0
    fatigue_bar.value = 0
    morale_bar.value = 0
    loyalty_bar.value = 0
    summary_state.text = "Abrí esta ficha desde Barracones o Arena."
    _clear_content()
    _add_message("No existe un gladiador válido para mostrar.")

func _refresh_all() -> void:
    var fighter = _fighter()
    if fighter == null:
        _refresh_empty_state()
        return
    _refresh_header_and_summary(fighter)
    _refresh_tab_buttons()
    _render_active_tab(fighter)

func _refresh_header_and_summary(fighter) -> void:
    var record: Dictionary = GladiatorProgressionManager.get_record(gladiator_id)
    var specialization_id := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))
    var specialization_name := GladiatorProgressionManager.get_specialization_name(specialization_id)
    var level := int(record.get("level", 1))
    var experience := int(record.get("experience", 0))
    var required := GladiatorProgressionManager.get_experience_required(level) if level < GladiatorProgressionManager.DEMO_MAX_LEVEL else 1

    header_name.text = fighter.display_name.to_upper()
    header_subtitle.text = "%s · %s · NIVEL %d" % [fighter.origin, specialization_name, level]
    quick_health.text = "SALUD %d/%d" % [int(fighter.health), int(fighter.get_max_health())]
    quick_fatigue.text = "FATIGA %d%%" % int(fighter.fatigue)
    quick_morale.text = "MORAL %d%%" % int(fighter.morale)
    quick_loyalty.text = "LEALTAD %d%%" % int(fighter.loyalty)

    summary_name.text = fighter.display_name.to_upper()
    summary_role.text = "%s · %s" % [specialization_name, _career_label(str(record.get("career_state", "activo")))]
    experience_label.text = "EXPERIENCIA · NIVEL %d" % level
    experience_bar.max_value = float(maxi(1, required))
    experience_bar.value = float(required if level >= GladiatorProgressionManager.DEMO_MAX_LEVEL else experience)
    health_label.text = "SALUD · %d/%d" % [int(fighter.health), int(fighter.get_max_health())]
    health_bar.max_value = float(maxi(1, int(fighter.get_max_health())))
    health_bar.value = float(clampi(int(fighter.health), 0, int(fighter.get_max_health())))
    fatigue_label.text = "FATIGA · %d/100" % int(fighter.fatigue)
    fatigue_bar.max_value = 100
    fatigue_bar.value = float(fighter.fatigue)
    morale_label.text = "MORAL · %d/100" % int(fighter.morale)
    morale_bar.max_value = 100
    morale_bar.value = float(fighter.morale)
    loyalty_label.text = "LEALTAD · %d/100" % int(fighter.loyalty)
    loyalty_bar.max_value = 100
    loyalty_bar.value = float(fighter.loyalty)
    summary_state.text = "%s\n%s" % [
        "LISTO PARA COMBATIR" if fighter.is_available_for_combat() else _availability_text(fighter),
        fighter.get_injury_summary()
    ]

func _refresh_tab_buttons() -> void:
    for tab_id in TAB_ORDER:
        var button := tab_buttons.get(tab_id) as Button
        if button != null:
            button.disabled = tab_id == active_tab

func _select_tab(tab_id: String) -> void:
    if not TAB_ORDER.has(tab_id):
        return
    active_tab = tab_id
    feedback.text = equipment_feedback if active_tab == "equipment" else ""
    _refresh_all()

func _render_active_tab(fighter) -> void:
    section_title.text = str(TAB_TITLES.get(active_tab, active_tab.to_upper()))
    feedback.text = equipment_feedback if active_tab == "equipment" else ""
    _clear_content()
    match active_tab:
        "information": _render_information(fighter)
        "statistics": _render_statistics(fighter)
        "equipment": _render_equipment(fighter)
        "skills": _render_skills(fighter)
        "specialization": _render_specialization(fighter)
        "traits": _render_traits(fighter)
        "bonds": _render_bonds(fighter)
        _: _add_message("Sección no disponible.")

func _render_information(fighter) -> void:
    var record: Dictionary = GladiatorProgressionManager.get_record(gladiator_id)
    var event: Dictionary = CombatManager.get_current_event_details()
    var specialization := GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION)))
    var profile := "Gladiador de origen %s. Su ficha reúne estado físico, trayectoria, preparación y situación dentro del ludus." % fighter.origin
    _add_card("INFORMACIÓN PERSONAL", "%s\n\nOrigen: %s\nRol: Gladiador\nEspecialización: %s\nEstado de carrera: %s\nSemanas de carrera: %d" % [
        profile,
        fighter.origin,
        specialization,
        _career_label(str(record.get("career_state", "activo"))),
        int(record.get("age_days", 0))
    ])
    _add_card("ESTADO ACTUAL", "Disponibilidad: %s\nSalud: %d/%d\nFatiga: %d/100\nMoral: %d/100\nLealtad: %d/100\nLesiones: %s" % [
        "Listo" if fighter.is_available_for_combat() else _availability_text(fighter),
        int(fighter.health), int(fighter.get_max_health()), int(fighter.fatigue), int(fighter.morale), int(fighter.loyalty), fighter.get_injury_summary()
    ])
    _add_card("TRAYECTORIA", "Nivel: %d\nExperiencia actual: %d\nFama: %d\nVictorias: %d\nDerrotas: %d\nValor estimado: %d denarios" % [
        int(record.get("level", 1)), int(record.get("experience", 0)), int(record.get("fame", 0)),
        int(record.get("wins", 0)), int(record.get("losses", 0)), GladiatorProgressionManager.get_market_value(gladiator_id)
    ])
    _add_card("PRÓXIMO ENCUENTRO", "%s\n%s\nRiesgo: %s\nRecompensa: %s" % [
        event.get("name", "Combate semanal"), event.get("rules", "Sin reglas especiales."),
        event.get("risk", "—"), event.get("reward", "—")
    ])

func _render_statistics(fighter) -> void:
    var record: Dictionary = GladiatorProgressionManager.get_record(gladiator_id)
    var equipment_stats: Dictionary = EquipmentManager.get_equipped_stats(fighter)
    var base_attack := int(fighter.get_base_attack())
    var base_defense := int(fighter.get_base_defense())
    var total_attack := base_attack + int(equipment_stats.get("power", 0))
    var total_defense := base_defense + int(equipment_stats.get("defense", 0))
    _add_card("ATRIBUTOS PRINCIPALES", "Fuerza: %d\nAgilidad: %d\nResistencia: %d\nTécnica: %d\nInteligencia: %d" % [
        int(fighter.strength), int(fighter.agility), int(fighter.endurance), int(fighter.technique), int(fighter.intelligence)
    ])
    _add_card("COMBATE", "Ataque base: %d\nBonificación de equipo: +%d\nAtaque preparado: %d\n\nDefensa base: %d\nBonificación de equipo: +%d\nDefensa preparada: %d\n\nSalud máxima: %d\nEnergía máxima: %d" % [
        base_attack, int(equipment_stats.get("power", 0)), total_attack,
        base_defense, int(equipment_stats.get("defense", 0)), total_defense,
        int(fighter.get_max_health()), int(fighter.get_max_energy())
    ])
    var total_fights := int(record.get("wins", 0)) + int(record.get("losses", 0))
    var win_rate := 0
    if total_fights > 0:
        win_rate = int(round(100.0 * float(record.get("wins", 0)) / float(total_fights)))
    _add_card("HISTORIAL", "Combates registrados: %d\nVictorias: %d\nDerrotas: %d\nPorcentaje de victorias: %d%%\nFama: %d" % [
        total_fights, int(record.get("wins", 0)), int(record.get("losses", 0)), win_rate, int(record.get("fame", 0))
    ])
    var morale_bonus := RelationshipManager.get_combat_morale_bonus(gladiator_id)
    _add_card("MODIFICADORES SOCIALES", "Bonificación de moral por vínculos: %+d\nLos vínculos positivos y las rivalidades respetuosas pueden sostener al gladiador; las enemistades reducen su estabilidad." % morale_bonus)

func _render_equipment(fighter) -> void:
    var slots: Dictionary = EquipmentManager.get_equipped_slots(fighter)
    var slot_names: Dictionary = EquipmentManager.get_equipped_loadout(fighter).get("slot_names", {})
    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    content.add_child(grid)

    for slot_id in EquipmentManager.get_slot_ids():
        var button := Button.new()
        button.custom_minimum_size = Vector2(560, 88)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        var item_name := str(slot_names.get(slot_id, "Ninguno"))
        button.text = "%s\n%s%s" % [
            EquipmentManager.get_slot_label(slot_id).to_upper(),
            item_name,
            "\nPRÓXIMAMENTE" if slot_id == "mount" else ""
        ]
        var icon_path := EquipmentManager.get_slot_icon_asset(slot_id)
        if not icon_path.is_empty():
            button.icon = Pack000Assets.get_texture(icon_path)
            button.expand_icon = true
        button.disabled = slot_id == "mount"
        button.tooltip_text = "Las monturas se habilitarán en una actualización futura." if slot_id == "mount" else "Seleccionar ranura"
        if slot_id != "mount":
            button.pressed.connect(_select_equipment_slot.bind(slot_id))
        if slot_id == selected_equipment_slot:
            button.text = "▶ %s" % button.text
        grid.add_child(button)

    _add_separator()
    var selected_item_id := str(slots.get(selected_equipment_slot, ""))
    _add_heading("GESTIÓN DE %s" % EquipmentManager.get_slot_label(selected_equipment_slot).to_upper(), 20)
    _add_message("Equipado: %s" % EquipmentManager.get_item_name(selected_item_id))

    equipment_candidate_ids.clear()
    equipment_candidate_list = ItemList.new()
    equipment_candidate_list.custom_minimum_size = Vector2(0, 230)
    equipment_candidate_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    equipment_candidate_list.allow_reselect = true
    var candidates := EquipmentManager.get_available_items_for_slot(selected_equipment_slot, gladiator_id)
    for item_value in candidates:
        var item: Dictionary = item_value
        var item_id := str(item.get("id", ""))
        equipment_candidate_ids.append(item_id)
        equipment_candidate_list.add_item("%s · %s · ATQ +%d · DEF +%d%s" % [
            item.get("name", "Objeto"), item.get("quality", "Común"), int(item.get("power", 0)), int(item.get("defense", 0)),
            " · EQUIPADO" if item_id == selected_item_id else ""
        ])
        equipment_candidate_list.set_item_metadata(equipment_candidate_list.item_count - 1, item_id)
    if equipment_candidate_ids.is_empty():
        equipment_candidate_list.add_item("No hay objetos compatibles en el inventario.")
        equipment_candidate_list.set_item_disabled(0, true)
    content.add_child(equipment_candidate_list)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 10)
    content.add_child(actions)
    var equip_button := Button.new()
    equip_button.custom_minimum_size = Vector2(280, 48)
    equip_button.text = "EQUIPAR SELECCIONADO"
    equip_button.disabled = equipment_candidate_ids.is_empty()
    equip_button.pressed.connect(_equip_selected_candidate)
    actions.add_child(equip_button)
    var unequip_button := Button.new()
    unequip_button.custom_minimum_size = Vector2(230, 48)
    unequip_button.text = "QUITAR DE LA RANURA"
    unequip_button.disabled = selected_item_id.is_empty()
    unequip_button.pressed.connect(_unequip_selected_slot)
    actions.add_child(unequip_button)

    _add_card("REGLAS DEL EQUIPAMIENTO", "Casco, torso y parte inferior aportan protección. Mano derecha y mano izquierda definen armas y escudos. Accesorio admite vendas, antídotos y artículos de contrabando. Montura queda visible como ranura futura, pero no puede utilizarse todavía.")

func _select_equipment_slot(slot_id: String) -> void:
    selected_equipment_slot = slot_id
    equipment_feedback = "Ranura seleccionada: %s." % EquipmentManager.get_slot_label(slot_id)
    _refresh_all()

func _equip_selected_candidate() -> void:
    if equipment_candidate_list == null:
        return
    var selected := equipment_candidate_list.get_selected_items()
    if selected.is_empty():
        equipment_feedback = "Seleccioná un objeto del inventario."
        feedback.text = equipment_feedback
        return
    var index := int(selected[0])
    if index < 0 or index >= equipment_candidate_ids.size():
        equipment_feedback = "La selección ya no está disponible."
        feedback.text = equipment_feedback
        return
    var item_id := equipment_candidate_ids[index]
    if EquipmentManager.equip_item_to_slot(gladiator_id, item_id, selected_equipment_slot):
        equipment_feedback = "%s equipado en %s." % [EquipmentManager.get_item_name(item_id), EquipmentManager.get_slot_label(selected_equipment_slot)]
        _refresh_all()

func _unequip_selected_slot() -> void:
    if EquipmentManager.unequip_equipment_slot(gladiator_id, selected_equipment_slot):
        equipment_feedback = "La ranura %s quedó libre." % EquipmentManager.get_slot_label(selected_equipment_slot)
        _refresh_all()

func _render_skills(fighter) -> void:
    var record: Dictionary = GladiatorProgressionManager.get_record(gladiator_id)
    var learned: Dictionary = record.get("abilities", {})
    _add_card("RESUMEN", "Puntos de habilidad disponibles: %d\nLas habilidades aprendidas se habilitan en combate cuando el equipamiento cumple sus requisitos." % int(record.get("skill_points", 0)))
    var ability_ids := GladiatorProgressionManager.get_available_ability_ids(gladiator_id)
    if ability_ids.is_empty():
        _add_message("No hay habilidades disponibles para esta especialización.")
        return
    for ability_id in ability_ids:
        var ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
        var level := int(learned.get(ability_id, 0))
        var availability := "APRENDIDA · NIVEL %d" % level if level > 0 else "NO APRENDIDA"
        var equipment_ready := EquipmentManager.can_use_ability(fighter, ability)
        _add_card(str(ability.get("name", ability_id)).to_upper(), "%s\n%s\n\n%s\nEstado del equipo: %s" % [
            availability,
            str(ability.get("description", "Sin descripción disponible.")),
            EquipmentManager.get_ability_requirement(ability),
            "Compatible" if equipment_ready else "Requisito pendiente"
        ])

func _render_specialization(fighter) -> void:
    var record: Dictionary = GladiatorProgressionManager.get_record(gladiator_id)
    var specialization_id := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))
    var specialization_name := GladiatorProgressionManager.get_specialization_name(specialization_id)
    var level := int(record.get("level", 1))
    var rank := _specialization_rank(level)
    var required := GladiatorProgressionManager.get_experience_required(level) if level < GladiatorProgressionManager.DEMO_MAX_LEVEL else 1
    var current_exp := int(record.get("experience", 0))
    var percentage := 100 if level >= GladiatorProgressionManager.DEMO_MAX_LEVEL else int(round(100.0 * float(current_exp) / float(maxi(1, required))))
    _add_card("DOMINIO ACTUAL", "%s\nRango: %s\nNivel general: %d\nProgreso hacia el siguiente nivel: %d%%\nExperiencia: %d/%d" % [
        specialization_name, rank, level, clampi(percentage, 0, 100), current_exp, required
    ])
    _add_card("PROGRESIÓN", "Iniciado: niveles 1–2\nAdepto: niveles 3–4\nVeterano: niveles 5–7\nMaestro: niveles 8–9\nLeyenda: nivel 10\n\nLos combates, la dificultad del rival y las victorias aportan experiencia. El equipo correcto habilita las técnicas propias de cada estilo.")
    _add_heading("ESPECIALIZACIONES REGISTRADAS", 20)
    for candidate_id in GladiatorProgressionManager.get_specialization_ids():
        var candidate_name := GladiatorProgressionManager.get_specialization_name(candidate_id)
        var status := "ACTUAL" if candidate_id == specialization_id else ("DISPONIBLE DESDE NIVEL 3" if level < 3 else "CONSULTAR EN PROGRESIÓN")
        _add_message("%s · %s" % [candidate_name, status])

func _render_traits(fighter) -> void:
    if fighter.traits.is_empty():
        _add_message("Este gladiador todavía no tiene rasgos registrados.")
        return
    var categories := {"origin": [], "obtainable": [], "other": []}
    for trait_id_value in fighter.traits:
        var trait_id := str(trait_id_value)
        var trait_data: Dictionary = TraitManager.get_trait(trait_id)
        var category := str(trait_data.get("category", "other"))
        if not categories.has(category):
            category = "other"
        categories[category].append({"id":trait_id, "data":trait_data})
    for category_id in ["origin", "obtainable", "other"]:
        var entries: Array = categories[category_id]
        if entries.is_empty():
            continue
        _add_heading(_trait_category_label(category_id), 20)
        for entry_value in entries:
            var entry: Dictionary = entry_value
            var trait_id := str(entry.get("id", ""))
            var trait_data: Dictionary = entry.get("data", {})
            var modifiers: Dictionary = trait_data.get("modifiers", {})
            var modifier_lines: Array[String] = []
            for key in modifiers.keys():
                modifier_lines.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(modifiers[key])])
            _add_card(TraitManager.get_trait_name(trait_id).to_upper(), "%s%s" % [
                str(trait_data.get("description", "Rasgo registrado en la historia del gladiador.")),
                "\n\nEfectos: %s" % ", ".join(modifier_lines) if not modifier_lines.is_empty() else ""
            ])

func _render_bonds(_fighter) -> void:
    var bonds := RelationshipManager.get_person_relationships(gladiator_id)
    var gladiator_bonds: Array[Dictionary] = []
    for relation_value in bonds:
        if not relation_value is Dictionary:
            continue
        var relation: Dictionary = relation_value
        var other = RosterManager.get_person(str(relation.get("other_id", "")))
        if other != null and str(other.role) == "gladiator":
            gladiator_bonds.append(relation)
    var overview := RelationshipManager.get_social_overview()
    _add_card("CLIMA DEL LUDUS", "Cohesión general: %d\nTensión general: %d\nIntervenciones disponibles: %d/%d" % [
        int(overview.get("cohesion", 50)), int(overview.get("tension", 0)),
        int(overview.get("interventions_remaining", 0)), RelationshipManager.MAX_WEEKLY_INTERVENTIONS
    ])
    if gladiator_bonds.is_empty():
        _add_message("Todavía no existen vínculos registrados con otros gladiadores.")
        return
    for relation in gladiator_bonds:
        _add_card("%s · %s" % [
            str(relation.get("other_name", "GLADIADOR")).to_upper(),
            str(relation.get("tone", relation.get("state_label", "Neutral"))).to_upper()
        ], "Afinidad: %d\nRespeto: %d\nRivalidad: %d\nCelos: %d\nTensión: %d\nMentoría: %d\n\n%s\nÚltimo cambio: %s" % [
            int(relation.get("affinity", 0)), int(relation.get("respect", 0)), int(relation.get("rivalry", 0)),
            int(relation.get("jealousy", 0)), int(relation.get("tension", 0)), int(relation.get("mentorship", 0)),
            str(relation.get("effect_summary", "Sin efecto activo.")), str(relation.get("last_change", "Sin cambios"))
        ])

func _add_card(title: String, body: String) -> void:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 11)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 11)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    margin.add_child(box)
    var heading := Label.new()
    heading.text = title
    heading.add_theme_font_size_override("font_size", 19)
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(heading)
    var label := Label.new()
    label.text = body
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(label)

func _add_heading(text_value: String, font_size: int = 19) -> void:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(label)

func _add_message(text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(label)

func _add_separator() -> void:
    content.add_child(HSeparator.new())

func _clear_content() -> void:
    equipment_candidate_list = null
    equipment_candidate_ids.clear()
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()

func _refresh_if_open() -> void:
    if is_visible_in_tree() and not gladiator_id.is_empty():
        _refresh_all()

func _refresh_if_equipment() -> void:
    if is_visible_in_tree() and active_tab == "equipment":
        _refresh_all()

func _refresh_if_bonds() -> void:
    if is_visible_in_tree() and active_tab == "bonds":
        _refresh_all()

func _on_equipment_changed(person_id: String) -> void:
    if person_id == gladiator_id:
        _refresh_all()

func _on_equipment_failed(reason: String) -> void:
    if not is_visible_in_tree() or active_tab != "equipment":
        return
    equipment_feedback = reason
    feedback.text = reason

func _on_traits_changed(person_id: String) -> void:
    if person_id == gladiator_id and is_visible_in_tree():
        _refresh_all()

func _availability_text(fighter) -> String:
    if int(fighter.injury_days) > 0:
        return "HERIDO · %d SEMANA(S)" % int(fighter.injury_days)
    if int(fighter.fatigue) >= 90:
        return "AGOTADO"
    return "NO DISPONIBLE"

func _career_label(state: String) -> String:
    match state:
        "veterano": return "Veterano"
        "declive": return "En declive"
        _: return "Carrera activa"

func _specialization_rank(level: int) -> String:
    if level >= 10:
        return "Leyenda"
    if level >= 8:
        return "Maestro"
    if level >= 5:
        return "Veterano"
    if level >= 3:
        return "Adepto"
    return "Iniciado"

func _trait_category_label(category_id: String) -> String:
    match category_id:
        "origin": return "RASGOS DE ORIGEN"
        "obtainable": return "RASGOS OBTENIDOS"
        _: return "OTROS RASGOS"

func _return_to_context() -> void:
    FincaHubController.return_from_gladiator_dossier(return_context)
