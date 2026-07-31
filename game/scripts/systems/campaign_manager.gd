extends Node

signal campaign_changed
signal rank_promoted(rank_id: String)
signal objective_completed(objective: Dictionary)
signal chapter_changed(chapter_id: String)
signal campaign_finished(victory: bool, reason: String)

const DEMO_FINAL_WEEK := 16

const CHAPTERS := [
    {
        "id":"ruins",
        "number":1,
        "name":"Un ludus en ruinas",
        "week_start":1,
        "week_end":5,
        "description":"Estabilizá la casa, prepará a tu primer gladiador y sobreviví a las primeras semanas.",
        "objectives":["first_fight", "first_victory", "basic_preparation"]
    },
    {
        "id":"blood_reputation",
        "number":2,
        "name":"Sangre y reputación",
        "week_start":6,
        "week_end":11,
        "description":"Convertí al ludus en una casa reconocida y construí una plantilla competitiva.",
        "objectives":["three_victories", "recognized_house", "trained_roster"]
    },
    {
        "id":"name_of_ludus",
        "number":3,
        "name":"El nombre del ludus",
        "week_start":12,
        "week_end":16,
        "description":"Cerrá la demo derrotando a rivales de prestigio y consolidando el nombre de la casa.",
        "objectives":["six_victories", "provincial_house", "demo_finale"]
    }
]

const RANKS := [
    {"id":"unknown","name":"Ludus desconocido","reputation":0,"wins":0,"wealth":0,"unlock":"Duelo local"},
    {"id":"recognized","name":"Casa reconocida","reputation":10,"wins":3,"wealth":300,"unlock":"Juegos del Foro"},
    {"id":"provincial","name":"Potencia provincial","reputation":25,"wins":6,"wealth":700,"unlock":"Copa Provincial"},
    {"id":"renowned","name":"Ludus célebre","reputation":45,"wins":12,"wealth":1400,"unlock":"Patrocinio imperial"},
    {"id":"imperial","name":"Ludus imperial","reputation":70,"wins":25,"wealth":2500,"unlock":"Prueba Imperial"}
]

const OBJECTIVES := [
    {"id":"first_fight","chapter":"ruins","title":"Entrar a la arena","description":"Disputá el primer combate de la campaña.","type":"fights","target":1,"reward_denarii":60,"reward_reputation":1},
    {"id":"first_victory","chapter":"ruins","title":"Primera sangre","description":"Ganá el primer combate.","type":"wins","target":1,"reward_denarii":100,"reward_reputation":2},
    {"id":"basic_preparation","chapter":"ruins","title":"Una casa preparada","description":"Alcanzá 6 niveles totales de instalaciones.","type":"building_levels","target":6,"reward_denarii":120,"reward_reputation":2},
    {"id":"three_victories","chapter":"blood_reputation","title":"Primeras victorias","description":"Ganá 3 combates.","type":"wins","target":3,"reward_denarii":160,"reward_reputation":3},
    {"id":"recognized_house","chapter":"blood_reputation","title":"Casa reconocida","description":"Alcanzá 10 de reputación.","type":"reputation","target":10,"reward_denarii":180,"reward_reputation":2},
    {"id":"trained_roster","chapter":"blood_reputation","title":"Escuela de gladiadores","description":"Tené 3 gladiadores formados.","type":"gladiators","target":3,"reward_denarii":220,"reward_reputation":4},
    {"id":"six_victories","chapter":"name_of_ludus","title":"Nombre en la arena","description":"Ganá 6 combates durante la demo.","type":"wins","target":6,"reward_denarii":300,"reward_reputation":5},
    {"id":"provincial_house","chapter":"name_of_ludus","title":"Prestigio provincial","description":"Alcanzá 25 de reputación.","type":"reputation","target":25,"reward_denarii":350,"reward_reputation":5},
    {"id":"demo_finale","chapter":"name_of_ludus","title":"Final de campaña","description":"Llegá a la semana 16 con al menos 6 victorias.","type":"demo_finale","target":1,"reward_denarii":500,"reward_reputation":8}
]

var current_rank_index: int = 0
var current_chapter_index: int = 0
var total_wins: int = 0
var total_losses: int = 0
var completed_objectives: Array[String] = []
var campaign_over: bool = false
var victory_achieved: bool = false
var defeat_reason: String = ""

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.week_advanced.connect(_on_week_advanced)
    evaluate_progress()

func _on_combat_finished(result: Dictionary) -> void:
    if bool(result.get("victory", false)):
        total_wins += 1
    else:
        total_losses += 1
    evaluate_progress()

func _on_week_advanced(_week: int) -> void:
    evaluate_progress()
    _evaluate_defeat()

func evaluate_progress() -> void:
    if campaign_over:
        return
    _evaluate_chapter()
    _evaluate_rank()
    _evaluate_objectives()
    if GameState.get_week() >= DEMO_FINAL_WEEK and total_wins >= 6:
        campaign_over = true
        victory_achieved = true
        campaign_finished.emit(true, "El ludus completó la campaña de la demo y aseguró un lugar entre las casas provinciales.")
    campaign_changed.emit()

func _evaluate_chapter() -> void:
    var resolved_index := 0
    for index in range(CHAPTERS.size()):
        if GameState.get_week() >= int(CHAPTERS[index].get("week_start", 1)):
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
        "fights": return total_wins + total_losses
        "wins": return total_wins
        "reputation": return GameState.reputation
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
            return 1 if GameState.get_week() >= DEMO_FINAL_WEEK and total_wins >= 6 else 0
        _: return 0

func _evaluate_defeat() -> void:
    if campaign_over:
        return
    if EconomyManager.get_bankruptcy_level() >= 3 and EconomyManager.insolvency_days >= 10:
        _set_defeat("Los acreedores liquidaron el ludus tras una insolvencia prolongada.")
    elif RosterManager.get_people().is_empty():
        _set_defeat("El ludus se quedó sin personal.")
    elif GameState.get_week() > DEMO_FINAL_WEEK and total_wins < 6:
        _set_defeat("La casa llegó al final de la campaña sin las victorias necesarias para consolidarse.")

func _set_defeat(reason: String) -> void:
    campaign_over = true
    victory_achieved = false
    defeat_reason = reason
    campaign_finished.emit(false, reason)
    campaign_changed.emit()

func get_current_chapter() -> Dictionary:
    return CHAPTERS[current_chapter_index].duplicate(true)

func get_chapter_for_week(week: int) -> Dictionary:
    var selected: Dictionary = CHAPTERS[0]
    for chapter in CHAPTERS:
        if week >= int(chapter.get("week_start", 1)):
            selected = chapter
    return selected.duplicate(true)

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
        "chapter":get_current_chapter(),
        "rank":get_current_rank(),
        "next_rank":get_next_rank(),
        "wins":total_wins,
        "losses":total_losses,
        "campaign_over":campaign_over,
        "victory":victory_achieved,
        "defeat_reason":defeat_reason,
        "final_week":DEMO_FINAL_WEEK
    }

func export_state() -> Dictionary:
    return {
        "rank_index":current_rank_index,
        "chapter_index":current_chapter_index,
        "wins":total_wins,
        "losses":total_losses,
        "completed_objectives":completed_objectives.duplicate(),
        "campaign_over":campaign_over,
        "victory":victory_achieved,
        "defeat_reason":defeat_reason
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
    _evaluate_chapter()
    campaign_changed.emit()