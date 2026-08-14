extends Node

const ArenaLimboAIRequestProviderScript = preload(
	"res://scripts/combat/arena_limboai_request_provider.gd"
)
const CombatV1ArenaRuntimeMonthlyScript = preload(
	"res://scripts/ui/combat_v1_arena_runtime_monthly.gd"
)
const ArenaScreenMonthlyScript = preload("res://scripts/ui/arena_screen_monthly.gd")
const ArenaScreenScene = preload("res://scenes/ArenaScreenMonthly.tscn")
const FunctionalUiStatePolicyScript = preload("res://scripts/ui/demo_functional_ui_state_policy.gd")


func run() -> void:
	DataRepository.load_all()
	CampaignManager.campaign_over = false
	GameState.day = 1
	TournamentManager.prepare_month(1, true)
	var arena_state := FunctionalUiStatePolicyScript.new().evaluate("arena")
	assert(
		str(arena_state.get("state", "")) == "ready",
		"Mes 1 Arena must be ready because canonical non-GT combat is available",
	)

	_add_test_gladiator("qa_arena_1v1", "QA Arena 1v1")
	_add_test_gladiator("qa_arena_1v2", "QA Arena 1v2")
	_add_test_gladiator("qa_arena_2v2_a", "QA Arena 2v2 A")
	_add_test_gladiator("qa_arena_2v2_b", "QA Arena 2v2 B")
	assert(
		GladiatorProgressionManager.set_tactical_plan(
			"qa_arena_1v1", [{"ability_id": "charge", "condition": "always"}]
		),
		"Arena QA gladiator must accept the learned charge Tactical Plan",
	)

	_assert_month_one_real_ui_flow("qa_arena_1v1")
	_assert_playable_format("1v2", ["qa_arena_1v2"], 2, false)
	_assert_playable_format("2v2", ["qa_arena_2v2_a", "qa_arena_2v2_b"], 2, false)
	print("Monthly Arena playable autobattle integration tests passed")


func _assert_month_one_real_ui_flow(fighter_id: String) -> void:
	GameState.day = 1
	TournamentManager.prepare_month(1, true)
	var arena_screen = ArenaScreenScene.instantiate()
	add_child(arena_screen)

	var roster_list := (
		arena_screen.get_node("Body/RosterPanel/Margin/Scroll/Content/RosterList") as ItemList
	)
	assert(roster_list.item_count > 0, "The real Arena roster must expose the hired gladiator")
	var fighter_index := -1
	for index in range(roster_list.item_count):
		if str(roster_list.get_item_metadata(index)) == fighter_id:
			fighter_index = index
			break
	assert(fighter_index >= 0, "The requested gladiator must be selectable in the real Arena UI")
	if fighter_index < 0:
		arena_screen.queue_free()
		return
	roster_list.select(fighter_index)
	roster_list.item_selected.emit(fighter_index)

	var enroll_button := (
		arena_screen.get_node(
			"Body/CenterPanel/Margin/Scroll/Content/EventBanner/Margin/Row/QuickMonthlyArenaAction"
		)
		as Button
	)
	assert(not enroll_button.disabled)
	assert(enroll_button.text.begins_with("INSCRIBIR EN BAJO MUNDO"))
	enroll_button.pressed.emit()
	var contract := TournamentManager.get_active_contract_for_fighter(fighter_id)
	assert(not contract.is_empty(), "Pressing the real Arena button must create the contract")
	assert(enroll_button.text.begins_with("INICIAR Bajo Mundo"))

	# From this press onward the test deliberately supplies no combat input.
	enroll_button.pressed.emit()
	var session := arena_screen.get("_session") as Dictionary
	assert(
		str(session.get("status", "")) == "encounter_finished",
		"The real Arena must finish after one start press and no mid-fight input",
	)
	var action_selector := arena_screen.get("action_selector") as Control
	var target_selector := arena_screen.get("target_selector") as Control
	var manual_exchange_button := arena_screen.get("start_button") as Control
	assert(not action_selector.visible, "Autobattle must not expose a manual action selector")
	assert(not target_selector.visible, "Autobattle must not expose a manual target selector")
	assert(
		not manual_exchange_button.visible, "Autobattle must not expose a resolve-exchange button"
	)
	_assert_presentation_events(session, "1v1")
	_assert_presented_skill(session, fighter_id, "charge")
	_assert_finished_outcome_contract(session)
	var providers := session.get("last_intent_providers", {}) as Dictionary
	assert(not providers.is_empty())
	for provider_name in providers.values():
		assert(str(provider_name) == "limboai")
	assert(
		CombatV1SessionStore.get_non_gt_session(1).is_empty(),
		"Finished non-GT combat must not persist under the Save v14 running-session contract",
	)
	arena_screen.queue_free()


func _assert_playable_format(
	format_id: String,
	player_ids: Array[String],
	opponent_count: int,
	require_underworld: bool,
) -> void:
	var event := _prepare_real_event(format_id, require_underworld)
	assert(not event.is_empty(), "A real monthly event must exist for %s" % format_id)
	if event.is_empty():
		return

	var gt_points_before := int(TournamentManager.get_gt1_summary().get("player_points", 0))
	var event_id := str(event.get("id", ""))
	var accepted := false
	if int(event.get("team_size", 1)) > 1:
		accepted = TournamentManager.accept_event_team(event_id, player_ids)
	else:
		var arena_screen = ArenaScreenMonthlyScript.new()
		accepted = arena_screen.accept_non_gt_event_for_fighter(event_id, player_ids[0])
		arena_screen.free()
	assert(accepted, "Real monthly event must be accepted from the Arena path for %s" % format_id)
	if not accepted:
		return

	var contract: Dictionary = TournamentManager.get_active_contract_for_event(event_id)
	assert(not contract.is_empty(), "Accepted monthly event must create an active contract")
	assert(str(contract.get("format", "")) == format_id)
	assert(str(contract.get("competition", "")) != "grand_tournament")
	if contract.is_empty():
		return

	var runtime = CombatV1ArenaRuntimeMonthlyScript.new()
	var session: Dictionary = runtime.start_non_gt_contract(contract, "player")
	assert(
		str(session.get("status", "")) == "combat_running",
		(
			"%s must start a real monthly combat session: %s"
			% [format_id, str(session.get("errors", []))]
		),
	)
	if str(session.get("status", "")) != "combat_running":
		return
	assert(str(session.get("session_kind", "")) == "monthly_non_gt")
	assert((session.get("opponent_fighter_ids", []) as Array).size() == opponent_count)
	assert(not str(session.get("rival_ludus_id", "")).is_empty())

	var ai_provider = ArenaLimboAIRequestProviderScript.new()
	var request_provider := Callable(ai_provider, "build_requests").bind(self, self)
	var final_session: Dictionary = runtime.resolve_autobattle(session, request_provider)
	assert(
		str(final_session.get("status", "")) == "encounter_finished",
		(
			"%s must reach encounter_finished automatically instead of deadlocking: %s"
			% [format_id, str(final_session.get("errors", []))]
		),
	)
	if str(final_session.get("status", "")) != "encounter_finished":
		return

	_assert_presentation_events(final_session, format_id)
	var providers := final_session.get("last_intent_providers", {}) as Dictionary
	assert(not providers.is_empty())
	for provider_name in providers.values():
		assert(str(provider_name) == "limboai")

	_assert_finished_outcome_contract(final_session)
	var tournament_result := final_session.get("last_tournament_result", {}) as Dictionary
	assert(not tournament_result.is_empty())
	assert(str(tournament_result.get("competition", "")) != "grand_tournament")
	assert(int(final_session.get("player_points", -1)) == 0)
	assert(
		int(TournamentManager.get_gt1_summary().get("player_points", 0)) == gt_points_before,
		"Non-GT Arena combat must never award Torneo de Marte points",
	)


func _assert_finished_outcome_contract(session: Dictionary) -> void:
	var combat_result := session.get("last_combat_result", {}) as Dictionary
	var tournament_result := session.get("last_tournament_result", {}) as Dictionary
	assert(str(combat_result.get("status", "")) == "combat_finished")
	assert(not tournament_result.is_empty())
	var outcome := str(combat_result.get("outcome", ""))
	var winner_team_id := str(combat_result.get("winner_team_id", ""))
	match outcome:
		"team_win":
			assert(not winner_team_id.is_empty(), "team_win requires an authoritative winner")
			assert(str(tournament_result.get("result_kind", "")) == "team_win")
			assert(not bool(tournament_result.get("draw", true)))
			assert(str(tournament_result.get("winner_team_id", "")) == winner_team_id)
		"double_ko":
			assert(winner_team_id.is_empty(), "double_ko must never invent a winner")
			assert(str(tournament_result.get("result_kind", "")) == "double_ko")
			assert(bool(tournament_result.get("draw", false)))
			assert(str(tournament_result.get("status", "")) == "doble_ko")
			assert(int(tournament_result.get("reward_paid", -1)) == 0)
			assert(int(tournament_result.get("reputation_change", -1)) == 0)
			assert(int(tournament_result.get("points", -1)) == 0)
		_:
			assert(false, "Finished Combat V1 result must be team_win or double_ko")


func _assert_presentation_events(session: Dictionary, format_id: String) -> void:
	var events := session.get("presentation_events", []) as Array
	assert(not events.is_empty(), "%s autobattle must publish presentation events" % format_id)
	if events.is_empty():
		return
	assert(str((events[0] as Dictionary).get("type", "")) == "exchange_started")
	var has_action := false
	var has_attack := false
	var has_ko := false
	var has_finished := false
	for raw_event in events:
		var event := raw_event as Dictionary
		match str(event.get("type", "")):
			"action_declared":
				has_action = true
			"attack_resolved":
				has_attack = true
			"fighter_knocked_out":
				has_ko = true
			"combat_finished":
				has_finished = true
	assert(has_action, "%s presentation must expose resolved action facts" % format_id)
	assert(has_attack, "%s presentation must expose simulator attack facts" % format_id)
	assert(has_ko, "%s presentation must expose knockout facts" % format_id)
	assert(has_finished, "%s presentation must expose the authoritative combat finish" % format_id)
	assert(str((events[-1] as Dictionary).get("type", "")) == "combat_finished")


func _assert_presented_skill(session: Dictionary, fighter_id: String, skill_id: String) -> void:
	for raw_event in session.get("presentation_events", []) as Array:
		var event := raw_event as Dictionary
		if (
			str(event.get("type", "")) == "action_declared"
			and str(event.get("actor_id", "")) == fighter_id
			and str(event.get("skill_id", "")) == skill_id
		):
			return
	assert(false, "Validated Tactical Plan skill must survive into read-only presentation metadata")


func _prepare_real_event(format_id: String, require_underworld: bool) -> Dictionary:
	if require_underworld:
		GameState.day = 1
		TournamentManager.prepare_month(1, true)
		for raw_event in TournamentManager.get_month_schedule(1):
			var event := raw_event as Dictionary
			if (
				str(event.get("competition", "")) == "underworld"
				and str(event.get("format", "")) == format_id
			):
				return event.duplicate(true)
		return {}

	for month in range(1, 13):
		GameState.day = month
		TournamentManager.prepare_month(month, true)
		for raw_event in TournamentManager.get_month_schedule(month):
			var event := raw_event as Dictionary
			if (
				str(event.get("competition", "")) == "official_minor"
				and str(event.get("format", "")) == format_id
			):
				return event.duplicate(true)
	return {}


func _add_test_gladiator(person_id: String, display_name: String) -> void:
	if RosterManager.get_person(person_id) != null:
		return
	var person := (
		LudusPerson
		. new(
			{
				"id": person_id,
				"name": display_name,
				"role": "gladiator",
				"strength": 7,
				"agility": 7,
				"endurance": 7,
				"resistance": 6,
				"intelligence": 5,
				"technique": 7,
				"health": 58,
				"fatigue": 0,
			}
		)
	)
	assert(RosterManager.add_person(person))
	var record := GladiatorProgressionManager.ensure_record(person_id)
	record["abilities"] = {"charge": 1}
