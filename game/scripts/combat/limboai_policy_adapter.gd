extends RefCounted

const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")

const REQUIRED_LIMBOAI_CLASSES := [
	"BehaviorTree",
	"BTPlayer",
	"BTAction",
	"Blackboard",
	"LimboHSM",
	"LimboState",
]

var _policy_contract = CombatPolicyContractScript.new()


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


func validate_policy_output(state: Dictionary, desired_action: Dictionary) -> Array[String]:
	return _policy_contract.validate_desired_action(state, desired_action)


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
