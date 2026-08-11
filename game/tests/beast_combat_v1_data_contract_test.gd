extends Node

const BeastCombatV1DataContractScript = preload(
	"res://scripts/core/beast_combat_v1_data_contract.gd"
)


func run() -> void:
	DataRepository.load_all()
	var contract = BeastCombatV1DataContractScript.new()
	_test_canonical_catalog(contract)
	_test_changed_stat_is_rejected(contract)
	_test_missing_stamina_is_rejected(contract)
	_test_unfrozen_mechanical_field_is_rejected(contract)
	_test_contract_metadata(contract)
	print("Beast Combat V1 canonical data contract: OK")


func _test_canonical_catalog(contract) -> void:
	var errors: Array[String] = contract.validate_entries(DataRepository.beasts)
	assert(errors.is_empty(), "Canonical beast profiles must validate cleanly: %s" % [errors])
	assert(
		(
			contract.get_profile("boar")
			== {"FUE": 7, "AGI": 5, "TEC": 6, "RES": 6, "PV": 56, "stamina": 10}
		)
	)
	assert(
		(
			contract.get_profile("lion")
			== {"FUE": 8, "AGI": 9, "TEC": 8, "RES": 5, "PV": 55, "stamina": 10}
		)
	)
	assert(
		(
			contract.get_profile("bear")
			== {"FUE": 10, "AGI": 4, "TEC": 5, "RES": 8, "PV": 68, "stamina": 10}
		)
	)


func _test_changed_stat_is_rejected(contract) -> void:
	var fixture := DataRepository.beasts.duplicate(true)
	for raw_beast in fixture:
		var beast := raw_beast as Dictionary
		if str(beast.get("id", "")) == "bear":
			beast["FUE"] = 9
			break
	var errors: Array[String] = contract.validate_entries(fixture)
	assert(errors.has("Demo beast bear has non-canonical FUE"))


func _test_missing_stamina_is_rejected(contract) -> void:
	var fixture := DataRepository.beasts.duplicate(true)
	for raw_beast in fixture:
		var beast := raw_beast as Dictionary
		if str(beast.get("id", "")) == "boar":
			beast.erase("stamina")
			break
	var errors: Array[String] = contract.validate_entries(fixture)
	assert(errors.has("Demo beast boar is missing canonical stamina"))


func _test_unfrozen_mechanical_field_is_rejected(contract) -> void:
	var fixture := DataRepository.beasts.duplicate(true)
	for raw_beast in fixture:
		var beast := raw_beast as Dictionary
		if str(beast.get("id", "")) == "lion":
			beast["damage_bonus"] = 2
			break
	var errors: Array[String] = contract.validate_entries(fixture)
	assert(errors.has("Demo beast lion contains unfrozen Combat V1 field: damage_bonus"))


func _test_contract_metadata(contract) -> void:
	var metadata: Dictionary = contract.get_contract()
	assert(metadata.get("status") == "frozen")
	assert(metadata.get("requires_stamina") == true)
	assert(metadata.get("source") == "explicit_canonical_beast_data")
	assert(metadata.get("generated_stats_allowed") == false)
	assert(metadata.get("legacy_beast_stats_allowed") == false)
	assert(metadata.get("save_version_change_required") == false)
