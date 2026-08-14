extends Node

signal month_advanced(month: int)
signal monthly_report(report: Dictionary)

# Save-v14 and migration compatibility signals. Their integer payload mirrors
# the canonical campaign month. They never trigger additional simulation ticks.
signal day_advanced(day: int)
signal daily_report(report: Dictionary)
signal week_advanced(week: int)
signal weekly_report(report: Dictionary)
signal resources_changed
signal campaign_action_blocked(reason: String)

const LEGACY_DAYS_PER_WEEK := 7
const DAYS_PER_WEEK := LEGACY_DAYS_PER_WEEK
const MonthlyTurnClosurePolicyScript = preload(
	"res://scripts/systems/monthly_turn_closure_policy.gd"
)

# Save-v14 compatibility storage. `day` is retained as the serialized legacy
# field, but its value is the canonical campaign turn/month index.
var day: int = 1
var denarii: int = 0
var food: int = 100
var ore: int = 20
var reputation: int = 0
var _monthly_turn_closure_policy = MonthlyTurnClosurePolicyScript.new()


func _ready() -> void:
	call_deferred("_apply_starting_resources_from_data")


func _apply_starting_resources_from_data() -> void:
	var starting_resources := DataRepository.get_economy_rule("demo_starting_resources")
	if starting_resources.is_empty():
		push_error("No se encontró la regla canónica de recursos iniciales de la demo.")
		return
	denarii = int(starting_resources.get("denarii", 0))


func get_month() -> int:
	return maxi(1, day)


func get_week() -> int:
	# Save-v14 compatibility alias only.
	return get_month()


func get_month_closure_status() -> Dictionary:
	return (
		_monthly_turn_closure_policy
		. evaluate(
			get_month(),
			CampaignManager.campaign_over,
			EventManager.get_pending_event(),
			TournamentManager.get_gt1_encounter(get_month()),
			TournamentManager.get_gt1_summary(),
		)
	)


func get_month_closure_contract() -> Dictionary:
	return _monthly_turn_closure_policy.get_contract()


func advance_month() -> void:
	var closure_status := get_month_closure_status()
	if not bool(closure_status.get("can_close", false)):
		var blockers: Array = closure_status.get("blockers", [])
		var reason := (
			str(blockers.front())
			if not blockers.is_empty()
			else "El mes no puede cerrarse por un bloqueo de campaña."
		)
		campaign_action_blocked.emit(reason)
		return

	var closing_month := get_month()
	var work_results: Array[Dictionary] = []
	var report := {
		"period": "month",
		"month": closing_month,
		"closed_month": closing_month,
		"internal_work_ticks": 1,
		"processing_order": MonthlyTurnClosurePolicyScript.PROCESSING_ORDER.duplicate(),
		"ore": 0,
		"food": 0,
		"security": 0,
		"intel": 0,
		"training": 0,
		"promotions": [],
		"work_results": work_results,
		# Save-v14 / legacy presentation alias. There are no internal daily loops.
		"daily_results": work_results,
	}

	# One player turn is one in-world month. Every active simulation subsystem is
	# entered through a month-native API exactly once. Legacy day/week entrypoints
	# are adapters only and are not used by the canonical closure path.
	var work_result: Dictionary = RosterManager.process_month()
	work_results.append(work_result)
	for key in ["ore", "food", "security", "intel", "training"]:
		report[key] = int(report.get(key, 0)) + int(work_result.get(key, 0))
	for promoted_name in work_result.get("promotions", []):
		if not report["promotions"].has(promoted_name):
			report["promotions"].append(promoted_name)

	var rival_events: Array = RivalManager.process_month()
	var economy_report: Dictionary = EconomyManager.process_month()
	var tournament_events: Array = TournamentManager.process_month()
	report["rival_events"] = rival_events
	report["economy"] = economy_report
	report["tournament_events"] = tournament_events

	day += 1
	TournamentManager.prepare_month(get_month())

	# Narrative events are generated once, after the new campaign month begins.
	var narrative_event: Dictionary = EventManager.process_month()
	report["narrative_event"] = narrative_event

	var base_consumption := maxi(1, RosterManager.people.size())
	var monthly_consumption := maxi(
		1, int(ceil(float(base_consumption) * EventManager.get_food_consumption_multiplier()))
	)
	food = maxi(0, food - monthly_consumption)
	ore += int(report.get("ore", 0))
	report["food_consumed"] = monthly_consumption
	report["next_month"] = get_month()
	# Legacy report key retains the historical serialized meaning: next turn index.
	report["week"] = get_month()
	var next_encounter := TournamentManager.get_gt1_encounter(get_month())
	if next_encounter.is_empty():
		report["fight"] = {
			"month": get_month(),
			"required": false,
			"name": "Gestión del ludus",
		}
	else:
		next_encounter["required"] = true
		report["fight"] = next_encounter
	report["chapter"] = CampaignManager.get_chapter_for_month(closing_month)

	month_advanced.emit(get_month())
	monthly_report.emit(report)

	# Compatibility signals mirror the completed month only. They do not execute
	# simulation and must not be consumed by new runtime systems.
	week_advanced.emit(get_month())
	weekly_report.emit(report)
	day_advanced.emit(day)
	daily_report.emit(report)
	resources_changed.emit()


func advance_week() -> void:
	# Save-v14 / legacy UI adapter.
	advance_month()


func advance_day() -> void:
	# Save-v14 / legacy UI adapter.
	advance_month()


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
	return (
		(
			"Mes: %d | Denarios: %d | Comida: %d | Mineral: %d | Reputación: %d | "
			+ "Seguridad: %d | Intel: %d | Deuda: %d | Combates: %d"
		)
		% [
			get_month(),
			denarii,
			food,
			ore,
			reputation,
			RosterManager.security_score,
			RosterManager.intelligence_points,
			int(economy.get("total_debt", 0)),
			TournamentManager.active_contracts.size(),
		]
	)
