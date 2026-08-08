extends Node

const EstateManagerScript = preload("res://scripts/systems/estate_manager.gd")

const CANONICAL_BUILDINGS: Array[String] = [
	"barracks",
	"beast_area",
	"dominus_house",
	"forge",
	"infirmary",
	"mine",
	"training_yard",
]


func _ready() -> void:
	var estate = EstateManagerScript.new()
	estate._ensure_catalog_loaded()

	assert(
		estate.BUILDINGS.size() == 7,
		"The frozen estate catalog must define exactly seven facilities"
	)
	assert(
		estate.get_building_ids() == CANONICAL_BUILDINGS,
		"The estate catalog must expose only the seven frozen facilities"
	)
	assert(
		estate.canonicalize_building_id("quarters") == "barracks",
		"Legacy quarters id must migrate to barracks"
	)
	assert(
		estate.canonicalize_building_id("guard_post").is_empty(),
		"Removed guard post ids must not remain canonical"
	)
	assert(
		estate.canonicalize_building_id("security").is_empty(),
		"Removed security building ids must not remain canonical"
	)
	assert(
		estate.canonicalize_building_id("kitchen").is_empty(),
		"Removed kitchen ids must not remain canonical"
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
		not migrated.has("wall_and_gate"),
		"Removed security buildings must not enter canonical saves"
	)
	assert(not migrated.has("kitchen"), "Removed kitchen buildings must not enter canonical saves")
	assert(
		not migrated.has("unknown_building"), "Unknown legacy ids must not enter canonical saves"
	)
	assert(
		migrated.size() == 7,
		"Migrated estate state must contain every frozen facility and nothing else"
	)

	assert(int(migrated.get("dominus_house", -1)) == 1, "Casa del Dominus must start at level I")
	assert(int(migrated.get("training_yard", -1)) == 1, "Training yard must start at level I")
	assert(int(migrated.get("forge", -1)) == 0, "Forge must start at level 0")
	assert(int(migrated.get("infirmary", -1)) == 0, "Infirmary must start at level 0")
	assert(int(migrated.get("mine", -1)) == 0, "Mine must start at level 0")
	assert(int(migrated.get("beast_area", -1)) == 0, "Beast area must start at level 0")

	estate.levels = migrated
	estate.demo_mode = true
	assert(estate.is_demo_available("forge"), "Forge must be available in the demo")
	assert(estate.is_demo_available("mine"), "Mine must be part of the frozen demo facility set")
	assert(
		estate.get_effective_max_level("forge") == 3,
		"Demo buildings must allow progression through level III"
	)
	assert(estate.get_effective_max_level("mine") == 3, "Mine must use the same demo level cap")
	assert(
		not estate.can_upgrade("mine"),
		"Mine upgrades must remain blocked until its frozen monthly cost is recovered"
	)
	assert(estate.get_security_bonus() == 0, "Security must no longer come from a building")

	estate.demo_mode = false
	assert(
		estate.get_effective_max_level("forge") == 10,
		"Full game facilities must preserve level X progression"
	)
	assert(
		estate.get_effective_max_level("beast_area") == 10,
		"Beast area must preserve level X progression"
	)

	estate.free()
	print("Estate catalog tests passed")
	get_tree().quit(0)
