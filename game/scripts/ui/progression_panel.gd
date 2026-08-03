extends VBoxContainer

@onready var back_button: Button = $Navigation/BackToFinca
@onready var scroll: ScrollContainer = $Scroll
@onready var gladiator_selector: OptionButton = $Scroll/Content/GladiatorSelector
@onready var summary: RichTextLabel = $Scroll/Content/Summary
@onready var specialization_selector: OptionButton = $Scroll/Content/SpecializationRow/SpecializationSelector
@onready var apply_specialization: Button = $Scroll/Content/SpecializationRow/ApplySpecialization
@onready var ability_selector: OptionButton = $Scroll/Content/AbilityRow/AbilitySelector
@onready var upgrade_ability: Button = $Scroll/Content/AbilityRow/UpgradeAbility
@onready var retire_button: Button = $Scroll/Content/RetireButton
@onready var retired_history: RichTextLabel = $Scroll/Content/RetiredHistory
@onready var feedback: Label = $Scroll/Content/Feedback

var gladiator_ids: Array[String] = []
var specialization_ids: Array[String] = []
var ability_ids: Array[String] = []

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    GladiatorProgressionManager.progression_changed.connect(_refresh)
    RosterManager.roster_changed.connect(_refresh)
    TraitManager.traits_changed.connect(func(_person_id: String): _refresh())
    gladiator_selector.item_selected.connect(_on_gladiator_selected)
    apply_specialization.pressed.connect(_on_apply_specialization)
    upgrade_ability.pressed.connect(_on_upgrade_ability)
    retire_button.pressed.connect(_on_retire)
    _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _return_to_finca() -> void:
    FincaHubController.show_finca()

func _refresh() -> void:
    var selected_id := _get_selected_gladiator_id()
    gladiator_selector.clear()
    gladiator_ids.clear()
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        gladiator_ids.append(person.id)
        gladiator_selector.add_item(person.display_name)
    if not selected_id.is_empty() and gladiator_ids.has(selected_id):
        gladiator_selector.select(gladiator_ids.find(selected_id))
    elif not gladiator_ids.is_empty():
        gladiator_selector.select(0)
    _refresh_specializations()
    _refresh_abilities()
    _refresh_details()
    _refresh_retired_history()

func _refresh_specializations() -> void:
    specialization_selector.clear()
    specialization_ids = GladiatorProgressionManager.get_specialization_ids()
    var person_id := _get_selected_gladiator_id()
    var record: Dictionary = GladiatorProgressionManager.get_record(person_id) if not person_id.is_empty() else {}
    var current := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))
    for specialization_id in specialization_ids:
        specialization_selector.add_item(GladiatorProgressionManager.get_specialization_name(specialization_id))
        if specialization_id == current:
            specialization_selector.select(specialization_selector.item_count - 1)

func _refresh_abilities() -> void:
    ability_selector.clear()
    ability_ids.clear()
    var person_id := _get_selected_gladiator_id()
    if person_id.is_empty():
        return
    for ability_id in GladiatorProgressionManager.get_available_ability_ids(person_id):
        var data: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
        var current_level := GladiatorProgressionManager.get_ability_level(person_id, ability_id)
        var demo_max_level := int(data.get("demo_max_level", 2))
        if current_level < demo_max_level:
            ability_ids.append(ability_id)
            var next_level := current_level + 1
            var action := "Aprender" if current_level == 0 else "Mejorar"
            ability_selector.add_item("%s — %s nivel %d" % [str(data.get("name", ability_id)), action, next_level])
            continue
        ability_ids.append("")
        ability_selector.add_item("%s — Nivel III [PRÓXIMAMENTE]" % str(data.get("name", ability_id)))
        ability_selector.set_item_disabled(ability_selector.item_count - 1, true)

func _refresh_details() -> void:
    var person_id := _get_selected_gladiator_id()
    if person_id.is_empty():
        summary.text = "No hay gladiadores disponibles."
        apply_specialization.disabled = true
        upgrade_ability.disabled = true
        retire_button.disabled = true
        return

    var person = RosterManager.get_person(person_id)
    var record: Dictionary = GladiatorProgressionManager.get_record(person_id)
    var level := int(record.get("level", 1))
    var specialization := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))
    var learned_names: Array[String] = []
    var learned: Dictionary = record.get("abilities", {})
    for ability_id in learned.keys():
        var data: Dictionary = GladiatorProgressionManager.abilities.get(str(ability_id), {})
        var learned_level := int(learned[ability_id])
        var roman_level := "II" if learned_level >= 2 else "I"
        learned_names.append("%s %s · III 🔒" % [str(data.get("name", ability_id)), roman_level])

    var trait_names: Array[String] = []
    for trait_id in person.traits:
        trait_names.append(TraitManager.get_trait_name(str(trait_id)))

    var xp_text := "MÁXIMO"
    if level < GladiatorProgressionManager.DEMO_MAX_LEVEL:
        xp_text = "%d/%d" % [int(record.get("experience", 0)), GladiatorProgressionManager.get_experience_required(level)]

    summary.text = "[b]%s[/b]\nNivel %d — XP %s\nEspecialización: %s\nFama: %d | Victorias: %d | Derrotas: %d\nCarrera: %s (%d días)\nPuntos de habilidad: %d\nFUE %d | AGI %d | RES %d | INT %d | TEC %d | VIDA %d\nValor de mercado: %d denarios\nRasgos permanentes: %s\nHabilidades: %s\n[color=gray]Nivel III de habilidades: 🔒 PRÓXIMAMENTE[/color]" % [
        person.display_name,
        level,
        xp_text,
        GladiatorProgressionManager.get_specialization_name(specialization),
        int(record.get("fame", 0)),
        int(record.get("wins", 0)),
        int(record.get("losses", 0)),
        str(record.get("career_state", "activo")).capitalize(),
        int(record.get("age_days", 0)),
        int(record.get("skill_points", 0)),
        person.strength,
        person.agility,
        person.endurance,
        person.intelligence,
        person.technique,
        person.health,
        MarketValuation.person_value(person, record),
        ", ".join(trait_names) if not trait_names.is_empty() else "Ninguno",
        ", ".join(learned_names) if not learned_names.is_empty() else "Ninguna"
    ]

    var can_choose_specialization := specialization == GladiatorProgressionManager.DEFAULT_SPECIALIZATION and level >= 3
    apply_specialization.disabled = not can_choose_specialization
    specialization_selector.disabled = not can_choose_specialization
    var selected_ability_id := ""
    if ability_selector.selected >= 0 and ability_selector.selected < ability_ids.size():
        selected_ability_id = ability_ids[ability_selector.selected]
    upgrade_ability.disabled = selected_ability_id.is_empty() or int(record.get("skill_points", 0)) <= 0
    retire_button.disabled = not GladiatorProgressionManager.can_retire(person_id)

func _refresh_retired_history() -> void:
    var lines: Array[String] = ["[b]Gladiadores retirados[/b]"]
    for entry in GladiatorProgressionManager.get_retired_history():
        lines.append("%s — nivel %d, fama %d, %dV/%dD" % [entry.get("name", "Desconocido"), int(entry.get("level", 1)), int(entry.get("fame", 0)), int(entry.get("wins", 0)), int(entry.get("losses", 0))])
    if lines.size() == 1:
        lines.append("Todavía no hay retiros registrados.")
    retired_history.text = "\n".join(lines)

func _get_selected_gladiator_id() -> String:
    var index := gladiator_selector.selected
    if index < 0 or index >= gladiator_ids.size():
        return ""
    return gladiator_ids[index]

func _on_gladiator_selected(_index: int) -> void:
    feedback.text = ""
    _refresh_specializations()
    _refresh_abilities()
    _refresh_details()
    scroll.scroll_vertical = 0

func _on_apply_specialization() -> void:
    var person_id := _get_selected_gladiator_id()
    var index := specialization_selector.selected
    if person_id.is_empty() or index < 0 or index >= specialization_ids.size():
        return
    var specialization_id := specialization_ids[index]
    if GladiatorProgressionManager.set_specialization(person_id, specialization_id):
        feedback.text = "Especialización aplicada de forma permanente."
    else:
        feedback.text = "No se cumplen los requisitos o el gladiador ya está especializado."
    _refresh()
    call_deferred("_scroll_to_feedback")

func _on_upgrade_ability() -> void:
    var person_id := _get_selected_gladiator_id()
    var index := ability_selector.selected
    if person_id.is_empty() or index < 0 or index >= ability_ids.size():
        return
    var ability_id := ability_ids[index]
    if ability_id.is_empty():
        feedback.text = "El nivel III estará disponible próximamente."
        call_deferred("_scroll_to_feedback")
        return
    if GladiatorProgressionManager.upgrade_ability(person_id, ability_id):
        feedback.text = "Habilidad aprendida o mejorada."
    else:
        feedback.text = "No hay puntos suficientes o la habilidad está bloqueada."
    _refresh()
    call_deferred("_scroll_to_feedback")

func _on_retire() -> void:
    var person_id := _get_selected_gladiator_id()
    if person_id.is_empty():
        return
    if GladiatorProgressionManager.retire_gladiator(person_id):
        feedback.text = "El gladiador se retiró con honor."
    else:
        feedback.text = "Todavía no reúne la trayectoria necesaria para retirarse."
    _refresh()
    call_deferred("_scroll_to_feedback")

func _scroll_to_feedback() -> void:
    if scroll == null or not is_instance_valid(scroll):
        return
    await get_tree().process_frame
    scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
