extends Node

const ArenaScreenScene = preload("res://scenes/ArenaScreenMonthly.tscn")


func run() -> void:
	DataRepository.load_all()
	CampaignManager.campaign_over = false
	GameState.day = 1
	TournamentManager.prepare_month(1, true)
	_add_test_gladiator()

	var arena_screen = ArenaScreenScene.instantiate()
	add_child(arena_screen)

	var roster_list := (
		arena_screen.get_node("Body/RosterPanel/Margin/Scroll/Content/RosterList") as ItemList
	)
	var fighter_index := -1
	for index in range(roster_list.item_count):
		if str(roster_list.get_item_metadata(index)) == "qa_arena_exchange":
			fighter_index = index
			break
	assert(fighter_index >= 0)
	roster_list.select(fighter_index)
	roster_list.item_selected.emit(fighter_index)

	var enroll_button := (
		arena_screen.get_node(
			"Body/CenterPanel/Margin/Scroll/Content/EventBanner/Margin/Row/QuickMonthlyArenaAction"
		)
		as Button
	)
	assert(enroll_button.text.begins_with("INSCRIBIR EN BAJO MUNDO"))
	enroll_button.pressed.emit()
	assert(enroll_button.text.begins_with("INICIAR Bajo Mundo"))

	# One start press is the only gameplay input required after enrollment.
	enroll_button.pressed.emit()
	var final_session := CombatV1SessionStore.get_non_gt_session(1)
	assert(
		str(final_session.get("status", "")) == "encounter_finished",
		"Arena must finish automatically after the single start press",
	)
	assert(int(final_session.get("autobattle_exchanges", 0)) > 0)
	assert(not str((final_session.get("last_combat_result", {}) as Dictionary).get("winner_team_id", "")).is_empty())

	var providers := final_session.get("last_intent_providers", {}) as Dictionary
	assert(not providers.is_empty(), "Autobattle must record the LimboAI providers")
	for provider_name in providers.values():
		assert(str(provider_name) == "limboai")

	var action_selector := (
		arena_screen.get_node(
			"Body/CenterPanel/Margin/Scroll/Content/PreparationView/Preparation/Margin/Content/Options/TacticSelector"
		)
		as OptionButton
	)
	var target_selector := (
		arena_screen.get_node(
			"Body/CenterPanel/Margin/Scroll/Content/PreparationView/Preparation/Margin/Content/Options/EnergySelector"
		)
		as OptionButton
	)
	var legacy_exchange_button := (
		arena_screen.get_node(
			"Body/CenterPanel/Margin/Scroll/Content/PreparationView/ActionRow/StartCombat"
		)
		as Button
	)
	assert(not action_selector.visible, "Autobattle must not expose a manual action selector")
	assert(not target_selector.visible, "Autobattle must not expose a manual target selector")
	assert(not legacy_exchange_button.visible, "Autobattle must not expose RESOLVER INTERCAMBIO")

	arena_screen.queue_free()
	print("Monthly Arena autobattle UI test passed")


func _add_test_gladiator() -> void:
	if RosterManager.get_person("qa_arena_exchange") != null:
		return
	var person := (
		LudusPerson
		. new(
			{
				"id": "qa_arena_exchange",
				"name": "QA Arena Exchange",
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
