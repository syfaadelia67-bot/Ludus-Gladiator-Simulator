extends Node

signal day_advanced(day: int)
signal resources_changed
signal daily_report(report: Dictionary)

var day: int = 1
var denarii: int = 500
var food: int = 100
var ore: int = 20
var reputation: int = 0

func advance_day() -> void:
    var report: Dictionary = RosterManager.process_day()
    var rival_events: Array = RivalManager.process_day()
    var narrative_event: Dictionary = EventManager.process_day()
    var economy_report: Dictionary = EconomyManager.process_day()
    var tournament_events: Array = TournamentManager.process_day()
    report["rival_events"] = rival_events
    report["narrative_event"] = narrative_event
    report["economy"] = economy_report
    report["tournament_events"] = tournament_events
    day += 1
    var base_consumption := maxi(1, RosterManager.people.size())
    var food_consumed := maxi(1, int(ceil(float(base_consumption) * EventManager.get_food_consumption_multiplier())))
    food = maxi(0, food - food_consumed)
    ore += int(report.get("ore", 0))
    report["food_consumed"] = food_consumed
    day_advanced.emit(day)
    resources_changed.emit()
    daily_report.emit(report)

func spend_denarii(amount: int) -> bool:
    if amount < 0 or denarii < amount:
        return false
    denarii -= amount
    resources_changed.emit()
    return true

func add_denarii(amount: int) -> void:
    denarii += maxi(0, amount)
    resources_changed.emit()

func get_resource_summary() -> String:
    var economy := EconomyManager.get_summary()
    return "Día: %d | Denarios: %d | Comida: %d | Mineral: %d | Reputación: %d | Seguridad: %d | Intel: %d | Deuda: %d | Combates: %d" % [
        day,
        denarii,
        food,
        ore,
        reputation,
        RosterManager.security_score,
        RosterManager.intelligence_points,
        int(economy.get("total_debt", 0)),
        TournamentManager.active_contracts.size()
    ]
