extends Node

const DataRepositoryScript = preload("res://scripts/core/data_repository.gd")

const COLLECTION_PATHS: Dictionary = {
	"traits": "res://data/traits.json",
	"buildings": "res://data/buildings.json",
	"weapons": "res://data/weapons.json",
	"beasts": "res://data/beasts.json",
}
const MISSING_PATH: String = "user://data_repository_missing_test.json"
const INVALID_PATH: String = "user://data_repository_invalid_test.json"


func _ready() -> void:
	var repository = DataRepositoryScript.new()

	for collection_name: String in COLLECTION_PATHS:
		var path: String = str(COLLECTION_PATHS[collection_name])
		var collection: Array = repository._load_json_array(path)
		_assert_valid_collection(collection_name, collection)

	repository.load_all()
	assert(repository.beasts.size() == 3, "DataRepository must load the three frozen demo beasts")
	assert(
		repository.is_frozen_contract_valid(),
		"Canonical data must satisfy the frozen Part 3 contract: %s"
		% [repository.get_frozen_contract_errors()]
	)

	_remove_user_file(MISSING_PATH)
	var missing_collection: Array = repository._load_json_array(MISSING_PATH)
	assert(missing_collection.is_empty(), "A missing JSON file must return an empty array")

	_write_invalid_json()
	var invalid_collection: Array = repository._load_json_array(INVALID_PATH)
	assert(invalid_collection.is_empty(), "An invalid JSON file must return an empty array")
	_remove_user_file(INVALID_PATH)

	repository.free()
	print("DataRepository tests passed")
	get_tree().quit(0)


func _assert_valid_collection(collection_name: String, collection: Array) -> void:
	assert(not collection.is_empty(), "%s must be a non-empty array" % collection_name)
	var identifiers: Dictionary = {}
	for raw_entry: Variant in collection:
		assert(raw_entry is Dictionary, "%s entries must be dictionaries" % collection_name)
		var entry: Dictionary = raw_entry as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		var entry_name: String = str(entry.get("name", ""))
		assert(not entry_id.is_empty(), "%s entries must have an id" % collection_name)
		assert(not entry_name.is_empty(), "%s entries must have a name" % collection_name)
		assert(
			not identifiers.has(entry_id),
			"%s contains duplicate id: %s" % [collection_name, entry_id]
		)
		identifiers[entry_id] = true


func _write_invalid_json() -> void:
	var file := FileAccess.open(INVALID_PATH, FileAccess.WRITE)
	assert(file != null, "The invalid JSON fixture must be writable")
	if file == null:
		return
	file.store_string("{invalid json")
	file.close()


func _remove_user_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert(error == OK, "Temporary test file could not be removed: %s" % path)
