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
	["recover", "Recuperar"],
]

var _arena_ai_provider = ArenaLimboAIRequestProviderScript.new()


func _ready() -> void:
	super._ready()
	set_ai_request_provider(Callable(self, "_build_default_ai_requests"))
	_apply_player_facing_tournament_names()
	visibility_changed.connect(_apply_player_facing_tournament_names)


func _accept_started_session(result: Dictionary) -> Dictionary:
	var accepted := super._accept_started_session(result)
	if str(accepted.get("status", "")) != "combat_running":
		return accepted
	return _resolve_current_autobattle()


func _resolve_current_autobattle() -> Dictionary:
	var final_session: Dictionary = _arena_runtime.resolve_autobattle(
		_session, Callable(self, "_build_default_ai_requests")
	)
	if str(final_session.get("status", "")) == "rejected":
		_render_error(final_session)
		return final_session

	var persisted := false
	if str(final_session.get("session_kind", "")) == "monthly_non_gt":
		persisted = CombatV1SessionStore.set_non_gt_session(final_session)
	else:
		persisted = CombatV1SessionStore.set_gt1_session(final_session)
	if not persisted:
		var persistence_error := _ui_rejected(
			"session_persistence_rejected",
			["El resultado automático no superó el contrato de persistencia Save v14."],
		)
		_render_error(persistence_error)
		return persistence_error

	_session = final_session.duplicate(true)
	_refresh_all()
	if str(_session.get("status", "")) == "encounter_finished":
		_render_encounter_finished()
		_show_result_view()
	return _session.duplicate(true)


func _refresh_all() -> void:
	super._refresh_all()
	_apply_player_facing_tournament_names()


func _refresh_combat_controls() -> void:
	super._refresh_combat_controls()
	action_selector.visible = false
	target_selector.visible = false
	start_button.visible = false
	_apply_player_facing_tournament_names()


func _render_encounter_finished() -> void:
	super._render_encounter_finished()
	_apply_player_facing_tournament_names()


func _render_error(result: Dictionary) -> void:
	super._render_error(result)
	_apply_player_facing_tournament_names()


func _build_default_ai_requests(session: Dictionary) -> Dictionary:
	return _arena_ai_provider.build_requests(session, self, self)


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
