extends "res://scripts/ui/arena_screen_monthly.gd"

const TOURNAMENT_DISPLAY_NAME := "Torneo de Marte"
const INTERNAL_TOURNAMENT_LABELS := ["Gran Torneo de Roma", "GT I", "GT1"]
const INTERNAL_PRESENTATION_REPLACEMENTS := [
	["0 puntos GT I", "0 puntos del Torneo de Marte"],
	["puntos GT I", "puntos del Torneo de Marte"],
	["COMBAT V1", "COMBATE"],
	["Combat V1", "combate"],
	["CombatSimulator", "Sistema de combate"],
	["TournamentManager", "Arena"],
	["Save v14", "partida guardada"],
]


func _ready() -> void:
	super._ready()
	_apply_player_facing_tournament_names()
	visibility_changed.connect(_apply_player_facing_tournament_names)


func _refresh_all() -> void:
	super._refresh_all()
	_apply_player_facing_tournament_names()


func _refresh_combat_controls() -> void:
	super._refresh_combat_controls()
	_apply_player_facing_tournament_names()


func _render_encounter_finished() -> void:
	super._render_encounter_finished()
	_apply_player_facing_tournament_names()


func _render_error(result: Dictionary) -> void:
	super._render_error(result)
	_apply_player_facing_tournament_names()


func _apply_player_facing_tournament_names() -> void:
	_sanitize_node(self)


func _sanitize_node(node: Node) -> void:
	if node is Label:
		(node as Label).text = _sanitize_text((node as Label).text)
	elif node is RichTextLabel:
		(node as RichTextLabel).text = _sanitize_text((node as RichTextLabel).text)
	elif node is BaseButton:
		(node as BaseButton).text = _sanitize_text((node as BaseButton).text)

	if node is Control:
		var control := node as Control
		control.tooltip_text = _sanitize_text(control.tooltip_text)

	if node is OptionButton:
		var option_button := node as OptionButton
		for index in range(option_button.item_count):
			option_button.set_item_text(index, _sanitize_text(option_button.get_item_text(index)))

	for child in node.get_children():
		_sanitize_node(child)


func _sanitize_text(value: String) -> String:
	var sanitized := value
	for replacement in INTERNAL_PRESENTATION_REPLACEMENTS:
		sanitized = sanitized.replace(str(replacement[0]), str(replacement[1]))
	for internal_label in INTERNAL_TOURNAMENT_LABELS:
		sanitized = sanitized.replace(str(internal_label), TOURNAMENT_DISPLAY_NAME)
	return sanitized
