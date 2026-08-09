extends Node

const RosterAdapterScript = preload("res://scripts/combat/combat_roster_fighter_adapter.gd")
const PersonScript = preload("res://scripts/entities/person.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var adapter = RosterAdapterScript.new()
	_test_missing_resistance_fails_closed(adapter)
	_test_explicit_resistance_builds_fighter(adapter)
	_test_live_person_supplies_canonical_resistance(adapter)
	_test_legacy_person_receives_neutral_resistance_baseline(adapter)
	_test_resistance_growth_is_independent_from_endurance()
	if _failures.is_empty():
		print("Combat roster fighter adapter: OK")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_missing_resistance_fails_closed(adapter) -> void:
	var source := _person_source()
	var before := source.duplicate(true)
	var result: Dictionary = adapter.build_fighter(source, "player", {"power": 4, "defense": 3})
	_assert_eq(
		result.get("status"),
		"pending_canonical_stats",
		"dictionary sources without explicit resistance must still fail closed",
	)
	_assert_eq(
		result.get("pending_stat_ids"),
		["RES"],
		"RES must remain the explicit unresolved stat for incomplete dictionary sources",
	)
	_assert_eq(result.get("fighter"), {}, "incomplete canonical stats must create no fighter")
	_assert_eq(source, before, "adapter must not mutate roster source")
	var separate := result.get("legacy_separate", {}) as Dictionary
	_assert_eq(separate, {"endurance": 99}, "Endurance must remain a separate legacy stat")
	_assert_eq(
		result.get("legacy_unmapped", {}),
		{"endurance": 99},
		"compatibility alias must expose only Endurance",
	)
	_assert_eq(
		separate.has("intelligence"), false, "Intelligence must be absent from adapter output"
	)


func _test_explicit_resistance_builds_fighter(adapter) -> void:
	var result: Dictionary = (
		adapter
		. build_fighter(
			_person_source(),
			"player",
			{"power": 4, "defense": 3},
			{"resistance": 14},
		)
	)
	_assert_eq(result.get("status"), "ready", "explicit resistance must complete fighter")
	var fighter := result.get("fighter", {}) as Dictionary
	var stats := fighter.get("stats", {}) as Dictionary
	_assert_eq(stats, {"FUE": 11, "AGI": 12, "TEC": 13, "RES": 14, "PV": 50})
	_assert_eq(fighter.get("equipment"), {"power": 4, "defense": 3})
	_assert_eq(fighter.get("team"), "player")
	_assert_eq(
		result.get("legacy_separate", {}),
		{"endurance": 99},
		"Endurance must remain separate even when canonical RES exists",
	)
	var contract: Dictionary = adapter.get_contract()
	_assert_eq(contract.get("live_roster_res_source"), "person.resistance")
	_assert_eq(contract.get("legacy_missing_resistance_baseline"), 5)
	_assert_eq(
		contract.get("endurance_to_resistance_fallback"),
		false,
		"adapter contract must forbid endurance fallback",
	)
	_assert_eq(
		contract.get("endurance_to_stamina_fallback"),
		false,
		"Endurance must not silently become Stamina",
	)
	_assert_eq(
		contract.get("removed_legacy_stats"),
		["intelligence"],
		"Intelligence must be explicitly removed from the active adapter contract",
	)


func _test_live_person_supplies_canonical_resistance(adapter) -> void:
	var person = (
		PersonScript
		. new(
			{
				"id": "live_g1",
				"strength": 7,
				"agility": 8,
				"technique": 9,
				"resistance": 12,
				"endurance": 88,
				"health": 60,
			}
		)
	)
	var result: Dictionary = adapter.build_from_person(person, "player", {"power": 2, "defense": 1})
	_assert_eq(result.get("status"), "ready", "live roster person must build without override")
	var fighter := result.get("fighter", {}) as Dictionary
	var stats := fighter.get("stats", {}) as Dictionary
	_assert_eq(stats.get("RES"), 12, "live person resistance must be Combat V1 RES")
	_assert_eq(
		(result.get("legacy_separate", {}) as Dictionary).get("endurance"),
		88,
		"live Endurance must remain separate from RES",
	)


func _test_legacy_person_receives_neutral_resistance_baseline(adapter) -> void:
	var legacy_person = (
		PersonScript
		. new(
			{
				"id": "legacy_g1",
				"strength": 7,
				"agility": 8,
				"technique": 9,
				"endurance": 99,
				"health": 60,
			}
		)
	)
	_assert_eq(legacy_person.resistance, 5, "legacy v14 person must receive neutral RES baseline")
	var result: Dictionary = adapter.build_from_person(legacy_person, "player")
	var fighter := result.get("fighter", {}) as Dictionary
	var stats := fighter.get("stats", {}) as Dictionary
	_assert_eq(stats.get("RES"), 5, "migrated baseline must reach Combat V1")
	_assert_eq(stats.get("RES") == legacy_person.endurance, false, "Endurance must not become RES")


func _test_resistance_growth_is_independent_from_endurance() -> void:
	var person = PersonScript.new({"id": "growth_g1", "resistance": 6, "endurance": 20})
	person.apply_growth({"resistance": 3, "endurance": 2})
	_assert_eq(person.resistance, 9, "RES growth must use resistance growth only")
	_assert_eq(person.endurance, 22, "legacy Endurance growth remains independent")


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
