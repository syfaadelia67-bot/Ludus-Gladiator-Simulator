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
	enroll_button.pressed.emit()

	var started_session := CombatV1SessionStore.get_non_gt_session(1)
	assert(str(started_session.get("status", "")) == "combat_running")

	var exchange_button := (
		arena_screen.get_node(
			"Body/CenterPanel/Margin/Scroll/Content/PreparationView/ActionRow/StartCombat"
		)
		as Button
	)
	assert(not exchange_button.disabled, "Started Arena combat must allow the first exchange")
	assert(exchange_button.text == "RESOLVER INTERCAMBIO")
	exchange_button.pressed.emit()

	var advanced_session := CombatV1SessionStore.get_non_gt_session(1)
	assert(str(advanced_session.get("status", "")) != "rejected")
	var providers := advanced_session.get("last_intent_providers", {}) as Dictionary
	assert(not providers.is_empty(), "The real UI must resolve intent providers on first exchange")
	for provider_name in providers.values():
		assert(str(provider_name) == "limboai")

	arena_screen.queue_free()
	print("Monthly Arena exchange UI test passed")


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
