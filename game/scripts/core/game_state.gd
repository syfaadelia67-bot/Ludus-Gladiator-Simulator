extends Node

signal day_advanced(day: int)
signal daily_report(report: Dictionary)
signal week_advanced(week: int)
signal weekly_report(report: Dictionary)
signal resources_changed
signal campaign_action_blocked(reason: String)

const DAYS_PER_WEEK := 7

# Compatibility note: this legacy field is now the visible campaign week index.
# Keeping the serialized key avoids invalidating existing saves.
var day: int = 1
var denarii: int = 500
var food: int = 100
var ore: int = 20
var reputation: int = 0

func get_week() -> int:
    return maxi(1, day)

func advance_week() -> void:
    if CampaignManager.campaign_over:
        campaign_action_blocked.emit("La campaña terminó. La partida permanece disponible en modo de consulta.")
        return
    var report := {
        "ore":0,
        "food":0,
        "security":0,
        "intel":0,
        "training":0,
        "promotions":[],
        "daily_results":[]
    }

    # The player advances one week, while roster recovery, fatigue and jobs
    # retain seven internal daily simulation ticks.
    for _internal_day in range(DAYS_PER_WEEK):
        var daily: Dictionary = RosterManager.process_day()
        report["daily_results"].append(daily)
        for key in ["ore", "food", "security", "intel", "training"]:
            report[key] = int(report.get(key, 0)) + int(daily.get(key, 0))
        for promoted_name in daily.get("promotions", []):
            if not report["promotions"].has(promoted_name):
                report["promotions"].append(promoted_name)

    var rival_events: Array = RivalManager.process_day()
    var economy_report: Dictionary = EconomyManager.process_week()
    var tournament_events: Array = TournamentManager.process_week()
    report["rival_events"] = rival_events
    report["economy"] = economy_report
    report["tournament_events"] = tournament_events

    day += 1

    # One unresolved narrative decision may persist, otherwise the new week
    # receives one guaranteed chapter-appropriate event.
    var narrative_event: Dictionary = EventManager.process_week()
    report["narrative_event"] = narrative_event

    var base_consumption := maxi(1, RosterManager.people.size())
    var weekly_consumption := maxi(1, int(ceil(float(base_consumption * DAYS_PER_WEEK) * EventManager.get_food_consumption_multiplier())))
    food = maxi(0, food - weekly_consumption)
    ore += int(report.get("ore", 0))
    report["food_consumed"] = weekly_consumption
    report["week"] = get_week()
    report["fight"] = CombatManager.get_current_event_details()
    report["chapter"] = CampaignManager.get_chapter_for_week(get_week())

    week_advanced.emit(get_week())
    weekly_report.emit(report)
    # Legacy signals remain active until every dependent system is migrated.
    day_advanced.emit(day)
    daily_report.emit(report)
    resources_changed.emit()

func advance_day() -> void:
    advance_week()

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
    return "Semana: %d | Denarios: %d | Comida: %d | Mineral: %d | Reputación: %d | Seguridad: %d | Intel: %d | Deuda: %d | Combates: %d" % [
        get_week(), denarii, food, ore, reputation,
        RosterManager.security_score,
        RosterManager.intelligence_points,
        int(economy.get("total_debt", 0)),
        TournamentManager.active_contracts.size()
    ]
