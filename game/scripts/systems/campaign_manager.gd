extends Node

signal campaign_changed
signal rank_promoted(rank_id: String)
signal objective_completed(objective: Dictionary)
signal chapter_changed(chapter_id: String)
signal campaign_finished(victory: bool, reason: String)

const DEMO_FINAL_MONTH := 20
# Save/UI compatibility alias while weekly consumers are migrated.
const DEMO_FINAL_WEEK := DEMO_FINAL_MONTH
const LEGACY_DEMO_WIN_TARGET := 6

const CHAPTERS := [
	{
		"id": "ruins",
		"number": 1,
		"name": "Un ludus en ruinas",
		"month_start": 1,
		"month_end": 6,
		"week_start": 1,
		"week_end": 6,
		"description":
		"Estabilizá la casa, prepará a tu primer gladiador y sobreviví a los primeros meses.",
		"objectives": ["first_fight", "first_victory", "basic_preparation"],
	},
	{
		"id": "blood_reputation",
		"number": 2,
		"name": "Sangre y reputación",
		"month_start": 7,
		"month_end": 12,
		"week_start": 7,
		"week_end": 12,
		"description":
		"Convertí al ludus en una casa reconocida y construí una plantilla competitiva.",
		"objectives": ["three_victories", "recognized_house", "trained_roster"],
	},
	{
		"id": "name_of_ludus",
		"number": 3,
		"name": "El nombre del ludus",
		"month_start": 13,
		"month_end": 20,
		"week_start": 13,
		"week_end": 20,
		"description": "Prepará el primer Gran Torneo y cerrá la demo en el mes XX.",
		"objectives": ["six_victories", "provincial_house", "demo_finale"],
	},
]

const RANKS := [
	{
		"id": "unknown",
		"name": "Ludus desconocido",
		"reputation": 0,
		"wins": 0,
		"wealth": 0,
		"unlock": "Duelo local",
	},
	{
		"id": "recognized",
		"name": "Casa reconocida",
		"reputation": 10,
		"wins": 3,
		"wealth": 300,
		"unlock": "Juegos del Foro",
	},
	{
		"id": "provincial",
		"name": "Potencia provincial",
		"reputation": 25,
		"wins": 6,
		"wealth": 700,
		"unlock": "Copa Provincial",
	},
	{
		"id": "renowned",
		"name": "Ludus célebre",
		"reputation": 45,
		"wins": 12,
		"wealth": 1400,
		"unlock": "Patrocinio imperial",
	},
	{
		"id": "imperial",
		"name": "Ludus imperial",
		"reputation": 70,
		"wins": 25,
		"wealth": 2500,
		"unlock": "Prueba Imperial",
	},
]

const OBJECTIVES := [
	{
		"id": "first_fight",
		"chapter": "ruins",
		"title": "Entrar a la arena",
		"description": "Disputá el primer combate de la campaña.",
		"type": "fights",
		"target": 1,
		"reward_denarii": 60,
		"reward_reputation": 1,
	},
	{
		"id": "first_victory",
		"chapter": "ruins",
		"title": "Primera sangre",
		"description": "Ganá el primer combate.",
		"type": "wins",
		"target": 1,
		"reward_denarii": 100,
		"reward_reputation": 2,
	},
	{
		"id": "basic_preparation",
		"chapter": "ruins",
		"title": "Una casa preparada",
		"description": "Alcanzá 6 niveles totales de instalaciones.",
		"type": "building_levels",
		"target": 6,
		"reward_denarii": 120,
		"reward_reputation": 2,
	},
	{
		"id": "three_victories",
		"chapter": "blood_reputation",
		"title": "Primeras victorias",
		"description": "Ganá 3 combates.",
		"type": "wins",
		"target": 3,
		"reward_denarii": 160,
		"reward_reputation": 3,
	},
	{
		"id": "recognized_house",
		"chapter": "blood_reputation",
		"title": "Casa reconocida",
		"description": "Alcanzá 10 de reputación.",
		"type": "reputation",
		"target": 10,
		"reward_denarii": 180,
		"reward_reputation": 2,
	},
	{
		"id": "trained_roster",
		"chapter": "blood_reputation",
		"title": "Escuela de gladiadores",
		"description": "Tené 3 gladiadores formados.",
		"type": "gladiators",
		"target": 3,
		"reward_denarii": 220,
		"reward_reputation": 4,
	},
	{
		"id": "six_victories",
		"chapter": "name_of_ludus",
		"title": "Nombre en la arena",
		"description": "Ganá 6 combates durante la demo.",
		"type": "wins",
		"target": 6,
		"reward_denarii": 300,
		"reward_reputation": 5,
	},
	{
		"id": "provincial_house",
		"chapter": "name_of_ludus",
		"title": "Prestigio provincial",
		"description": "Alcanzá 25 de reputación.",
		"type": "reputation",
		"target": 25,
		"reward_denarii": 350,
		"reward_reputation": 5,
	},
	{
		"id": "demo_finale",
		"chapter": "name_of_ludus",
		"title": "Final de campaña",
		"description": "Resolvé el cierre competitivo del mes XX.",
		"type": "demo_finale",
		"target": 1,
		"reward_denarii": 500,
		"reward_reputation": 8,
	},
]

var current_rank_index: int = 0
var current_chapter_index: int = 0
var total_wins: int = 0
var total_losses: int = 0
var completed_objectives: Array[String] = []
var campaign_over: bool = false
var victory_achieved: bool = false
var defeat_reason: String = ""
var final_combat_resolved: bool = false


func _ready() -> void:
	CombatManager.combat_finished.connect(_on_combat_finished)
	GameState.month_advanced.connect(_on_month_advanced)
	evaluate_progress()


func _on_combat_finished(result: Dictionary) -> void:
	if bool(result.get("victory", false)):
		total_wins += 1
	else:
		total_losses += 1
	if GameState.get_month() >= DEMO_FINAL_MONTH:
		final_combat_resolved = true
	evaluate_progress()
	_evaluate_campaign_finale()


func _on_month_advanced(_month: int) -> void:
	evaluate_progress()
	_evaluate_defeat()


func evaluate_progress() -> void:
	if campaign_over:
		return
	_evaluate_chapter()
	_evaluate_rank()
	_evaluate_objectives()
	campaign_changed.emit()


func _evaluate_campaign_finale() -> void:
	if campaign_over or not final_combat_resolved or GameState.get_month() < DEMO_FINAL_MONTH:
		return

	# Compatibility bridge only. The next tournament migration replaces this
	# legacy six-win gate with GT I placement (Gold/Silver/Bronze/no medal).
	if total_wins >= LEGACY_DEMO_WIN_TARGET:
		campaign_over = true
		victory_achieved = true
		defeat_reason = ""
		campaign_finished.emit(
			true, "El ludus completó el cierre competitivo del mes XX de la demo."
		)
		campaign_changed.emit()
		return
	_set_defeat("La casa cerró el mes XX sin alcanzar el objetivo competitivo de transición.")


func _evaluate_chapter() -> void:
	var resolved_index := 0
	for index in range(CHAPTERS.size()):
		if GameState.get_month() >= int(CHAPTERS[index].get("month_start", 1)):
			resolved_index = index
	if resolved_index != current_chapter_index:
		current_chapter_index = resolved_index
		chapter_changed.emit(str(CHAPTERS[current_chapter_index].get("id", "chapter")))


func _evaluate_rank() -> void:
	var promoted := false
	while current_rank_index + 1 < RANKS.size():
		var next_rank: Dictionary = RANKS[current_rank_index + 1]
		if GameState.reputation < int(next_rank.get("reputation", 0)):
			break
		if total_wins < int(next_rank.get("wins", 0)):
			break
		if GameState.denarii < int(next_rank.get("wealth", 0)):
			break
		current_rank_index += 1
		promoted = true
		rank_promoted.emit(str(next_rank.get("id", "rank")))
	if promoted:
		GameState.reputation += 2
		GameState.resources_changed.emit()


func _evaluate_objectives() -> void:
	for objective in OBJECTIVES:
		var objective_id := str(objective.get("id", ""))
		if completed_objectives.has(objective_id):
			continue
		if _objective_progress(objective) < int(objective.get("target", 1)):
			continue
		completed_objectives.append(objective_id)
		GameState.denarii += int(objective.get("reward_denarii", 0))
		GameState.reputation += int(objective.get("reward_reputation", 0))
		objective_completed.emit(objective.duplicate(true))
		GameState.resources_changed.emit()


func _objective_progress(objective: Dictionary) -> int:
	match str(objective.get("type", "")):
		"fights":
			return total_wins + total_losses
		"wins":
			return total_wins
		"reputation":
			return GameState.reputation
		"gladiators":
			var count := 0
			for person in RosterManager.get_people():
				if person.role == "gladiator":
					count += 1
			return count
		"building_levels":
			var total := 0
			for building_id in EstateManager.get_building_ids():
				total += EstateManager.get_level(building_id)
			return total
		"demo_finale":
			return (
				1
				if (
					final_combat_resolved
					and GameState.get_month() >= DEMO_FINAL_MONTH
					and total_wins >= LEGACY_DEMO_WIN_TARGET
				)
				else 0
			)
		_:
			return 0


func _evaluate_defeat() -> void:
	if campaign_over:
		return
	if EconomyManager.get_bankruptcy_level() >= 3 and EconomyManager.insolvency_days >= 10:
		_set_defeat("Los acreedores liquidaron el ludus tras una insolvencia prolongada.")
	elif RosterManager.get_people().is_empty():
		_set_defeat("El ludus se quedó sin personal.")


func _set_defeat(reason: String) -> void:
	campaign_over = true
	victory_achieved = false
	defeat_reason = reason
	campaign_finished.emit(false, reason)
	campaign_changed.emit()


func get_current_chapter() -> Dictionary:
	return CHAPTERS[current_chapter_index].duplicate(true)


func get_chapter_for_month(month: int) -> Dictionary:
	var selected: Dictionary = CHAPTERS[0]
	for chapter in CHAPTERS:
		if month >= int(chapter.get("month_start", chapter.get("week_start", 1))):
			selected = chapter
	return selected.duplicate(true)


func get_chapter_for_week(week: int) -> Dictionary:
	# Compatibility alias: historical week indices map 1:1 to campaign months.
	return get_chapter_for_month(week)


func get_current_rank() -> Dictionary:
	return RANKS[current_rank_index].duplicate(true)


func get_next_rank() -> Dictionary:
	if current_rank_index + 1 >= RANKS.size():
		return {}
	return RANKS[current_rank_index + 1].duplicate(true)


func get_objectives(chapter_id: String = "") -> Array:
	var result: Array = []
	for objective in OBJECTIVES:
		if not chapter_id.is_empty() and str(objective.get("chapter", "")) != chapter_id:
			continue
		var data: Dictionary = objective.duplicate(true)
		data["progress"] = _objective_progress(objective)
		data["completed"] = completed_objectives.has(str(objective.get("id", "")))
		result.append(data)
	return result


func get_current_chapter_objectives() -> Array:
	return get_objectives(str(get_current_chapter().get("id", "")))


func get_summary() -> Dictionary:
	return {
		"chapter": get_current_chapter(),
		"rank": get_current_rank(),
		"next_rank": get_next_rank(),
		"wins": total_wins,
		"losses": total_losses,
		"campaign_over": campaign_over,
		"victory": victory_achieved,
		"defeat_reason": defeat_reason,
		"final_month": DEMO_FINAL_MONTH,
		# Compatibility alias for presenters/tests not migrated yet.
		"final_week": DEMO_FINAL_MONTH,
		"final_combat_resolved": final_combat_resolved,
	}


func export_state() -> Dictionary:
	return {
		"rank_index": current_rank_index,
		"chapter_index": current_chapter_index,
		"wins": total_wins,
		"losses": total_losses,
		"completed_objectives": completed_objectives.duplicate(),
		"campaign_over": campaign_over,
		"victory": victory_achieved,
		"defeat_reason": defeat_reason,
		"final_combat_resolved": final_combat_resolved,
	}


func import_state(data: Dictionary) -> void:
	current_rank_index = clampi(int(data.get("rank_index", 0)), 0, RANKS.size() - 1)
	current_chapter_index = clampi(int(data.get("chapter_index", 0)), 0, CHAPTERS.size() - 1)
	total_wins = maxi(0, int(data.get("wins", 0)))
	total_losses = maxi(0, int(data.get("losses", 0)))
	completed_objectives.assign(data.get("completed_objectives", []))
	campaign_over = bool(data.get("campaign_over", false))
	victory_achieved = bool(data.get("victory", false))
	defeat_reason = str(data.get("defeat_reason", ""))
	final_combat_resolved = bool(data.get("final_combat_resolved", false))
	_evaluate_chapter()
	campaign_changed.emit()
