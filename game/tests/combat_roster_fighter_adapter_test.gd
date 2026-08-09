extends SceneTree

const RosterAdapterScript = preload("res://scripts/combat/combat_roster_fighter_adapter.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var adapter = RosterAdapterScript.new()
	_test_missing_resistance_fails_closed(adapter)
	_test_explicit_resistance_builds_fighter(adapter)
	if _failures.is_empty():
		print("Combat roster fighter adapter: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_missing_resistance_fails_closed(adapter) -> void:
	var source := _person_source()
	var before := source.duplicate(true)
	var result: Dictionary = adapter.build_fighter(source, "player", {"power": 4, "defense": 3})
	_assert_eq(
		result.get("status"),
		"pending_canonical_stats",
		"missing explicit resistance must fail closed",
	)
	_assert_eq(
		result.get("pending_stat_ids"),
		["RES"],
		"RES must remain the explicit unresolved stat",
	)
	_assert_eq(result.get("fighter"), {}, "incomplete canonical stats must create no fighter")
	_assert_eq(source, before, "adapter must not mutate roster source")
	var unmapped := result.get("legacy_unmapped", {}) as Dictionary
	_assert_eq(unmapped.get("endurance"), 99, "legacy endurance must remain visible but unmapped")


func _test_explicit_resistance_builds_fighter(adapter) -> void:
	var result: Dictionary = adapter.build_fighter(
		_person_source(),
		"player",
		{"power": 4, "defense": 3},
		{"resistance": 14},
	)
	_assert_eq(result.get("status"), "ready", "explicit resistance must complete fighter")
	var fighter := result.get("fighter", {}) as Dictionary
	var stats := fighter.get("stats", {}) as Dictionary
	_assert_eq(stats, {"FUE": 11, "AGI": 12, "TEC": 13, "RES": 14, "PV": 50})
	_assert_eq(fighter.get("equipment"), {"power": 4, "defense": 3})
	_assert_eq(fighter.get("team"), "player")
	var contract: Dictionary = adapter.get_contract()
	_assert_eq(
		contract.get("endurance_to_resistance_fallback"),
		false,
		"adapter contract must forbid endurance fallback",
	)


func _person_source() -> Dictionary:
	return {
		"id": "g1",
		"strength": 11,
		"agility": 12,
		"technique": 13,
		"health": 50,
		"endurance": 99,
		"intelligence": 7,
		"stamina": 10,
	}


func _assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
