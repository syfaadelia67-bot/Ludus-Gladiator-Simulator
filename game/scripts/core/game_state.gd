extends Node

signal month_advanced(month: int)
signal monthly_report(report: Dictionary)

# Save-v14 and migration compatibility signals. Their integer payload now mirrors
# the canonical campaign month until every legacy consumer is migrated.
signal day_advanced(day: int)
signal daily_report(report: Dictionary)
signal week_advanced(week: int)
signal weekly_report(report: Dictionary)
signal resources_changed
signal campaign_action_blocked(reason: String)

const LEGACY_DAYS_PER_WEEK := 7
const DAYS_PER_WEEK := LEGACY_DAYS_PER_WEEK

# Save-v14 compatibility storage. `day` is retained as the serialized legacy
# field, but its value is now the canonical campaign turn/month index.
var day: int = 1
var denarii: int = 500
var food: int = 100
var ore: int = 20
var reputation: int = 0


func get_month() -> int:
	return maxi(1, day)


func get_week() -> int:
	# Compatibility alias: one former weekly turn maps 1:1 to one campaign month.
	return get_month()


func advance_month() -> void:
	if CampaignManager.campaign_over:
		campaign_action_blocked.emit(
			"La campaña terminó. La partida permanece disponible en modo de consulta."
		)
		return

	var closing_month := get_month()
	var work_results: Array[Dictionary] = []
	var report := {
		"period": "month",
		"month": closing_month,
		"closed_month": closing_month,
		"internal_work_ticks": 1,
		"ore": 0,
		"food": 0,
		"security": 0,
		"intel": 0,
		"training": 0,
		"promotions": [],
		"work_results": work_results,
		# Save-v14 / legacy presentation alias. There are no seven internal days.
		"daily_results": work_results,
	}

	# Frozen campaign rule: one player turn is one in-world month. Legacy systems
	# are still called through their old method names during migration, but each
	# resolves exactly once per month. There are no internal weeks or daily loops.
	var work_result: Dictionary = RosterManager.process_day()
	work_results.append(work_result)
	for key in ["ore", "food", "security", "intel", "training"]:
		report[key] = int(report.get(key, 0)) + int(work_result.get(key, 0))
	for promoted_name in work_result.get("promotions", []):
		if not report["promotions"].has(promoted_name):
			report["promotions"].append(promoted_name)

	var rival_events: Array = RivalManager.process_week()
	var economy_report: Dictionary = EconomyManager.process_week()
	var tournament_events: Array = TournamentManager.process_month()
	report["rival_events"] = rival_events
	report["economy"] = economy_report
	report["tournament_events"] = tournament_events

	day += 1
	TournamentManager.prepare_month(get_month())

	# Preserve existing event ordering while the event system is migrated: the
	# narrative event is generated once, after the new campaign month begins.
	var narrative_event: Dictionary = EventManager.process_week()
	report["narrative_event"] = narrative_event

	var base_consumption := maxi(1, RosterManager.people.size())
	var monthly_consumption := maxi(
		1, int(ceil(float(base_consumption) * EventManager.get_food_consumption_multiplier()))
	)
	food = maxi(0, food - monthly_consumption)
	ore += int(report.get("ore", 0))
	report["food_consumed"] = monthly_consumption
	report["next_month"] = get_month()
	# Legacy report key retains the previous meaning: the index after advancing.
	report["week"] = get_week()
	report["fight"] = CombatManager.get_current_event_details()
	report["chapter"] = CampaignManager.get_chapter_for_month(closing_month)

	month_advanced.emit(get_month())
	monthly_report.emit(report)

	# Compatibility signals remain active until every dependent system is moved
	# to month-native names. They do not represent additional simulation ticks.
	week_advanced.emit(get_week())
	weekly_report.emit(report)
	day_advanced.emit(day)
	daily_report.emit(report)
	resources_changed.emit()


func advance_week() -> void:
	advance_month()


func advance_day() -> void:
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
