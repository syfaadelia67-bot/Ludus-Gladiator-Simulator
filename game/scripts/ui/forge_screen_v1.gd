extends HSplitContainer

var selected_recipe_id := ""

@onready var back_to_finca: Button = $ForgePanel/Header/BackToFinca
@onready var recipe_list: ItemList = $RecipeList
@onready var recipe_details: RichTextLabel = $ForgePanel/RecipeDetails
@onready var craft_button: Button = $ForgePanel/CraftItem
@onready var inventory: RichTextLabel = $ForgePanel/Inventory


func _ready() -> void:
	back_to_finca.pressed.connect(_return_to_finca)
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_on_craft_item)
	EstateManager.estate_changed.connect(_refresh_recipes)
	EquipmentManager.inventory_changed.connect(_refresh_inventory)
	EquipmentManager.craft_completed.connect(_on_craft_completed)
	EquipmentManager.craft_failed.connect(_show_error)
	GameState.resources_changed.connect(_refresh_recipe_details)
	_refresh_recipes()
	_refresh_inventory()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_return_to_finca()
		get_viewport().set_input_as_handled()


func _return_to_finca() -> void:
	FincaHubController.show_finca()


func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= recipe_list.item_count:
		selected_recipe_id = ""
	else:
		selected_recipe_id = str(recipe_list.get_item_metadata(index))
	_refresh_recipe_details()


func _on_craft_item() -> void:
	EquipmentManager.craft(selected_recipe_id)


func _refresh_recipes() -> void:
	var previous_id := selected_recipe_id
	recipe_list.clear()
	var ids := EquipmentManager.get_recipe_ids()
	for index in range(ids.size()):
		var recipe_id := str(ids[index])
		var data := EquipmentManager.get_recipe(recipe_id)
		var required_level := int(data.get("forge_level", 1))
		var unlocked := bool(data.get("unlocked", false))
		var marker := "" if unlocked else " · REQUIERE FORJA %d" % required_level
		recipe_list.add_item("%s%s" % [data.get("name", recipe_id), marker])
		recipe_list.set_item_metadata(index, recipe_id)
	if ids.is_empty():
		selected_recipe_id = ""
	else:
		var selected_index := ids.find(previous_id)
		if selected_index < 0:
			selected_index = 0
		selected_recipe_id = str(ids[selected_index])
		recipe_list.select(selected_index)
	_refresh_recipe_details()


func _refresh_recipe_details() -> void:
	var data := EquipmentManager.get_recipe(selected_recipe_id)
	if data.is_empty():
		craft_button.disabled = true
		craft_button.text = "SELECCIONÁ UNA RECETA"
		recipe_details.text = "Seleccioná una receta del catálogo de la forja."
		return

	var required_level := int(data.get("forge_level", 1))
	var unlocked := bool(data.get("unlocked", false))
	var ore_cost := int(data.get("ore", 0))
	var denarii_cost := int(data.get("denarii", 0))
	var enough_ore := GameState.ore >= ore_cost
	var enough_denarii := GameState.denarii >= denarii_cost
	var can_craft := (
		bool(data.get("balance_ready", false))
		and unlocked
		and enough_ore
		and enough_denarii
		and not CampaignManager.campaign_over
	)
	craft_button.disabled = not can_craft
	if CampaignManager.campaign_over:
		craft_button.text = "CAMPAÑA FINALIZADA"
	elif not unlocked:
		craft_button.text = "REQUIERE FORJA NIVEL %d" % required_level
	elif not enough_ore or not enough_denarii:
		craft_button.text = "RECURSOS INSUFICIENTES"
	else:
		craft_button.text = "FABRICAR"

	var slot_id := EquipmentManager.get_item_slot(data)
	var power := int(data.get("power", 0))
	var defense := int(data.get("defense", 0))
	var stat_lines: Array[String] = []
	if power > 0:
		stat_lines.append("Poder base: +%d" % power)
	if defense > 0:
		stat_lines.append("Defensa base: +%d" % defense)
	if stat_lines.is_empty():
		stat_lines.append("Sin bonificación directa de poder o defensa")

	var availability := "Disponible" if unlocked else "Requiere nivel %d de Forja" % required_level
	var resource_status := (
		"Recursos disponibles"
		if enough_ore and enough_denarii
		else "Faltan recursos para fabricar"
	)
	var lines: Array[String] = [
		"[b]%s[/b]" % data.get("name", selected_recipe_id),
		"Ranura: %s" % EquipmentManager.get_slot_label(slot_id),
		"Nivel de Forja: %d · %s" % [required_level, availability],
		"Costo: %d mineral · %d denarios" % [ore_cost, denarii_cost],
		"%s" % resource_status,
		"",
	]
	lines.append_array(stat_lines)
	lines.append("")
	lines.append("Calidad al fabricar: Común, Superior o Magistral.")
	recipe_details.text = "\n".join(lines)


func _refresh_inventory() -> void:
	var items := EquipmentManager.get_inventory()
	if items.is_empty():
		inventory.text = "Vacío"
		return
	var lines: Array[String] = []
	for item in items:
		var owner := str(item.get("equipped_by", ""))
		var slot_id := EquipmentManager.get_item_slot(item)
		var equipped_text := ""
		if not owner.is_empty():
			equipped_text = " · equipado por %s" % owner
		lines.append(
			(
				"• %s · %s · %s%s"
				% [
					item.get("name", "Objeto"),
					item.get("quality", "Común"),
					EquipmentManager.get_slot_label(slot_id),
					equipped_text
				]
			)
		)
	inventory.text = "\n".join(lines)


func _on_craft_completed(item_name: String, cost_ore: int, cost_denarii: int) -> void:
	_refresh_inventory()
	_refresh_recipe_details()
	recipe_details.text += (
		"\n\n[color=green]Fabricado: %s · costo %d mineral / %d denarios.[/color]"
		% [item_name, cost_ore, cost_denarii]
	)


func _show_error(reason: String) -> void:
	_refresh_recipe_details()
	recipe_details.text += "\n\n[color=orange]%s[/color]" % reason