extends SceneTree

const BuilderScript = preload("res://scripts/combat/gt1_live_roster_state_builder.gd")
const PersonScript = preload("res://scripts/entities/person.gd")

var _failures: Array[String] = []


class FakePerson:
	extends RefCounted
	var id: String
	var role := "gladiator"
	var strength := 10
	var agility := 9
	var technique := 8
	var resistance := 7
	var health := 40
	var endurance := 6

	func _init(person_id: String) -> void:
		id = person_id


func _initialize() -> void:
	_test_live_autoload_roster_uses_real_equipment_snapshots()
	_test_month_20_builds_real_2v2_snapshots()
	_test_month_13_requires_same_live_gladiator()
	_test_unavailable_gladiator_fails_closed()
	_test_opponents_are_explicit_and_not_generated()
	if _failures.is_empty():
		print("GT I live roster state builder: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_live_autoload_roster_uses_real_equipment_snapshots() -> void:
	var roster_manager = root.get_node_or_null("RosterManager")
	var equipment_manager = root.get_node_or_null("EquipmentManager")
	_assert_true(
		roster_manager != null, "live integration requires the real RosterManager autoload"
	)
	_assert_true(
		equipment_manager != null, "live integration requires the real EquipmentManager autoload"
	)
	if roster_manager == null or equipment_manager == null:
		return

	var original_people: Array = roster_manager.people.duplicate()
	var original_inventory: Array = equipment_manager.inventory.duplicate(true)
	var original_serial: int = int(equipment_manager.serial)

	var live_person = (
		PersonScript
		. new(
			{
				"id": "live_gladiator",
				"name": "Live Gladiator",
				"role": "gladiator",
				"strength": 11,
				"agility": 10,
				"technique": 9,
				"resistance": 8,
				"health": 42,
				"endurance": 7,
			}
		)
	)
	roster_manager.people = [live_person]
	equipment_manager.inventory = []
	equipment_manager.serial = 0

	var live_item: Dictionary = (
		equipment_manager
		. add_market_item(
			{
				"recipe_id": "live_test_gladius",
				"name": "Live Test Gladius",
				"type": "weapon",
				"slot": "right_hand",
				"quality": "Común",
				"power": 9,
				"defense": 3,
				"tags": ["sword"],
			}
		)
	)
	var item_id := str(live_item.get("id", ""))
	_assert_true(not item_id.is_empty(), "real EquipmentManager must create the live test item")
	_assert_true(
		equipment_manager.equip_item_to_slot(live_person.id, item_id, "right_hand"),
		"real EquipmentManager must equip the live test item",
	)

	var builder = BuilderScript.new()
	var opponents := [
		[_opponent("live_x", "rival", 0)],
		[_opponent("live_y", "rival", 0)],
		[_opponent("live_z", "rival", 0)],
	]
	var first_result: Dictionary = (
		builder
		. build_from_live_roster(
			13,
			"player",
			[[live_person.id], [live_person.id], [live_person.id]],
			opponents,
		)
	)
	_assert_eq(first_result.get("status"), "ready", "live autoload build must be ready")
	var first_states := first_result.get("bout_states", []) as Array
	var first_fighter := _fighter_by_id(first_states[0] as Dictionary, live_person.id)
	var first_equipment := first_fighter.get("equipment", {}) as Dictionary
	var first_expected: Dictionary = equipment_manager.get_equipped_stats(live_person)
	_assert_eq(
		first_equipment,
		first_expected,
		"GT I builder must snapshot power/defense from the real EquipmentManager",
	)
	_assert_eq(
		first_equipment.get("power"), 9, "first live equipment snapshot must use current power"
	)

	var stored_item: Dictionary = equipment_manager.get_item(item_id)
	stored_item["power"] = 17
	var second_result: Dictionary = (
		builder
		. build_from_live_roster(
			13,
			"player",
			[[live_person.id], [live_person.id], [live_person.id]],
			opponents,
		)
	)
	_assert_eq(second_result.get("status"), "ready", "second live autoload build must be ready")
	var second_states := second_result.get("bout_states", []) as Array
	var second_fighter := _fighter_by_id(second_states[0] as Dictionary, live_person.id)
	var second_equipment := second_fighter.get("equipment", {}) as Dictionary
	_assert_eq(
		second_equipment,
		equipment_manager.get_equipped_stats(live_person),
		"a new GT I build must read the updated real equipment state",
	)
	_assert_eq(
		second_equipment.get("power"), 17, "second live snapshot must reflect equipment change"
	)
	_assert_eq(
		first_equipment.get("power"),
		9,
		"previous GT I state must remain an immutable build-time equipment snapshot",
	)
	_assert_eq(
		first_result.get("source"),
		"live_roster_and_equipment_snapshots",
		"live integration must report its authoritative player source",
	)

	roster_manager.people = original_people
	equipment_manager.inventory = original_inventory
	equipment_manager.serial = original_serial


func _test_month_20_builds_real_2v2_snapshots() -> void:
	var builder = BuilderScript.new()
	var people := {
		"a": FakePerson.new("a"),
		"b": FakePerson.new("b"),
		"c": FakePerson.new("c"),
	}
	var equipment := {
		"a": {"power": 12, "defense": 4},
		"b": {"power": 5, "defense": 9},
		"c": {"power": 3, "defense": 2},
	}
	var selections := [["a", "b"], ["a", "b"], ["a", "c"]]
	var opponents := [
		[_opponent("x1", "rival", 8), _opponent("x2", "rival", 9)],
		[_opponent("y1", "rival", 7), _opponent("y2", "rival", 6)],
		[_opponent("z1", "rival", 10), _opponent("z2", "rival", 11)],
	]
	var result: Dictionary = builder.build_from_sources(
		20, "player", selections, opponents, people, equipment
	)
	_assert_eq(result.get("status"), "ready", "month XX live roster assembly must be ready")
	_assert_eq(result.get("format"), "2v2", "month XX must materialize 2v2 states")
	var states := result.get("bout_states", []) as Array
	_assert_eq(states.size(), 3, "GT I encounter must materialize three bouts")
	for raw_state in states:
		var state := raw_state as Dictionary
		_assert_eq(state.get("format"), "2v2", "every month XX bout must remain 2v2")
		_assert_eq((state.get("fighters", []) as Array).size(), 4, "2v2 requires four fighters")
	var first_a := _fighter_by_id(states[0] as Dictionary, "a")
	_assert_eq(
		(first_a.get("equipment", {}) as Dictionary).get("power"),
		12,
		"equipment power must snapshot from live equipment",
	)
	_assert_eq(
		(first_a.get("stats", {}) as Dictionary).get("RES"),
		7,
		"RES must come from person.resistance",
	)
	var third_ids := _team_ids(states[2] as Dictionary, "player")
	_assert_eq(third_ids, ["a", "c"], "single month XX substitution must materialize")


func _test_month_13_requires_same_live_gladiator() -> void:
	var builder = BuilderScript.new()
	var people := {"a": FakePerson.new("a"), "b": FakePerson.new("b")}
	var result: Dictionary = (
		builder
		. build_from_sources(
			13,
			"player",
			[["a"], ["b"], ["a"]],
			[
				[_opponent("x", "rival", 0)],
				[_opponent("y", "rival", 0)],
				[_opponent("z", "rival", 0)]
			],
			people,
			{},
		)
	)
	_assert_eq(result.get("status"), "invalid", "month XIII roster change must fail closed")
	_assert_true(
		_contains(result.get("errors", []), "same gladiator"),
		"month XIII violation must be explicit",
	)


func _test_unavailable_gladiator_fails_closed() -> void:
	var builder = BuilderScript.new()
	var people := {"a": FakePerson.new("a")}
	var result: Dictionary = (
		builder
		. build_from_sources(
			16,
			"player",
			[["a"], ["missing"], ["a"]],
			[
				[_opponent("x", "rival", 0)],
				[_opponent("y", "rival", 0)],
				[_opponent("z", "rival", 0)]
			],
			people,
			{},
		)
	)
	_assert_eq(result.get("status"), "invalid", "unavailable live fighter must fail closed")
	_assert_true(
		_contains(result.get("errors", []), "unavailable gladiator missing"),
		"missing roster id must be reported",
	)


func _test_opponents_are_explicit_and_not_generated() -> void:
	var builder = BuilderScript.new()
	var contract: Dictionary = builder.get_contract()
	_assert_eq(contract.get("rival_generation_allowed"), false, "builder must never invent rivals")
	_assert_eq(
		contract.get("opponent_source"),
		"explicit_external_combat_v1_snapshots",
		"opponents must remain explicit",
	)


func _opponent(fighter_id: String, team_id: String, power: int) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 8, "AGI": 8, "TEC": 8, "RES": 8, "PV": 30},
		"stamina": 10,
		"equipment": {"power": power, "defense": 0},
	}


func _fighter_by_id(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter
	return {}


func _team_ids(state: Dictionary, team_id: String) -> Array[String]:
	var ids: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) == team_id:
			ids.append(str(fighter.get("id", "")))
	ids.sort()
	return ids


func _contains(errors: Variant, fragment: String) -> bool:
	if not errors is Array:
		return false
	for raw_error in errors as Array:
		if str(raw_error).contains(fragment):
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
