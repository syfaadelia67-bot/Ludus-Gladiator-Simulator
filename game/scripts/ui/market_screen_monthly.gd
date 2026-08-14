extends "res://scripts/ui/market_screen.gd"

# Active monthly demo presentation. Authored unique gladiators are the canonical
# recruit stock. Procedural recruit/equipment generation stays disabled by the
# frozen monthly market policy; equipment is obtained through the demo Forge.


func _ready() -> void:
	back_button.pressed.connect(_return_to_finca)
	fighters_card.pressed.connect(_open_fighters)
	equipment_card.pressed.connect(_open_equipment)
	back_to_market_home.pressed.connect(_show_market_home)
	fighter_list.item_selected.connect(_on_fighter_selected)
	equipment_list.item_selected.connect(_on_equipment_selected)
	fighter_buy_button.pressed.connect(_buy_selected_fighter)
	equipment_buy_button.pressed.connect(_buy_selected_equipment)
	equipment_refresh_button.pressed.connect(_refresh_equipment_only)
	visibility_changed.connect(_on_visibility_changed)

	MarketManager.market_changed.connect(_refresh_fighter_offers)
	MarketManager.equipment_market_changed.connect(_refresh_equipment_offers)
	MarketManager.purchase_completed.connect(_on_fighter_purchase_completed)
	MarketManager.purchase_failed.connect(_on_fighter_purchase_failed)
	MarketManager.equipment_purchase_completed.connect(_on_equipment_purchase_completed)
	MarketManager.equipment_purchase_failed.connect(_on_equipment_purchase_failed)
	GameState.resources_changed.connect(_refresh_controls)
	GameState.month_advanced.connect(func(_month: int): _refresh_all())

	_configure_cover_cards()
	_show_market_home()
	_refresh_all()


func _open_fighters() -> void:
	active_section = "fighters"
	landing.visible = false
	landing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_shell.visible = true
	content_shell.mouse_filter = Control.MOUSE_FILTER_PASS
	fighters_view.visible = true
	fighters_view.mouse_filter = Control.MOUSE_FILTER_PASS
	equipment_view.visible = false
	equipment_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_title.text = "MERCADO DE LUCHADORES"
	feedback.text = "Los gladiadores únicos disponibles se actualizan con el avance mensual."
	_refresh_fighter_offers()


func _open_equipment() -> void:
	active_section = "equipment"
	landing.visible = false
	landing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_shell.visible = true
	content_shell.mouse_filter = Control.MOUSE_FILTER_PASS
	fighters_view.visible = false
	fighters_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_view.visible = true
	equipment_view.mouse_filter = Control.MOUSE_FILTER_PASS
	section_title.text = "MERCADO DE EQUIPAMIENTO"
	feedback.text = "En la demo, el equipamiento se obtiene mediante la Forja."
	_refresh_equipment_offers()


func _refresh_rotation_label() -> void:
	rotation_label.text = "MERCADO DE LUCHADORES · ACTUALIZACIÓN MENSUAL"


func _refresh_fighter_offers() -> void:
	super._refresh_fighter_offers()
	if MarketManager.get_offers().is_empty():
		fighter_details.text = (
			"[b]NO HAY GLADIADORES DISPONIBLES[/b]\n\n"
			+ "No hay otro gladiador único disponible para contratar este mes."
		)


func _refresh_equipment_offers() -> void:
	super._refresh_equipment_offers()
	if MarketManager.get_equipment_offers().is_empty():
		equipment_details.text = (
			"[b]SIN STOCK DE EQUIPAMIENTO EN EL MERCADO[/b]\n\n"
			+ "Durante la demo, fabricá armas y protecciones desde la Forja."
		)
	_refresh_controls()


func _refresh_equipment_only() -> void:
	# Kept wired for scene/node compatibility. The frozen demo policy intentionally
	# exposes no manual equipment-market refresh.
	feedback.text = "La renovación manual de equipamiento no está disponible en la demo."


func _refresh_controls() -> void:
	equipment_refresh_button.text = "RENOVACIÓN MANUAL NO DISPONIBLE"
	equipment_refresh_button.disabled = true
	if not selected_fighter_offer_id.is_empty():
		_refresh_fighter_details()
	if not selected_equipment_offer_id.is_empty():
		_refresh_equipment_details()
