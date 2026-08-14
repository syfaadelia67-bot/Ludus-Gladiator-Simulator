extends Node

var _sanitizing: bool = false


func _ready() -> void:
	EquipmentManager.equipment_changed.connect(_on_equipment_changed)
	RosterManager.roster_changed.connect(_sanitize_all_records)
	GladiatorProgressionManager.progression_changed.connect(_sanitize_all_records)
	call_deferred("_sanitize_all_records")


func _on_equipment_changed(person_id: String) -> void:
	_sanitize_person_record(person_id)


func _sanitize_all_records() -> void:
	if _sanitizing:
		return
	_sanitizing = true
	var changed := false
	for person_id in GladiatorProgressionManager.records.keys():
		changed = _sanitize_person_record_internal(str(person_id)) or changed
	_sanitizing = false
	if changed:
		GladiatorProgressionManager.progression_changed.emit()


func _sanitize_person_record(person_id: String) -> void:
	if _sanitizing:
		return
	_sanitizing = true
	var changed := _sanitize_person_record_internal(person_id)
	_sanitizing = false
	if changed:
		GladiatorProgressionManager.progression_changed.emit()


func _sanitize_person_record_internal(person_id: String) -> bool:
	if not GladiatorProgressionManager.records.has(person_id):
		return false
	var person = RosterManager.get_person(person_id)
	if person == null:
		return false
	var record: Dictionary = GladiatorProgressionManager.records[person_id]
	var learned: Dictionary = record.get("abilities", {})
	var current_plan: Array = record.get("tactical_plan", [])
	var sanitized: Array[Dictionary] = []
	for raw_order in current_plan:
		if not raw_order is Dictionary or sanitized.size() >= 4:
			continue
		var ability_id := str(raw_order.get("ability_id", ""))
		if int(learned.get(ability_id, 0)) <= 0:
			continue
		if not _tactical_ability_is_available(person, ability_id):
			continue
		(
			sanitized
			. append(
				{
					"ability_id": ability_id,
					"condition": str(raw_order.get("condition", "always")),
				}
			)
		)
	if sanitized == current_plan:
		return false
	record["tactical_plan"] = sanitized
	GladiatorProgressionManager.records[person_id] = record
	return true


func get_blocked_learned_abilities(person_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var person = RosterManager.get_person(person_id)
	if person == null:
		return result
	var record := GladiatorProgressionManager.get_record(person_id)
	var learned: Dictionary = record.get("abilities", {})
	for ability_id in learned.keys():
		if int(learned.get(ability_id, 0)) <= 0:
			continue
		var ability_id_string := str(ability_id)
		if _is_canonical_combat_v1_skill(ability_id_string):
			continue
		var ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id_string, {})
		if EquipmentManager.can_use_ability(person, ability):
			continue
		(
			result
			. append(
				{
					"ability_id": ability_id_string,
					"name": str(ability.get("name", ability_id)),
					"requirement": EquipmentManager.get_ability_requirement(ability),
				}
			)
		)
	return result


func _tactical_ability_is_available(person, ability_id: String) -> bool:
	if _is_canonical_combat_v1_skill(ability_id):
		# Combat V1 equipment requirements are evaluated at decision time by the
		# canonical skill runtime resolver. Keeping the order here allows LimboAI
		# to skip an unavailable skill and continue down the Tactical Plan.
		return true
	var legacy_ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
	return EquipmentManager.can_use_ability(person, legacy_ability)


func _is_canonical_combat_v1_skill(ability_id: String) -> bool:
	if ability_id.is_empty():
		return false
	return (
		not DataRepository.get_skill(ability_id).is_empty()
		and not DataRepository.get_skill_mechanics_v1_entry(ability_id).is_empty()
	)
