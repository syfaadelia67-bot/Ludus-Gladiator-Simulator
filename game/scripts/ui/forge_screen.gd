extends HSplitContainer

@onready var back_to_finca: Button = $ForgePanel/Header/BackToFinca
@onready var recipe_list: ItemList = $RecipeList
@onready var recipe_details: RichTextLabel = $ForgePanel/RecipeDetails
@onready var craft_button: Button = $ForgePanel/CraftItem
@onready var inventory: RichTextLabel = $ForgePanel/Inventory

var selected_recipe_id := ""

func _ready() -> void:
    back_to_finca.pressed.connect(_return_to_finca)
    recipe_list.item_selected.connect(_on_recipe_selected)
    craft_button.pressed.connect(_on_craft_item)
    EstateManager.estate_changed.connect(_refresh_recipes)
    EquipmentManager.inventory_changed.connect(_refresh_inventory)
    EquipmentManager.craft_completed.connect(_on_craft_completed)
    EquipmentManager.craft_failed.connect(_show_error)
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
    if selected_recipe_id.is_empty():
        _show_error("Seleccioná una receta.")
        return
    EquipmentManager.craft(selected_recipe_id)

func _on_craft_completed(item_name: String, cost_ore: int, cost_denarii: int) -> void:
    recipe_details.text = "[color=gold]Fabricaste %s por %d mineral y %d denarios.[/color]" % [item_name, cost_ore, cost_denarii]
    _refresh_recipes()
    _refresh_inventory()

func _refresh_recipes() -> void:
    var previous_id := selected_recipe_id
    recipe_list.clear()
    var ids := EquipmentManager.get_recipe_ids()
    for index in range(ids.size()):
        var recipe_id := str(ids[index])
        var data := EquipmentManager.get_recipe(recipe_id)
        var status := "Disponible" if bool(data.get("unlocked", false)) else "Bloqueada"
        recipe_list.add_item("%s — %s" % [data.get("name", recipe_id), status])
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
        recipe_details.text = "Seleccioná una receta."
        craft_button.disabled = true
        return
    var unlocked := bool(data.get("unlocked", false))
    craft_button.disabled = not unlocked
    var stat_text := "Poder: %d" % int(data.get("power", 0)) if data.has("power") else "Defensa: %d" % int(data.get("defense", 0))
    recipe_details.text = "[b]%s[/b]\nTipo: %s | %s\nNivel de forja requerido: %d\nCosto: %d mineral y %d denarios\nEstado: %s" % [
        data.get("name", selected_recipe_id),
        data.get("type", "item"),
        stat_text,
        int(data.get("forge_level", 1)),
        int(data.get("ore", 0)),
        int(data.get("denarii", 0)),
        "Disponible" if unlocked else "Bloqueada"
    ]

func _refresh_inventory() -> void:
    var items := EquipmentManager.get_inventory()
    if items.is_empty():
        inventory.text = "Vacío"
        return
    var lines: Array[String] = []
    for item in items:
        var owner := str(item.get("equipped_by", ""))
        var equipped_text := "" if owner.is_empty() else " — Equipado"
        lines.append("• %s — Calidad %s%s" % [item.get("name", "Objeto"), item.get("quality", "Común"), equipped_text])
    inventory.text = "\n".join(lines)

func _show_error(reason: String) -> void:
    recipe_details.text = "[color=orange]%s[/color]" % reason
