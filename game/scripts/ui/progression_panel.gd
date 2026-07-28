extends VBoxContainer

@onready var gladiator_selector: OptionButton = $GladiatorSelector
@onready var summary: RichTextLabel = $Summary
@onready var specialization_selector: OptionButton = $SpecializationRow/SpecializationSelector
@onready var apply_specialization: Button = $SpecializationRow/ApplySpecialization
@onready var technique_selector: OptionButton = $TechniqueRow/TechniqueSelector
@onready var learn_technique: Button = $TechniqueRow/LearnTechnique
@onready var retire_button: Button = $RetireButton
@onready var retired_history: RichTextLabel = $RetiredHistory
@onready var feedback: Label = $Feedback

var gladiator_ids: Array[String] = []
var specialization_ids: Array[String] = []
var technique_ids: Array[String] = []

func _ready() -> void:
    GladiatorProgressionManager.progression_changed.connect(_refresh)
    RosterManager.roster_changed.connect(_refresh)
    gladiator_selector.item_selected.connect(_on_gladiator_selected)
    apply_specialization.pressed.connect(_on_apply_specialization)
    learn_technique.pressed.connect(_on_learn_technique)
    retire_button.pressed.connect(_on_retire)
    _refresh()

func _refresh() -> void:
    var selected_id: String = _get_selected_gladiator_id()
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
    _refresh_techniques()
    _refresh_details()
    _refresh_retired_history()

func _refresh_specializations() -> void:
    specialization_selector.clear()
    specialization_ids = GladiatorProgressionManager.get_specialization_ids()
    var person_id: String = _get_selected_gladiator_id()
    var record: Dictionary = GladiatorProgressionManager.get_record(person_id) if not person_id.is_empty() else {}
    var current: String = str(record.get("specialization", "balanced"))
    for specialization_id in specialization_ids:
        specialization_selector.add_item(GladiatorProgressionManager.get_specialization_name(specialization_id))
        if specialization_id == current:
            specialization_selector.select(specialization_selector.item_count - 1)

func _refresh_techniques() -> void:
    technique_selector.clear()
    technique_ids.clear()
    var person_id: String = _get_selected_gladiator_id()
    if person_id.is_empty():
        return
    var record: Dictionary = GladiatorProgressionManager.get_record(person_id)
    var learned: Array = record.get("techniques", [])
    for technique_id in GladiatorProgressionManager.get_technique_ids():
        if learned.has(technique_id):
            continue
        var data: Dictionary = GladiatorProgressionManager.get_technique(technique_id)
        technique_ids.append(technique_id)
        technique_selector.add_item("%s (Nv. %d, %d punto)" % [data.get("name", technique_id), int(data.get("min_level", 1)), int(data.get("cost", 1))])

func _refresh_details() -> void:
    var person_id: String = _get_selected_gladiator_id()
    if person_id.is_empty():
        summary.text = "No hay gladiadores disponibles."
        apply_specialization.disabled = true
        learn_technique.disabled = true
        retire_button.disabled = true
        return
    var person = RosterManager.get_person(person_id)
    var record: Dictionary = GladiatorProgressionManager.get_record(person_id)
    var modifiers: Dictionary = GladiatorProgressionManager.get_modifiers(person_id)
    var learned_names: Array[String] = []
    for technique_id in record.get("techniques", []):
        learned_names.append(str(GladiatorProgressionManager.get_technique(str(technique_id)).get("name", technique_id)))
    var required: int = GladiatorProgressionManager.get_experience_required(int(record.get("level", 1)))
    summary.text = "[b]%s[/b]\nNivel %d — XP %d/%d\nEspecialización: %s\nFama: %d | Victorias: %d | Derrotas: %d\nCarrera: %s (%d días)\nPuntos de técnica: %d\nValor de mercado: %d denarios\nBonificadores: ATQ x%.2f | DEF x%.2f | VIDA x%.2f | ENE x%.2f | PREC %d\nTécnicas: %s" % [
        person.display_name,
        int(record.get("level", 1)), int(record.get("experience", 0)), required,
        GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", "balanced"))),
        int(record.get("fame", 0)), int(record.get("wins", 0)), int(record.get("losses", 0)),
        str(record.get("career_state", "activo")).capitalize(), int(record.get("age_days", 0)),
        int(record.get("technique_points", 0)), GladiatorProgressionManager.get_market_value(person_id),
        float(modifiers.get("attack", 1.0)), float(modifiers.get("defense", 1.0)), float(modifiers.get("health", 1.0)), float(modifiers.get("energy", 1.0)), int(modifiers.get("accuracy_bonus", 0)),
        ", ".join(learned_names) if not learned_names.is_empty() else "Ninguna"
    ]
    apply_specialization.disabled = false
    learn_technique.disabled = technique_ids.is_empty()
    retire_button.disabled = not GladiatorProgressionManager.can_retire(person_id)

func _refresh_retired_history() -> void:
    var lines: Array[String] = ["[b]Gladiadores retirados[/b]"]
    for entry in GladiatorProgressionManager.get_retired_history():
        lines.append("%s — nivel %d, fama %d, %dV/%dD" % [entry.get("name", "Desconocido"), int(entry.get("level", 1)), int(entry.get("fame", 0)), int(entry.get("wins", 0)), int(entry.get("losses", 0))])
    if lines.size() == 1:
        lines.append("Todavía no hay retiros registrados.")
    retired_history.text = "\n".join(lines)

func _get_selected_gladiator_id() -> String:
    var index: int = gladiator_selector.selected
    if index < 0 or index >= gladiator_ids.size():
        return ""
    return gladiator_ids[index]

func _on_gladiator_selected(_index: int) -> void:
    feedback.text = ""
    _refresh_specializations()
    _refresh_techniques()
    _refresh_details()

func _on_apply_specialization() -> void:
    var person_id: String = _get_selected_gladiator_id()
    var index: int = specialization_selector.selected
    if person_id.is_empty() or index < 0 or index >= specialization_ids.size():
        return
    var specialization_id: String = specialization_ids[index]
    if GladiatorProgressionManager.set_specialization(person_id, specialization_id):
        feedback.text = "Especialización actualizada."
    else:
        feedback.text = "No se cumplen los requisitos para esa especialización."
    _refresh()

func _on_learn_technique() -> void:
    var person_id: String = _get_selected_gladiator_id()
    var index: int = technique_selector.selected
    if person_id.is_empty() or index < 0 or index >= technique_ids.size():
        return
    if GladiatorProgressionManager.unlock_technique(person_id, technique_ids[index]):
        feedback.text = "Técnica aprendida."
    else:
        feedback.text = "No hay nivel o puntos suficientes para aprenderla."
    _refresh()

func _on_retire() -> void:
    var person_id: String = _get_selected_gladiator_id()
    if person_id.is_empty():
        return
    if GladiatorProgressionManager.retire_gladiator(person_id):
        feedback.text = "El gladiador se retiró con honor."
    else:
        feedback.text = "Todavía no reúne la trayectoria necesaria para retirarse."
    _refresh()
