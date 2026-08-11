extends "res://scripts/core/save_manager.gd"

## Demo save extension. SAVE_VERSION remains 14. The canonical campaign turn is
## now `month`, while `day` and `week` remain serialized as 1:1 compatibility
## aliases so existing v12/v13/v14 migration paths and older consumers survive.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not GameState.month_advanced.is_connected(_on_month_advanced):
		GameState.month_advanced.connect(_on_month_advanced)


func _on_month_advanced(_month: int) -> void:
	if autosave_enabled:
		call_deferred("save_game")


func get_save_metadata() -> Dictionary:
	var data: Dictionary = _read_payload(SAVE_PATH)
	if data.is_empty():
		data = _read_payload(BACKUP_PATH)
	if data.is_empty():
		return {}

	var game_data: Dictionary = data.get("game_state", {})
	var owner_profile: Dictionary = data.get("owner", {}).get("profile", {})
	var month := maxi(
		1, int(game_data.get("month", game_data.get("week", game_data.get("day", 1))))
	)
	return {
		"version": int(data.get("version", 0)),
		"saved_at_unix": int(data.get("saved_at_unix", 0)),
		"month": month,
		# Compatibility metadata for old start/load screens.
		"day": month,
		"week": month,
		"owner_name": str(owner_profile.get("display_name", "")),
		"owner_title": str(owner_profile.get("title", "dominus")),
	}


func _validate_payload(payload: Dictionary) -> bool:
	if not super._validate_payload(payload):
		return false
	var runtime_value: Variant = payload.get("combat_v1_runtime", {})
	return runtime_value is Dictionary


func _build_payload() -> Dictionary:
	var payload := super._build_payload()
	var game_data: Dictionary = payload.get("game_state", {})
	var month := GameState.get_month()
	game_data["month"] = month
	# Keep the old v14 keys alive with identical values. No schema-version bump.
	game_data["day"] = month
	game_data["week"] = month
	payload["game_state"] = game_data
	_inject_canonical_resistance(payload)
	_inject_equipment_slots(payload)
	_inject_monthly_roster_state(payload)
	payload["unique_gladiators"] = UniqueGladiatorManager.export_state()
	# Save v14 accepts additive dictionaries. Beast ownership stores identity only;
	# Combat V1 beast stats remain separately blocked until they are frozen.
	payload["owned_beasts"] = OwnedBeastRegistry.export_state()
	_inject_monthly_market_state(payload)
	_inject_equipment_runtime_state(payload)
	# Additive v14 runtime section: active Combat V1 state, including consecutive
	# carryover and championship rematch state, never changes SAVE_VERSION.
	payload["combat_v1_runtime"] = CombatV1SessionStore.export_state()
	return payload


func _inject_canonical_resistance(payload: Dictionary) -> void:
	var roster_data := payload.get("roster", {}) as Dictionary
	var people_data := roster_data.get("people", []) as Array
	var live_people := RosterManager.get_people()
	var count := mini(people_data.size(), live_people.size())
	for index in range(count):
		if not people_data[index] is Dictionary:
			continue
		var serialized_person := people_data[index] as Dictionary
		var live_person = live_people[index]
		serialized_person["resistance"] = maxi(1, int(live_person.resistance))
	roster_data["people"] = people_data
	payload["roster"] = roster_data


func _inject_equipment_slots(payload: Dictionary) -> void:
	var roster_data := payload.get("roster", {}) as Dictionary
	var people_data := roster_data.get("people", []) as Array
	var live_people := RosterManager.get_people()
	var people_by_id: Dictionary = {}
	for person in live_people:
		people_by_id[str(person.id)] = person
	for raw_person_data in people_data:
		if not raw_person_data is Dictionary:
			continue
		var person_data := raw_person_data as Dictionary
		var person_id := str(person_data.get("id", ""))
		if not people_by_id.has(person_id):
			continue
		var live_person = people_by_id[person_id]
		person_data["equipped_slots"] = live_person.get_equipped_slots()
	roster_data["people"] = people_data
	payload["roster"] = roster_data


func _inject_monthly_roster_state(payload: Dictionary) -> void:
	var roster_data := payload.get("roster", {}) as Dictionary
	roster_data["last_processed_month"] = RosterManager.last_processed_month
	roster_data["last_monthly_result"] = RosterManager.last_monthly_result.duplicate(true)
	roster_data["monthly_policy_status"] = str(
		RosterManager.get_monthly_work_policy().get("status", "")
	)
	payload["roster"] = roster_data


func _inject_monthly_market_state(payload: Dictionary) -> void:
	var market_data := payload.get("market", {}) as Dictionary
	var rotation_month := MarketManager.last_market_rotation_month
	market_data["last_market_rotation_month"] = rotation_month
	market_data["last_auto_refresh_month"] = rotation_month
	# Save-v14 compatibility alias only.
	market_data["last_auto_refresh_week"] = rotation_month
	market_data["monthly_policy_status"] = str(
		MarketManager.get_market_rotation_policy().get("status", "")
	)
	payload["market"] = market_data


func _inject_equipment_runtime_state(payload: Dictionary) -> void:
	var equipment_data := payload.get("equipment", {}) as Dictionary
	equipment_data["runtime_policy_status"] = str(
		EquipmentManager.get_runtime_policy().get("status", "")
	)
	equipment_data["canonical_slots_persisted"] = true
	payload["equipment"] = equipment_data


func _apply_payload(data: Dictionary) -> bool:
	if not super._apply_payload(data):
		return false

	var game_data: Dictionary = data.get("game_state", {})
	GameState.day = maxi(
		1, int(game_data.get("month", game_data.get("week", game_data.get("day", 1))))
	)
	var roster_data: Dictionary = data.get("roster", {})
	RosterManager.last_processed_month = maxi(0, int(roster_data.get("last_processed_month", 0)))
	var last_roster_result: Variant = roster_data.get("last_monthly_result", {})
	RosterManager.last_monthly_result = (
		last_roster_result.duplicate(true) if last_roster_result is Dictionary else {}
	)

	var market_data: Dictionary = data.get("market", {})
	MarketManager.last_market_rotation_month = maxi(
		1,
		int(
			(
				market_data
				. get(
					"last_market_rotation_month",
					market_data.get(
						"last_auto_refresh_month",
						market_data.get("last_auto_refresh_week", GameState.get_month())
					),
				)
			)
		),
	)
	var owned_beast_data: Variant = data.get("owned_beasts", {})
	OwnedBeastRegistry.import_state(owned_beast_data if owned_beast_data is Dictionary else {})
	EquipmentManager.reconcile_inventory_ownership()

	var unique_data: Variant = data.get("unique_gladiators", null)
	if unique_data is Dictionary and not unique_data.is_empty():
		UniqueGladiatorManager.import_state(unique_data)
	else:
		# Older v14 saves reconstruct ownership from roster, rival houses and
		# saved market offers without being rejected.
		UniqueGladiatorManager.reconcile_from_world()
	MarketManager.sync_unique_offers()

	var runtime_data: Variant = data.get("combat_v1_runtime", {})
	if not CombatV1SessionStore.import_state(
		runtime_data if runtime_data is Dictionary else {}
	):
		return false
	return true
