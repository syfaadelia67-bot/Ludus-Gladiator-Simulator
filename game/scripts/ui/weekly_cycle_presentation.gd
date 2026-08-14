extends Node

const MAX_BIND_ATTEMPTS := 30

var advance_button: Button
var activity_log: RichTextLabel


func _ready() -> void:
	GameState.month_advanced.connect(_on_month_advanced)
	call_deferred("_bind")


func _bind() -> void:
	for _attempt in range(MAX_BIND_ATTEMPTS):
		await get_tree().process_frame
		var root := get_tree().current_scene
		if root == null:
			continue
		advance_button = root.get_node_or_null("Margin/VBox/TopButtons/AdvanceDay") as Button
		activity_log = root.get_node_or_null("Margin/VBox/Tabs/Personal/Log") as RichTextLabel
		if advance_button != null:
			advance_button.text = "Cerrar mes"
			advance_button.tooltip_text = (
				"Procesa trabajos, economía, recuperación y consecuencias; "
				+ "luego abre el siguiente mes de campaña."
			)
			return


func _on_month_advanced(month: int) -> void:
	call_deferred("_normalize_month_log", month)


func _normalize_month_log(month: int) -> void:
	if activity_log == null:
		return
	# Compatibility cleanup for logs produced by older scenes or saves.
	activity_log.text = activity_log.text.replace("[b]Día %d[/b]" % month, "[b]Mes %d[/b]" % month)
	activity_log.text = activity_log.text.replace(
		"[b]Semana %d[/b]" % month, "[b]Mes %d[/b]" % month
	)
	var encounter := TournamentManager.get_gt1_encounter(month)
	if encounter.is_empty():
		activity_log.append_text("\n[color=gray]Mes de gestión del ludus.[/color]")
		return
	(
		activity_log
		. append_text(
			(
				"\n[color=gold]%s · %s.[/color]"
				% [
					str(encounter.get("tournament_name", "Gran Torneo de Roma")),
					str(encounter.get("format", "Arena")),
				]
			)
		)
	)
