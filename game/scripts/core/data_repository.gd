extends Node

const FrozenDataValidatorScript = preload("res://scripts/core/frozen_data_validator.gd")
const EquipmentDataValidatorScript = preload("res://scripts/core/equipment_data_validator.gd")
const RivalLudiDataValidatorScript = preload("res://scripts/core/rival_ludi_data_validator.gd")

var traits: Array = []
var buildings: Array = []
var weapons: Array = []
# Legacy combat abilities are kept temporarily for old presentation/runtime compatibility.
# Frozen Combat V1 skill identity lives in skills.json and must not be inferred from this array.
var abilities: Array = []
var skills: Array = []
var specializations: Array = []
var beasts: Array = []
var rival_ludi: Array = []
var unique_gladiators: Array = []
var economy_rules: Array = []
var frozen_contract_errors: Array[String] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	traits = _load_json_array("res://data/traits.json")
	buildings = _load_json_array("res://data/buildings.json")
	weapons = _load_json_array("res://data/weapons.json")
	abilities = _load_json_array("res://data/abilities.json")
	skills = _load_json_array("res://data/skills.json")
	specializations = _load_json_array("res://data/specializations.json")
	beasts = _load_json_array("res://data/beasts.json")
	rival_ludi = _load_json_array("res://data/rival_ludi.json")
	unique_gladiators = _load_json_array("res://data/unique_gladiators.json")
	economy_rules = _load_json_array("res://data/economy_rules.json")
	_validate_frozen_contracts()


func _validate_frozen_contracts() -> void:
	var frozen_validator = FrozenDataValidatorScript.new()
	var equipment_validator = EquipmentDataValidatorScript.new()
	var rival_ludi_validator = RivalLudiDataValidatorScript.new()
	frozen_contract_errors = frozen_validator.validate_repository(self)
	frozen_contract_errors.append_array(equipment_validator.validate_repository(self))
	frozen_contract_errors.append_array(rival_ludi_validator.validate_repository(self))
	for error_message in frozen_contract_errors:
		push_error("Frozen data contract: %s" % error_message)


func is_frozen_contract_valid() -> bool:
	return frozen_contract_errors.is_empty()


func get_frozen_contract_errors() -> Array[String]:
	return frozen_contract_errors.duplicate()


func get_unique_gladiator(gladiator_id: String) -> Dictionary:
	for entry in unique_gladiators:
		if entry is Dictionary and str(entry.get("id", "")) == gladiator_id:
			return entry.duplicate(true)
	return {}


func get_buildings() -> Array:
	return buildings.duplicate(true)


func get_building(building_id: String) -> Dictionary:
	for entry in buildings:
		if entry is Dictionary and str(entry.get("id", "")) == building_id:
			return entry.duplicate(true)
	return {}


func get_skills() -> Array:
	return skills.duplicate(true)


func get_skill(skill_id: String) -> Dictionary:
	for entry in skills:
		if entry is Dictionary and str(entry.get("id", "")) == skill_id:
			return entry.duplicate(true)
	return {}


func get_rival_ludi() -> Array:
	return rival_ludi.duplicate(true)


func get_rival_ludus(rival_id: String) -> Dictionary:
	for entry in rival_ludi:
		if entry is Dictionary and str(entry.get("id", "")) == rival_id:
			return entry.duplicate(true)
	return {}


func get_economy_rule(rule_id: String) -> Dictionary:
	for entry in economy_rules:
		if entry is Dictionary and str(entry.get("id", "")) == rule_id:
			return entry.duplicate(true)
	return {}


func get_unique_gladiators_for_stage(stage: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in unique_gladiators:
		if entry is Dictionary and str(entry.get("release_stage", "")) == stage:
			result.append(entry.duplicate(true))
	return result


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		print_verbose("No se encontró: %s" % path)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print_verbose("No se pudo abrir: %s" % path)
		return []

	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error == OK and json.data is Array:
		return json.data

	print_verbose("El archivo no contiene un Array válido: %s" % path)
	return []
