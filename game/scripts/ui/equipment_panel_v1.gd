extends VBoxContainer

const ACTIVE_SLOTS: Array[String] = [
	"head",
	"torso",
	"right_hand",
	"left_hand",
	"lower_body",
	"accessory",
]

const SLOT_PATHS := {
	"head": "HeadRow",
	"torso": "ArmorRow",
	"right_hand": "WeaponRow",
	"left_hand": "ShieldRow",
	"lower_body": "LowerBodyRow",
	"accessory": "AccessoryRow",
}

var gladiator_ids: Array[String] = []
var selectors: Dictionary = {}
var item_ids_by_slot: Dictionary = {}

@onready var back_to_finca: Button = $Header/BackToFinca
@onready var gladiator_selector: OptionButton = $GladiatorSelector
@onready var status: RichTextLabel = $Status


func _ready() -> void:
	back_to_finca.pressed.connect(_return_to_finca)
	gladiator_selector.item_selected.connect(_on_gladiator_selected)
	for slot_id in ACTIVE_SLOTS:
		var row_path := str(SLOT_PATHS[slot_id])
		var selector := get_node("%s/Selector" % row_path) as OptionButton
		var equip_button := get_node("%s/Equip" % row_path) as Button
		var unequip_button := get_node("%s/Unequip" % row_path) as Button
		selectors[slot_id] = selector
		item_ids_by_slot[slot_id] = []
		equip_button.pressed.connect(_equip_selected.bind(slot_id))
		unequip_button.pressed.connect(_unequip.bind(slot_id))
	RosterManager.roster_changed.connect(_refresh)
	EquipmentManager.inventory_changed.connect(_refresh)
	EquipmentManager.equipment_changed.connect(func(_person_id: String): _refresh())
	EquipmentManager.equipment_failed.connect(_show_error)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_return_to_finca()
		get_viewport().set_input_as_handled()


func _return_to_finca() -> void:
	FincaHubController.show_finca()


func _refresh() -> void:
	var previous_id := _selected_gladiator_id()
	gladiator_selector.clear()
	gladiator_ids.clear()
	for person in RosterManager.get_gladiators():
		gladiator_ids.append(str(person.id))
		var availability: String = (
			"Disponible" if person.is_available_for_combat() else str(person.get_injury_summary())
		)
		gladiator_selector.add_item("%s — %s" % [person.display_name, availability])
	if gladiator_ids.is_empty():
		status.text = "No hay gladiadores disponibles."
		_set_controls_enabled(false)
		return
	var selected_index := gladiator_ids.find(previous_id)
	gladiator_selector.select(selected_index if selected_index >= 0 else 0)
	_refresh_items()
	_refresh_status()


func _on_gladiator_selected(_index: int) -> void:
	_refresh_items()
	_refresh_status()


func _refresh_items() -> void:
	var person_id := _selected_gladiator_id()
	for slot_id in ACTIVE_SLOTS:
		var selector := selectors[slot_id] as OptionButton
		selector.clear()
		var ids: Array[String] = []
		for item in EquipmentManager.get_available_items_for_slot(slot_id, person_id):
			var item_id := str(item.get("id", ""))
			ids.append(item_id)
			selector.add_item(str(item.get("name", "Objeto")))
		selector.disabled = ids.is_empty()
		item_ids_by_slot[slot_id] = ids
	_set_controls_enabled(not CampaignManager.campaign_over)


func _refresh_status() -> void:
	var person = RosterManager.get_person(_selected_gladiator_id())
	if person == null:
		return
	var slots := EquipmentManager.get_equipped_slots(person)
	var lines: Array[String] = [
		"[b]%s[/b]" % person.display_name,
		(
			"FUE %d | AGI %d | TEC %d | RES %d | PV %d"
			% [person.strength, person.agility, person.technique, person.resistance, person.health]
		),
		"",
		"[b]EQUIPO ESTRUCTURAL[/b]",
	]
	for slot_id in ACTIVE_SLOTS:
		var item_id := str(slots.get(slot_id, ""))
		lines.append(
			(
				"%s: %s"
				% [
					EquipmentManager.get_slot_label(slot_id),
					EquipmentManager.get_item_name(item_id)
				]
			)
		)
	lines.append("")
	lines.append("Montura: Próximamente")
	lines.append("")
	lines.append(
		(
			"[color=orange]Los valores power/defense, calidad y requisitos legacy no modifican "
			+ "Combat V1 hasta congelar el catálogo definitivo.[/color]"
		)
	)
	if CampaignManager.campaign_over:
		lines.append("[color=gray]Campaña finalizada: equipamiento en modo consulta.[/color]")
	status.text = "\n".join(lines)


func _equip_selected(slot_id: String) -> void:
	var selector := selectors.get(slot_id) as OptionButton
	var ids: Array = item_ids_by_slot.get(slot_id, [])
	if selector == null or selector.selected < 0 or selector.selected >= ids.size():
		_show_error("No hay un objeto seleccionado para esa ranura.")
		return
	EquipmentManager.equip_item_to_slot(
		_selected_gladiator_id(), str(ids[selector.selected]), slot_id
	)


func _unequip(slot_id: String) -> void:
	EquipmentManager.unequip_equipment_slot(_selected_gladiator_id(), slot_id)


func _selected_gladiator_id() -> String:
	if gladiator_selector.selected < 0 or gladiator_selector.selected >= gladiator_ids.size():
		return ""
	return gladiator_ids[gladiator_selector.selected]


func _set_controls_enabled(enabled: bool) -> void:
	for slot_id in ACTIVE_SLOTS:
		var row_path := str(SLOT_PATHS[slot_id])
		var equip_button := get_node("%s/Equip" % row_path) as Button
		var unequip_button := get_node("%s/Unequip" % row_path) as Button
		equip_button.disabled = not enabled
		unequip_button.disabled = not enabled


func _show_error(reason: String) -> void:
	status.text = "[color=orange]%s[/color]" % reason
