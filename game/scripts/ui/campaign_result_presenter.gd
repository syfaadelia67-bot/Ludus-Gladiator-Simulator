extends Node

const MAIN_SCENE_NAME := "Main"

var overlay: ColorRect
var card: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CampaignManager.campaign_finished.connect(_on_campaign_finished)
	SaveManager.load_completed.connect(
		func(_path: String): call_deferred("_show_loaded_result_if_needed")
	)


func _show_loaded_result_if_needed() -> void:
	var summary := CampaignManager.get_summary()
	if bool(summary.get("campaign_over", false)):
		_show_result(bool(summary.get("victory", false)), str(summary.get("defeat_reason", "")))


func _on_campaign_finished(victory: bool, reason: String) -> void:
	SaveManager.call_deferred("save_game")
	call_deferred("_show_result", victory, reason)


func _show_result(victory: bool, reason: String) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.name != MAIN_SCENE_NAME:
		return
	_ensure_overlay(scene)
	_clear_card()
	var summary := CampaignManager.get_summary()
	var owner := LudusOwnerManager.get_profile()
	var rank: Dictionary = summary.get("rank", {})
	var finale: Dictionary = summary.get("finale", {})

	card.add_child(
		_make_label(
			_t("CAMPAIGN_RESULT_TITLE_VICTORY") if victory else _t("CAMPAIGN_RESULT_TITLE_FINISHED"),
			34,
		)
	)
	card.add_child(
		_make_label(
			"%s %s"
			% [LudusOwnerManager.get_title_label(), str(owner.get("display_name", ""))],
			20,
		)
	)

	var details := RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.custom_minimum_size = Vector2(0, 270)
	details.text = _build_result_details(summary, rank, finale, reason)
	card.add_child(details)

	var read_only_button := Button.new()
	read_only_button.text = _t("CAMPAIGN_RESULT_READ_ONLY_BUTTON")
	read_only_button.custom_minimum_size = Vector2(0, 48)
	read_only_button.pressed.connect(_enter_read_only)
	card.add_child(read_only_button)

	var menu_button := Button.new()
	menu_button.text = _t("CAMPAIGN_RESULT_RETURN_MENU_BUTTON")
	menu_button.custom_minimum_size = Vector2(0, 48)
	menu_button.pressed.connect(_return_to_title)
	card.add_child(menu_button)
	overlay.visible = true


func _build_result_details(
	summary: Dictionary, rank: Dictionary, finale: Dictionary, reason: String
) -> String:
	var text := _t(
		"CAMPAIGN_RESULT_DETAILS",
		{
			"month": GameState.get_month(),
			"final_month": int(summary.get("final_month", CampaignManager.DEMO_FINAL_MONTH)),
			"wins": int(summary.get("wins", 0)),
			"losses": int(summary.get("losses", 0)),
			"rank": str(rank.get("name", "Ludus desconocido")),
			"reputation": GameState.reputation,
			"denarii": GameState.denarii,
			"objectives": CampaignManager.completed_objectives.size(),
			"objective_total": CampaignManager.OBJECTIVES.size(),
		},
	)
	if (
		bool(summary.get("final_combat_resolved", false))
		and bool(finale.get("classification_valid", false))
	):
		var gt_summary: Dictionary = summary.get("grand_tournament", {})
		text += "\n\n" + _t(
			"CAMPAIGN_RESULT_GT1",
			{
				"placement": int(finale.get("placement", 0)),
				"medal": _medal_label(str(finale.get("medal", ""))),
				"points": int(gt_summary.get("player_points", 0)),
				"bouts": int(gt_summary.get("player_bouts", 0)),
			},
		)
	if not reason.strip_edges().is_empty():
		text += "\n\n" + reason.strip_edges()
	return text


func _medal_label(medal: String) -> String:
	match medal:
		"gold":
			return _t("GT1_MEDAL_GOLD")
		"silver":
			return _t("GT1_MEDAL_SILVER")
		"bronze":
			return _t("GT1_MEDAL_BRONZE")
		_:
			return _t("GT1_MEDAL_NONE")


func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.translate_key(key, values)


func _ensure_overlay(scene: Node) -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	overlay = ColorRect.new()
	overlay.name = "CampaignResultScreen"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.03, 0.025, 0.02, 0.97)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	scene.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 540)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 16)
	margin.add_child(card)


func _clear_card() -> void:
	for child in card.get_children():
		child.queue_free()


func _make_label(text_value: String, size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


func _enter_read_only() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false


func _return_to_title() -> void:
	if not SaveManager.save_game():
		return
	overlay.visible = false
	StartScreenController.show_main_menu()
