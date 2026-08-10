extends "res://scripts/ui/market_screen.gd"

# Active demo presentation for Part 3. The legacy screen remains as a base so
# stable node paths and purchase rendering stay intact while all temporal copy
# and scheduling are month-native and fail closed around unfrozen balance.


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
	feedback.text = (
		"Las ofertas canónicas permanecen hasta que se congele la cadencia mensual del mercado."
	)
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
	feedback.text = (
		"La renovación manual permanece bloqueada hasta congelar su balance mensual."
	)
	_refresh_equipment_offers()


func _refresh_rotation_label() -> void:
	rotation_label.text = "ROTACIÓN DEL MERCADO · PENDIENTE DE BALANCE MENSUAL"


func _refresh_fighter_offers() -> void:
	super._refresh_fighter_offers()
	if MarketManager.get_offers().is_empty():
		fighter_details.text = (
			"[b]NO HAY OFERTAS DISPONIBLES[/b]\n\n"
			+ "La próxima rotación no se programará hasta congelar la cadencia mensual."
		)


func _refresh_equipment_offers() -> void:
	super._refresh_equipment_offers()
	if MarketManager.get_equipment_offers().is_empty():
		equipment_details.text = (
			"[b]SIN EQUIPAMIENTO DISPONIBLE[/b]\n\n"
			+ "La generación y renovación de objetos esperan balance mensual congelado."
		)
	_refresh_controls()


func _refresh_equipment_only() -> void:
	MarketManager.refresh_equipment_market(true)


func _refresh_controls() -> void:
	equipment_refresh_button.text = "RENOVACIÓN MANUAL · PENDIENTE"
	equipment_refresh_button.disabled = true
	if not selected_fighter_offer_id.is_empty():
		_refresh_fighter_details()
	if not selected_equipment_offer_id.is_empty():
		_refresh_equipment_details()
