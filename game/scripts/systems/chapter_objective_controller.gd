extends Node

signal chapter_objectives_changed

const PRIMARY_BY_CHAPTER := {
    "ruins":"first_victory",
    "blood_reputation":"three_victories",
    "name_of_ludus":"demo_finale"
}

func _ready() -> void:
    CampaignManager.campaign_changed.connect(func(): chapter_objectives_changed.emit())
    GameState.week_advanced.connect(func(_week: int): chapter_objectives_changed.emit())
    EstateManager.estate_changed.connect(func(): chapter_objectives_changed.emit())
    RosterManager.roster_changed.connect(func(): chapter_objectives_changed.emit())

func get_current_overview() -> Dictionary:
    var chapter := CampaignManager.get_current_chapter()
    var objectives: Array = []
    var chapter_id := str(chapter.get("id", ""))
    var end_week := int(chapter.get("week_end", GameState.get_week()))
    for raw in CampaignManager.get_current_chapter_objectives():
        var objective: Dictionary = raw.duplicate(true)
        var objective_id := str(objective.get("id", ""))
        objective["primary"] = objective_id == str(PRIMARY_BY_CHAPTER.get(chapter_id, ""))
        objective["deadline_week"] = end_week
        objective["weeks_remaining"] = maxi(0, end_week - GameState.get_week() + 1)
        objective["failed"] = GameState.get_week() > end_week and not bool(objective.get("completed", false))
        objective["status"] = _status_for(objective)
        objectives.append(objective)
    return {
        "chapter": chapter,
        "objectives": objectives,
        "week": GameState.get_week(),
        "deadline_week": end_week,
        "weeks_remaining": maxi(0, end_week - GameState.get_week() + 1),
        "milestones": get_calendar_milestones()
    }

func get_calendar_milestones() -> Array[Dictionary]:
    var milestones: Array[Dictionary] = []
    for chapter in CampaignManager.CHAPTERS:
        milestones.append({
            "week": int(chapter.get("week_start", 1)),
            "type":"chapter_start",
            "label":"Inicio: %s" % str(chapter.get("name", "Capítulo")),
            "chapter_id":str(chapter.get("id", ""))
        })
        milestones.append({
            "week": int(chapter.get("week_end", 1)),
            "type":"chapter_deadline",
            "label":"Cierre: %s" % str(chapter.get("name", "Capítulo")),
            "chapter_id":str(chapter.get("id", ""))
        })
    milestones.append({"week":CampaignManager.DEMO_FINAL_WEEK,"type":"finale","label":"Combate final de la demo","chapter_id":"name_of_ludus"})
    return milestones

func get_week_markers(week: int) -> Array[String]:
    var result: Array[String] = []
    for milestone in get_calendar_milestones():
        if int(milestone.get("week", 0)) == week:
            result.append(str(milestone.get("label", "Hito")))
    var event_name := CombatManager.get_event_name_for_week(week)
    if not event_name.is_empty():
        result.append(event_name)
    return result

func _status_for(objective: Dictionary) -> String:
    if bool(objective.get("completed", false)):
        return "completado"
    if bool(objective.get("failed", false)):
        return "fallido"
    var progress := int(objective.get("progress", 0))
    var target := maxi(1, int(objective.get("target", 1)))
    return "en_riesgo" if int(objective.get("weeks_remaining", 0)) <= 1 and progress < target else "en_progreso"
