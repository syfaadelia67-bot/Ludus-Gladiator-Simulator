extends Node

const EstateManagerScript = preload("res://scripts/systems/estate_manager.gd")

const DEMO_BUILDINGS: Array[String] = [
	"barracks",
	"beast_area",
	"dominus_house",
	"forge",
	"infirmary",
	"mine",
	"training_yard",
]
const REQUIRED_FULL_GAME_BUILDINGS: Array[String] = [
	"kitchen",
	"private_arena",
	"sanctuary",
	"stable",
	"wall_and_gate",
	"warehouse",
	"worker_quarters",
]


func _ready() -> void:
	var estate = EstateManagerScript.new()
	estate._ensure_catalog_loaded()

	assert(
		estate.get_demo_building_ids() == DEMO_BUILDINGS,
		"The demo must expose exactly the seven frozen facilities"
	)
	assert(
		estate.BUILDINGS.size() > DEMO_BUILDINGS.size(),
		"The full-game estate catalog must preserve facilities beyond the demo scope"
	)
	for building_id in REQUIRED_FULL_GAME_BUILDINGS:
		assert(
			estate.BUILDINGS.has(building_id),
			"Full-game facility must remain in the canonical catalog: %s" % building_id
		)
		assert(
			not estate.is_demo_available(building_id),
			"Full-game facility must remain locked in the demo: %s" % building_id
		)

	assert(
		estate.canonicalize_building_id("quarters") == "barracks",
		"Legacy quarters id must migrate to barracks"
	)
	assert(
		estate.canonicalize_building_id("guard_post") == "wall_and_gate",
		"Legacy guard_post id must migrate to wall_and_gate"
	)
	assert(
		estate.canonicalize_building_id("security") == "wall_and_gate",
		"Legacy security id must migrate to wall_and_gate"
	)

	var migrated := (
		estate
		. migrate_levels(
			{
				"quarters": 2,
				"barracks": 1,
				"guard_post": 3,
				"kitchen": 2,
				"unknown_building": 9,
			}
		)
	)
	assert(
		int(migrated.get("barracks", -1)) == 2,
		"Migration must keep the highest compatible barracks level"
	)
	assert(
		int(migrated.get("wall_and_gate", -1)) == 3,
		"Legacy security levels must migrate to the full-game wall"
	)
	assert(int(migrated.get("kitchen", -1)) == 2, "Full-game building state must survive Save v14")
	assert(
		not migrated.has("unknown_building"), "Unknown legacy ids must not enter canonical saves"
	)
	assert(
		migrated.size() == estate.BUILDINGS.size(),
		"Migrated estate state must contain every canonical full-game facility"
	)

	assert(int(migrated.get("dominus_house", -1)) == 1, "Casa del Dominus must start at level I")
	assert(int(migrated.get("training_yard", -1)) == 1, "Training yard must start at level I")
	assert(int(migrated.get("forge", -1)) == 0, "Forge must start at level 0")
	assert(int(migrated.get("infirmary", -1)) == 0, "Infirmary must start at level 0")
	assert(int(migrated.get("mine", -1)) == 0, "Mine must start at level 0")
	assert(int(migrated.get("beast_area", -1)) == 0, "Beast area must start at level 0")
	assert(int(migrated.get("stable", -1)) == 0, "Full-game facilities must default to level 0")

	estate.levels = migrated
	estate.demo_mode = true
	assert(estate.is_demo_available("forge"), "Forge must be available in the demo")
	assert(estate.is_demo_available("mine"), "Mine must be part of the frozen demo facility set")
	assert(not estate.is_demo_available("stable"), "Stable must be reserved for the full game")
	assert(
		not estate.is_demo_available("sanctuary"), "Sanctuary must be reserved for the full game"
	)
	assert(
		not estate.is_demo_available("private_arena"),
		"Private arena must be reserved for the full game"
	)
	assert(not estate.is_demo_available("wall_and_gate"), "Wall must be reserved for the full game")
	assert(
		estate.get_effective_max_level("forge") == 3,
		"Demo buildings must allow progression through level III"
	)
	assert(estate.get_effective_max_level("mine") == 3, "Mine must use the same demo level cap")
	assert(
		estate.get_effective_max_level("stable") == 0,
		"Locked full-game facilities must cap at 0 in demo"
	)
	assert(
		not estate.can_upgrade("mine"),
		"Mine upgrades must remain blocked until its frozen monthly cost is recovered"
	)
	assert(not estate.can_upgrade("stable"), "Full-game facilities must not be upgradeable in demo")
	assert(estate.get_security_bonus() == 0, "The full-game wall must not affect demo security")

	estate.demo_mode = false
	assert(
		estate.get_effective_max_level("forge") == 10,
		"Full game facilities must preserve level X progression"
	)
	assert(
		estate.get_effective_max_level("beast_area") == 10,
		"Beast area must preserve level X progression"
	)
	assert(
		estate.get_effective_max_level("stable") == 10,
		"Stable must remain available for full-game progression"
	)
	assert(
		estate.get_effective_max_level("sanctuary") == 10,
		"Sanctuary must remain available for full-game progression"
	)
	assert(
		estate.get_effective_max_level("private_arena") == 10,
		"Private arena must remain available for full-game progression"
	)
	assert(
		estate.get_effective_max_level("wall_and_gate") == 10,
		"Wall must remain available for full-game progression"
	)
	assert(
		estate.get_security_bonus() == 9, "Full-game wall security effect must remain functional"
	)

	estate.free()
	print("Estate catalog tests passed")
	get_tree().quit(0)
