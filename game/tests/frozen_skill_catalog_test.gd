extends Node

const EXPECTED_GENERAL := {
	"aid": "Auxilio",
	"charge": "Embestida",
	"closed_guard": "Guardia Cerrada",
	"counterattack": "Contraataque",
	"demolisher": "Demoledor",
	"execution": "Ejecución",
	"feint": "Finta",
	"provoke": "Provocación",
}
const EXPECTED_SPECIALIZED := {
	"anchor": "Anclaje",
	"disarm": "Desarme",
	"immobilization": "Inmovilización",
	"interception": "Intercepción",
}


func _ready() -> void:
	var skills := DataRepository.get_skills()
	assert(skills.size() == 12, "Frozen combat data must expose exactly twelve skills")
	assert(DataRepository.is_frozen_contract_valid(), "Frozen data validator must accept canonical skills")

	var seen: Dictionary = {}
	for raw_entry in skills:
		assert(raw_entry is Dictionary, "Every frozen skill must be a Dictionary")
		var entry: Dictionary = raw_entry
		var skill_id := str(entry.get("id", ""))
		seen[skill_id] = true
		assert(entry.keys().size() == 3, "Frozen skill identity must not contain unfrozen mechanics")
		if EXPECTED_GENERAL.has(skill_id):
			assert(str(entry.get("name", "")) == EXPECTED_GENERAL[skill_id])
			assert(str(entry.get("category", "")) == "general")
		elif EXPECTED_SPECIALIZED.has(skill_id):
			assert(str(entry.get("name", "")) == EXPECTED_SPECIALIZED[skill_id])
			assert(str(entry.get("category", "")) == "specialized")
		else:
			assert(false, "Unexpected frozen skill: %s" % skill_id)

	for skill_id in EXPECTED_GENERAL.keys():
		assert(seen.has(skill_id), "Missing frozen general skill: %s" % skill_id)
	for skill_id in EXPECTED_SPECIALIZED.keys():
		assert(seen.has(skill_id), "Missing frozen specialized skill: %s" % skill_id)

	assert(
		not DataRepository.abilities.is_empty(),
		"Legacy ability data must remain available until old CombatManager is retired"
	)
	print("Frozen twelve-skill catalog tests passed")
	get_tree().quit(0)
