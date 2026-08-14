extends VBoxContainer

@onready var back_button: Button = $Header/BackToFinca
@onready var status: RichTextLabel = $Status


func _ready() -> void:
	back_button.pressed.connect(_return_to_finca)
	EstateManager.estate_changed.connect(_refresh)
	OwnedBeastRegistry.owned_beasts_changed.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_return_to_finca()
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()


func _return_to_finca() -> void:
	FincaHubController.show_finca()


func _refresh() -> void:
	var data := EstateManager.get_building_data("beast_area")
	var level := int(data.get("level", 0))
	var lines: Array[String] = []
	lines.append("[b]ZONA DE BESTIAS · NIVEL %d/3[/b]" % level)
	lines.append("")
	if level <= 0:
		lines.append(
			(
				"La instalación todavía está en nivel 0. El registro de propiedad se conserva, "
				+ "pero no se aplica una capacidad numérica no congelada."
			)
		)
	else:
		lines.append(
			(
				"La instalación está construida. El alojamiento existe como estructura, pero la "
				+ "capacidad por nivel sigue pendiente de balance."
			)
		)
	lines.append("")
	lines.append("[b]BESTIAS PROPIEDAD DEL LUDUS[/b]")
	var owned := OwnedBeastRegistry.get_owned_beasts()
	if owned.is_empty():
		lines.append("No hay bestias registradas.")
	else:
		for entry in owned:
			var beast_id := str(entry.get("beast_id", ""))
			lines.append(
				(
					"• %s · instancia %s"
					% [_beast_name(beast_id), str(entry.get("instance_id", "sin_id"))]
				)
			)
	lines.append("")
	var combat_status := (
		"[color=orange]Las stats Combat V1 y el adapter canónico de Jabalí, León y Oso ya están "
		+ "listos para Mes XVI. La selección visual final desde Arena sigue pendiente.[/color]"
	)
	lines.append(combat_status)
	status.text = "\n".join(lines)


func _beast_name(beast_id: String) -> String:
	for raw_beast in DataRepository.beasts:
		if not raw_beast is Dictionary:
			continue
		var beast: Dictionary = raw_beast
		if str(beast.get("id", "")) != beast_id:
			continue
		return str(beast.get("name", beast_id))
	return beast_id if not beast_id.is_empty() else "Bestia desconocida"
