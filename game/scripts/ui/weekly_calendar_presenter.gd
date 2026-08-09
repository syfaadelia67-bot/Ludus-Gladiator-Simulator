extends Node

const DEMO_FINAL_MONTH := 20


func _ready() -> void:
	call_deferred("_attach")
	GameState.month_advanced.connect(func(_month: int): call_deferred("_refresh"))
	CampaignManager.campaign_changed.connect(func(): call_deferred("_refresh"))
	TournamentManager.calendar_changed.connect(func(): call_deferred("_refresh"))


func _attach() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var tabs := root.find_child("Tabs", true, false) as TabContainer
	if tabs == null:
		return
	var panel := tabs.get_node_or_null("Campaña") as VBoxContainer
	if panel == null:
		return
	var existing := panel.get_node_or_null("MonthlyCalendar") as RichTextLabel
	if existing != null:
		_refresh()
		return
	var legacy := panel.get_node_or_null("WeeklyCalendar")
	if legacy != null:
		legacy.queue_free()
	var calendar := RichTextLabel.new()
	calendar.name = "MonthlyCalendar"
	calendar.bbcode_enabled = true
	calendar.fit_content = true
	calendar.custom_minimum_size = Vector2(0, 285)
	panel.add_child(calendar)
	panel.move_child(calendar, 0)
	_refresh()


func _refresh() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var calendar := root.find_child("MonthlyCalendar", true, false) as RichTextLabel
	if calendar == null:
		return

	var chapter: Dictionary = CampaignManager.get_current_chapter()
	var lines: Array[String] = [
		"[b]CAPÍTULO %d — %s[/b]"
		% [int(chapter.get("number", 1)), chapter.get("name", "Campaña")],
		str(chapter.get("description", "")),
		"[b]Objetivos del capítulo[/b]",
	]
	for objective in CampaignManager.get_current_chapter_objectives():
		var completed := bool(objective.get("completed", false))
		var marker := "✓" if completed else "•"
		lines.append(
			"%s %s — %d/%d"
			% [
				marker,
				objective.get("title", "Objetivo"),
				int(objective.get("progress", 0)),
				int(objective.get("target", 1)),
			]
		)

	lines.append("[b]CALENDARIO MENSUAL[/b]")
	var current_month := GameState.get_month()
	for offset in range(4):
		var month := current_month + offset
		if month > DEMO_FINAL_MONTH:
			break
		var current_marker := "→ " if offset == 0 else ""
		if TournamentManager.is_grand_tournament_month(month):
			var encounter := TournamentManager.get_gt1_encounter(month)
			lines.append(
				"%sMes %d — %s · %s"
				% [
					current_marker,
					month,
					str(encounter.get("tournament_name", "Gran Torneo de Roma")),
					str(encounter.get("format", "Arena")),
				]
			)
		else:
			lines.append("%sMes %d — Gestión del ludus" % [current_marker, month])
	if current_month > DEMO_FINAL_MONTH:
		lines.append("Demo completada.")
	calendar.text = "\n".join(lines)
