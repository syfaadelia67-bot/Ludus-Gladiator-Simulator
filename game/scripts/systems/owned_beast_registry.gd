extends Node

signal owned_beasts_changed

var owned_beast_ids: Array[String] = []


func get_owned_beast_ids() -> Array[String]:
	return owned_beast_ids.duplicate()


func get_owned_count() -> int:
	return owned_beast_ids.size()


func owns(beast_id: String) -> bool:
	return owned_beast_ids.has(beast_id)


func register_owned_beast(beast_id: String) -> bool:
	if not _is_canonical_beast_id(beast_id) or owned_beast_ids.has(beast_id):
		return false
	owned_beast_ids.append(beast_id)
	owned_beasts_changed.emit()
	return true


func release_owned_beast(beast_id: String) -> bool:
	if not owned_beast_ids.has(beast_id):
		return false
	owned_beast_ids.erase(beast_id)
	owned_beasts_changed.emit()
	return true


func reset_state() -> void:
	owned_beast_ids.clear()
	owned_beasts_changed.emit()


func export_state() -> Dictionary:
	return {"ids": owned_beast_ids.duplicate()}


func import_state(data: Dictionary) -> void:
	owned_beast_ids.clear()
	for raw_id in data.get("ids", []) as Array:
		var beast_id := str(raw_id)
		if _is_canonical_beast_id(beast_id) and not owned_beast_ids.has(beast_id):
			owned_beast_ids.append(beast_id)
	owned_beasts_changed.emit()


func _is_canonical_beast_id(beast_id: String) -> bool:
	if beast_id.is_empty():
		return false
	for raw_beast in DataRepository.beasts:
		if raw_beast is Dictionary and str((raw_beast as Dictionary).get("id", "")) == beast_id:
			return true
	return false
