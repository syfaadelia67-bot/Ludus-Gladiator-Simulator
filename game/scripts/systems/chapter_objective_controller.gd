extends Node

signal chapter_objectives_changed

const PRIMARY_BY_CHAPTER := {
	"ruins": "first_victory",
	"blood_reputation": "three_victories",
	"name_of_ludus": "demo_finale",
}


func _ready() -> void:
	CampaignManager.campaign_changed.connect(func(): chapter_objectives_changed.emit())
	if CampaignManager.has_signal("objective_failed"):
		CampaignManager.objective_failed.connect(
			func(_objective: Dictionary): chapter_objectives_changed.emit()
		)
	GameState.month_advanced.connect(func(_month: int): chapter_objectives_changed.emit())
	EstateManager.estate_changed.connect(func(): chapter_objectives_changed.emit())
	RosterManager.roster_changed.connect(func(): chapter_objectives_changed.emit())
	if TournamentManager.has_signal("grand_tournament_changed"):
		TournamentManager.grand_tournament_changed.connect(
			func(_summary: Dictionary): chapter_objectives_changed.emit()
		)


func get_current_overview() -> Dictionary:
	var chapter := CampaignManager.get_current_chapter()
	var objectives: Array = []
	var chapter_id := str(chapter.get("id", ""))
	var end_month := int(chapter.get("month_end", GameState.get_month()))
	for raw in CampaignManager.get_current_chapter_objectives():
		var objective: Dictionary = raw.duplicate(true)
		var objective_id := str(objective.get("id", ""))
		objective["primary"] = objective_id == str(PRIMARY_BY_CHAPTER.get(chapter_id, ""))
		objective["deadline_month"] = int(objective.get("deadline_month", end_month))
		objective["months_remaining"] = int(
			objective.get("months_remaining", maxi(0, end_month - GameState.get_month() + 1))
		)
		objective["failed"] = bool(objective.get("failed", false))
		objective["status"] = _status_for(objective)
		# Save/UI compatibility aliases only.
		objective["deadline_week"] = objective["deadline_month"]
		objective["weeks_remaining"] = objective["months_remaining"]
		objectives.append(objective)
	return {
		"chapter": chapter,
		"objectives": objectives,
		"month": GameState.get_month(),
		"deadline_month": end_month,
		"months_remaining": maxi(0, end_month - GameState.get_month() + 1),
		"milestones": get_calendar_milestones(),
		# Save/UI compatibility aliases only.
		"week": GameState.get_month(),
		"deadline_week": end_month,
		"weeks_remaining": maxi(0, end_month - GameState.get_month() + 1),
	}


func get_calendar_milestones() -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []
	for chapter in CampaignManager.CHAPTERS:
		(
			milestones
			. append(
				{
					"month": int(chapter.get("month_start", 1)),
					"type": "chapter_start",
					"label": "Inicio: %s" % str(chapter.get("name", "Capítulo")),
					"chapter_id": str(chapter.get("id", "")),
				}
			)
		)
		(
			milestones
			. append(
				{
					"month": int(chapter.get("month_end", 1)),
					"type": "chapter_deadline",
					"label": "Cierre: %s" % str(chapter.get("name", "Capítulo")),
					"chapter_id": str(chapter.get("id", "")),
				}
			)
		)
	for month in TournamentManager.GT1_ENCOUNTER_MONTHS:
		var encounter := TournamentManager.get_gt1_encounter(month)
		(
			milestones
			. append(
				{
					"month": month,
					"type": "gt1_encounter",
					"label":
					(
						"%s · Encuentro %d"
						% [
							str(encounter.get("tournament_name", "Gran Torneo de Roma")),
							int(encounter.get("encounter", 0)),
						]
					),
					"chapter_id": "name_of_ludus",
				}
			)
		)
	for milestone in milestones:
		milestone["week"] = int(milestone.get("month", 1))
	return milestones


func get_month_markers(month: int) -> Array[String]:
	var result: Array[String] = []
	for milestone in get_calendar_milestones():
		if int(milestone.get("month", 0)) == month:
			result.append(str(milestone.get("label", "Hito")))
	return result


func get_week_markers(week: int) -> Array[String]:
	# Compatibility alias only. A legacy week index is the canonical campaign month.
	return get_month_markers(week)


func _status_for(objective: Dictionary) -> String:
	if bool(objective.get("design_blocked", false)):
		return "bloqueado_diseno"
	if bool(objective.get("completed", false)):
		return "completado"
	if bool(objective.get("failed", false)):
		return "fallido"
	var progress := int(objective.get("progress", 0))
	var target := maxi(1, int(objective.get("target", 1)))
	return (
		"en_riesgo"
		if int(objective.get("months_remaining", 0)) <= 1 and progress < target
		else "en_progreso"
	)
