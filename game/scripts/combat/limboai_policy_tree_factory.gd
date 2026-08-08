extends RefCounted

const PublishDesiredActionTaskScript = preload("res://ai/tasks/combat/publish_desired_action.gd")


func create_policy_tree() -> Object:
	if not ClassDB.class_exists("BehaviorTree"):
		return null
	var behavior_tree: Object = ClassDB.instantiate("BehaviorTree")
	if behavior_tree == null or not behavior_tree.has_method("set_root_task"):
		return null
	behavior_tree.call("set_root_task", PublishDesiredActionTaskScript.new())
	return behavior_tree
