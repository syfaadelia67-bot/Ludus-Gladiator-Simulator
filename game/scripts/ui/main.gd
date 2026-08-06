extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/TopButtons/AdvanceDay
@onready var refresh_market_button: Button = $Margin/VBox/TopButtons/RefreshMarket
@onready var capacity_label: Label = $Margin/VBox/TopButtons/Capacity
@onready var building_list: ItemList = $Margin/VBox/Tabs/Finca/BuildingList
@onready var building_details: RichTextLabel = $Margin/VBox/Tabs/Finca/BuildingPanel/BuildingDetails
@onready var upgrade_button: Button = $Margin/VBox/Tabs/Finca/BuildingPanel/UpgradeBuilding

var selected_building_id := ""

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_week)
    refresh_market_button.visible = false
    refresh_market_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    building_list.item_selected.connect(_on_building_selected)
    upgrade_button.pressed.connect(_on_upgrade_building)
    GameState.resources_changed.connect(_refresh_resources)
    RosterManager.roster_changed.connect(_refresh_resources)
    EstateManager.estate_changed.connect(_refresh_estate)
    EstateManager.upgrade_completed.connect(_on_upgrade_completed)
    EstateManager.upgrade_failed.connect(_on_upgrade_failed)
    _refresh_resources()
    _refresh_estate()

func _on_advance_week() -> void:
    GameState.advance_week()

func _on_building_selected(index: int) -> void:
    if index < 0 or index >= building_list.item_count:
        return
    selected_building_id = str(building_list.get_item_metadata(index))
    _refresh_building_details()

func _on_upgrade_building() -> void:
    if selected_building_id.is_empty():
        building_details.text = "[color=orange]Seleccioná una instalación.[/color]"
        return
    EstateManager.upgrade(selected_building_id)

func _on_upgrade_completed(_building_id: String, _new_level: int) -> void:
    _refresh_estate()

func _on_upgrade_failed(reason: String) -> void:
    building_details.text = "[color=orange]%s[/color]" % reason

func _refresh_resources() -> void:
    resources_label.text = GameState.get_resource_summary()
    capacity_label.text = "Capacidad: %s" % RosterManager.get_capacity_summary()

func _refresh_estate() -> void:
    var previous_id := selected_building_id
    building_list.clear()
    var ids := EstateManager.get_building_ids()
    for index in range(ids.size()):
        var building_id: String = str(ids[index])
        var data := EstateManager.get_building_data(building_id)
        building_list.add_item("%s — Nivel %d" % [data.get("name", building_id), int(data.get("level", 0))])
        building_list.set_item_metadata(index, building_id)

    if ids.is_empty():
        selected_building_id = ""
    elif ids.has(previous_id):
        selected_building_id = previous_id
    else:
        selected_building_id = str(ids[0])

    for index in range(ids.size()):
        if str(ids[index]) == selected_building_id:
            building_list.select(index)
            break

    _refresh_building_details()
    _refresh_resources()

func _refresh_building_details() -> void:
    var data := EstateManager.get_building_data(selected_building_id)
    if data.is_empty():
        building_details.text = "Seleccioná una instalación."
        upgrade_button.disabled = true
        return

    var level := int(data.get("level", 0))
    var max_level := int(data.get("max_level", 5))
    upgrade_button.disabled = level >= max_level
    building_details.text = "[b]%s[/b]\nNivel: %d/%d\n%s\n\nPróxima mejora: %d denarios\n\nEfectos actuales:\nCapacidad: %s\nMultiplicador de entrenamiento: x%.2f\nNivel de forja: %d\nRecuperación extra: %d\nSeguridad fija: %d" % [
        data.get("name", selected_building_id),
        level,
        max_level,
        data.get("description", ""),
        int(data.get("upgrade_cost", 0)),
        RosterManager.get_capacity_summary(),
        EstateManager.get_training_multiplier(),
        EstateManager.get_forge_level(),
        EstateManager.get_recovery_bonus(),
        EstateManager.get_security_bonus()
    ]
