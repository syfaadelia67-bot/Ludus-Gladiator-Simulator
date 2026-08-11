extends SceneTree

const CombatSkillRuntimeResolverScript = preload(
	"res://scripts/combat/combat_skill_runtime_resolver.gd"
)


func _initialize() -> void:
	DataRepository.load_all()
	var resolver = CombatSkillRuntimeResolverScript.new()
	var indexed := _index(DataRepository.get_skill_mechanics_v1())
	_assert_skill_translation(resolver, indexed)
	_assert_beast_rejection(resolver, indexed)
	_assert_authority_boundary(resolver.get_contract())
	print("Combat V1 skill runtime resolver: OK")
	quit(0)


func _assert_skill_translation(resolver, indexed: Dictionary) -> void:
	var fighter := {"id": "g1", "team": "player", "entity_type": "gladiator"}
	var result: Dictionary = resolver.resolve_desired_action(
		fighter,
		{"actor_id": "g1", "skill_id": "charge", "target_id": "e1"},
		indexed,
	)
	assert(result.get("status") == "ready")
	var desired := result.get("desired_action", {}) as Dictionary
	assert(str(desired.get("actor_id", "")) == "g1")
	assert(str(desired.get("action_id", "")) == "heavy")
	assert(str(desired.get("target_id", "")) == "e1")
	assert(not desired.has("skill_id"))
	var activation := result.get("skill_activation", {}) as Dictionary
	assert(str(activation.get("skill_id", "")) == "charge")
	assert(str(activation.get("mapped_action_id", "")) == "heavy")


func _assert_beast_rejection(resolver, indexed: Dictionary) -> void:
	var beast := {"id": "b1", "team": "enemy", "entity_type": "beast", "beast_id": "lion"}
	var result: Dictionary = resolver.resolve_desired_action(
		beast,
		{"actor_id": "b1", "skill_id": "charge", "target_id": "g1"},
		indexed,
	)
	assert(result.get("status") == "rejected")
	assert(str(result.get("reason", "")) == "beast_skill_forbidden")


func _assert_authority_boundary(contract: Dictionary) -> void:
	assert(contract.get("status") == "frozen")
	assert(contract.get("authority") == "skill_intent_translation_only")
	assert(contract.get("damage_authority") == "combat_simulator")
	assert(contract.get("ko_authority") == "combat_simulator")
	assert(contract.get("winner_authority") == "combat_simulator")
	assert(contract.get("beast_skills_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _index(entries: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		indexed[str(entry.get("id", ""))] = entry.duplicate(true)
	return indexed
