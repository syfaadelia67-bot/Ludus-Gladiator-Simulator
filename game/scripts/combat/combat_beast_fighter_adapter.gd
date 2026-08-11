extends RefCounted

const BeastCombatV1DataContractScript = preload(
	"res://scripts/core/beast_combat_v1_data_contract.gd"
)
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")

const REQUIRED_BEAST_IDS: Array[String] = ["bear", "boar", "lion"]
const REQUIRED_STAT_IDS: Array[String] = ["FUE", "AGI", "TEC", "RES", "PV"]
const REQUIRED_RESTRICTIONS := {
	"technique_label": "Instinto",
	"can_block": false,
	"can_parry": false,
	"has_skills": false,
	"has_traits": false,
	"has_specialization": false,
	"uses_equipment": false,
	"uses_routines": false,
	"uses_loyalty": false,
	"uses_fame": false,
	"can_train": false,
}

var _data_contract = BeastCombatV1DataContractScript.new()
var _combat_contract = CombatContractScript.new()


func build_from_beast_id(beast_id: String, fighter_id: String, team_id: String) -> Dictionary:
	var beast := _find_beast(DataRepository.beasts, beast_id)
	if beast.is_empty():
		return _invalid(["Unknown canonical Combat V1 beast id: %s" % beast_id])
	return build_fighter(beast, fighter_id, team_id)


func build_fighter(beast_source: Dictionary, fighter_id: String, team_id: String) -> Dictionary:
	var errors := _validate_beast_source(beast_source)
	if fighter_id.is_empty():
		errors.append("Combat beast fighter requires non-empty fighter_id")
	if team_id.is_empty():
		errors.append("Combat beast fighter requires non-empty team_id")
	if not errors.is_empty():
		return _invalid(errors)

	var stats: Dictionary = {}
	for stat_id in REQUIRED_STAT_IDS:
		stats[stat_id] = beast_source[stat_id]
	var beast_id := str(beast_source.get("id", ""))
	var fighter := {
		"id": fighter_id,
		"team": team_id,
		"stats": stats,
		"stamina": float(beast_source.get("stamina", 0.0)),
		"equipment": {"power": 0, "defense": 0},
		"entity_type": "beast",
		"beast_id": beast_id,
		"display_name": str(beast_source.get("name", "")),
		"technique_label": "Instinto",
		"can_block": false,
		"can_parry": false,
		"has_skills": false,
		"uses_equipment": false,
	}
	var snapshot_errors: Array[String] = _combat_contract.validate_fighter_snapshot(fighter)
	if not snapshot_errors.is_empty():
		return _invalid(snapshot_errors)
	return {
		"status": "ready",
		"errors": [],
		"fighter": fighter.duplicate(true),
		"beast_id": beast_id,
		"source": "explicit_canonical_beast_data",
	}


func audit_catalog(beasts: Array) -> Dictionary:
	var errors: Array[String] = _data_contract.validate_entries(beasts)
	for beast_id in REQUIRED_BEAST_IDS:
		var beast := _find_beast(beasts, beast_id)
		if beast.is_empty():
			continue
		var adapted := build_fighter(beast, "beast_audit_%s" % beast_id, "beast_audit_team")
		if adapted.get("status") != "ready":
			for raw_error in adapted.get("errors", []) as Array:
				errors.append("%s: %s" % [beast_id, str(raw_error)])
	return {
		"status": "ready" if errors.is_empty() else "invalid",
		"ready": errors.is_empty(),
		"errors": errors.duplicate(),
		"required_beast_ids": REQUIRED_BEAST_IDS.duplicate(),
		"source": "explicit_canonical_beast_data",
		"save_version_change_required": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"source": "DataRepository.beasts",
		"required_beast_ids": REQUIRED_BEAST_IDS.duplicate(),
		"stat_mapping": {
			"FUE": "FUE",
			"AGI": "AGI",
			"TEC": "TEC",
			"RES": "RES",
			"PV": "PV",
			"stamina": "stamina",
		},
		"equipment_power": 0,
		"equipment_defense": 0,
		"entity_type": "beast",
		"technique_label": "Instinto",
		"block_allowed": false,
		"parry_allowed": false,
		"skills_allowed": false,
		"traits_allowed": false,
		"specialization_allowed": false,
		"equipment_allowed": false,
		"generated_stats_allowed": false,
		"legacy_beast_stats_allowed": false,
		"result_authority": "combat_simulator",
		"save_version_change_required": false,
	}


func _validate_beast_source(beast: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var beast_id := str(beast.get("id", ""))
	if not REQUIRED_BEAST_IDS.has(beast_id):
		return ["Unknown canonical Combat V1 beast id: %s" % beast_id]
	var expected := _data_contract.get_profile(beast_id)
	for stat_id in REQUIRED_STAT_IDS:
		if not beast.has(stat_id) or not _is_numeric(beast.get(stat_id)):
			errors.append("Combat beast %s has invalid canonical %s" % [beast_id, stat_id])
		elif float(beast.get(stat_id)) != float(expected.get(stat_id)):
			errors.append("Combat beast %s has non-canonical %s" % [beast_id, stat_id])
	if not beast.has("stamina") or not _is_numeric(beast.get("stamina")):
		errors.append("Combat beast %s has invalid canonical stamina" % beast_id)
	elif float(beast.get("stamina")) != float(expected.get("stamina")):
		errors.append("Combat beast %s has non-canonical stamina" % beast_id)
	for field_name in REQUIRED_RESTRICTIONS.keys():
		if not beast.has(field_name) or beast.get(field_name) != REQUIRED_RESTRICTIONS[field_name]:
			errors.append(
			"Combat beast %s violates canonical restriction %s" % [beast_id, field_name]
		)
	return errors


func _find_beast(beasts: Array, beast_id: String) -> Dictionary:
	for raw_beast in beasts:
		if raw_beast is Dictionary and str((raw_beast as Dictionary).get("id", "")) == beast_id:
			return (raw_beast as Dictionary).duplicate(true)
	return {}


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float


func _invalid(errors: Array[String]) -> Dictionary:
	return {
		"status": "invalid",
		"errors": errors.duplicate(),
		"fighter": {},
		"beast_id": "",
		"source": "",
	}
