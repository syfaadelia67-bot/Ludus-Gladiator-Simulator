class_name HudStatusSnapshot
extends RefCounted

const DEFAULT_DAILY_FOOD_PER_PERSON: int = 1
const LOW_FOOD_DAYS: int = 5
const CRITICAL_FOOD_DAYS: int = 2

static func build(
        game_state: Dictionary,
        roster_state: Dictionary = {},
        economy_state: Dictionary = {},
        tournament_state: Dictionary = {}
) -> Dictionary:
    var people_count: int = maxi(0, int(roster_state.get("people_count", 0)))
    var food: int = maxi(0, int(game_state.get("food", 0)))
    var daily_food: int = maxi(
        1,
        int(roster_state.get("daily_food_consumption", people_count * DEFAULT_DAILY_FOOD_PER_PERSON))
    )
    var food_days: int = int(floor(float(food) / float(daily_food)))
    var active_gladiators: int = maxi(0, int(roster_state.get("active_gladiators", 0)))
    var gladiator_capacity: int = maxi(active_gladiators, int(roster_state.get("gladiator_capacity", active_gladiators)))
    var next_combat_days: int = int(tournament_state.get("next_combat_days", -1))

    return {
        "day": maxi(1, int(game_state.get("day", 1))),
        "denarii": maxi(0, int(game_state.get("denarii", 0))),
        "food": food,
        "food_days": food_days,
        "ore": maxi(0, int(game_state.get("ore", 0))),
        "reputation": int(game_state.get("reputation", 0)),
        "security": maxi(0, int(roster_state.get("security", 0))),
        "intelligence": maxi(0, int(roster_state.get("intelligence", 0))),
        "debt": maxi(0, int(economy_state.get("total_debt", 0))),
        "active_gladiators": active_gladiators,
        "gladiator_capacity": gladiator_capacity,
        "next_combat_days": next_combat_days,
        "alerts": _build_alerts(food_days, active_gladiators, gladiator_capacity, economy_state, tournament_state)
    }

static func _build_alerts(
        food_days: int,
        active_gladiators: int,
        gladiator_capacity: int,
        economy_state: Dictionary,
        tournament_state: Dictionary
) -> Array[Dictionary]:
    var alerts: Array[Dictionary] = []

    if food_days <= CRITICAL_FOOD_DAYS:
        alerts.append({
            "id": "food_critical",
            "severity": "critical",
            "title": "Comida crítica",
            "detail": "Quedan aproximadamente %d días de alimento." % food_days,
            "action": "estate"
        })
    elif food_days <= LOW_FOOD_DAYS:
        alerts.append({
            "id": "food_low",
            "severity": "warning",
            "title": "Comida baja",
            "detail": "Quedan aproximadamente %d días de alimento." % food_days,
            "action": "estate"
        })

    if gladiator_capacity > 0 and active_gladiators >= gladiator_capacity:
        alerts.append({
            "id": "gladiator_capacity",
            "severity": "warning",
            "title": "Barracones completos",
            "detail": "%d de %d plazas ocupadas." % [active_gladiators, gladiator_capacity],
            "action": "estate"
        })

    var total_debt: int = maxi(0, int(economy_state.get("total_debt", 0)))
    if total_debt > 0:
        alerts.append({
            "id": "outstanding_debt",
            "severity": "warning",
            "title": "Deuda pendiente",
            "detail": "%d denarios adeudados." % total_debt,
            "action": "economy"
        })

    var next_combat_days: int = int(tournament_state.get("next_combat_days", -1))
    if next_combat_days >= 0 and next_combat_days <= 1:
        alerts.append({
            "id": "combat_imminent",
            "severity": "info",
            "title": "Combate inminente",
            "detail": "El próximo combate es %s." % ("hoy" if next_combat_days == 0 else "mañana"),
            "action": "arena"
        })

    return alerts
