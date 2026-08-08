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
		1,
		int(game_data.get("month", game_data.get("week", game_data.get("day", 1))))
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


func _build_payload() -> Dictionary:
	var payload := super._build_payload()
	var game_data: Dictionary = payload.get("game_state", {})
	var month := GameState.get_month()
	game_data["month"] = month
	# Keep the old v14 keys alive with identical values. No schema-version bump.
	game_data["day"] = month
	game_data["week"] = month
	payload["game_state"] = game_data
	payload["unique_gladiators"] = UniqueGladiatorManager.export_state()
	return payload


func _apply_payload(data: Dictionary) -> bool:
	if not super._apply_payload(data):
		return false

	var game_data: Dictionary = data.get("game_state", {})
	GameState.day = maxi(
		1,
		int(game_data.get("month", game_data.get("week", game_data.get("day", 1))))
	)

	var unique_data: Variant = data.get("unique_gladiators", null)
	if unique_data is Dictionary and not unique_data.is_empty():
		UniqueGladiatorManager.import_state(unique_data)
	else:
		# Older v14 saves reconstruct ownership from roster, rival houses and
		# saved market offers without being rejected.
		UniqueGladiatorManager.reconcile_from_world()
	MarketManager.sync_unique_offers()
	return true
