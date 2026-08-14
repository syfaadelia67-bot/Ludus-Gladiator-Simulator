extends "res://scripts/ui/finca_screen.gd"


func _ready() -> void:
	advance_week_button.pressed.connect(_advance_month)
	enter_button.pressed.connect(_open_selected_building)
	upgrade_button.pressed.connect(_upgrade_selected_building)
	market_quick_button.pressed.connect(_open_system.bind("mercado"))
	arena_quick_button.pressed.connect(_open_system.bind("arena"))
	personal_quick_button.pressed.connect(_open_system.bind("personal"))

	EstateManager.estate_changed.connect(_refresh_all)
	EstateManager.upgrade_completed.connect(_on_upgrade_completed)
	EstateManager.upgrade_failed.connect(_on_upgrade_failed)
	GameState.resources_changed.connect(_refresh_all)
	GameState.month_advanced.connect(func(_month: int): _refresh_all())
	RosterManager.roster_changed.connect(_refresh_all)
	OwnedBeastRegistry.owned_beasts_changed.connect(_refresh_all)
	EventManager.events_changed.connect(_refresh_alerts)
	world_area.resized.connect(_layout_hotspots)

	_build_building_modal()
	_build_hotspots()
	_refresh_all()
	_select_building(selected_building_id)
	call_deferred("_layout_hotspots")


func _refresh_top_hud() -> void:
	var people := RosterManager.get_people()
	var morale_total := 0
	for person in people:
		morale_total += int(person.morale)
	var average_morale := int(round(float(morale_total) / float(maxi(1, people.size()))))
	resource_summary.text = (
		"Denarios %d  ·  Comida %d  ·  Mineral %d  ·  Reputación %d  ·  Moral %d%%"
		% [GameState.denarii, GameState.food, GameState.ore, GameState.reputation, average_morale]
	)
	week_summary.text = "MES %d" % GameState.get_month()
	advance_week_button.text = "Cerrar mes"
	advance_week_button.tooltip_text = "Cerrar el turno mensual y avanzar la campaña."
	advance_week_button.disabled = CampaignManager.campaign_over


func _refresh_selected_building() -> void:
	var data := EstateManager.get_building_data(selected_building_id)
	if data.is_empty():
		building_title.text = "INSTALACIÓN"
		building_status.text = "No disponible"
		building_description.text = "Seleccioná un edificio del mapa."
		enter_button.disabled = true
		upgrade_button.disabled = true
		_refresh_modal()
		return

	var locked := bool(data.get("locked", false))
	var level := int(data.get("level", 0))
	var max_level := int(data.get("effective_max_level", 0))
	var upgrade_status: Dictionary = data.get("upgrade_status", {})
	building_title.text = str(data.get("name", selected_building_id)).to_upper()
	building_status.text = (
		"BLOQUEADA · JUEGO COMPLETO" if locked else "DEMO · NIVEL %d/%d" % [level, max_level]
	)
	building_description.text = (
		"[b]Descripción[/b]\n%s" % str(data.get("description", "Sin descripción."))
	)
	building_effect.text = "Efecto actual: %s" % _building_effect_text(data)
	_set_upgrade_copy(data, upgrade_status, false)

	var system_id := FincaHubController.get_building_system_id(selected_building_id)
	enter_button.text = _entry_button_text(selected_building_id)
	enter_button.disabled = locked or system_id.is_empty()
	upgrade_button.disabled = not bool(upgrade_status.get("can_upgrade", false))
	_refresh_modal()


func _refresh_modal() -> void:
	if modal_title == null:
		return
	var data := EstateManager.get_building_data(selected_building_id)
	if data.is_empty():
		modal_title.text = "INSTALACIÓN"
		modal_status.text = "No disponible"
		modal_description.text = "Seleccioná un edificio."
		modal_effect.text = ""
		modal_next_upgrade.text = ""
		modal_cost.text = ""
		modal_enter_button.disabled = true
		modal_upgrade_button.disabled = true
		return

	var locked := bool(data.get("locked", false))
	var level := int(data.get("level", 0))
	var demo_max := int(data.get("effective_max_level", 0))
	var upgrade_status: Dictionary = data.get("upgrade_status", {})
	modal_title.text = str(data.get("name", selected_building_id)).to_upper()
	modal_status.text = (
		"JUEGO COMPLETO · NIVELES 0–10"
		if locked
		else "DEMO · NIVEL %d/%d · JUEGO COMPLETO 0–10" % [level, demo_max]
	)
	modal_description.text = (
		"[b]Descripción[/b]\n%s" % str(data.get("description", "Sin descripción."))
	)
	modal_effect.text = "EFECTO ACTUAL · %s" % _building_effect_text(data)
	_set_upgrade_copy(data, upgrade_status, true)

	var system_id := FincaHubController.get_building_system_id(selected_building_id)
	modal_enter_button.text = _entry_button_text(selected_building_id)
	modal_enter_button.disabled = locked or system_id.is_empty()
	modal_upgrade_button.disabled = not bool(upgrade_status.get("can_upgrade", false))


func _set_upgrade_copy(data: Dictionary, status: Dictionary, modal: bool) -> void:
	var target_next := modal_next_upgrade if modal else building_next_upgrade
	var target_cost := modal_cost if modal else building_cost
	var code := str(status.get("code", "unknown"))
	if code == "available":
		target_next.text = (
			("PRÓXIMA MEJORA · NIVEL %d/%d" if modal else "Próxima mejora: nivel %d de %d")
			% [int(status.get("next_level", 0)), int(status.get("max_level", 0))]
		)
		target_cost.text = (
			("COSTO · %d DENARIOS" if modal else "Costo: %d denarios") % int(status.get("cost", 0))
		)
		return
	if code == "upgrade_cost_pending":
		target_next.text = "Mejora bloqueada hasta congelar su costo canónico."
		target_cost.text = "Costo: pendiente" if not modal else "COSTO · PENDIENTE"
		return
	if code == "max_level":
		target_next.text = "Nivel máximo disponible en la demo."
		target_cost.text = "Costo: —" if not modal else ""
		return
	if code == "campaign_over":
		target_next.text = "Campaña finalizada · modo consulta."
		target_cost.text = "Costo: —" if not modal else ""
		return
	if bool(data.get("locked", false)):
		target_next.text = "Disponible en el juego completo."
		target_cost.text = "Costo: —" if not modal else ""
		return
	target_next.text = str(status.get("reason", "Mejora no disponible."))
	target_cost.text = "Costo: —" if not modal else ""


func _building_effect_text(data: Dictionary) -> String:
	if bool(data.get("locked", false)):
		return "Sin efecto durante la demo."
	var building_id := str(data.get("id", ""))
	var level := int(data.get("level", 0))
	var effect_text := "Efecto reservado para una actualización posterior."
	match building_id:
		"dominus_house":
			effect_text = "Centro administrativo y acceso a la campaña."
		"barracks":
			effect_text = (
				"Capacidad estructural de personal %s." % RosterManager.get_capacity_summary()
			)
		"training_yard":
			effect_text = "Planificación disponible; ganancia, fatiga y riesgo mensual pendientes."
		"forge":
			effect_text = (
				"Nivel estructural de Forja %d; desbloqueos según catálogo vigente." % level
			)
		"infirmary":
			effect_text = "Consulta y prioridad médica disponibles; recuperación y costos pendientes."
		"mine":
			effect_text = "Asignación disponible; producción y costo de mejora mensual pendientes."
		"beast_area":
			effect_text = (
				"Registro de propiedad disponible · %d bestia(s); capacidad y combate pendientes."
				% OwnedBeastRegistry.get_owned_count()
			)
	return effect_text


func _entry_button_text(building_id: String) -> String:
	var labels := {
		"dominus_house": "Abrir campaña",
		"barracks": "Entrar a barracones",
		"training_yard": "Abrir luchadores y entrenamiento",
		"forge": "Entrar a la forja",
		"infirmary": "Revisar personal y heridos",
		"mine": "Abrir economía de la mina",
		"beast_area": "Abrir zona de bestias",
	}
	return str(labels.get(building_id, "Entrar"))


func _open_selected_building() -> void:
	if EstateManager.is_locked(selected_building_id):
		_set_feedback("Esta instalación estará disponible en el juego completo.")
		return
	_close_building_modal()
	if not FincaHubController.open_building_system(selected_building_id):
		_set_feedback("No se pudo abrir el sistema de esta instalación.")


func _advance_month() -> void:
	GameState.advance_month()


func _refresh_alerts() -> void:
	var injured := 0
	var idle_workers := 0
	for person in RosterManager.get_people():
		if int(person.injury_days) > 0:
			injured += 1
		if str(person.job) == "idle":
			idle_workers += 1
	injuries_alert.text = "LESIONES\n%d persona(s) heridas" % injured
	food_alert.text = "COMIDA\n%d disponibles · consumo mensual pendiente" % GameState.food
	workers_alert.text = (
		"PERSONAL\n%d sin asignación · %s" % [idle_workers, RosterManager.get_capacity_summary()]
	)
	var pending: Dictionary = EventManager.get_pending_event()
	event_alert.text = (
		"EVENTO\n%s"
		% (
			str(pending.get("title", pending.get("name", "Decisión pendiente")))
			if not pending.is_empty()
			else "Sin decisión pendiente"
		)
	)
	combat_alert.text = "ARENA\nMes %d · consultar Torneos" % GameState.get_month()
