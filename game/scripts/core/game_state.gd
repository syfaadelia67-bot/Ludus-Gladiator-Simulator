extends Node

signal day_advanced(day: int)
signal resources_changed

var day: int = 1
var denarii: int = 500
var food: int = 100
var ore: int = 20
var reputation: int = 0

func advance_day() -> void:
    day += 1
    food = maxi(0, food - 5)
    ore += 2
    day_advanced.emit(day)
    resources_changed.emit()

func get_resource_summary() -> String:
    return "Día: %d | Denarios: %d | Comida: %d | Mineral: %d | Reputación: %d" % [
        day, denarii, food, ore, reputation
    ]
