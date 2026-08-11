extends Node

const CanonicalSkillMechanicsContractScript = preload(
	"res://scripts/core/canonical_skill_mechanics_contract.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var contract = CanonicalSkillMechanicsContractScript.new()
	var production: Dictionary = contract.evaluate(
		DataRepository.get_skills(), DataRepository.get_skill_mechanics_v1(), true
	)
	assert(production.get("ready") == true)
	assert(production.get("design_ready") == true)
	assert(production.get("runtime_resolver_ready") == true)
	assert((production.get("missing_mechanics_ids", []) as Array).is_empty())
	assert((production.get("missing_progression_ids", []) as Array).is_empty())
	print("Canonical Combat V1 skill mechanics boundary: OK")
	get_tree().quit(0)
