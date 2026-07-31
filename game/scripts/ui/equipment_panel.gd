extends VBoxContainer

@onready var gladiator_selector: OptionButton = $GladiatorSelector
@onready var status: RichTextLabel = $Status
@onready var weapon_selector: OptionButton = $WeaponRow/WeaponSelector
@onready var armor_selector: OptionButton = $ArmorRow/ArmorSelector
@onready var shield_selector: OptionButton = $ShieldRow/ShieldSelector
@onready var equip_weapon: Button = $WeaponRow/EquipWeapon
@onready var equip_armor: Button = $ArmorRow/EquipArmor
@onready var equip_shield: Button = $ShieldRow/EquipShield
@onready var unequip_weapon: Button = $UnequipRow/UnequipWeapon
@onready var unequip_armor: Button = $UnequipRow/UnequipArmor
@onready var unequip_shield: Button = $UnequipRow/UnequipShield

var gladiator_ids: Array[String] = []
var weapon_ids: Array[String] = []
var armor_ids: Array[String] = []
var shield_ids: Array[String] = []

func _ready() -> void:
    gladiator_selector.item_selected.connect(_on_gladiator_selected)
    equip_weapon.pressed.connect(func(): _equip_selected("weapon"))
    equip_armor.pressed.connect(func(): _equip_selected("armor"))
    equip_shield.pressed.connect(func(): _equip_selected("shield"))
    unequip_weapon.pressed.connect(func(): _unequip("weapon"))
    unequip_armor.pressed.connect(func(): _unequip("armor"))
    unequip_shield.pressed.connect(func(): _unequip("shield"))
    RosterManager.roster_changed.connect(_refresh)
    GladiatorProgressionManager.progression_changed.connect(_refresh)
    EquipmentManager.inventory_changed.connect(_refresh)
    EquipmentManager.equipment_changed.connect(func(_person_id): _refresh())
    EquipmentManager.equipment_failed.connect(_show_error)
    _refresh()

func _refresh() -> void:
    var previous_id: String = _selected_gladiator_id()
    gladiator_selector.clear()
    gladiator_ids.clear()
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            gladiator_ids.append(person.id)
            var record: Dictionary = GladiatorProgressionManager.get_record(person.id)
            var level: int = int(record.get("level", 1))
            var specialization: String = GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION)))
            var state: String = "Disponible" if person.is_available_for_combat() else person.get_injury_summary()
            gladiator_selector.add_item("%s — Nv. %d %s — %s" % [person.display_name, level, specialization, state])
    if gladiator_ids.is_empty():
        status.text = "No hay gladiadores disponibles."
        _set_controls_enabled(false)
        return
    var selected_index: int = gladiator_ids.find(previous_id)
    gladiator_selector.select(selected_index if selected_index >= 0 else 0)
    _refresh_items()
    _refresh_status()

func _on_gladiator_selected(_index: int) -> void:
    _refresh_items()
    _refresh_status()

func _refresh_items() -> void:
    var person_id: String = _selected_gladiator_id()
    _populate_item_selector(weapon_selector, weapon_ids, "weapon", person_id)
    _populate_item_selector(armor_selector, armor_ids, "armor", person_id)
    _populate_item_selector(shield_selector, shield_ids, "shield", person_id)
    _set_controls_enabled(true)

func _populate_item_selector(selector: OptionButton, ids: Array[String], item_type: String, person_id: String) -> void:
    selector.clear()
    ids.clear()
    for item in EquipmentManager.get_available_items(item_type, person_id):
        ids.append(str(item.get("id", "")))
        var stat: int = int(item.get("power", item.get("defense", 0)))
        selector.add_item("%s — %s — %d" % [item.get("name", "Objeto"), item.get("quality", "Común"), stat])
    selector.disabled = ids.is_empty()

func _refresh_status() -> void:
    var person_id: String = _selected_gladiator_id()
    var person = RosterManager.get_person(person_id)
    if person == null:
        return
    var record: Dictionary = GladiatorProgressionManager.get_record(person_id)
    var bonuses: Dictionary = EquipmentManager.get_equipped_stats(person)
    var level: int = int(record.get("level", 1))
    var specialization: String = GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION)))
    var learned: Dictionary = record.get("abilities", {})
    var ability_lines: Array[String] = []
    for ability_id in learned.keys():
        var ability: Dictionary = GladiatorProgressionManager.abilities.get(str(ability_id), {})
        ability_lines.append("%s %s" % [str(ability.get("name", ability_id)), _roman_level(int(learned[ability_id]))])
    var abilities_text: String = ", ".join(ability_lines) if not ability_lines.is_empty() else "Ninguna"
    status.text = "[b]%s[/b] — Nivel %d — %s\nPuntos de habilidad: %d\nFUE %d | AGI %d | RES %d | INT %d | TEC %d | VIDA %d\nHabilidades: %s\nNivel III: [color=gray]🔒 PRÓXIMAMENTE[/color]\n\nArma: %s\nArmadura: %s\nEscudo: %s\n\nAtaque final: %d | Defensa final: %d\nEstado: %s | Fatiga: %d | Moral: %d" % [
        person.display_name,
        level,
        specialization,
        int(record.get("skill_points", 0)),
        person.strength,
        person.agility,
        person.endurance,
        person.intelligence,
        person.technique,
        person.health,
        abilities_text,
        EquipmentManager.get_item_name(person.equipped_weapon_id),
        EquipmentManager.get_item_name(person.equipped_armor_id),
        EquipmentManager.get_item_name(person.equipped_shield_id),
        person.get_base_attack() + int(bonuses.get("power", 0)),
        person.get_base_defense() + int(bonuses.get("defense", 0)),
        person.get_injury_summary(),
        person.fatigue,
        person.morale
    ]

func _roman_level(level: int) -> String:
    match level:
        1: return "I"
        2: return "II"
        3: return "III"
        _: return str(level)

func _equip_selected(slot: String) -> void:
    var person_id: String = _selected_gladiator_id()
    var ids: Array[String]
    var selector: OptionButton
    match slot:
        "weapon": ids = weapon_ids; selector = weapon_selector
        "armor": ids = armor_ids; selector = armor_selector
        "shield": ids = shield_ids; selector = shield_selector
        _: return
    if selector.selected < 0 or selector.selected >= ids.size():
        _show_error("No hay un objeto seleccionado para esa ranura.")
        return
    EquipmentManager.equip_item(person_id, ids[selector.selected])

func _unequip(slot: String) -> void:
    EquipmentManager.unequip_slot(_selected_gladiator_id(), slot)

func _selected_gladiator_id() -> String:
    if gladiator_selector.selected < 0 or gladiator_selector.selected >= gladiator_ids.size():
        return ""
    return gladiator_ids[gladiator_selector.selected]

func _set_controls_enabled(enabled: bool) -> void:
    equip_weapon.disabled = not enabled
    equip_armor.disabled = not enabled
    equip_shield.disabled = not enabled
    unequip_weapon.disabled = not enabled
    unequip_armor.disabled = not enabled
    unequip_shield.disabled = not enabled

func _show_error(reason: String) -> void:
    status.text = "[color=orange]%s[/color]" % reason
