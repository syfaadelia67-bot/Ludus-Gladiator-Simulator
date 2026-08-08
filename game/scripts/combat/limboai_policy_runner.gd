extends RefCounted

const LimboAIPolicyAdapterScript = preload("res://scripts/combat/limboai_policy_adapter.gd")
const LimboAIPolicyTreeFactoryScript = preload(
	"res://scripts/combat/limboai_policy_tree_factory.gd"
)

var _adapter = LimboAIPolicyAdapterScript.new()
var _tree_factory = LimboAIPolicyTreeFactoryScript.new()


func evaluate_proposal(
	state: Dictionary,
	actor_id: String,
	policy_proposal: Dictionary,
	agent: Node,
	instance_owner: Node
) -> Dictionary:
	if agent == null or instance_owner == null:
		return _rejected(
			"invalid_runtime_owner", ["Policy runner requires agent and instance_owner"]
		)

	var context_result: Dictionary = _adapter.build_policy_context(state, actor_id)
	if context_result.get("status") != "ready":
		return _rejected(
			str(context_result.get("status", "invalid_context")),
			_to_string_array(context_result.get("errors", []))
		)

	var runtime: Dictionary = _adapter.prepare_runtime_objects()
	if runtime.get("status") != "ready":
		return _rejected(
			str(runtime.get("status", "runtime_unavailable")), ["LimboAI runtime is not ready"]
		)

	var context := context_result.get("context", {}) as Dictionary
	var write_result: Dictionary = _adapter.write_policy_context_to_blackboard(runtime, context)
	if write_result.get("status") != "ready":
		_adapter.release_runtime_objects(runtime)
		return _rejected(
			str(write_result.get("status", "blackboard_write_failed")),
			_to_string_array(write_result.get("errors", []))
		)

	var objects := runtime.get("objects", {}) as Dictionary
	var blackboard: Object = objects.get("blackboard") as Object
	blackboard.call("set_var", &"policy_proposal", policy_proposal.duplicate(true))

	var behavior_tree: Object = _tree_factory.create_policy_tree()
	if behavior_tree == null:
		_adapter.release_runtime_objects(runtime)
		return _rejected("tree_unavailable", ["LimboAI policy tree could not be created"])

	var bt_instance: Object = behavior_tree.call(
		"instantiate", agent, blackboard, instance_owner, instance_owner
	)
	if bt_instance == null:
		_adapter.release_runtime_objects(runtime)
		return _rejected("tree_instantiation_failed", ["LimboAI policy tree could not instantiate"])

	bt_instance.call("update", 0.0)
	var desired_action: Dictionary = _adapter.read_desired_action_from_blackboard(runtime)
	var policy_errors := _to_string_array(blackboard.call("get_var", &"policy_errors", []))
	_adapter.release_runtime_objects(runtime)

	if desired_action.is_empty():
		return _rejected("proposal_rejected", policy_errors)
	return {
		"status": "ready",
		"provider": "limboai",
		"errors": [],
		"desired_action": desired_action,
	}


func _rejected(status: String, errors: Array[String]) -> Dictionary:
	return {
		"status": status,
		"provider": "limboai",
		"errors": errors.duplicate(),
		"desired_action": {},
	}


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is not Array:
		return result
	for item in value as Array:
		result.append(str(item))
	return result
