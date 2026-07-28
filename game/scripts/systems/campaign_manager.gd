extends Node

signal campaign_changed
signal rank_promoted(rank_id: String)
signal objective_completed(objective: Dictionary)
signal campaign_finished(victory: bool, reason: String)

const RANKS := [
    {"id":"unknown","name":"Ludus desconocido","reputation":0,"wins":0,"wealth":0,"unlock":"Duelo local"},
    {"id":"recognized","name":"Casa reconocida","reputation":10,"wins":3,"wealth":300,"unlock":"Juegos del Foro"},
    {"id":"provincial","name":"Potencia provincial","reputation":25,"wins":8,"wealth":700,"unlock":"Copa Provincial"},
    {"id":"renowned","name":"Ludus célebre","reputation":45,"wins":15,"wealth":1400,"unlock":"Patrocinio imperial"},
    {"id":"imperial","name":"Ludus imperial","reputation":70,"wins":25,"wealth":2500,"unlock":"Prueba Imperial"}
]

const OBJECTIVES := [
    {"id":"first_victories","title":"Primeras victorias","description":"Ganá 3 combates.","type":"wins","target":3,"reward_denarii":120,"reward_reputation":3},
    {"id":"trained_roster","title":"Escuela de gladiadores","description":"Tené 3 gladiadores formados.","type":"gladiators","target":3,"reward_denarii":180,"reward_reputation":4},
    {"id":"stable_estate","title":"Finca consolidada","description":"Alcanzá 10 niveles totales de instalaciones.","type":"building_levels","target":10,"reward_denarii":250,"reward_reputation":5},
    {"id":"provincial_glory","title":"Gloria provincial","description":"Ganá 12 combates.","type":"wins","target":12,"reward_denarii":450,"reward_reputation":8},
    {"id":"imperial_legacy","title":"Legado imperial","description":"Alcanzá 70 de reputación y 25 victorias.","type":"legacy","target":1,"reward_denarii":1000,"reward_reputation":15}
]

var current_rank_index: int = 0
var total_wins: int = 0
var total_losses: int = 0
var completed_objectives: Array[String] = []
var campaign_over: bool = false
var victory_achieved: bool = false
var defeat_reason: String = ""

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.day_advanced.connect(_on_day_advanced)
    evaluate_progress()

func _on_combat_finished(result: Dictionary) -> void:
    if bool(result.get("victory", false)):
        total_wins += 1
    else:
        total_losses += 1
    evaluate_progress()

func _on_day_advanced(_day: int) -> void:
    evaluate_progress()
    _evaluate_defeat()

func evaluate_progress() -> void:
    if campaign_over:
        return
    _evaluate_rank()
    _evaluate_objectives()
    if current_rank_index >= RANKS.size() - 1 and total_wins >= 25 and GameState.reputation >= 70:
        campaign_over = true
        victory_achieved = true
        campaign_finished.emit(true, "El ludus alcanzó prestigio imperial y aseguró su legado.")
    campaign_changed.emit()

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
        "wins": return total_wins
        "gladiators":
            var count := 0
            for person in RosterManager.get_people():
                if person.role == "gladiator": count += 1
            return count
        "building_levels":
            var total := 0
            for building_id in EstateManager.get_building_ids():
                total += EstateManager.get_level(building_id)
            return total
        "legacy":
            return 1 if GameState.reputation >= 70 and total_wins >= 25 else 0
        _: return 0

func _evaluate_defeat() -> void:
    if campaign_over:
        return
    if EconomyManager.get_bankruptcy_level() >= 3 and EconomyManager.insolvency_days >= 10:
        _set_defeat("Los acreedores liquidaron el ludus tras una insolvencia prolongada.")
    elif RosterManager.get_people().is_empty():
        _set_defeat("El ludus se quedó sin personal.")
    elif GameState.day >= 180 and current_rank_index < 2:
        _set_defeat("La casa no logró consolidarse antes de perder el apoyo regional.")

func _set_defeat(reason: String) -> void:
    campaign_over = true
    victory_achieved = false
    defeat_reason = reason
    campaign_finished.emit(false, reason)
    campaign_changed.emit()

func get_current_rank() -> Dictionary:
    return RANKS[current_rank_index].duplicate(true)

func get_next_rank() -> Dictionary:
    if current_rank_index + 1 >= RANKS.size(): return {}
    return RANKS[current_rank_index + 1].duplicate(true)

func get_objectives() -> Array:
    var result: Array = []
    for objective in OBJECTIVES:
        var data: Dictionary = objective.duplicate(true)
        data["progress"] = _objective_progress(objective)
        data["completed"] = completed_objectives.has(str(objective.get("id", "")))
        result.append(data)
    return result

func get_summary() -> Dictionary:
    return {"rank":get_current_rank(),"next_rank":get_next_rank(),"wins":total_wins,"losses":total_losses,"campaign_over":campaign_over,"victory":victory_achieved,"defeat_reason":defeat_reason}

func export_state() -> Dictionary:
    return {"rank_index":current_rank_index,"wins":total_wins,"losses":total_losses,"completed_objectives":completed_objectives.duplicate(),"campaign_over":campaign_over,"victory":victory_achieved,"defeat_reason":defeat_reason}

func import_state(data: Dictionary) -> void:
    current_rank_index = clampi(int(data.get("rank_index", 0)), 0, RANKS.size() - 1)
    total_wins = maxi(0, int(data.get("wins", 0)))
    total_losses = maxi(0, int(data.get("losses", 0)))
    completed_objectives.assign(data.get("completed_objectives", []))
    campaign_over = bool(data.get("campaign_over", false))
    victory_achieved = bool(data.get("victory", false))
    defeat_reason = str(data.get("defeat_reason", ""))
    campaign_changed.emit()