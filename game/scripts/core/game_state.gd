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
    report["rival_events"] = rival_events
    day += 1
    food = maxi(0, food - maxi(1, RosterManager.people.size()))
    ore += int(report.get("ore", 0))
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
    return "Día: %d | Denarios: %d | Comida: %d | Mineral: %d | Reputación: %d | Seguridad: %d | Intel: %d" % [
        day,
        denarii,
        food,
        ore,
        reputation,
        RosterManager.security_score,
        RosterManager.intelligence_points
    ]