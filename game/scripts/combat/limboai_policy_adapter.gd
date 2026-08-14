extends RefCounted

const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatPolicyContextBuilderScript = preload(
	"res://scripts/combat/combat_policy_context_builder.gd"
)

const REQUIRED_LIMBOAI_CLASSES := [
	"BehaviorTree",
	"BTPlayer",
	"BTAction",
	"Blackboard",
	"LimboHSM",
	"LimboState",
]
const POLICY_CONTEXT_KEYS := [
	"format",
	"actor",
	"actor_id",
	"allies",
	"enemies",
	"available_action_ids",
	"action_contracts",
	"target_candidates",
	"legal_targets",
	"combat_state",
	"tactical_plan",
	"exchange_index",
	"last_exchange_result",
	"desired_action",
]

var _policy_contract = CombatPolicyContractScript.new()
var _context_builder = CombatPolicyContextBuilderScript.new()


func is_limboai_available() -> bool:
	for required_class in REQUIRED_LIMBOAI_CLASSES:
		if not ClassDB.class_exists(required_class):
			return false
	return true


func get_runtime_status() -> Dictionary:
	var missing_classes: Array[String] = []
	for required_class in REQUIRED_LIMBOAI_CLASSES:
		if not ClassDB.class_exists(required_class):
			missing_classes.append(required_class)
	return {
		"provider": "limboai",
		"version_contract": "1.6.0",
		"available": missing_classes.is_empty(),
		"missing_classes": missing_classes,
	}


func build_policy_context(
	state: Dictionary, actor_id: String, decision_context: Dictionary = {}
) -> Dictionary:
	return _context_builder.build_context(state, actor_id, decision_context)


func extract_desired_action(policy_context: Dictionary) -> Dictionary:
	var desired_action_value: Variant = policy_context.get("desired_action", {})
	if desired_action_value is not Dictionary:
		return {}
	return (desired_action_value as Dictionary).duplicate(true)


func validate_policy_output(state: Dictionary, desired_action: Dictionary) -> Array[String]:
	return _policy_contract.validate_desired_action(state, desired_action)


func write_policy_context_to_blackboard(
	runtime_objects: Dictionary, policy_context: Dictionary
) -> Dictionary:
	var blackboard := _get_blackboard(runtime_objects)
	if blackboard == null:
		return {
			"status": "blackboard_unavailable",
			"errors": ["LimboAI runtime does not expose a usable Blackboard"],
		}

	for key in POLICY_CONTEXT_KEYS:
		if not policy_context.has(key):
			return {
				"status": "invalid_context",
				"errors": ["Policy context is missing key: %s" % key],
			}
		blackboard.call("set_var", StringName(key), _isolate_value(policy_context[key]))

	return {"status": "ready", "errors": []}


func read_desired_action_from_blackboard(runtime_objects: Dictionary) -> Dictionary:
	var blackboard := _get_blackboard(runtime_objects)
	if blackboard == null:
		return {}
	var desired_action: Variant = blackboard.call("get_var", &"desired_action", {})
	if desired_action is not Dictionary:
		return {}
	return (desired_action as Dictionary).duplicate(true)


func prepare_runtime_objects() -> Dictionary:
	if not is_limboai_available():
		return {
			"status": "unavailable",
			"provider": "limboai",
			"objects": {},
		}

	var bt_player: Object = ClassDB.instantiate("BTPlayer")
	var behavior_tree: Object = ClassDB.instantiate("BehaviorTree")
	var blackboard: Object = ClassDB.instantiate("Blackboard")
	if bt_player == null or behavior_tree == null or blackboard == null:
		if bt_player != null and bt_player is Node:
			(bt_player as Node).free()
		return {
			"status": "initialization_failed",
			"provider": "limboai",
			"objects": {},
		}

	return {
		"status": "ready",
		"provider": "limboai",
		"objects":
		{
			"bt_player": bt_player,
			"behavior_tree": behavior_tree,
			"blackboard": blackboard,
		},
	}


func release_runtime_objects(runtime_objects: Dictionary) -> void:
	var objects_value: Variant = runtime_objects.get("objects", {})
	if objects_value is not Dictionary:
		return
	var objects := objects_value as Dictionary
	var bt_player: Variant = objects.get("bt_player")
	if bt_player is Node:
		(bt_player as Node).free()
	# BehaviorTree and Blackboard are RefCounted in the GDExtension contract.
	objects.clear()


func _get_blackboard(runtime_objects: Dictionary) -> Object:
	var objects_value: Variant = runtime_objects.get("objects", {})
	if objects_value is not Dictionary:
		return null
	var blackboard: Variant = (objects_value as Dictionary).get("blackboard")
	if blackboard == null or not blackboard is Object:
		return null
	var blackboard_object := blackboard as Object
	if not blackboard_object.has_method("set_var") or not blackboard_object.has_method("get_var"):
		return null
	return blackboard_object


func _isolate_value(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
