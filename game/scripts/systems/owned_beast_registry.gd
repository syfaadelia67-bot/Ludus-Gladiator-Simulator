extends Node

signal owned_beasts_changed

var owned_beasts: Array[Dictionary] = []


func get_owned_beasts() -> Array[Dictionary]:
	return owned_beasts.duplicate(true)


func get_owned_count() -> int:
	return owned_beasts.size()


func owns_instance(instance_id: String) -> bool:
	for entry in owned_beasts:
		if str(entry.get("instance_id", "")) == instance_id:
			return true
	return false


func register_owned_beast(instance_id: String, beast_id: String) -> bool:
	if instance_id.is_empty() or owns_instance(instance_id) or not _is_canonical_beast_id(beast_id):
		return false
	owned_beasts.append({"instance_id": instance_id, "beast_id": beast_id})
	owned_beasts_changed.emit()
	return true


func release_owned_beast(instance_id: String) -> bool:
	for entry in owned_beasts:
		if str(entry.get("instance_id", "")) == instance_id:
			owned_beasts.erase(entry)
			owned_beasts_changed.emit()
			return true
	return false


func reset_state() -> void:
	owned_beasts.clear()
	owned_beasts_changed.emit()


func export_state() -> Dictionary:
	return {"entries": owned_beasts.duplicate(true)}


func import_state(data: Dictionary) -> void:
	owned_beasts.clear()
	for raw_entry in data.get("entries", []) as Array:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var instance_id := str(entry.get("instance_id", ""))
		var beast_id := str(entry.get("beast_id", ""))
		if (
			instance_id.is_empty()
			or owns_instance(instance_id)
			or not _is_canonical_beast_id(beast_id)
		):
			continue
		owned_beasts.append({"instance_id": instance_id, "beast_id": beast_id})
	owned_beasts_changed.emit()


func _is_canonical_beast_id(beast_id: String) -> bool:
	if beast_id.is_empty():
		return false
	for raw_beast in DataRepository.beasts:
		if raw_beast is Dictionary and str((raw_beast as Dictionary).get("id", "")) == beast_id:
			return true
	return false
